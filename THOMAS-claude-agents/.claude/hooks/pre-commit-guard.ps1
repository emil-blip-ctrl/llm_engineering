#requires -Version 5
# version: 1.0.0
# pre-commit-guard.ps1 -- PreToolUse(Bash) commit guard for the Agentic-Claude library (Windows).
#
# Cross-platform twin: pre-commit-guard.js (Node, identical logic). On macOS/Linux, change the
# .claude/settings.json command to:  node "$CLAUDE_PROJECT_DIR/.claude/hooks/pre-commit-guard.js"
# (PowerShell 5.1 is guaranteed on Windows; node/python are not, so PowerShell is the default.)
#
# Blocks `git commit` against THIS repo until ALL of:
#   1. CLAUDE.md references every agents/, skills/, teams/*.md by backticked `name`.
#   2. Every AGENT.md / SKILL.md has `name:` and `description:` frontmatter.
#   3. Twin-parity: this .ps1 and pre-commit-guard.js declare the same `# version:`.
#   4. Bump-on-change: a staged AGENT.md/SKILL.md/teams/*.md/hook whose `version:` did not
#      change blocks the commit (new object must declare a version; rename only warns; delete skipped).
# Object versions are informational (Claude Code installs only the plugin version); this rule keeps
# the per-object semver honest. A human is still the only committer. ASCII-only (Windows PowerShell
# 5.1 mis-decodes non-ASCII in .ps1 files saved without a BOM).

$ErrorActionPreference = 'SilentlyContinue'
$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }
try { $p = $raw | ConvertFrom-Json } catch { exit 0 }
$cmd = [string]$p.tool_input.command
if ($cmd -notmatch 'git\b.*\bcommit\b') { exit 0 }

$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$target = (Get-Location).Path
if ($cmd -match '-C\s+"?([^"\s]+)"?') { $target = $matches[1] }
$top = git -C $target rev-parse --show-toplevel 2>$null
if (-not $top) { exit 0 }
try { if ((Resolve-Path $top).Path -ne (Resolve-Path $root).Path) { exit 0 } } catch { exit 0 }

$claudeMd = Join-Path $root 'CLAUDE.md'
if (-not (Test-Path $claudeMd)) { exit 0 }
$doc = Get-Content $claudeMd -Raw
$problems = @()
function InDoc($n) { return ($doc.Contains('`' + $n + '`') -or $doc.Contains('`/' + $n + '`')) }

foreach ($d in Get-ChildItem (Join-Path $root 'agents') -Directory) { if (-not (InDoc $d.Name)) { $problems += "inventory: agent not in CLAUDE.md -> $($d.Name)" } }
foreach ($d in Get-ChildItem (Join-Path $root 'skills') -Directory) { if (-not (InDoc $d.Name)) { $problems += "inventory: skill not in CLAUDE.md -> $($d.Name)" } }
foreach ($f in Get-ChildItem (Join-Path $root 'teams') -Filter *.md) { if (-not (InDoc $f.BaseName)) { $problems += "inventory: team not in CLAUDE.md -> $($f.BaseName)" } }

function Lint($file, $rel) {
  if (-not (Test-Path $file)) { return }
  $t = Get-Content $file -Raw
  if (-not $t.StartsWith('---')) { $script:problems += "frontmatter: missing --- block -> $rel"; return }
  $end = $t.IndexOf("`n---", 3)
  $fm = if ($end -gt 0) { $t.Substring(0, $end) } else { $t }
  if ($fm -notmatch 'name:\s*\S') { $script:problems += "frontmatter: missing name -> $rel" }
  if ($fm -notmatch 'description:\s*\S') { $script:problems += "frontmatter: missing description -> $rel" }
}
foreach ($d in Get-ChildItem (Join-Path $root 'agents') -Directory) { Lint (Join-Path $d.FullName 'AGENT.md') "agents/$($d.Name)/AGENT.md" }
foreach ($d in Get-ChildItem (Join-Path $root 'skills') -Directory) { Lint (Join-Path $d.FullName 'SKILL.md') "skills/$($d.Name)/SKILL.md" }

# --- Versioning checks (guard v1.0.0) ---
function ParseVer($text) { if ($text -match 'version:\s*([0-9]+\.[0-9]+\.[0-9]+)') { return $matches[1] } else { return $null } }

# Twin-parity: the .ps1 and .js guards must declare the same version header.
$psVer = ParseVer (Get-Content (Join-Path $PSScriptRoot 'pre-commit-guard.ps1') -Raw)
$jsVer = ParseVer (Get-Content (Join-Path $PSScriptRoot 'pre-commit-guard.js') -Raw)
if ($psVer -and $jsVer -and ($psVer -ne $jsVer)) { $problems += "twin-parity: hook versions differ -> .ps1=$psVer .js=$jsVer" }

# Bump-on-change: a staged versioned object whose version did not change blocks the commit.
function IsVersioned($p) { return ($p -match '^agents/[^/]+/AGENT\.md$' -or $p -match '^skills/[^/]+/SKILL\.md$' -or $p -match '^teams/[^/]+\.md$' -or $p -match '^\.claude/hooks/pre-commit-guard\.(ps1|js)$') }
$staged = git -C $target diff --cached --name-status -M 2>$null
foreach ($row in @($staged -split "`n")) {
  $row = $row.Trim(); if (-not $row) { continue }
  $f = $row -split "`t"
  $code = $f[0].Substring(0,1)
  if ($code -eq 'R') { $oldPath = $f[1]; $newPath = $f[2] } else { $oldPath = $f[1]; $newPath = $f[1] }
  if (-not (IsVersioned $newPath)) { continue }
  if ($code -eq 'D') { continue }
  $newVer = ParseVer ((git -C $target show ":$newPath" 2>$null) -join "`n")
  if ($code -eq 'A') { if (-not $newVer) { $problems += "version: new object missing a version -> $newPath" }; continue }
  if ($code -eq 'R') {
    $oldVer = ParseVer ((git -C $target show "HEAD:$oldPath" 2>$null) -join "`n")
    if ($oldVer -and $newVer -and ($oldVer -eq $newVer)) { [Console]::Error.WriteLine("  ! warn: renamed without version bump -> $oldPath -> $newPath") }
    continue
  }
  # Modified
  $oldVer = ParseVer ((git -C $target show "HEAD:$newPath" 2>$null) -join "`n")
  if (-not $oldVer) { continue }       # HEAD had no version -> newly versioned, skip compare
  if (-not $newVer) { $problems += "version: object lost its version -> $newPath"; continue }
  if ($oldVer -eq $newVer) { $problems += "version: not bumped (still $newVer) -> $newPath" }
}

if ($problems.Count -gt 0) {
  [Console]::Error.WriteLine("BLOCKED by .claude/hooks/pre-commit-guard.ps1 -- the library drifted; convene the repo-improvement-team before committing.")
  foreach ($m in $problems) { [Console]::Error.WriteLine("  - $m") }
  exit 2
}
exit 0
