# CLAUDE.md — <ProjectName>

> This file is the project's memory for Claude Code sessions.
> Fill in every section. The more context here, the better agents perform.
> Keep it concise and scannable — use tables and bullet points, not paragraphs.

---

## What This Project Does

<!-- One paragraph: what it is, who uses it, what problem it solves -->

## Quick Start

```bash
# Install dependencies
<install command>

# Run the application
<run command>

# Run all tests
<test command>
```

## Architecture

<!-- Key modules and their responsibilities -->

| Module / Folder | Purpose |
|-----------------|---------|
| `src/`          | Application code |
| `tests/`        | Test suite (unit + integration) |
| `docs/`         | Architecture docs, ADRs, operations runbooks |

## Key Patterns

<!-- Patterns agents MUST follow when working on this project. Be specific. -->

- **Naming**: ...
- **Error handling**: ...
- **Data access**: ...
- **Logging**: structured JSON to stdout via `structlog` / `winston` / ...
- **Config**: environment variables only — no hardcoded values

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Language | Python 3.x / Node.js / Java / ... |
| Framework | FastAPI / Express / Spring Boot / ... |
| Database | PostgreSQL / ChromaDB / ... |
| Message broker | IBM MQ / RabbitMQ / ... |
| API gateway | IBM APIC / Kong / ... |
| CI/CD | GitHub Actions |
| Hosting | Azure Container Apps / AKS / ... |

## Integration Points

<!-- External systems this project connects to. Critical for the architect and tester agents. -->

| System | Type | Direction | Auth |
|--------|------|-----------|------|
| ... | REST / MQ / SOAP | inbound / outbound | IBM Client-Id/Secret / OAuth2 |

## Environment Variables

<!-- Names only — never values. Values go in .env or Azure Key Vault. -->

| Variable | Required | Description |
|----------|----------|-------------|
| `DATABASE_URL` | Yes | Connection string |
| `APIC_CLIENT_ID` | Yes | IBM APIC client identifier |
| `APIC_CLIENT_SECRET` | Yes | IBM APIC client secret |

## Testing

```bash
# Unit tests
pytest tests/unit/ -v

# Integration tests (requires running services)
pytest tests/integration/ -v

# All tests with coverage
pytest --cov=src --cov-report=term-missing tests/

# Check coverage threshold
pytest --cov=src --cov-fail-under=80 tests/
```

## Common Commands

```bash
# Lint
ruff check src/ / eslint src/

# Format
black src/ / prettier --write src/

# Build Docker image
docker build -t <project-name>:local .

# Run locally
docker compose up
```

## Known Gotchas

<!-- Things that wasted time before — save the next agent from the same trap -->

- ...

## Agent Notes

<!-- Instructions specific to this project that override or supplement agent defaults -->

- **Developer**: always run `<lint command>` before committing
- **Tester**: integration tests need `<service>` running — see `docker-compose.yml`
- **DevOps**: deployment targets `<environment>` — use `<pipeline file>`
- **Documentarian**: ADRs go in `docs/adr/` with format `NNNN-title.md`
- **Architect**: integration diagrams in `docs/architecture/` use C4 Model format
