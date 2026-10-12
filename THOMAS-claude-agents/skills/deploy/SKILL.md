---
name: deploy
version: 1.1.0
type: technological
category: devops-toolchain
platform: GitHub Actions · Azure · Docker
standards:
  - Azure Well-Architected Framework — Operational Excellence
  - CycloneDX SBOM v1.4
description: >
  Manage CI/CD pipelines, Docker builds, and cloud deployments. Creates or updates
  GitHub Actions workflows, Dockerfiles, Azure configurations, and SBOM generation.
  Use when the user says "deploy", "pipeline", "CI/CD", "Docker", "Azure", or "release".
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Task, TodoWrite, WebSearch
---

# /deploy — CI/CD & Deployment Workflow

## Step 1: Assess Current Infrastructure

Check what already exists before creating anything:

```bash
ls -la .github/workflows/ 2>/dev/null
ls -la Dockerfile* docker-compose* 2>/dev/null
ls -la bicep/ infra/ 2>/dev/null
git remote -v 2>/dev/null
```

Also read `.claude/memory/team-findings.md` — DevOps notes from previous sessions often contain pipeline quirks, required base image constraints, or environment-specific settings.

## Step 2: Map the Required Changes

Based on the request:

| Request | Files to create/update |
|---------|----------------------|
| Set up CI | `.github/workflows/ci.yml` |
| Add Docker | `Dockerfile`, `.dockerignore` |
| Deploy to Azure | `.github/workflows/deploy.yml`, `bicep/*.bicep` |
| Add linting/security | Steps in existing `ci.yml` |
| Set up environments | GitHub environment rules + `deploy.yml` |
| Add SBOM | `syft` or `cyclonedx` step in CI |
| Release pipeline | `.github/workflows/release.yml` |

Present the change list to the user before implementing. Do not create files speculatively.

## Step 3: Implement

### GitHub Actions standards
- Pin all actions to a full SHA: `actions/checkout@<sha>` (never `@v4` or `@main`)
- Use `actions/cache` for pip/npm/Maven dependencies
- One workflow per concern: `ci.yml` (build+test), `deploy.yml` (release), `security.yml` (scan)
- Use reusable workflows (`workflow_call`) for steps shared across repos
- Secrets via `${{ secrets.NAME }}` — never hardcoded, never echoed in logs

### Standard pipeline stages
```yaml
# Recommended stage order:
1. Checkout + Setup (actions/checkout, setup-python/node/java)
2. Cache dependencies
3. Install dependencies (pip/npm ci/mvn)
4. Lint + Format check (ruff/black/eslint/prettier)
5. Unit tests (pytest/jest) + coverage
6. Integration tests (with service containers)
7. Build image (docker build --no-cache)
8. Security scan (trivy for image, snyk/OWASP for deps)
9. SBOM generation (syft or cyclonedx)
10. Push image (on merge to main only)
11. Deploy (on merge to main, with environment approval gate)
```

### Docker standards
- Multi-stage builds: `builder` stage installs deps, `runtime` stage copies artefacts only
- Non-root user in final stage: `RUN useradd -m appuser && USER appuser`
- Specific base tags: `python:3.12-slim-bookworm` (never `latest`)
- `.dockerignore`: exclude `.git`, `.venv`, `__pycache__`, `*.md`, `tests/`
- Health check: `HEALTHCHECK CMD curl -f http://localhost:8000/health || exit 1`

### Azure standards
- Container Apps: `minReplicas: 0` for dev/QA, `minReplicas: 1` for prod
- Managed identity for all service-to-service auth (no credentials in config)
- Key Vault references for secrets: `@Microsoft.KeyVault(SecretUri=...)`
- Tag all resources: `project`, `environment`, `owner`, `cost-center`
- Always estimate cost impact before provisioning new resources

### IBM APIC deployment (if applicable)
- API definitions deployed via `apic publish` CLI — never manually via portal
- Catalog targets: `dev` → `sandbox`, `qa` → `test`, `main` → `production`
- Product version must be bumped before republishing (APIC rejects same-version republish)

## Step 4: Validate Before Reporting

```bash
# Validate YAML syntax
python3 -c "import yaml, sys; yaml.safe_load(open(sys.argv[1]))" .github/workflows/ci.yml

# Validate Dockerfile (if hadolint available)
hadolint Dockerfile 2>/dev/null || echo "hadolint not available — review manually"

# List all secrets the pipeline requires
grep -E '\$\{\{ secrets\.' .github/workflows/*.yml | grep -oE 'secrets\.[A-Z_]+' | sort -u
```

Write infrastructure discoveries to `.claude/memory/team-findings.md`:
```
[YYYY-MM-DD] devops — <finding, e.g. "CI requires DOCKER_USERNAME secret — see ci.yml:42">
```

## Step 5: Report

```
## Infrastructure Changes

### Files Created / Updated
- `.github/workflows/ci.yml` — Added: lint, test, docker build, trivy scan
- `Dockerfile` — Multi-stage build, non-root user, health check
- `.dockerignore` — Excludes .venv, __pycache__, tests/

### Required Configuration
| Secret / Variable | Where | Description |
|-------------------|-------|-------------|
| `AZURE_CREDENTIALS` | GitHub Secrets | Service principal JSON for Azure login |
| `REGISTRY_TOKEN`   | GitHub Secrets | Container registry push token |

### Cost Impact
- <Azure resources added and estimated monthly cost, or "none">

### Rollback Plan
- <How to roll back this deployment if it fails>

### Next Steps
- [ ] Add secrets in GitHub repository settings → Secrets and variables
- [ ] Enable environment protection rules for production
- [ ] Test pipeline by pushing to a feature branch
```
