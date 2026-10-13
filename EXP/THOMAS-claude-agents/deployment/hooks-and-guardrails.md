# Agentic-Claude — Hooks & Guardrails

Tool permissions and lifecycle hooks — the safety layer installed in every project.

Source file: `templates/settings.json`
Installed to: `.claude/settings.json` (per consuming project, by `setup.ps1`)

---

## How it works

`templates/settings.json` ships a pre-configured safety baseline.
`setup.ps1` copies it to `.claude/settings.json` in the consuming project.
Each project can then customise it independently — changes are project-scoped and never
affect other projects or the library itself.

---

## Permissions — Allowed

Pre-approved so agents don't need a human confirmation for every action:

| Category | Allowed |
|----------|---------|
| Navigation | `Read`, `Glob`, `Grep`, `Task`, `TodoWrite`, `AskUserQuestion`, `WebSearch`, `WebFetch` |
| Python / uv | `Bash(python *)`, `Bash(pytest *)`, `Bash(pip install *)`, `Bash(pip list*)`, `Bash(uv *)` |
| Git (read-only) | `Bash(git status*)`, `Bash(git diff*)`, `Bash(git log*)`, `Bash(git branch*)` |
| GitHub CLI | `Bash(gh pr *)`, `Bash(gh issue *)` |
| Docker | `Bash(docker build *)`, `Bash(docker compose *)` |
| Node | `Bash(npm *)`, `Bash(npx *)` |
| File ops | `Bash(ls *)`, `Bash(mkdir *)`, `Bash(cat *)` |

---

## Permissions — Denied (absolute nos)

| Denied command | Why |
|----------------|-----|
| `Bash(rm -rf /)` | Filesystem wipe — never safe |
| `Bash(rm -rf ~)` | Home directory wipe |
| `Bash(git push --force *)` | Overwrites shared history without review |
| `Bash(git reset --hard *)` | Discards all uncommitted work |
| `Bash(git clean -f*)` | Deletes untracked files irreversibly |

---

## Lifecycle Hooks

| Event | Matcher | Action |
|-------|---------|--------|
| `PostToolUse` | `Write\|Edit` | Reminds agent to run `/test` before committing |
| `SubagentStop` | `developer` | Signals orchestrator: trigger tester next |
| `SubagentStop` | `tester` | Signals orchestrator: trigger documentarian next |

### Hook details

**PostToolUse → Write|Edit**
Fires after every file write or edit. Currently prints a reminder so agents don't skip
the test step:
```
[Hook] File modified — remember to run /test before committing
```

**SubagentStop → developer**
Fires when the developer subagent finishes its turn. Signals to the orchestrator that
the tester should be triggered next in the pipeline:
```
[Hook] Developer agent finished — trigger tester agent next
```

**SubagentStop → tester**
Fires when the tester subagent finishes. Signals orchestrator to trigger the documentarian:
```
[Hook] Tester agent finished — trigger documentarian agent next
```

---

## Hook Templates

Ready-to-use hook snippets live in `templates/hooks/`. Copy the relevant `hooks` block
into your project's `.claude/settings.json`.

| Template file | Event | What it does |
|---------------|-------|-------------|
| `pii-guard.json` | `UserPromptSubmit` | **Bloque les prompts avec données personnelles (LPD/RGPD TCS)** |
| `auto-test.json` | `PostToolUse` | Lance `pytest --tb=short` après chaque Write/Edit |
| `auto-format.json` | `PostToolUse` | Lance `black` + `ruff --fix` sur les `.py` modifiés |
| `security-scan.json` | `PostToolUse` | Lance `bandit -ll` sur les `.py` modifiés |
| `agent-pipeline.json` | `SubagentStop` | Chaîne les 6 agents avec messages de signal |
| `confluence-publish.json` | `PostToolUse` | Publie `index.html` sur Confluence si le fichier change |
| `commit-guard.json` | `PreToolUse` | Avertit avant les git push --force, reset --hard, rm -rf |
| `notify-on-stop.json` | `Stop` | Notification desktop quand Claude a fini |

### PII Guard — détail

`pii-guard.json` utilise le script `templates/hooks/scripts/pii_check.py`.
Il intercepte chaque message utilisateur avant envoi à Claude, applique des regex, et
sort avec le code **2** (bloquant) si des données personnelles sont détectées :

| Catégorie | Exemple |
|-----------|---------|
| Numéro AVS/AHV | `756.1234.5678.90` |
| IBAN | `CH56 0483 5012 3456 7800 9` |
| Carte bancaire | `4111 1111 1111 1111` |
| Téléphone suisse | `+41 79 123 45 67` |
| Adresse e-mail | `prenom.nom@tcs.ch` |
| Numéro IDE (CHE) | `CHE-123.456.789` |
| Document d'identité | mention passeport / carte d'identité |
| Date de naissance | `01/01/1990`, `1990-01-01` |
| Adresse postale | `12 rue de Lausanne` |
| Identifiant long | `12345678` (≥ 8 chiffres consécutifs) |

Message affiché à l'utilisateur si bloqué :
```
======================================================================
BLOQUE -- Politique de protection des donnees TCS
======================================================================

  Donnees personnelles detectees : Numéro AVS/AHV | Adresse e-mail

  La saisie de donnees personnelles dans Claude Code est interdite
  par la Directive de protection des donnees TCS, conformement a la
  LPD (Loi federale sur la protection des donnees) et au RGPD.

  Anonymisez les donnees avant de les saisir
  Utilisez des donnees synthetiques ou des valeurs fictives
  En cas de doute, contactez : dpo@tcs.ch

  Ref. : Directive SI-04 -- Usage des outils IA au TCS
======================================================================
```

**Installation du PII guard :**
```
1. cp templates/hooks/scripts/pii_check.py .claude/hooks/pii_check.py
2. Ajouter dans .claude/settings.json :
```
```jsonc
"hooks": {
  "UserPromptSubmit": [
    {
      "hooks": [
        { "type": "command", "command": "python .claude/hooks/pii_check.py", "timeout": 10 }
      ]
    }
  ]
}
```

### Combiner plusieurs templates

Si deux templates partagent le même événement (ex. deux `PostToolUse`), fusionner les
tableaux plutôt que d'écraser :

```jsonc
"hooks": {
  "PostToolUse": [
    { "matcher": "Write|Edit", "hooks": [{ "type": "command", "command": "pytest --tb=short -q 2>&1 | tail -20", "timeout": 60 }] },
    { "matcher": "Write|Edit", "hooks": [{ "type": "command", "command": "bandit -q -ll ...", "timeout": 20 }] }
  ],
  "UserPromptSubmit": [
    { "hooks": [{ "type": "command", "command": "python .claude/hooks/pii_check.py", "timeout": 10 }] }
  ]
}
```

> Changes are project-scoped. The library's `templates/settings.json` is never modified
> by consuming projects — it is the source template only.
