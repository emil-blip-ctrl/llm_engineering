#!/usr/bin/env bash
# doctor.sh — Diagnose an Agentic-Claude installation in a project (Unix/Mac)
#
# Run from the Claude Agents library root to check that a consuming project
# is correctly set up. Reports what's missing and how to fix it.
#
# Usage:
#   bash templates/doctor.sh
#   bash templates/doctor.sh --project-path /path/to/project

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
PROJECT_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-path) PROJECT_PATH="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

[[ -z "$PROJECT_PATH" ]] && PROJECT_PATH="$(pwd)"
PROJECT_PATH="$(cd "$PROJECT_PATH" && pwd)" || { echo "ERROR: path not found"; exit 1; }

ERRORS=0

# ── Helpers ───────────────────────────────────────────────────────────────────

ok()   { echo "   OK   $1"; }
warn() { echo "   WARN $1"; }
fail() { echo "   FAIL $1"; ERRORS=$((ERRORS+1)); }
section() { echo ""; echo "$1"; printf '%0.s-' $(seq 1 ${#1}); echo ""; }

KNOWN_LATEST=("opus" "sonnet" "haiku" "claude-opus-4-8" "claude-sonnet-4-6" "claude-haiku-4-5-20251001")
declare -A OUTDATED=(
  ["claude-opus-4-6"]="claude-opus-4-8"
  ["claude-opus-4-7"]="claude-opus-4-8"
  ["claude-sonnet-4-5"]="claude-sonnet-4-6"
  ["claude-haiku-4-5"]="claude-haiku-4-5-20251001"
  ["claude-3-opus"]="claude-opus-4-8"
  ["claude-3-5-sonnet"]="claude-sonnet-4-6"
  ["claude-3-haiku"]="claude-haiku-4-5-20251001"
)

# ── Banner ────────────────────────────────────────────────────────────────────

echo ""
echo "  Agentic-Claude Doctor"
echo "  Project : $PROJECT_PATH"
echo "  Library : $REPO_ROOT"

# ── Agents ────────────────────────────────────────────────────────────────────

section "Agents (.claude/agents/)"

AGENTS_DIR="$PROJECT_PATH/.claude/agents"
EXPECTED_AGENTS=("developer" "tester" "devops" "documentarian" "product-owner-assistant" "architect")

if [[ ! -d "$AGENTS_DIR" ]]; then
  fail ".claude/agents/ not found — run: bash templates/setup.sh --project-path \"$PROJECT_PATH\""
else
  for agent in "${EXPECTED_AGENTS[@]}"; do
    path="$AGENTS_DIR/$agent"
    if [[ ! -e "$path" ]]; then
      fail "$agent  MISSING — run: bash templates/setup.sh --project-path \"$PROJECT_PATH\""
    elif [[ -L "$path" ]]; then
      target="$(readlink "$path")"
      if [[ -d "$path" ]]; then
        ok "$agent  [symlink → $target]"
      else
        fail "$agent  symlink broken ($target) — re-run setup.sh"
      fi
    else
      ok "$agent  [copy]"
    fi
  done
fi

# ── Skills ────────────────────────────────────────────────────────────────────

section "Skills (.claude/skills/)"

SKILLS_DIR="$PROJECT_PATH/.claude/skills"
EXPECTED_SKILLS=("develop" "test" "deploy" "review" "document")

if [[ ! -d "$SKILLS_DIR" ]]; then
  fail ".claude/skills/ not found — run: bash templates/setup.sh --project-path \"$PROJECT_PATH\""
else
  for skill in "${EXPECTED_SKILLS[@]}"; do
    path="$SKILLS_DIR/$skill"
    if [[ ! -e "$path" ]]; then
      fail "$skill  MISSING — run: bash templates/setup.sh --project-path \"$PROJECT_PATH\""
    elif [[ -L "$path" ]]; then
      if [[ -d "$path" ]]; then
        ok "$skill  [symlink]"
      else
        fail "$skill  symlink broken — re-run setup.sh"
      fi
    else
      ok "$skill  [copy]"
    fi
  done
fi

# ── Configuration ─────────────────────────────────────────────────────────────

section "Configuration"

if [[ -f "$PROJECT_PATH/.claude/settings.json" ]]; then
  ok "settings.json present"
else
  fail "settings.json missing — run: bash templates/setup.sh --project-path \"$PROJECT_PATH\""
fi

workspace=$(find "$PROJECT_PATH" -maxdepth 1 -name "*.code-workspace" 2>/dev/null | head -1)
if [[ -n "$workspace" ]]; then
  ok "$(basename "$workspace") present"
else
  fail "No *.code-workspace — run: bash templates/setup.sh --project-path \"$PROJECT_PATH\""
fi

claude_md="$PROJECT_PATH/CLAUDE.md"
if [[ ! -f "$claude_md" ]]; then
  fail "CLAUDE.md not found — run: bash templates/setup.sh --project-path \"$PROJECT_PATH\""
elif grep -q "Copy this file to your project\|your install command\|<ProjectName>" "$claude_md" 2>/dev/null; then
  warn "CLAUDE.md has unfilled placeholder sections — complete them for best results"
else
  ok "CLAUDE.md customized"
fi

# ── Models ────────────────────────────────────────────────────────────────────

section "Agent models"

if [[ -d "$AGENTS_DIR" ]]; then
  while IFS= read -r -d '' md; do
    agent="$(basename "$(dirname "$md")")"
    model=$(grep "^model:" "$md" 2>/dev/null | head -1 | sed 's/model:[[:space:]]*//' | tr -d '[:space:]')
    if [[ -z "$model" ]]; then
      warn "$agent  no model: field found"
      continue
    fi
    is_latest=false
    for m in "${KNOWN_LATEST[@]}"; do
      [[ "$model" == "$m" ]] && is_latest=true && break
    done
    if $is_latest; then
      ok "$agent  [$model]"
    elif [[ -n "${OUTDATED[$model]+_}" ]]; then
      warn "$agent  '$model' outdated → run: bash templates/update.sh --project-path \"$PROJECT_PATH\" --apply"
    else
      fail "$agent  unknown model '$model'"
    fi
  done < <(find "$AGENTS_DIR" -name "AGENT.md" -print0 2>/dev/null)
else
  warn "Skipping model check — agents directory not found"
fi

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo "──────────────────────────────────────────────────"
if [[ $ERRORS -eq 0 ]]; then
  echo "Installation looks good."
else
  echo "$ERRORS issue(s) found. Fix them with the commands shown above."
  exit 1
fi
echo ""
