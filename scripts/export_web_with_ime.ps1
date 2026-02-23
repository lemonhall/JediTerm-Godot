Param(
  [string]$GodotExe = $env:GODOT_WIN_EXE,
  [string]$Preset = "Web",
  [string]$OutDir = "",
  [string]$OutHtml = "",
  [switch]$PatchOnly,
  [string]$PatchJsSource = ".\\scripts\\web_ime_patch.js",
  [string]$PatchJsName = "JediTerm-Godot.ime_patch.js"
)

$ErrorActionPreference = "Stop"

function Resolve-ProjectRoot {
  $here = Resolve-Path $PSScriptRoot
  return Resolve-Path (Join-Path $here "..")
}

function Read-ExportPathFromPresets([string]$cfgText, [string]$presetName) {
  $escaped = [regex]::Escape($presetName)
  $pattern = '(?s)\nname="' + $escaped + '"\s*\n.*?\nexport_path="([^"]+)"'
  $m = [regex]::Match($cfgText, $pattern)
  if (-not $m.Success) { return "" }
  return [string]$m.Groups[1].Value
}

function Ensure-Dir([string]$p) {
  if ([string]::IsNullOrWhiteSpace($p)) { return }
  if (!(Test-Path $p)) { [void](New-Item -ItemType Directory -Force -Path $p) }
}

function Patch-HtmlWithIme([string]$htmlPath, [string]$patchJsRelativeName) {
  if (!(Test-Path $htmlPath)) { throw "Missing html: $htmlPath" }

  $html = Get-Content -Raw -Encoding UTF8 $htmlPath

  # Remove previous injected marker block (idempotent).
  $html = [regex]::Replace(
    $html,
    '(?s)\s*<!--\s*JEDITERM_IME_PATCH_BEGIN\s*-->.*?<!--\s*JEDITERM_IME_PATCH_END\s*-->\s*',
    "`n"
  )

  # Remove legacy inline IME bridge block if present.
  $html = [regex]::Replace(
    $html,
    '(?s)\s*/\*\s*=+\s*IME Bridge\s*=+\s*\*/\s*\(function\s*\(\)\s*\{.*?\}\)\(\)\;\s*',
    "`n"
  )

  $inject = @"
<!-- JEDITERM_IME_PATCH_BEGIN -->
<script src="$patchJsRelativeName"></script>
<!-- JEDITERM_IME_PATCH_END -->
"@

  # Ensure there is a hidden IME textarea present (legacy exports may not include it).
  if ($html -notmatch '(?is)<textarea[^>]+id="ime-input"') {
    $imeTextarea = '  <textarea id="ime-input" autocapitalize="off" autocomplete="off" spellcheck="false"></textarea>'
    if ($html -match '(?is)</canvas>') {
      $html = [regex]::Replace($html, '(?is)(</canvas>)', "`$1`n`n$imeTextarea`n", 1)
    } elseif ($html -match '(?is)<body[^>]*>') {
      $html = [regex]::Replace($html, '(?is)(<body[^>]*>)', "`$1`n$imeTextarea`n", 1)
    } else {
      $html = $html + "`n$imeTextarea`n"
    }
  }

  # Prefer injecting right after the engine .js include, before the inline startup script.
  $m = [regex]::Match($html, '(?is)(<script\s+src="[^"]+\.js"\s*>\s*</script>\s*)<script')
  if ($m.Success) {
    $html = [regex]::Replace($html, '(?is)(<script\s+src="[^"]+\.js"\s*>\s*</script>\s*)<script', "`$1`n$inject`n<script", 1)
  } else {
    # Fallback: inject before </body>.
    if ($html -match '(?is)</body>') {
      $html = [regex]::Replace($html, '(?is)</body>', "`n$inject`n</body>", 1)
    } else {
      $html = $html + "`n$inject`n"
    }
  }

  Set-Content -Encoding UTF8 -NoNewline -Path $htmlPath -Value $html
}

$RootDir = Resolve-ProjectRoot
Push-Location $RootDir.Path
try {
  if ([string]::IsNullOrWhiteSpace($OutHtml) -or [string]::IsNullOrWhiteSpace($OutDir)) {
    $presetCfgPath = Join-Path $RootDir.Path "export_presets.cfg"
    if (!(Test-Path $presetCfgPath)) { throw "Missing export_presets.cfg" }
    $cfgText = Get-Content -Raw -Encoding UTF8 $presetCfgPath
    $exportRel = Read-ExportPathFromPresets $cfgText $Preset
    if ([string]::IsNullOrWhiteSpace($exportRel)) { throw "Cannot find export_path for preset: $Preset" }

    $defaultDir = Split-Path -Parent $exportRel
    $defaultFile = Split-Path -Leaf $exportRel

    if ([string]::IsNullOrWhiteSpace($OutDir)) { $OutDir = $defaultDir }
    if ([string]::IsNullOrWhiteSpace($OutHtml)) { $OutHtml = $defaultFile }
  }

  $outDirAbs = Resolve-Path (Join-Path $RootDir.Path $OutDir) -ErrorAction SilentlyContinue
  if ($null -eq $outDirAbs) {
    Ensure-Dir (Join-Path $RootDir.Path $OutDir)
    $outDirAbs = Resolve-Path (Join-Path $RootDir.Path $OutDir)
  }

  $outHtmlAbs = Join-Path $outDirAbs.Path $OutHtml

  if (-not $PatchOnly) {
    if ([string]::IsNullOrWhiteSpace($GodotExe)) {
      $GodotExe = "E:\\Godot_v4.6-stable_win64.exe\\Godot_v4.6-stable_win64_console.exe"
    }
    if (!(Test-Path $GodotExe)) { throw "Godot exe not found: $GodotExe (set GODOT_WIN_EXE or pass -GodotExe)" }

    Write-Host ("[1/3] Exporting Web preset '{0}' -> {1}" -f $Preset, $outHtmlAbs) -ForegroundColor Cyan
    & $GodotExe --headless --export-release $Preset $outHtmlAbs
    if ($LASTEXITCODE -ne 0) { throw "Godot export failed (exit=$LASTEXITCODE)" }
  } else {
    Write-Host ("[1/3] PatchOnly: skipping export") -ForegroundColor DarkGray
  }

  if (!(Test-Path $PatchJsSource)) { throw "Missing patch js source: $PatchJsSource" }

  $patchTargetAbs = Join-Path $outDirAbs.Path $PatchJsName
  Write-Host ("[2/3] Writing IME patch: {0}" -f $patchTargetAbs) -ForegroundColor Cyan
  Copy-Item -Force $PatchJsSource $patchTargetAbs

  Write-Host ("[3/3] Patching HTML: {0}" -f $outHtmlAbs) -ForegroundColor Cyan
  Patch-HtmlWithIme -htmlPath $outHtmlAbs -patchJsRelativeName $PatchJsName

  Write-Host ("Done: {0}" -f $outHtmlAbs) -ForegroundColor Green
} finally {
  Pop-Location
}
