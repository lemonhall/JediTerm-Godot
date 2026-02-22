#!/usr/bin/env python3
from __future__ import annotations

import argparse
import datetime as _dt
import re
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Pair:
    upstream_rel: str
    target_rel: str | None  # None => missing
    target_candidates: tuple[str, ...] = ()


@dataclass(frozen=True)
class FuncRef:
    path: str
    line: int
    name: str


def _camel_to_snake(name: str) -> str:
    out: list[str] = []
    for i, ch in enumerate(name):
        if ch.isupper() and i and (
            name[i - 1].islower() or (i + 1 < len(name) and name[i + 1].islower())
        ):
            out.append("_")
        out.append(ch.lower())
    return "".join(out)


def _norm(name: str) -> str:
    return re.sub(r"[_\s]", "", name).lower()


def _read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="ignore")


def _gd_public_funcs(text: str) -> list[str]:
    funcs = re.findall(
        r"^\s*(?:static\s+)?func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(", text, re.M
    )
    # In this report, treat `_init` specially as a constructor-equivalent.
    public = sorted({f for f in funcs if (not f.startswith("_")) or (f == "_init")})
    return public


def _java_public_methods(text: str, class_name: str) -> list[str]:
    methods: set[str] = set()
    for m in re.finditer(
        r"^\s*(public|protected)\s+(?:static\s+)?[^\(\n;]+\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(",
        text,
        re.M,
    ):
        methods.add(m.group(2))
    # constructors
    for _m in re.finditer(
        r"^\s*(public|protected)\s+" + re.escape(class_name) + r"\s*\(",
        text,
        re.M,
    ):
        methods.add(class_name)
    return sorted(methods)


def _kt_public_methods(text: str) -> list[str]:
    methods: set[str] = set()
    for m in re.finditer(
        r"^\s*(?:(?:public|protected)\s+)?(?:override\s+)?fun\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(",
        text,
        re.M,
    ):
        name = m.group(1)
        methods.add(name)
    return sorted(methods)


def _extract_upstream_public_methods(upstream_path: Path) -> list[str]:
    text = _read_text(upstream_path)
    if upstream_path.suffix == ".java":
        return _java_public_methods(text, upstream_path.stem)
    if upstream_path.suffix == ".kt":
        return _kt_public_methods(text)
    return []


def _method_norm_for_match(upstream_method: str, upstream_class: str) -> str:
    # constructor -> `_init`
    if upstream_method == upstream_class:
        return _norm("_init")
    return _norm(upstream_method)

def _method_norms_for_match(upstream_method: str, upstream_class: str) -> set[str]:
    # In this repo, many value-ish types model constructors as a static factory
    # `static func ClassName(...)` instead of `_init`, so accept both forms.
    if upstream_method == upstream_class:
        return {_norm("_init"), _norm(upstream_class)}
    return {_norm(upstream_method)}


def _is_constructor(upstream_method: str, upstream_class: str) -> bool:
    return upstream_method == upstream_class


def _priority_tag(method_name: str) -> str:
    low = {"equals", "hashcode", "tostring"}
    if _norm(method_name) in low:
        return "P3"
    # Heuristic: getters/setters are typically mechanical, but still user-facing.
    if method_name.startswith(("get", "set", "is")):
        return "P2"
    return "P1"


def _upstream_area(upstream_rel: str) -> str:
    marker = "/com/jediterm/"
    if marker not in upstream_rel:
        return "unknown"
    tail = upstream_rel.split(marker, 1)[1]
    parts = [p for p in tail.split("/") if p]
    if not parts:
        return "unknown"
    return "/".join(parts[:2]) if len(parts) >= 2 else parts[0]


def _index_target_public_funcs(repo_root: Path, gd_root: Path) -> dict[str, list[FuncRef]]:
    index: dict[str, list[FuncRef]] = {}
    for gd_path in sorted(gd_root.rglob("*.gd")):
        rel = gd_path.relative_to(repo_root).as_posix()
        text = _read_text(gd_path)
        for i, line in enumerate(text.splitlines(), start=1):
            m = re.match(
                r"^\s*(?:static\s+)?func\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(", line
            )
            if not m:
                continue
            name = m.group(1)
            if name.startswith("_") and name != "_init":
                continue
            index.setdefault(_norm(name), []).append(FuncRef(path=rel, line=i, name=name))
    return index


def _choose_best_target_candidate(
    repo_root: Path, upstream_path: Path, candidates: list[str]
) -> str:
    upstream_methods = _extract_upstream_public_methods(upstream_path)
    upstream_norm: set[str] = set()
    for m in upstream_methods:
        upstream_norm |= _method_norms_for_match(m, upstream_path.stem)
    if not upstream_norm:
        return candidates[0]

    best = candidates[0]
    best_score = -1
    for c in candidates:
        target_path = repo_root / Path(c)
        target_funcs = _gd_public_funcs(_read_text(target_path))
        target_norm = {_norm(f) for f in target_funcs}
        score = len(upstream_norm & target_norm)
        if score > best_score:
            best = c
            best_score = score
    return best


def _make_pairs(repo_root: Path) -> tuple[list[Pair], list[str], dict[str, list[str]]]:
    upstream_root = (
        repo_root / "refs" / "jediterm-android" / "lib" / "src" / "main" / "java" / "com" / "jediterm"
    )
    gd_root = repo_root / "addons" / "jediterm"

    gd_by_stem: dict[str, list[str]] = {}
    for gd_path in sorted(gd_root.rglob("*.gd")):
        gd_by_stem.setdefault(gd_path.stem, []).append(
            gd_path.relative_to(repo_root).as_posix()
        )

    pairs: list[Pair] = []
    missing_upstream_files: list[str] = []
    matched_upstream_paths_by_target: dict[str, list[str]] = {}

    for upstream_path in sorted(upstream_root.rglob("*")):
        if upstream_path.suffix not in (".java", ".kt"):
            continue
        upstream_rel = upstream_path.relative_to(repo_root).as_posix()
        expected_gd_stem = _camel_to_snake(upstream_path.stem)
        candidates = gd_by_stem.get(expected_gd_stem, [])
        if not candidates:
            pairs.append(Pair(upstream_rel=upstream_rel, target_rel=None, target_candidates=()))
            missing_upstream_files.append(upstream_rel)
            continue
        target_rel = (
            candidates[0]
            if len(candidates) == 1
            else _choose_best_target_candidate(repo_root, upstream_path, candidates)
        )
        pairs.append(
            Pair(
                upstream_rel=upstream_rel,
                target_rel=target_rel,
                target_candidates=tuple(candidates),
            )
        )
        matched_upstream_paths_by_target.setdefault(target_rel, []).append(upstream_rel)

    return pairs, missing_upstream_files, matched_upstream_paths_by_target


def _print_header(repo_root: Path) -> None:
    today = _dt.date.today().isoformat()
    print("# v1 Gap：实现 vs 上游（函数级对齐清单）")
    print("")
    print(f"- 生成日期：{today}")
    print("- 再生成：`python scripts/gen_v1_upstream_gap_report.py > docs/plan/v1-gap-upstream-function-align.md`")
    print("- 上游：`refs/jediterm-android/lib/src/main/java/com/jediterm/**`")
    print("- 目标：`addons/jediterm/**`")
    print("")
    print("本报告用于回答：v1 文档（以“上游测试全绿”为 DoD）之外，距离“上游库实现”在 API/行为上还有哪些差距。")
    print("")
    print("说明（匹配规则）：")
    print("- 仅对齐“上游 public/protected 方法”与“目标脚本的非 `_` 函数 + `_init`”。")
    print("- 方法名做近似匹配：忽略大小写与下划线（例如 `writeString` ≈ `write_string`）。")
    print("- 上游构造函数（与类同名）按 `_init` 对齐（也接受 `static func ClassName(...)` 作为构造等价物）。")
    print("- 该报告是“API 形状”差距清单；行为差异仍以测试与对照阅读为准。")
    print("- “elsewhere 命中”：当缺失的上游方法名在其他目标脚本中出现同名 `func`（可能是合并实现/需要委托）。")
    print("")
    print("v1 当前事实基准：`docs/plan/v1-index.md` 的 suite 全绿（但并不意味着全库 API 完整）。")
    print("")


def _print_file_level(pairs: list[Pair], gd_file_count: int) -> None:
    total = len(pairs)
    matched = sum(1 for p in pairs if p.target_rel is not None)
    missing = total - matched
    ambiguous = sum(1 for p in pairs if p.target_rel is not None and len(p.target_candidates) > 1)
    print("## 文件级覆盖（上游类文件 → 目标脚本）")
    print("")
    print(f"- 上游类文件数（com/jediterm）：{total}")
    print(f"- 目标脚本数（addons/jediterm）：{gd_file_count}")
    print(f"- 1:1 命名匹配到的脚本：{matched}")
    print(f"- 未匹配（多为未移植/架构差异/合并实现）：{missing}")
    if ambiguous:
        print(f"- 多候选匹配（同 stem 多个脚本）：{ambiguous}（已用“方法名重叠度”挑选最可能目标）")
    print("")
    print("| Upstream | Target | Status |")
    print("|---|---|---|")
    for p in pairs:
        if p.target_rel is None:
            print(f"| `{p.upstream_rel}` | (none) | missing |")
        else:
            status = "present"
            if len(p.target_candidates) > 1:
                status = "present (ambiguous)"
            print(f"| `{p.upstream_rel}` | `{p.target_rel}` | {status} |")
    print("")

    ambiguous_pairs = [p for p in pairs if p.target_rel is not None and len(p.target_candidates) > 1]
    if ambiguous_pairs:
        print("### 备注：多候选文件名匹配")
        print("")
        print("以下 upstream 文件的期望 stem 在目标侧命中多个脚本，报告已自动选择“重叠度最高”的目标；其余候选列出供人工复核：")
        print("")
        for p in ambiguous_pairs:
            others = [c for c in p.target_candidates if c != p.target_rel]
            other_str = ", ".join(f"`{o}`" for o in others)
            print(f"- `{p.upstream_rel}` → `{p.target_rel}`（其他：{other_str}）")
        print("")


def _print_known_divergences(repo_root: Path, matched_upstream_paths_by_target: dict[str, list[str]]) -> None:
    print("## 结构性差异（非 1:1 文件映射）")
    print("")
    print("以下是 v1 测试可绿但与上游架构明显不同、后续补齐需要重点关注的点：")
    print("")

    # 1) Emulator
    print("- **Emulator 架构**：上游有 `Emulator`/`DataStreamIteratingEmulator`/`JediEmulator`（流式 + ControlSequence/OSC/鼠标/字符集等）；目标目前以 `addons/jediterm/terminal/emulator/ansi_input_processor.gd` 作为“字符串扫描处理器”。")
    print("  - 影响：上游的 `TerminalDataStream`、`ControlSequence`、字符集/鼠标模式等 API 目前未完整落地；部分行为被折叠进 `AnsiInputProcessor` + `JediTerminal`。")
    print("")

    # 2) BackBufferDisplay
    print("- **Display/渲染端契约**：上游有 `TerminalDisplay`、`TerminalOutputStream`、`TerminalStarter` 等；目标当前的 `addons/jediterm/util/back_buffer_display.gd` 更偏测试/内存断言用途。")
    print("")

    # 3) SynchronizedOutput
    print("- **SynchronizedOutput**：上游在 `terminal/emulator/SynchronizedOutput.kt` 内有独立实现；目标仓库未见同名脚本（行为可能被测试 harness/输入处理器吸收）。")
    print("")

    # Orphan targets (target exists but not matched from upstream by name)
    gd_root = repo_root / "addons" / "jediterm"
    all_targets = {p.relative_to(repo_root).as_posix() for p in gd_root.rglob("*.gd")}
    matched_targets = set(matched_upstream_paths_by_target.keys())
    orphans = sorted(all_targets - matched_targets)
    if orphans:
        print("### 目标侧“无上游同名文件”脚本（可能为合并实现/辅助类）")
        for t in orphans:
            print(f"- `{t}`")
        print("")

def _format_elsewhere_hits(hits: list[FuncRef], max_items: int = 2) -> str:
    if not hits:
        return ""
    shown = hits[:max_items]
    rendered = ", ".join(f"`{h.path}:{h.line}`" for h in shown)
    extra = len(hits) - len(shown)
    if extra > 0:
        rendered = f"{rendered}（+{extra}）"
    return rendered


def _collect_gap_stats(
    repo_root: Path,
    pairs: list[Pair],
    target_func_index: dict[str, list[FuncRef]],
) -> dict[str, object]:
    stats: dict[str, object] = {}

    matched_pairs = [p for p in pairs if p.target_rel is not None]
    missing_only_pairs = [p for p in pairs if p.target_rel is None]

    prio_counts_matched = {"P1": 0, "P2": 0, "P3": 0}
    prio_counts_missing_only = {"P1": 0, "P2": 0, "P3": 0}
    missing_methods_matched_total = 0
    extra_funcs_total = 0
    missing_methods_missing_only_total = 0
    elsewhere_hits_total = 0
    elsewhere_hits_p1_total = 0
    area_p1: dict[str, int] = {}
    top_by_p1: list[tuple[str, int, str | None]] = []

    for p in matched_pairs:
        upstream_path = repo_root / Path(p.upstream_rel)
        target_path = repo_root / Path(p.target_rel)
        upstream_methods = _extract_upstream_public_methods(upstream_path)
        target_funcs = _gd_public_funcs(_read_text(target_path))

        upstream_norm: set[str] = set()
        for m in upstream_methods:
            upstream_norm |= _method_norms_for_match(m, upstream_path.stem)
        target_norm = {_norm(m) for m in target_funcs}

        missing = [
            m
            for m in upstream_methods
            if not (_method_norms_for_match(m, upstream_path.stem) & target_norm)
        ]
        extra = [f for f in target_funcs if _norm(f) not in upstream_norm]

        missing_methods_matched_total += len(missing)
        extra_funcs_total += len(extra)

        p1_count = 0
        for m in missing:
            pr = _priority_tag(m)
            prio_counts_matched[pr] += 1
            if pr == "P1":
                p1_count += 1
            if not _is_constructor(m, upstream_path.stem):
                mn = _method_norm_for_match(m, upstream_path.stem)
                hits = [h for h in target_func_index.get(mn, []) if h.path != p.target_rel]
                if hits:
                    elsewhere_hits_total += 1
                    if pr == "P1":
                        elsewhere_hits_p1_total += 1

        area = _upstream_area(p.upstream_rel)
        area_p1[area] = area_p1.get(area, 0) + p1_count
        top_by_p1.append((p.upstream_rel, p1_count, p.target_rel))

    for p in missing_only_pairs:
        upstream_path = repo_root / Path(p.upstream_rel)
        upstream_methods = _extract_upstream_public_methods(upstream_path)
        missing_methods_missing_only_total += len(upstream_methods)

        p1_count = 0
        for m in upstream_methods:
            pr = _priority_tag(m)
            prio_counts_missing_only[pr] += 1
            if pr == "P1":
                p1_count += 1
            if not _is_constructor(m, upstream_path.stem):
                mn = _method_norm_for_match(m, upstream_path.stem)
                hits = target_func_index.get(mn, [])
                if hits:
                    elsewhere_hits_total += 1
                    if pr == "P1":
                        elsewhere_hits_p1_total += 1

        area = _upstream_area(p.upstream_rel)
        area_p1[area] = area_p1.get(area, 0) + p1_count
        top_by_p1.append((p.upstream_rel, p1_count, None))

    stats["prio_counts_matched"] = prio_counts_matched
    stats["prio_counts_missing_only"] = prio_counts_missing_only
    stats["missing_methods_matched_total"] = missing_methods_matched_total
    stats["missing_methods_missing_only_total"] = missing_methods_missing_only_total
    stats["extra_funcs_total"] = extra_funcs_total
    stats["elsewhere_hits_total"] = elsewhere_hits_total
    stats["elsewhere_hits_p1_total"] = elsewhere_hits_p1_total
    stats["area_p1"] = area_p1
    stats["top_by_p1"] = sorted(top_by_p1, key=lambda x: x[1], reverse=True)
    return stats


def _print_summary(
    repo_root: Path,
    pairs: list[Pair],
    gd_file_count: int,
    target_func_index: dict[str, list[FuncRef]],
) -> None:
    stats = _collect_gap_stats(repo_root, pairs, target_func_index)
    prio_counts_matched = stats["prio_counts_matched"]  # type: ignore[assignment]
    prio_counts_missing_only = stats["prio_counts_missing_only"]  # type: ignore[assignment]
    missing_methods_matched_total = int(stats["missing_methods_matched_total"])  # type: ignore[arg-type]
    missing_methods_missing_only_total = int(stats["missing_methods_missing_only_total"])  # type: ignore[arg-type]
    extra_funcs_total = int(stats["extra_funcs_total"])  # type: ignore[arg-type]
    elsewhere_hits_total = int(stats["elsewhere_hits_total"])  # type: ignore[arg-type]
    elsewhere_hits_p1_total = int(stats["elsewhere_hits_p1_total"])  # type: ignore[arg-type]
    area_p1 = stats["area_p1"]  # type: ignore[assignment]
    top_by_p1 = stats["top_by_p1"]  # type: ignore[assignment]

    total_upstream_files = len(pairs)
    matched = sum(1 for p in pairs if p.target_rel is not None)
    missing = total_upstream_files - matched

    print("## 摘要（聚合）")
    print("")
    print(f"- 上游类文件：{total_upstream_files}；目标脚本：{gd_file_count}")
    print(f"- 上游→目标（按文件名 stem）：匹配 {matched} / 缺失 {missing}")
    print(f"- 已匹配类：缺失方法 {missing_methods_matched_total}；额外函数 {extra_funcs_total}")
    print(f"- 缺失类：缺失方法 {missing_methods_missing_only_total}（这些类未有同名目标脚本）")
    print(
        "- 缺失方法优先级（已匹配类）："
        f"P1={prio_counts_matched['P1']}, P2={prio_counts_matched['P2']}, P3={prio_counts_matched['P3']}"
    )
    print(
        "- 缺失方法优先级（缺失类）："
        f"P1={prio_counts_missing_only['P1']}, P2={prio_counts_missing_only['P2']}, P3={prio_counts_missing_only['P3']}"
    )
    print(f"- elsewhere 命中：{elsewhere_hits_total}（其中 P1：{elsewhere_hits_p1_total}）")
    print("")

    print("### Top 缺口（按 P1 数量）")
    print("")
    print("| Upstream | Missing P1 | Target | Area |")
    print("|---|---:|---|---|")
    for upstream_rel, p1_count, target_rel in top_by_p1[:15]:
        area = _upstream_area(upstream_rel)
        target_cell = f"`{target_rel}`" if target_rel else "(none)"
        print(f"| `{upstream_rel}` | {p1_count} | {target_cell} | `{area}` |")
    print("")

    print("### P1 缺口分布（按 Area）")
    print("")
    print("| Area | Missing P1 |")
    print("|---|---:|")
    for area, count in sorted(area_p1.items(), key=lambda x: x[1], reverse=True)[:15]:
        print(f"| `{area}` | {count} |")
    print("")


def _print_api_gaps(
    repo_root: Path,
    pairs: list[Pair],
    target_func_index: dict[str, list[FuncRef]],
) -> None:
    print("## 函数级差距（API 形状）")
    print("")
    print("下面按“已匹配到目标脚本”的上游类，列出：")
    print("- 上游 `public/protected` 方法中，目标脚本未暴露的函数（Missing）。")
    print("- 目标脚本暴露但上游 public API 中没有的函数（Extra）。")
    print("")
    print("优先级标注（启发式）：")
    print("- P1：可能影响核心行为/外部调用面")
    print("- P2：多为 getters/setters/状态位（通常机械补齐）")
    print("- P3：`equals/hashCode/toString` 等（GDScript 不一定需要，通常低优先级）")
    print("")

    missing_only = [p for p in pairs if p.target_rel is None]
    if missing_only:
        print("### 缺失类（无目标脚本）")
        print("")
        print("这些文件在 `addons/jediterm/**` 下没有同名目标脚本；通常意味着：未移植 / 被合并进其他脚本 / 或命名不一致。")
        print("")
        for p in missing_only:
            upstream_path = repo_root / Path(p.upstream_rel)
            upstream_methods = _extract_upstream_public_methods(upstream_path)
            print(f"- `{p.upstream_rel}`")
            if upstream_methods:
                total_p1 = sum(
                    1
                    for m in upstream_methods
                    if _priority_tag(m) == "P1" and (not _is_constructor(m, upstream_path.stem))
                )
                found_p1 = 0
                found_examples: list[str] = []
                for m in upstream_methods:
                    pr = _priority_tag(m)
                    if pr == "P1":
                        if not _is_constructor(m, upstream_path.stem):
                            mn = _method_norm_for_match(m, upstream_path.stem)
                            hits = target_func_index.get(mn, [])
                            if hits:
                                found_p1 += 1
                                if len(found_examples) < 3:
                                    found_examples.append(
                                        f"`{m}` → {_format_elsewhere_hits(hits, max_items=1)}"
                                    )
                    print(f"  - `{m}` ({_priority_tag(m)})")
                if total_p1 and found_p1:
                    examples = "; ".join(found_examples)
                    print(f"  - Hint：P1 名称 elsewhere 命中 {found_p1}/{total_p1}（例：{examples}）")
            else:
                print("  - （未检测到 public/protected 方法；可能是常量/enum/注解/仅字段）")
        print("")

    print("### 已匹配类（有目标脚本）")
    print("")

    for p in pairs:
        if p.target_rel is None:
            continue
        upstream_path = repo_root / Path(p.upstream_rel)
        target_path = repo_root / Path(p.target_rel)

        upstream_methods = _extract_upstream_public_methods(upstream_path)
        target_funcs = _gd_public_funcs(_read_text(target_path))

        upstream_norm: set[str] = set()
        for m in upstream_methods:
            upstream_norm |= _method_norms_for_match(m, upstream_path.stem)
        target_norm = {_norm(m) for m in target_funcs}

        missing = [
            m
            for m in upstream_methods
            if not (_method_norms_for_match(m, upstream_path.stem) & target_norm)
        ]
        extra = [f for f in target_funcs if _norm(f) not in upstream_norm]

        if not missing and not extra:
            continue

        print(f"### `{p.target_rel}`")
        print(f"- Upstream: `{p.upstream_rel}`")
        if missing:
            elsewhere_count = 0
            for m in missing:
                if not _is_constructor(m, upstream_path.stem):
                    mn = _method_norm_for_match(m, upstream_path.stem)
                    hits = [h for h in target_func_index.get(mn, []) if h.path != p.target_rel]
                    if hits:
                        elsewhere_count += 1
            print(f"- Missing upstream methods: {len(missing)}（elsewhere 命中：{elsewhere_count}）")
            for m in missing:
                if not _is_constructor(m, upstream_path.stem):
                    mn = _method_norm_for_match(m, upstream_path.stem)
                    hits = [h for h in target_func_index.get(mn, []) if h.path != p.target_rel]
                    if hits:
                        print(
                            f"  - `{m}` ({_priority_tag(m)}) → elsewhere: {_format_elsewhere_hits(hits)}"
                        )
                        continue
                print(f"  - `{m}` ({_priority_tag(m)})")
        else:
            print("- Missing upstream methods: 0")

        if extra:
            print(f"- Extra target funcs: {len(extra)}")
            for f in extra:
                print(f"  - `{f}`")
        else:
            print("- Extra target funcs: 0")
        print("")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate v1 upstream gap report (API-level) for JediTerm-Godot."
    )
    _ = parser.parse_args()

    repo_root = Path(__file__).resolve().parents[1]
    pairs, _missing, matched_by_target = _make_pairs(repo_root)
    gd_file_count = len(list((repo_root / "addons" / "jediterm").rglob("*.gd")))
    target_func_index = _index_target_public_funcs(repo_root, repo_root / "addons" / "jediterm")

    _print_header(repo_root)
    _print_summary(repo_root, pairs, gd_file_count, target_func_index)
    _print_file_level(pairs, gd_file_count)
    _print_known_divergences(repo_root, matched_by_target)
    _print_api_gaps(repo_root, pairs, target_func_index)

    print("## 下一轮补齐建议（用于执行）")
    print("")
    print("建议以“先补齐契约，再补齐行为”为顺序：")
    print("- 先把缺失的 *核心 public API* 补齐到位（即便内部先委托/最小实现），让调用面统一。")
    print("- 然后用新增测试（或把上游更多测试纳入）去锁定行为差异。")
    print("")
    print("推荐从这些高杠杆点开始（通常影响范围最大）：")
    print("- `JediTerminal`：窗口标题栈、resize listeners、tabulator、output stream、mouse modes、charset 映射等。")
    print("- `TerminalTextBuffer` / `TerminalLine`：公共访问器（`getLine/getCharAt/getStyleAt` 等）与 listeners/lock/modify。")
    print("- Emulator 架构对齐：引入上游的 `TerminalDataStream` + `ControlSequence`/`JediEmulator` 形态，或明确继续走 `AnsiInputProcessor` 路线并补齐缺失的协议覆盖面。")
    print("")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
