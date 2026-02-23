from __future__ import annotations

import os
from dataclasses import dataclass


@dataclass(frozen=True)
class BridgeConfig:
    token: str
    allow_hosts: set[str] | None
    idle_timeout_sec: int
    allow_unknown_hosts: bool
    strict_host_keys: bool
    force_utf8_locale: bool


def _parse_allow_hosts(value: str | None) -> set[str] | None:
    if not value:
        return None
    items = [x.strip() for x in value.split(",")]
    items = [x for x in items if x]
    return set(items) if items else None


def load_config_from_env() -> BridgeConfig:
    token = os.getenv("BRIDGE_TOKEN", "").strip()
    if not token:
        raise RuntimeError("Missing BRIDGE_TOKEN env var (required).")

    allow_hosts = _parse_allow_hosts(os.getenv("BRIDGE_ALLOW_HOSTS"))
    idle_timeout_sec = int(os.getenv("BRIDGE_IDLE_TIMEOUT_SEC", "1800"))
    allow_unknown_hosts = os.getenv("BRIDGE_ALLOW_UNKNOWN_HOSTS", "").strip() in ("1", "true", "TRUE", "yes", "YES")
    strict_host_keys = os.getenv("BRIDGE_STRICT_HOST_KEYS", "").strip() in ("1", "true", "TRUE", "yes", "YES")
    # Default ON: most terminal sessions expect UTF-8 output for correct filenames/prompts.
    force_utf8_locale = os.getenv("BRIDGE_FORCE_UTF8_LOCALE", "1").strip() in ("1", "true", "TRUE", "yes", "YES")

    return BridgeConfig(
        token=token,
        allow_hosts=allow_hosts,
        idle_timeout_sec=idle_timeout_sec,
        allow_unknown_hosts=allow_unknown_hosts,
        strict_host_keys=strict_host_keys,
        force_utf8_locale=force_utf8_locale,
    )
