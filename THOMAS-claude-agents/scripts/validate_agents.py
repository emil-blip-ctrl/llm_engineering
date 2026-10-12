#!/usr/bin/env python3
"""
validate_agents.py — Local pre-push validator for Agentic-Claude.

Runs the same checks as .github/workflows/validate.yml so you can catch
issues before pushing. Run from the repo root:

    python3 scripts/validate_agents.py
    python3 scripts/validate_agents.py --strict   # fail on outdated models too
"""

import json
import re
import sys
from pathlib import Path

# ── Configuration ─────────────────────────────────────────────────────────────

REPO_ROOT = Path(__file__).parent.parent

KNOWN_LATEST_MODELS = {
    # Floating aliases are the preferred convention — they auto-track the latest
    # tier, so they never go "outdated" and update.ps1 has nothing to bump.
    "opus",
    "sonnet",
    "haiku",
    # Pinned full IDs remain valid (reproducible builds may prefer them).
    "claude-opus-4-8",
    "claude-sonnet-4-6",
    "claude-haiku-4-5-20251001",
}

# Models that are valid but outdated — warn, don't fail (unless --strict)
OUTDATED_MODELS = {
    "claude-opus-4-5":   "claude-opus-4-8",
    "claude-opus-4-6":   "claude-opus-4-8",
    "claude-opus-4-7":   "claude-opus-4-8",
    "claude-3-opus":     "claude-opus-4-8",
    "claude-sonnet-4-5": "claude-sonnet-4-6",
    "claude-3-5-sonnet": "claude-sonnet-4-6",
    "claude-haiku-4-5":  "claude-haiku-4-5-20251001",
    "claude-3-haiku":    "claude-haiku-4-5-20251001",
}

REQUIRED_AGENT_FIELDS = ["name", "description", "model", "tools", "memory"]
REQUIRED_SKILL_FIELDS  = ["name", "description", "allowed-tools"]

# ── Helpers ───────────────────────────────────────────────────────────────────

GREEN  = "\033[32m"
YELLOW = "\033[33m"
RED    = "\033[31m"
RESET  = "\033[0m"
BOLD   = "\033[1m"

# Force UTF-8 output on Windows terminals
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

def ok(msg):    print(f"  {GREEN}OK{RESET}   {msg}")
def warn(msg):  print(f"  {YELLOW}WARN{RESET} {msg}")
def fail(msg):  print(f"  {RED}FAIL{RESET} {msg}")

def parse_frontmatter(path: Path) -> dict:
    """Extract YAML-like key:value pairs from --- frontmatter block."""
    content = path.read_text(encoding="utf-8-sig")  # utf-8-sig strips BOM added by PowerShell 5.1
    if not content.startswith("---"):
        return {}
    end = content.find("---", 3)
    if end == -1:
        return {}
    block = content[3:end]
    fields = {}
    current_key = None
    for line in block.splitlines():
        if re.match(r"^\w[\w-]*:", line):
            key, _, val = line.partition(":")
            fields[key.strip()] = val.strip().strip('"').strip("'")
            current_key = key.strip()
        elif line.startswith("  ") and current_key:
            # Multi-line value continuation
            fields[current_key] = (fields.get(current_key, "") + " " + line.strip()).strip()
    return fields

# ── Validators ────────────────────────────────────────────────────────────────

def validate_agents(strict: bool) -> tuple[int, int]:
    errors = warnings = 0
    agent_dir = REPO_ROOT / "agents"
    agent_files = sorted(agent_dir.glob("*/AGENT.md"))

    if not agent_files:
        warn("No AGENT.md files found in agents/")
        return 0, 1

    print(f"\n{BOLD}Agents ({len(agent_files)} found){RESET}")

    for path in agent_files:
        agent = path.parent.name
        fields = parse_frontmatter(path)
        has_error = False

        for field in REQUIRED_AGENT_FIELDS:
            if field not in fields:
                fail(f"{agent}: missing required field '{field}'")
                errors += 1
                has_error = True

        if "name" in fields and fields["name"] != agent:
            fail(f"{agent}: name '{fields['name']}' does not match folder name '{agent}'")
            errors += 1
            has_error = True

        if "memory" in fields and fields["memory"] != "project":
            fail(f"{agent}: memory must be 'project', got '{fields['memory']}'")
            errors += 1
            has_error = True

        if "model" in fields:
            model = fields["model"]
            if model not in KNOWN_LATEST_MODELS:
                if model in OUTDATED_MODELS:
                    replacement = OUTDATED_MODELS[model]
                    msg = f"{agent}: model '{model}' is outdated → use '{replacement}'"
                    if strict:
                        fail(msg + "  [--strict: treated as error]")
                        errors += 1
                        has_error = True
                    else:
                        warn(msg)
                        warnings += 1
                else:
                    fail(f"{agent}: model '{model}' is unknown. Run update.ps1/update.sh to fix.")
                    errors += 1
                    has_error = True

        if not has_error:
            model_short = fields.get("model", "?").replace("claude-", "")
            ok(f"{agent}  [{model_short}]")

    return errors, warnings


def validate_skills() -> tuple[int, int]:
    errors = warnings = 0
    skill_dir = REPO_ROOT / "skills"
    skill_files = sorted(skill_dir.glob("*/SKILL.md"))

    if not skill_files:
        warn("No SKILL.md files found in skills/")
        return 0, 1

    print(f"\n{BOLD}Skills ({len(skill_files)} found){RESET}")

    for path in skill_files:
        skill = path.parent.name
        fields = parse_frontmatter(path)
        has_error = False

        for field in REQUIRED_SKILL_FIELDS:
            if field not in fields:
                fail(f"{skill}: missing required field '{field}'")
                errors += 1
                has_error = True

        if "name" in fields and fields["name"] != skill:
            fail(f"{skill}: name '{fields['name']}' does not match folder name '{skill}'")
            errors += 1
            has_error = True

        if not has_error:
            tools = fields.get("allowed-tools", "").replace("\n", " ").strip()
            ok(f"{skill}  [{tools[:60]}{'...' if len(tools)>60 else ''}]")

    return errors, warnings


def validate_plugin() -> tuple[int, int]:
    errors = warnings = 0
    print(f"\n{BOLD}Plugin manifests{RESET}")

    plugin_path = REPO_ROOT / ".claude-plugin" / "plugin.json"
    mkt_path    = REPO_ROOT / ".claude-plugin" / "marketplace.json"

    if not plugin_path.exists():
        fail("Missing .claude-plugin/plugin.json")
        return 1, 0

    plugin = json.loads(plugin_path.read_text())
    for field in ["name", "version", "description", "author"]:
        if field not in plugin:
            fail(f"plugin.json missing field: {field}")
            errors += 1

    if errors == 0:
        ok(f"plugin.json  [v{plugin['version']}]")

    if not mkt_path.exists():
        warn("Missing .claude-plugin/marketplace.json")
        warnings += 1
        return errors, warnings

    mkt = json.loads(mkt_path.read_text())
    if not mkt.get("plugins"):
        fail("marketplace.json: missing 'plugins' array")
        errors += 1
    else:
        for p in mkt["plugins"]:
            for field in ["name", "version", "source"]:
                if field not in p:
                    fail(f"marketplace.json plugin missing field: {field}")
                    errors += 1
            mkt_ver    = p.get("version", "?")
            plugin_ver = plugin.get("version", "?")
            if mkt_ver != plugin_ver:
                fail(f"Version mismatch: plugin.json={plugin_ver}, marketplace.json={mkt_ver}")
                errors += 1
            else:
                ok(f"marketplace.json  [v{mkt_ver}]")

    return errors, warnings

# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    strict = "--strict" in sys.argv

    print(f"\n{BOLD}Agentic-Claude — Local Validation{RESET}")
    print(f"Repo: {REPO_ROOT}")
    if strict:
        print(f"{YELLOW}Strict mode: outdated models treated as errors{RESET}")

    agent_errors,  agent_warnings  = validate_agents(strict)
    skill_errors,  skill_warnings  = validate_skills()
    plugin_errors, plugin_warnings = validate_plugin()

    total_errors   = agent_errors  + skill_errors  + plugin_errors
    total_warnings = agent_warnings + skill_warnings + plugin_warnings

    print(f"\n{'─'*50}")
    if total_errors == 0 and total_warnings == 0:
        print(f"{GREEN}{BOLD}All checks passed.{RESET}")
    elif total_errors == 0:
        print(f"{YELLOW}{BOLD}{total_warnings} warning(s) — no blocking errors.{RESET}")
        print("Run: powershell -File templates/update.ps1 -Apply  (or  bash templates/update.sh --apply)")
    else:
        print(f"{RED}{BOLD}{total_errors} error(s), {total_warnings} warning(s).{RESET}")
        print("Fix errors before pushing. Warnings can be resolved with update.ps1/update.sh.")
        sys.exit(1)


if __name__ == "__main__":
    main()
