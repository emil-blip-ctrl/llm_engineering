# doctor.ps1 — Diagnose an Agentic-Claude installation in a project
#
# Run this from the Claude Agents library root to check that a consuming
# project is correctly set up. Reports what's missing and how to fix it.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File templates/doctor.ps1
#   powershell -ExecutionPolicy Bypass -File templates/doctor.ps1 -ProjectPath "C:\path\to\project"

param(
    [string]$ProjectPath = ""
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = Split-Path -Parent $ScriptDir

if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    $ProjectPath = (Get-Location).Path
}
try { $ProjectPath = (Resolve-Path $ProjectPath -ErrorAction Stop).Path }
catch { Write-Host "ERROR: Project path not found: $ProjectPath" -ForegroundColor Red; exit 1 }

# ── Helpers ───────────────────────────────────────────────────────────────────

function ok($msg)   { Write-Host "   OK   $msg" -ForegroundColor Green }
function warn($msg) { Write-Host "   WARN $msg" -ForegroundColor Yellow }
function fail($msg) { Write-Host "   FAIL $msg" -ForegroundColor Red; $script:Errors++ }
function section($title) { Write-Host "`n$title" -ForegroundColor Cyan; Write-Host ("-" * $title.Length) -ForegroundColor Cyan }

$script:Errors = 0

# ── Banner ────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "  Agentic-Claude Doctor" -ForegroundColor White
Write-Host "  Project : $ProjectPath"
Write-Host "  Library : $RepoRoot"

# ── Agents ────────────────────────────────────────────────────────────────────

section "Agents (.claude/agents/)"

$agentsDir = Join-Path $ProjectPath ".claude\agents"
$expectedAgents = @("developer","tester","devops","documentarian","product-owner-assistant","architect")

if (-not (Test-Path $agentsDir)) {
    fail ".claude/agents/ directory not found — run: setup.ps1 -ProjectPath `"$ProjectPath`""
} else {
    foreach ($agent in $expectedAgents) {
        $path = Join-Path $agentsDir $agent
        if (-not (Test-Path $path)) {
            fail "$agent  MISSING — run: setup.ps1 -ProjectPath `"$ProjectPath`""
        } else {
            $item = Get-Item $path -Force
            $isJunction = $item.Attributes -band [System.IO.FileAttributes]::ReparsePoint
            if ($isJunction) {
                # Verify junction target exists
                $target = $item.Target
                if ($target -and (Test-Path $target)) {
                    ok "$agent  [junction → $($target | Split-Path -Parent | Split-Path -Leaf)\$($target | Split-Path -Leaf)]"
                } else {
                    fail "$agent  junction target broken ($target) — re-run: setup.ps1 -ProjectPath `"$ProjectPath`" -UseSymlinks"
                }
            } else {
                ok "$agent  [copy]"
            }
        }
    }
}

# ── Skills ────────────────────────────────────────────────────────────────────

section "Skills (.claude/skills/)"

$skillsDir = Join-Path $ProjectPath ".claude\skills"
$expectedSkills = @("develop","test","deploy","review","document")

if (-not (Test-Path $skillsDir)) {
    fail ".claude/skills/ directory not found — run: setup.ps1 -ProjectPath `"$ProjectPath`""
} else {
    foreach ($skill in $expectedSkills) {
        $path = Join-Path $skillsDir $skill
        if (-not (Test-Path $path)) {
            fail "$skill  MISSING — run: setup.ps1 -ProjectPath `"$ProjectPath`""
        } else {
            $item = Get-Item $path -Force
            $isJunction = $item.Attributes -band [System.IO.FileAttributes]::ReparsePoint
            if ($isJunction) {
                $target = $item.Target
                if ($target -and (Test-Path $target)) {
                    ok "$skill  [junction]"
                } else {
                    fail "$skill  junction broken — re-run setup.ps1"
                }
            } else {
                ok "$skill  [copy]"
            }
        }
    }
}

# ── Configuration ─────────────────────────────────────────────────────────────

section "Configuration"

# settings.json
$settingsPath = Join-Path $ProjectPath ".claude\settings.json"
if (Test-Path $settingsPath) { ok "settings.json present" }
else { fail "settings.json missing — run: setup.ps1 -ProjectPath `"$ProjectPath`" -IncludeHooks" }

# .code-workspace
$workspaceFiles = Get-ChildItem -Path $ProjectPath -Filter "*.code-workspace" -ErrorAction SilentlyContinue
if ($workspaceFiles) {
    ok "$($workspaceFiles[0].Name) present"
} else {
    fail "No *.code-workspace file — run: setup.ps1 -ProjectPath `"$ProjectPath`" -IncludeWorkspace"
}

# CLAUDE.md
$claudeMd = Join-Path $ProjectPath "CLAUDE.md"
if (-not (Test-Path $claudeMd)) {
    fail "CLAUDE.md not found — run: setup.ps1 -ProjectPath `"$ProjectPath`""
} else {
    $content = Get-Content $claudeMd -Raw -ErrorAction SilentlyContinue
    if ($content -match "Copy this file to your project") {
        warn "CLAUDE.md is still the unedited template — fill it in with your project context"
    } elseif ($content -match "<ProjectName>|your install command|your run command") {
        warn "CLAUDE.md has unfilled placeholder sections — complete them for best results"
    } else {
        ok "CLAUDE.md customized"
    }
}

# ── Models ────────────────────────────────────────────────────────────────────

section "Agent models"

$KNOWN_LATEST = @("opus", "sonnet", "haiku", "claude-opus-4-8", "claude-sonnet-4-6", "claude-haiku-4-5-20251001")
$OUTDATED     = @{
    "claude-opus-4-6"   = "claude-opus-4-8"
    "claude-opus-4-7"   = "claude-opus-4-8"
    "claude-sonnet-4-5" = "claude-sonnet-4-6"
    "claude-haiku-4-5"  = "claude-haiku-4-5-20251001"
    "claude-3-opus"     = "claude-opus-4-8"
    "claude-3-5-sonnet" = "claude-sonnet-4-6"
    "claude-3-haiku"    = "claude-haiku-4-5-20251001"
}

$agentMds = Get-ChildItem -Path $agentsDir -Filter "AGENT.md" -Recurse -ErrorAction SilentlyContinue
if ($agentMds) {
    foreach ($md in $agentMds) {
        $modelLine = Get-Content $md.FullName | Where-Object { $_ -match "^model:\s+\S" } | Select-Object -First 1
        $model = ($modelLine -replace "^model:\s*", "").Trim()
        $agentName = $md.Directory.Name
        if ([string]::IsNullOrWhiteSpace($model)) {
            warn "$agentName  no model: field found"
            continue
        }
        if ($KNOWN_LATEST -contains $model) {
            ok "$agentName  [$model]"
        } elseif ($OUTDATED.ContainsKey($model)) {
            warn "$agentName  model '$model' is outdated → run: update.ps1 -ProjectPath `"$ProjectPath`" -Apply"
        } else {
            fail "$agentName  unknown model '$model'"
        }
    }
} else {
    warn "No AGENT.md files found — agents may not be installed"
}

# ── Summary ───────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host ("─" * 50)
if ($script:Errors -eq 0) {
    Write-Host "Installation looks good." -ForegroundColor Green
} else {
    Write-Host "$($script:Errors) issue(s) found. Fix them with the commands shown above." -ForegroundColor Red
    exit 1
}
Write-Host ""
