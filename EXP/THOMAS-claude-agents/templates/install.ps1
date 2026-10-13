# install.ps1 — Install Agentic-Claude agents and skills into a project
#
# NOTE: For new projects, use setup.ps1 instead — it installs everything
#       (agents, skills, workspace, hooks, CLAUDE.md, .gitignore) in one shot:
#
#   powershell -ExecutionPolicy Bypass -File templates/setup.ps1
#
# Use install.ps1 only for selective installs or uninstall operations.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File install.ps1 -ProjectPath "C:\path\to\project"
#   powershell -ExecutionPolicy Bypass -File install.ps1 -ProjectPath "." -Agents developer,tester
#   powershell -ExecutionPolicy Bypass -File install.ps1 -ProjectPath "." -Skills develop,test -IncludeHooks
#   powershell -ExecutionPolicy Bypass -File install.ps1 -ProjectPath "." -UseSymlinks
#   powershell -ExecutionPolicy Bypass -File install.ps1 -ProjectPath "." -IncludeWorkspace -ProjectName "MyProject"
#
# Parameters:
#   -ProjectPath       : Path to the target project (required)
#   -Agents            : Comma-separated list of agents to install (default: all)
#   -Skills            : Comma-separated list of skills to install (default: all)
#   -IncludeHooks      : Also copy the template settings.json (default: false)
#   -IncludeWorkspace  : Generate a VS Code multi-root .code-workspace file (default: false)
#   -ProjectName       : Name for the workspace file and folder label (default: directory name)
#   -UseSymlinks       : Create directory junctions instead of copying (default: false)
#                        Junctions keep agents/skills always up-to-date with the library.
#   -Uninstall         : Remove installed agents, skills, and optionally settings (default: false)

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectPath,

    # Note: librarian and library-engineer are intentionally excluded -- they are repo-only
    # maintenance agents (repo-improvement-team) and must NOT be installed into consuming projects.
    [string]$Agents = "architect,developer,tester,devops,documentarian,product-owner-assistant",

    [string]$Skills = "develop,test,deploy,review,document,postman-collection-generator,publish-confluence",

    [switch]$IncludeHooks,

    [switch]$IncludeWorkspace,

    [string]$ProjectName = "",

    [switch]$UseSymlinks,

    [switch]$Uninstall
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir

# Resolve project path
$ProjectPath = Resolve-Path $ProjectPath -ErrorAction Stop

# --- Uninstall mode ---
if ($Uninstall) {
    Write-Host "Uninstalling Agentic-Claude from: $ProjectPath" -ForegroundColor Cyan

    $agentsDir = Join-Path $ProjectPath ".claude\agents"
    $skillsDir = Join-Path $ProjectPath ".claude\skills"

    $agentList = $Agents -split ","
    foreach ($agent in $agentList) {
        $agent = $agent.Trim()
        $dest = Join-Path $agentsDir $agent
        if (Test-Path $dest) {
            # Remove junction or directory
            $item = Get-Item $dest -Force
            if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
                cmd /c "rmdir `"$dest`"" 2>$null
            } else {
                Remove-Item -Path $dest -Recurse -Force
            }
            Write-Host "  Agent removed: $agent" -ForegroundColor Green
        }
    }

    $skillList = $Skills -split ","
    foreach ($skill in $skillList) {
        $skill = $skill.Trim()
        $dest = Join-Path $skillsDir $skill
        if (Test-Path $dest) {
            $item = Get-Item $dest -Force
            if ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
                cmd /c "rmdir `"$dest`"" 2>$null
            } else {
                Remove-Item -Path $dest -Recurse -Force
            }
            Write-Host "  Skill removed: $skill" -ForegroundColor Green
        }
    }

    Write-Host ""
    Write-Host "Uninstall complete." -ForegroundColor Cyan
    return
}

# --- Install mode ---
$mode = if ($UseSymlinks) { "symlink (directory junction)" } else { "copy" }
Write-Host "Installing Agentic-Claude into: $ProjectPath" -ForegroundColor Cyan
Write-Host "Mode: $mode" -ForegroundColor Cyan
Write-Host ""

# Create directories
$agentsDir = Join-Path $ProjectPath ".claude\agents"
$skillsDir = Join-Path $ProjectPath ".claude\skills"

New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null
New-Item -ItemType Directory -Path $skillsDir -Force | Out-Null

# Helper: install a component (copy or symlink)
function Install-Component {
    param(
        [string]$Source,
        [string]$Dest,
        [string]$Label
    )

    if (-not (Test-Path $Source)) {
        Write-Host "  $Label not found: $Source" -ForegroundColor Yellow
        return
    }

    # Remove existing destination (junction or directory)
    if (Test-Path $Dest) {
        $existing = Get-Item $Dest -Force
        if ($existing.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            cmd /c "rmdir `"$Dest`"" 2>$null
        } else {
            Remove-Item -Path $Dest -Recurse -Force
        }
    }

    if ($UseSymlinks) {
        # Create directory junction (no admin rights required on Windows)
        $mkCmd = "mklink /J `"$Dest`" `"$Source`""
        cmd /c $mkCmd | Out-Null
        if (Test-Path $Dest) {
            Write-Host "  $Label linked: $(Split-Path $Dest -Leaf)" -ForegroundColor Green
        } else {
            Write-Host "  $Label junction failed: $(Split-Path $Dest -Leaf) - falling back to copy" -ForegroundColor Yellow
            Copy-Item -Path $Source -Destination $Dest -Recurse -Force
            Write-Host "  $Label copied: $(Split-Path $Dest -Leaf)" -ForegroundColor Green
        }
    } else {
        Copy-Item -Path $Source -Destination $Dest -Recurse -Force
        Write-Host "  $Label installed: $(Split-Path $Dest -Leaf)" -ForegroundColor Green
    }
}

# Install agents
$agentList = $Agents -split ","
foreach ($agent in $agentList) {
    $agent = $agent.Trim()
    $source = Join-Path $RepoRoot "agents\$agent"
    $dest = Join-Path $agentsDir $agent
    Install-Component -Source $source -Dest $dest -Label "Agent"
}

# Install skills
$skillList = $Skills -split ","
foreach ($skill in $skillList) {
    $skill = $skill.Trim()
    $source = Join-Path $RepoRoot "skills\$skill"
    $dest = Join-Path $skillsDir $skill
    Install-Component -Source $source -Dest $dest -Label "Skill"
}

# Install hooks template
if ($IncludeHooks) {
    $settingsSource = Join-Path $RepoRoot "templates\settings.json"
    $settingsDest = Join-Path $ProjectPath ".claude\settings.json"

    if (-not (Test-Path $settingsDest)) {
        Copy-Item -Path $settingsSource -Destination $settingsDest -Force
        Write-Host "  Hooks template installed: .claude/settings.json" -ForegroundColor Green
    } else {
        Write-Host "  Skipped: .claude/settings.json already exists (won't overwrite)" -ForegroundColor Yellow
    }
}

# Generate VS Code workspace file
if ($IncludeWorkspace) {
    # Determine project name (from parameter or directory name)
    if ([string]::IsNullOrWhiteSpace($ProjectName)) {
        $ProjectName = Split-Path $ProjectPath -Leaf
    }

    $workspaceFile = Join-Path $ProjectPath "$ProjectName.code-workspace"

    if (-not (Test-Path $workspaceFile)) {
        # Calculate relative path from project to this library
        $relPath = [System.IO.Path]::GetRelativePath($ProjectPath, $RepoRoot) -replace '\\', '/'

        $workspaceContent = @"
{
    "folders": [
        {
            "name": "AI Tools",
            "path": "$relPath"
        },
        {
            "name": "$ProjectName",
            "path": "."
        }
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
        Set-Content -Path $workspaceFile -Value $workspaceContent -Encoding UTF8
        Write-Host "  Workspace file created: $ProjectName.code-workspace" -ForegroundColor Green
    } else {
        Write-Host "  Skipped: $ProjectName.code-workspace already exists (won't overwrite)" -ForegroundColor Yellow
    }
}

# Summary
Write-Host ""
Write-Host "Installation complete." -ForegroundColor Cyan
Write-Host "Mode: $mode"
Write-Host "Agents: $Agents"
Write-Host "Skills: $Skills"

# Show the version stamped in each installed object (informational; copy mode takes a snapshot).
function Get-ObjVersion($file) { if (Test-Path $file) { $t = Get-Content $file -Raw; if ($t -match 'version:\s*([0-9]+\.[0-9]+\.[0-9]+)') { return $matches[1] } }; return '?' }
Write-Host ""
Write-Host "Installed object versions:" -ForegroundColor White
foreach ($agent in ($Agents -split ",")) { $a = $agent.Trim(); Write-Host ("  agent {0,-28} v{1}" -f $a, (Get-ObjVersion (Join-Path $RepoRoot "agents\$a\AGENT.md"))) }
foreach ($skill in ($Skills -split ",")) { $s = $skill.Trim(); Write-Host ("  skill {0,-28} v{1}" -f $s, (Get-ObjVersion (Join-Path $RepoRoot "skills\$s\SKILL.md"))) }

if ($UseSymlinks) {
    Write-Host ""
    Write-Host "Symlink notes:" -ForegroundColor White
    Write-Host "  - Agents/skills point to the Agentic-Claude library and stay up-to-date automatically"
    Write-Host "  - Add .claude/agents/ and .claude/skills/ to .gitignore (junctions should not be committed)"
    Write-Host "  - Keep .claude/settings.json tracked in git (project-specific, not shared)"
}

Write-Host ""
Write-Host "Next steps:" -ForegroundColor White
Write-Host "  1. Review .claude/agents/ and .claude/skills/ in your project"
Write-Host "  2. Copy templates/project-claude.md to your project root as CLAUDE.md (if not already present)"
Write-Host "  3. Customize CLAUDE.md with your project-specific context"
Write-Host "  4. Add .claude/agents/ and .claude/skills/ to .gitignore"
if (-not $IncludeWorkspace) {
    Write-Host "  5. Create a .code-workspace file (re-run with -IncludeWorkspace or copy templates/project.code-workspace)"
    Write-Host "  6. Open the workspace in VS Code and run claude from the integrated terminal"
} else {
    Write-Host "  5. Open the .code-workspace file in VS Code (File > Open Workspace from File)"
    Write-Host "  6. Run claude from the integrated terminal"
}
