# Agentic-Claude

**8 specialized agents · 8 skills · 4 team blueprints** for Claude Code.
Built for enterprise software teams working with IBM APIC, ACE, and MQ.

---

## Install

```
/plugin marketplace add Aletheia-Thomas/Claude-Agents
/plugin install agentic-claude@agentic-claude-lib
```

Or bootstrap a new project in one command:
```powershell
powershell -ExecutionPolicy Bypass -File templates/setup.ps1
```
```bash
bash templates/setup.sh
```

---

## Agents

| Agent | Invoke as | Does |
|-------|-----------|------|
| `developer` | `@developer` | Production code — SOLID, Clean Code, no tests or docs |
| `tester` | `@tester` | ISTQB tests — pytest, async, mutation testing |
| `devops` | `@devops` | CI/CD, Docker, Azure, SBOM pipelines |
| `architect` | `@architect` | IBM APIC/ACE/MQ dependency mapping |
| `documentarian` | `@documentarian` | CLAUDE.md, ADRs, C4 diagrams |
| `product-owner-assistant` | `@product-owner-assistant` | Orchestration, backlog, agent delegation |
| `librarian` | `@librarian` | Maintains this library *(repo-improvement-team only)* |
| `library-engineer` | `@library-engineer` | Maintains scripts/hooks *(repo-improvement-team only)* |

---

## Skills

| Skill | Trigger phrases |
|-------|----------------|
| `/develop` | "implement", "build", "fix", "add feature" |
| `/test` | "test", "run tests", "coverage", "validate" |
| `/review` | "review", "check code", "code quality" |
| `/deploy` | "deploy", "pipeline", "CI/CD", "Docker", "Azure" |
| `/document` | "update docs", "document", "ADR", "update context" |
| `/security-audit` | "security audit", "OWASP", "vulnerabilities", "pentest" |
| `/postman-collection-generator` | "postman", "collection", "non-regression", "API test" |
| `/publish-confluence` | "publish", "confluence" |

---

## Teams

| Team | Agents | Use for |
|------|--------|---------|
| `feature-team` | developer → tester → documentarian | End-to-end feature |
| `release-team` | tester → devops → documentarian | Release preparation |
| `full-team` | all 6 project agents | Major features, migrations |
| `repo-improvement-team` | PO + librarian + library-engineer | Improving this library |

Enable teams:
```bash
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
```

---

## Hooks (included in setup)

`templates/settings.json` ships with hooks wired to your project:
- **Branch guardrail** — blocks `git push` and `git commit` directly on `main`
- **Agent reminders** — after each agent stops, prompts the next step
- **Notification log** — all Claude notifications logged to `.claude/memory/notifications.log`

---

## Keeping agents up to date

```powershell
powershell -ExecutionPolicy Bypass -File templates/update.ps1 -Apply
```
```bash
bash templates/update.sh --apply
```

---

## Docs

- [Plugin Setup Guide](docs/howto/PLUGIN-SETUP.md)
- [Create a new agent](docs/howto/AGENT-AUTHORING.md)
- [Create a new skill](docs/howto/SKILL-AUTHORING.md)
- [Create a new team](docs/howto/TEAM-AUTHORING.md)
- [Full README](README.md)
