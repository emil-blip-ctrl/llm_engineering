# update.ps1 — Update Agentic-Claude agents to the latest Claude model versions
#
# Parameters:
#   -LibraryPath   Path to the Claude Agents library repo (default: parent of this script)
#   -ProjectPath   Path to a consuming project using copy-mode installation (optional).
#                  When set, also updates AGENT.md files in <ProjectPath>/.claude/agents/.
#   -Apply         Actually write changes. Without this flag the script is a dry-run.
#   -BumpVersion   Increment the minor version in plugin.json and marketplace.json.
#                  Only takes effect when combined with -Apply.
#
# Usage (from the Claude Agents library root):
#   powershell -ExecutionPolicy Bypass -File templates/update.ps1
#   powershell -ExecutionPolicy Bypass -File templates/update.ps1 -Apply
#   powershell -ExecutionPolicy Bypass -File templates/update.ps1 -ProjectPath "C:\path\to\project" -Apply
#   powershell -ExecutionPolicy Bypass -File templates/update.ps1 -Apply -BumpVersion
#
# Default behaviour: dry-run (shows what would change, does NOT write anything).
# Pass -Apply to actually write the updates.
#
# What it does:
#   1. Scans all AGENT.md files in the library (agents/) for "model:" directives
#   2. Compares against the latest known Claude model IDs in $ModelMap
#   3. Prints a diff and, with -Apply, rewrites the model lines in place
#   4. With -Apply -BumpVersion, also bumps plugin.json + marketplace.json minor version

param(
    # Path to the Claude Agents library repo (default: parent of this script)
    [string]$LibraryPath = "",

    # Path to a consuming project using copy-mode installation (optional)
    # When set, updates AGENT.md files inside <ProjectPath>/.claude/agents/ as well
    [string]$ProjectPath = "",

    # Actually write changes. Without this flag the script is a dry-run.
    [switch]$Apply,

    # Bump the library version in plugin.json / marketplace.json as well
    [switch]$BumpVersion
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($LibraryPath)) {
    $LibraryPath = Split-Path -Parent $ScriptDir
}

# ── Latest model map ──────────────────────────────────────────────────────────
# Update this table whenever Anthropic releases new models.
# Format: "old-model-id" = "new-model-id"
$ModelMap = [ordered]@{
    "claude-opus-4-5"       = "claude-opus-4-8"
    "claude-opus-4-6"       = "claude-opus-4-8"
    "claude-opus-4-7"       = "claude-opus-4-8"
    "claude-sonnet-4-5"     = "claude-sonnet-4-6"
    "claude-haiku-4-5"      = "claude-haiku-4-5-20251001"
    "claude-3-opus"         = "claude-opus-4-8"
    "claude-3-5-sonnet"     = "claude-sonnet-4-6"
    "claude-3-haiku"        = "claude-haiku-4-5-20251001"
}

$LatestOpus   = "claude-opus-4-8"
$LatestSonnet = "claude-sonnet-4-6"
$LatestHaiku  = "claude-haiku-4-5-20251001"

# ── Helpers ───────────────────────────────────────────────────────────────────

function Write-Header { param([string]$Msg)
    Write-Host "`n$Msg" -ForegroundColor Cyan
    Write-Host ("-" * $Msg.Length) -ForegroundColor Cyan
}

$TotalChanges = 0

function Update-AgentFile {
    param([string]$FilePath)

    if (-not (Test-Path $FilePath)) { return }

    # Read as explicit UTF-8 to preserve special characters
    $content     = [System.IO.File]::ReadAllText($FilePath, [System.Text.Encoding]::UTF8)
    $newContent  = $content
    $fileChanged = $false

    foreach ($old in $ModelMap.Keys) {
        $new = $ModelMap[$old]
        if ($newContent -match "(?m)^model:\s*$old\s*$") {
            $newContent  = $newContent -replace "(?m)^model:\s*$old\s*$", "model: $new"
            $fileChanged = $true
            $rel         = $FilePath.Replace($LibraryPath, "").TrimStart('\/')
            if ($Apply) {
                Write-Host "  UPDATED  $rel" -ForegroundColor Green
                Write-Host "           $old → $new"
            } else {
                Write-Host "  WOULD UPDATE  $rel" -ForegroundColor Yellow
                Write-Host "                $old → $new"
            }
            $script:TotalChanges++
        }
    }

    if ($fileChanged -and $Apply) {
        # Write UTF-8 without BOM (Set-Content -Encoding UTF8 adds BOM on PowerShell 5.1)
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($FilePath, $newContent, $utf8NoBom)
    }
}

# ── Scan library agents ───────────────────────────────────────────────────────

Write-Header "Scanning library agents: $LibraryPath\agents"

$agentFiles = Get-ChildItem -Path (Join-Path $LibraryPath "agents") -Recurse -Filter "AGENT.md" -ErrorAction SilentlyContinue
foreach ($f in $agentFiles) {
    Update-AgentFile -FilePath $f.FullName
}

# ── Scan project copy-mode agents (optional) ──────────────────────────────────

if (-not [string]::IsNullOrWhiteSpace($ProjectPath)) {
    $copyDir = Join-Path $ProjectPath ".claude\agents"
    if (Test-Path $copyDir) {
        Write-Header "Scanning project copy-mode agents: $copyDir"
        $projFiles = Get-ChildItem -Path $copyDir -Recurse -Filter "AGENT.md" -ErrorAction SilentlyContinue
        foreach ($f in $projFiles) {
            Update-AgentFile -FilePath $f.FullName
        }
    }
}

# ── Bump plugin version (optional) ────────────────────────────────────────────

if ($BumpVersion -and $Apply) {
    Write-Header "Bumping plugin version"

    $pluginFile = Join-Path $LibraryPath ".claude-plugin\plugin.json"
    if (Test-Path $pluginFile) {
        $pluginJson = Get-Content $pluginFile -Raw | ConvertFrom-Json
        $current    = [System.Version]$pluginJson.version
        $next       = "$($current.Major).$($current.Minor + 1).0"
        $pluginContent = [System.IO.File]::ReadAllText($pluginFile, [System.Text.Encoding]::UTF8)
        $pluginContent = $pluginContent -replace '"version":\s*"[^"]+"', "`"version`": `"$next`""
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($pluginFile, $pluginContent, $utf8NoBom)
        Write-Host "  plugin.json: $current → $next" -ForegroundColor Green
    }

    $mktFile = Join-Path $LibraryPath ".claude-plugin\marketplace.json"
    if (Test-Path $mktFile) {
        # Increment the ref tag
        $content = Get-Content $mktFile -Raw
        if ($content -match '"ref":\s*"v(\d+)\.(\d+)"') {
            $maj  = [int]$Matches[1]
            $min  = [int]$Matches[2] + 1
            $newRef = "v$maj.$min"
            $content = $content -replace '"ref":\s*"v\d+\.\d+"', "`"ref`": `"$newRef`""
            $content = $content -replace '"version":\s*"[^"]+"', "`"version`": `"$maj.$min.0`""
            Set-Content $mktFile -Value $content -Encoding UTF8
            Write-Host "  marketplace.json ref → $newRef" -ForegroundColor Green
        }
    }
}

# ── Summary ───────────────────────────────────────────────────────────────────

Write-Host ""
if ($TotalChanges -eq 0) {
    Write-Host "All agents are already on the latest models. No changes needed." -ForegroundColor Green
} elseif ($Apply) {
    Write-Host "Done. $TotalChanges model reference(s) updated." -ForegroundColor Green
} else {
    Write-Host "Dry run: $TotalChanges change(s) pending." -ForegroundColor Yellow
    Write-Host "Re-run with -Apply to apply them:" -ForegroundColor Yellow
    Write-Host "  powershell -ExecutionPolicy Bypass -File templates/update.ps1 -Apply" -ForegroundColor White
}

Write-Host ""
Write-Host "Latest models (as of 2026-06):" -ForegroundColor DarkGray
Write-Host "  Opus   : $LatestOpus"   -ForegroundColor DarkGray
Write-Host "  Sonnet : $LatestSonnet" -ForegroundColor DarkGray
Write-Host "  Haiku  : $LatestHaiku"  -ForegroundColor DarkGray
Write-Host ""
Write-Host "Update this map in update.ps1 whenever Anthropic releases new models." -ForegroundColor DarkGray
