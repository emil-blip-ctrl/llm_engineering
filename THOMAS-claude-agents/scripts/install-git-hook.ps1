# install-git-hook.ps1 — install a post-commit hook that auto-publishes to Confluence
# whenever docs/presentation/index.html is part of the commit.
#
# One-time setup:
#   ./scripts/install-git-hook.ps1
#
# The hook reads CONFLUENCE_* from the current environment or from a .env file
# at the repo root (key=value, one per line — never committed).
# Uninstall: Remove-Item .git/hooks/post-commit

param(
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"
$root     = Split-Path -Parent $PSScriptRoot
$hookDir  = Join-Path $root ".git" "hooks"
$hookFile = Join-Path $hookDir "post-commit"

if (-not (Test-Path $hookDir)) {
    Write-Error "No .git/hooks directory found. Run this script from inside a git repo."
    exit 1
}

if ($Uninstall) {
    if (Test-Path $hookFile) {
        Remove-Item $hookFile
        Write-Host "Hook removed: $hookFile"
    } else {
        Write-Host "No hook to remove."
    }
    exit 0
}

# POSIX shell script — runs on Linux/macOS runners and Git Bash on Windows.
$hookContent = @'
#!/bin/sh
# Auto-publish to Confluence when docs/presentation/index.html changes.
# Installed by scripts/install-git-hook.ps1 — remove with: Remove-Item .git/hooks/post-commit

CHANGED=$(git diff --name-only HEAD~1 HEAD 2>/dev/null || git diff --name-only HEAD 2>/dev/null)
echo "$CHANGED" | grep -q "docs/presentation/index.html" || exit 0

echo "[post-commit] docs/presentation/index.html changed — publishing to Confluence..."

# Load .env if present (key=value, no quotes needed).
if [ -f ".env" ]; then
    set -a
    . ./.env
    set +a
fi

uv run \
    --with beautifulsoup4 \
    --with lxml \
    --with requests \
    python scripts/publish_to_confluence.py

EXIT=$?
if [ $EXIT -ne 0 ]; then
    echo "[post-commit] Confluence publish failed (exit $EXIT) — commit is still saved."
fi
exit 0
'@

$hookContent | Set-Content -Path $hookFile -Encoding utf8 -NoNewline

Write-Host "Hook installed: $hookFile"
Write-Host ""
Write-Host "It will publish to Confluence after every commit that touches"
Write-Host "docs/presentation/index.html."
Write-Host ""
Write-Host "Set CONFLUENCE_* variables in your environment or create a .env file"
Write-Host "at the repo root (it is already git-ignored)."
Write-Host ""
Write-Host "To disable: ./scripts/install-git-hook.ps1 -Uninstall"
