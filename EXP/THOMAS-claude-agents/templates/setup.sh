#!/usr/bin/env bash
# setup.sh — One-shot bootstrap for Agentic-Claude v1.2+ (Unix/Mac)
#
# Installs agents, skills, workspace, hooks and CLAUDE.md template in a single command.
# This is the recommended entry point for new projects on Unix/Mac.
#
# Parameters:
#   --project-path PATH   Path to the target project (default: current directory)
#   --project-name NAME   Display name for workspace file (default: directory name)
#   --mode MODE           "symlink" (follows HEAD) or "copy" (static snapshot) [default: symlink]
#   --silent              Skip all interactive prompts; uses defaults
#
# Quick start (from the Claude Agents repo root):
#   bash templates/setup.sh
#
# Silent mode:
#   bash templates/setup.sh --project-path /path/to/project --silent
#
# Copy mode (static snapshot, useful for pinned versions):
#   bash templates/setup.sh --project-path /path/to/project --mode copy

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
VERSION="1.2.0"

# ── Defaults ──────────────────────────────────────────────────────────────────

PROJECT_PATH=""
PROJECT_NAME=""
MODE="symlink"
SILENT=false

# ── Argument parsing ──────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project-path) PROJECT_PATH="$2"; shift 2 ;;
    --project-name) PROJECT_NAME="$2"; shift 2 ;;
    --mode)         MODE="$2";         shift 2 ;;
    --silent)       SILENT=true;       shift   ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ── Helpers ───────────────────────────────────────────────────────────────────

step()  { echo ""; echo "▶  $1"; }
ok()    { echo "   ✓  $1"; }
skip()  { echo "   –  $1"; }
warn()  { echo "   !  $1"; }
error() { echo "   ✗  $1"; exit 1; }

install_dir() {
  local src="$1" dest="$2" label="$3"
  [[ ! -d "$src" ]] && { warn "$label not found: $src"; return; }

  if [[ -e "$dest" || -L "$dest" ]]; then
    rm -rf "$dest"
  fi

  if [[ "$MODE" == "symlink" ]]; then
    ln -s "$src" "$dest"
    ok "$label linked  → $(basename "$dest")"
  else
    cp -r "$src" "$dest"
    ok "$label copied  → $(basename "$dest")"
  fi
}

# ── Banner ────────────────────────────────────────────────────────────────────

echo ""
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║   Agentic-Claude Setup  v${VERSION}              ║"
echo "  ╚══════════════════════════════════════════════╝"
echo ""

# ── Step 1: Resolve project path ──────────────────────────────────────────────

step "Project location"

if [[ -z "$PROJECT_PATH" ]]; then
  if $SILENT; then
    PROJECT_PATH="$(pwd)"
  else
    read -rp "  Project path (Enter = current directory): " input
    PROJECT_PATH="${input:-$(pwd)}"
  fi
fi

PROJECT_PATH="$(cd "$PROJECT_PATH" && pwd)" || error "Project path not found: $PROJECT_PATH"
[[ -z "$PROJECT_NAME" ]] && PROJECT_NAME="$(basename "$PROJECT_PATH")"

ok "Target : $PROJECT_PATH"
ok "Name   : $PROJECT_NAME"
ok "Mode   : $MODE"

# ── Step 2: Detect project type ───────────────────────────────────────────────

# ── Step 3: Install agents ────────────────────────────────────────────────────

step "Installing agents"

AGENTS_DIR="$PROJECT_PATH/.claude/agents"
mkdir -p "$AGENTS_DIR"

for agent in developer tester devops documentarian product-owner-assistant architect; do
  install_dir "$REPO_ROOT/agents/$agent" "$AGENTS_DIR/$agent" "Agent[$agent]"
done

# ── Step 4: Install skills ────────────────────────────────────────────────────

step "Installing skills"

SKILLS_DIR="$PROJECT_PATH/.claude/skills"
mkdir -p "$SKILLS_DIR"

for skill in develop test deploy review document postman-collection-generator; do
  install_dir "$REPO_ROOT/skills/$skill" "$SKILLS_DIR/$skill" "Skill[$skill]"
done

# ── Step 5: Settings / hooks ──────────────────────────────────────────────────

step "Settings & hooks"

SETTINGS_SRC="$REPO_ROOT/templates/settings.json"
SETTINGS_DEST="$PROJECT_PATH/.claude/settings.json"

if [[ ! -f "$SETTINGS_DEST" ]]; then
  cp "$SETTINGS_SRC" "$SETTINGS_DEST"
  ok "settings.json installed (.claude/settings.json)"
else
  skip "settings.json already exists — not overwritten"
fi

# ── Step 6: VS Code workspace ─────────────────────────────────────────────────

step "VS Code workspace"

WORKSPACE_FILE="$PROJECT_PATH/$PROJECT_NAME.code-workspace"

if [[ ! -f "$WORKSPACE_FILE" ]]; then
  REL_PATH="$(python3 -c "import os; print(os.path.relpath('$REPO_ROOT', '$PROJECT_PATH'))" 2>/dev/null || \
             ruby  -e "require 'pathname'; puts Pathname.new('$REPO_ROOT').relative_path_from(Pathname.new('$PROJECT_PATH'))")"

  cat > "$WORKSPACE_FILE" << EOF
{
    "folders": [
        { "name": "AI Tools", "path": "${REL_PATH}" },
        { "name": "${PROJECT_NAME}", "path": "." }
    ],
    "settings": {
        "terminal.integrated.env.osx": {
            "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
        },
        "terminal.integrated.env.linux": {
            "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
        },
        "files.exclude": {
            "**/.git": true,
            "**/.DS_Store": true
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
EOF
  ok "Workspace created: $PROJECT_NAME.code-workspace"
else
  skip "$PROJECT_NAME.code-workspace already exists — not overwritten"
fi

# ── Step 7: CLAUDE.md template ────────────────────────────────────────────────

step "CLAUDE.md"

CLAUDE_MD="$PROJECT_PATH/CLAUDE.md"
TEMPLATE_SRC="$REPO_ROOT/templates/project-claude.md"

if [[ ! -f "$CLAUDE_MD" ]]; then
  if [[ -f "$TEMPLATE_SRC" ]]; then
    sed "s/<ProjectName>/$PROJECT_NAME/g" "$TEMPLATE_SRC" > "$CLAUDE_MD"
    ok "CLAUDE.md created from template"
  else
    warn "Template not found: $TEMPLATE_SRC"
  fi
else
  skip "CLAUDE.md already exists — not overwritten"
fi

# ── Step 8: .gitignore entries ────────────────────────────────────────────────

step ".gitignore"

GITIGNORE="$PROJECT_PATH/.gitignore"
MARKER="# Agentic-Claude"

if [[ -f "$GITIGNORE" ]] && grep -q "$MARKER" "$GITIGNORE"; then
  skip ".gitignore already has Agentic-Claude entries"
else
  cat >> "$GITIGNORE" << 'EOF'

# Agentic-Claude — agent/skill symlinks (managed by library)
.claude/agents/
.claude/skills/
!.claude/settings.json

# Claude runtime files
.claude/settings.local.json
CLAUDE.local.md
.claude/memory/checkpoints/
EOF
  ok ".gitignore updated with agent/skill exclusions"
fi

# ── Step 9: Memory scaffold ───────────────────────────────────────────────────

step "Memory scaffold"

mkdir -p "$PROJECT_PATH/.claude/memory/sessions"
mkdir -p "$PROJECT_PATH/.claude/memory/checkpoints"

TEAM_FINDINGS="$PROJECT_PATH/.claude/memory/team-findings.md"
if [[ ! -f "$TEAM_FINDINGS" ]]; then
  cat > "$TEAM_FINDINGS" << 'EOF'
# Team Findings

Cross-agent discoveries. Consolidate into CLAUDE.md periodically via /document.

<!-- Agents append entries here. Documentarian clears consolidated entries. -->
EOF
  ok "team-findings.md created"
else
  skip "team-findings.md already exists"
fi

# ── Done ──────────────────────────────────────────────────────────────────────

echo ""
echo "  ══════════════════════════════════════════════"
echo "  Setup complete — Agentic-Claude v${VERSION}"
echo "  ══════════════════════════════════════════════"
echo ""
echo "  Next steps:"
echo "  1. Open $PROJECT_NAME.code-workspace in VS Code"
echo "     (File > Open Workspace from File)"
echo "  2. Edit CLAUDE.md to describe your project"
echo "  3. Run claude from the VS Code integrated terminal"
echo ""
if [[ "$MODE" == "symlink" ]]; then
  echo "  Symlink mode: agents/skills auto-update when the library changes."
  echo "  Run 'bash templates/update.sh' (or update.ps1) to pull latest models."
  echo ""
fi
