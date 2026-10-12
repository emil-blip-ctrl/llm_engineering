#!/usr/bin/env bash
# update.sh — Update Agentic-Claude agents to the latest Claude model versions (Unix/Mac)
#
# Parameters:
#   --library-path PATH   Path to the Claude Agents library repo (default: parent of this script)
#   --project-path PATH   Path to a consuming project using copy-mode installation (optional)
#                         When set, also updates AGENT.md files in <project>/.claude/agents/
#   --apply               Actually write changes (default: dry-run)
#   --bump-version        Increment minor version in plugin.json + marketplace.json (needs --apply)
#
# Usage (from the Claude Agents library root):
#   bash templates/update.sh                          # dry-run
#   bash templates/update.sh --apply                  # apply model updates
#   bash templates/update.sh --project-path /my/proj --apply
#   bash templates/update.sh --apply --bump-version

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIBRARY_PATH="$(dirname "$SCRIPT_DIR")"
PROJECT_PATH=""
APPLY=false
BUMP_VERSION=false

# ── Argument parsing ──────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    --library-path)  LIBRARY_PATH="$2"; shift 2 ;;
    --project-path)  PROJECT_PATH="$2"; shift 2 ;;
    --apply)         APPLY=true;        shift   ;;
    --bump-version)  BUMP_VERSION=true; shift   ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ── Latest model map ──────────────────────────────────────────────────────────
# Update this list whenever Anthropic releases new models.
declare -A MODEL_MAP=(
  ["claude-opus-4-5"]="claude-opus-4-8"
  ["claude-opus-4-6"]="claude-opus-4-8"
  ["claude-opus-4-7"]="claude-opus-4-8"
  ["claude-sonnet-4-5"]="claude-sonnet-4-6"
  ["claude-haiku-4-5"]="claude-haiku-4-5-20251001"
  ["claude-3-opus"]="claude-opus-4-8"
  ["claude-3-5-sonnet"]="claude-sonnet-4-6"
  ["claude-3-haiku"]="claude-haiku-4-5-20251001"
)

LATEST_OPUS="claude-opus-4-8"
LATEST_SONNET="claude-sonnet-4-6"
LATEST_HAIKU="claude-haiku-4-5-20251001"
TOTAL_CHANGES=0

# ── Helpers ───────────────────────────────────────────────────────────────────

header() { echo ""; echo "$1"; printf '%0.s-' $(seq 1 ${#1}); echo ""; }

update_agent_file() {
  local file="$1"
  [[ ! -f "$file" ]] && return

  local content changed=false
  content=$(cat "$file")

  for old in "${!MODEL_MAP[@]}"; do
    new="${MODEL_MAP[$old]}"
    if echo "$content" | grep -q "^model: ${old}$"; then
      local rel="${file#$LIBRARY_PATH/}"
      if $APPLY; then
        sed -i.bak "s|^model: ${old}$|model: ${new}|" "$file" && rm -f "${file}.bak"
        echo "  UPDATED  $rel"
        echo "           $old → $new"
      else
        echo "  WOULD UPDATE  $rel"
        echo "                $old → $new"
      fi
      TOTAL_CHANGES=$((TOTAL_CHANGES + 1))
      changed=true
      break  # one model: line per file — stop after first match to avoid double-apply
    fi
  done
}

# ── Scan library agents ───────────────────────────────────────────────────────

header "Scanning library agents: $LIBRARY_PATH/agents"

while IFS= read -r -d '' file; do
  update_agent_file "$file"
done < <(find "$LIBRARY_PATH/agents" -name "AGENT.md" -print0 2>/dev/null)

# ── Scan project copy-mode agents (optional) ──────────────────────────────────

if [[ -n "$PROJECT_PATH" ]]; then
  copy_dir="$PROJECT_PATH/.claude/agents"
  if [[ -d "$copy_dir" ]]; then
    header "Scanning project copy-mode agents: $copy_dir"
    while IFS= read -r -d '' file; do
      update_agent_file "$file"
    done < <(find "$copy_dir" -name "AGENT.md" -print0 2>/dev/null)
  fi
fi

# ── Bump plugin version (optional) ────────────────────────────────────────────

if $BUMP_VERSION && $APPLY; then
  header "Bumping plugin version"

  plugin_file="$LIBRARY_PATH/.claude-plugin/plugin.json"
  if [[ -f "$plugin_file" ]]; then
    current=$(python3 -c "import json; print(json.load(open('$plugin_file'))['version'])")
    IFS='.' read -ra parts <<< "$current"
    next="${parts[0]}.$((parts[1] + 1)).0"
    python3 -c "
import json, re
with open('$plugin_file') as f: data = f.read()
data = re.sub(r'\"version\":\s*\"[^\"]+\"', f'\"version\": \"$next\"', data, count=1)
open('$plugin_file', 'w').write(data)
"
    echo "  plugin.json: $current → $next"
  fi

  mkt_file="$LIBRARY_PATH/.claude-plugin/marketplace.json"
  if [[ -f "$mkt_file" ]]; then
    python3 -c "
import json, re
with open('$mkt_file') as f: data = f.read()
m = re.search(r'\"ref\":\s*\"v(\d+)\.(\d+)\"', data)
if m:
    maj, min_ = int(m.group(1)), int(m.group(2)) + 1
    data = re.sub(r'\"ref\":\s*\"v\d+\.\d+\"', f'\"ref\": \"v{maj}.{min_}\"', data)
    data = re.sub(r'\"version\":\s*\"[^\"]+\"', f'\"version\": \"{maj}.{min_}.0\"', data)
    open('$mkt_file', 'w').write(data)
    print(f'  marketplace.json ref → v{maj}.{min_}')
"
  fi
fi

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
if [[ $TOTAL_CHANGES -eq 0 ]]; then
  echo "All agents are already on the latest models. No changes needed."
elif $APPLY; then
  echo "Done. $TOTAL_CHANGES model reference(s) updated."
else
  echo "Dry run: $TOTAL_CHANGES change(s) pending."
  echo "Re-run with --apply to apply them:"
  echo "  bash templates/update.sh --apply"
fi

echo ""
echo "Latest models (as of 2026-06):"
echo "  Opus   : $LATEST_OPUS"
echo "  Sonnet : $LATEST_SONNET"
echo "  Haiku  : $LATEST_HAIKU"
echo ""
echo "Update the MODEL_MAP in update.sh whenever Anthropic releases new models."
