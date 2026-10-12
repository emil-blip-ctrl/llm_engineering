# setup.ps1 — One-shot bootstrap for Agentic-Claude v1.2+
#
# Installs agents, skills, workspace, hooks and CLAUDE.md template in a single command.
# This is the recommended entry point for new projects.
#
# Parameters:
#   -ProjectPath   Path to the target project (default: current directory)
#   -ProjectName   Display name used in workspace file and CLAUDE.md (default: directory name)
#   -Mode          "symlink" = junction to library HEAD (auto-updates on git pull)
#                  "copy"    = static snapshot of the current working tree
#   -Silent        Skip all interactive prompts; uses defaults for every question
#
# Quick start (from the Claude Agents repo root):
#   powershell -ExecutionPolicy Bypass -File templates/setup.ps1
#
# Silent mode (no prompts — uses all defaults):
#   powershell -ExecutionPolicy Bypass -File templates/setup.ps1 -ProjectPath "C:\path\to\project" -Silent

param(
    [string]$ProjectPath = "",

    [string]$ProjectName = "",

    # Install mode: "symlink" (follows HEAD) or "copy" (static snapshot)
    [ValidateSet("symlink", "copy")]
    [string]$Mode = "symlink",

    # Skip all interactive prompts and use defaults
    [switch]$Silent
)

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot   = Split-Path -Parent $ScriptDir
$Version    = "1.2.0"

# ── Helpers ──────────────────────────────────────────────────────────────────

function Write-Step { param([string]$Msg) Write-Host "`n▶  $Msg" -ForegroundColor Cyan }
function Write-OK   { param([string]$Msg) Write-Host "   ✓  $Msg" -ForegroundColor Green }
function Write-Skip { param([string]$Msg) Write-Host "   –  $Msg" -ForegroundColor DarkGray }
function Write-Warn { param([string]$Msg) Write-Host "   !  $Msg" -ForegroundColor Yellow }

function Ask-YesNo {
    param([string]$Question, [bool]$Default = $true)
    if ($Silent) { return $Default }
    $hint = if ($Default) { "[Y/n]" } else { "[y/N]" }
    $ans  = Read-Host "$Question $hint"
    if ([string]::IsNullOrWhiteSpace($ans)) { return $Default }
    return $ans -match '^[Yy]'
}

function Install-Dir {
    param([string]$Source, [string]$Dest, [string]$Label)
    if (-not (Test-Path $Source)) { Write-Warn "$Label not found: $Source"; return }

    if (Test-Path $Dest) {
        $item = Get-Item $Dest -Force
        if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            cmd /c "rmdir `"$Dest`"" 2>$null
        } else {
            Remove-Item $Dest -Recurse -Force
        }
    }

    if ($Mode -eq "symlink") {
        cmd /c "mklink /J `"$Dest`" `"$Source`"" | Out-Null
        if (Test-Path $Dest) { Write-OK "$Label linked  → $(Split-Path $Dest -Leaf)" }
        else {
            Write-Warn "Junction failed, falling back to copy"
            Copy-Item $Source $Dest -Recurse -Force
            Write-OK "$Label copied  → $(Split-Path $Dest -Leaf)"
        }
    } else {
        Copy-Item $Source $Dest -Recurse -Force
        Write-OK "$Label copied  → $(Split-Path $Dest -Leaf)"
    }
}

# ── Banner ───────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════╗" -ForegroundColor White
Write-Host "  ║   Agentic-Claude Setup  v$Version              ║" -ForegroundColor White
Write-Host "  ╚══════════════════════════════════════════════╝" -ForegroundColor White
Write-Host ""

# ── Step 1: Resolve project path ─────────────────────────────────────────────

Write-Step "Project location"

if ([string]::IsNullOrWhiteSpace($ProjectPath)) {
    if ($Silent) {
        $ProjectPath = (Get-Location).Path
    } else {
        $input = Read-Host "  Project path (Enter = current directory)"
        $ProjectPath = if ([string]::IsNullOrWhiteSpace($input)) { (Get-Location).Path } else { $input }
    }
}

try   { $ProjectPath = (Resolve-Path $ProjectPath -ErrorAction Stop).Path }
catch { Write-Host "  ERROR: Project path not found: $ProjectPath" -ForegroundColor Red; exit 1 }

if ([string]::IsNullOrWhiteSpace($ProjectName)) {
    $ProjectName = Split-Path $ProjectPath -Leaf
}

Write-OK "Target : $ProjectPath"
Write-OK "Name   : $ProjectName"
Write-OK "Mode   : $Mode"

# ── Step 2: Detect project type ───────────────────────────────────────────────

# ── Step 3: Install agents ────────────────────────────────────────────────────

Write-Step "Installing agents"

$allAgents = @("developer","tester","devops","documentarian","product-owner-assistant","architect")
$agentsDir  = Join-Path $ProjectPath ".claude\agents"
New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null

foreach ($agent in $allAgents) {
    $src  = Join-Path $RepoRoot "agents\$agent"
    $dest = Join-Path $agentsDir $agent
    Install-Dir -Source $src -Dest $dest -Label "Agent[$agent]"
}

# ── Step 4: Install skills ────────────────────────────────────────────────────

Write-Step "Installing skills"

$allSkills = @("develop","test","deploy","review","document","postman-collection-generator")
$skillsDir  = Join-Path $ProjectPath ".claude\skills"
New-Item -ItemType Directory -Path $skillsDir -Force | Out-Null

foreach ($skill in $allSkills) {
    $src  = Join-Path $RepoRoot "skills\$skill"
    $dest = Join-Path $skillsDir $skill
    Install-Dir -Source $src -Dest $dest -Label "Skill[$skill]"
}

# ── Step 5: Settings / hooks ──────────────────────────────────────────────────

Write-Step "Settings & hooks"

$settingsSrc  = Join-Path $RepoRoot "templates\settings.json"
$settingsDest = Join-Path $ProjectPath ".claude\settings.json"

if (-not (Test-Path $settingsDest)) {
    Copy-Item $settingsSrc $settingsDest -Force
    Write-OK "settings.json installed (.claude/settings.json)"
} else {
    Write-Skip "settings.json already exists — not overwritten"
}

# ── Step 6: VS Code workspace ─────────────────────────────────────────────────

Write-Step "VS Code workspace"

$workspaceFile = Join-Path $ProjectPath "$ProjectName.code-workspace"
if (-not (Test-Path $workspaceFile)) {
    $relPath = [System.IO.Path]::GetRelativePath($ProjectPath, $RepoRoot) -replace '\\', '/'
    $ws = @"
{
    "folders": [
        { "name": "AI Tools", "path": "$relPath" },
        { "name": "$ProjectName", "path": "." }
    ],
    "settings": {
        "terminal.integrated.env.windows": {
            "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
        },
        "files.exclude": {
            "**/.git": true,
            "**/.DS_Store": true,
            "**/Thumbs.db": true
        },
        "search.exclude": {
            ".venv/**": true,
            "node_modules/**": true,
            "htmlcov/**": true,
            ".pytest_cache/**": true,
            "__pycache__/**": true
        }
    }
}
"@
    Set-Content -Path $workspaceFile -Value $ws -Encoding UTF8
    Write-OK "Workspace created: $ProjectName.code-workspace"
} else {
    Write-Skip "$ProjectName.code-workspace already exists — not overwritten"
}

# ── Step 7: CLAUDE.md template ────────────────────────────────────────────────

Write-Step "CLAUDE.md"

$claudeMd     = Join-Path $ProjectPath "CLAUDE.md"
$templateSrc  = Join-Path $RepoRoot "templates\project-claude.md"

if (-not (Test-Path $claudeMd)) {
    if (Test-Path $templateSrc) {
        Copy-Item $templateSrc $claudeMd -Force
        # Inject project name into template placeholder
        (Get-Content $claudeMd -Raw) -replace '<ProjectName>', $ProjectName |
            Set-Content $claudeMd -Encoding UTF8
        Write-OK "CLAUDE.md created from template"
    } else {
        Write-Warn "Template not found: $templateSrc"
    }
} else {
    Write-Skip "CLAUDE.md already exists — not overwritten"
}

# ── Step 8: .gitignore entries ────────────────────────────────────────────────

Write-Step ".gitignore"

$gitignore = Join-Path $ProjectPath ".gitignore"
$entries   = @(
    "",
    "# Agentic-Claude — agent/skill symlinks (managed by library)",
    ".claude/agents/",
    ".claude/skills/",
    "!.claude/settings.json",
    "",
    "# Claude runtime files",
    ".claude/settings.local.json",
    "CLAUDE.local.md",
    ".claude/memory/checkpoints/"
)

if (Test-Path $gitignore) {
    $content = Get-Content $gitignore -Raw
    if ($content -notmatch "Agentic-Claude") {
        Add-Content -Path $gitignore -Value ($entries -join "`n")
        Write-OK ".gitignore updated with agent/skill exclusions"
    } else {
        Write-Skip ".gitignore already has Agentic-Claude entries"
    }
} else {
    Set-Content -Path $gitignore -Value ($entries -join "`n") -Encoding UTF8
    Write-OK ".gitignore created"
}

# ── Step 9: Memory scaffold ───────────────────────────────────────────────────

Write-Step "Memory scaffold"

$memDir = Join-Path $ProjectPath ".claude\memory"
New-Item -ItemType Directory -Path (Join-Path $memDir "sessions")     -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $memDir "checkpoints")  -Force | Out-Null

$teamFindings = Join-Path $memDir "team-findings.md"
if (-not (Test-Path $teamFindings)) {
    Set-Content -Path $teamFindings -Value @"
# Team Findings

Cross-agent discoveries. Consolidate into CLAUDE.md periodically via /document.

<!-- Agents append entries here. Documentarian clears consolidated entries. -->
"@ -Encoding UTF8
    Write-OK "team-findings.md created"
} else {
    Write-Skip "team-findings.md already exists"
}

# ── Done ──────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "  ══════════════════════════════════════════════" -ForegroundColor White
Write-Host "  Setup complete — Agentic-Claude v$Version"     -ForegroundColor Green
Write-Host "  ══════════════════════════════════════════════" -ForegroundColor White
Write-Host ""
Write-Host "  Next steps:" -ForegroundColor White
Write-Host "  1. Open $ProjectName.code-workspace in VS Code"
Write-Host "     (File > Open Workspace from File)"
Write-Host "  2. Edit CLAUDE.md to describe your project"
Write-Host "  3. Run claude from the VS Code integrated terminal"
Write-Host ""
Write-Host "  Plugin install (optional — pins the version):" -ForegroundColor DarkGray
Write-Host "  /plugin marketplace add Aletheia-Thomas/Claude-Agents" -ForegroundColor DarkGray
Write-Host "  /plugin install agentic-claude@agentic-claude-lib"       -ForegroundColor DarkGray
Write-Host ""

if ($Mode -eq "symlink") {
    Write-Host "  Symlink mode: agents/skills auto-update when the library changes." -ForegroundColor DarkGray
    Write-Host "  Run templates/update.ps1 to pull the latest models and library updates." -ForegroundColor DarkGray
    Write-Host ""
}
