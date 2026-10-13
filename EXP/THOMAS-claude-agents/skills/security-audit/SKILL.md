---
name: security-audit
version: 1.2.0
type: methodological
category: security
standards:
  - OWASP Top 10 (2021)
  - OWASP ASVS 4.0
  - CWE/SANS Top 25
  - IBM APIC/ACE security hardening guide
description: >
  Dedicated security audit covering OWASP Top 10, secret scanning, dependency CVEs,
  authentication/authorization, cryptography, and IBM integration security (APIC/ACE).
  More thorough than the security section in /review. Use when the user says "security audit",
  "pentest", "vulnerability scan", "OWASP", or before a production release.
allowed-tools: Read, Grep, Glob, Bash, Task, TodoWrite, WebSearch
---

# /security-audit — Security Audit Workflow

## Step 1: Map the attack surface

Before checking anything, understand what you're auditing:

```bash
# Identify entry points (HTTP handlers, CLI args, file readers)
grep -rn "request\|@app\.\|@router\.\|argparse\|sys.argv\|open(" src/ --include="*.py" -l 2>/dev/null | head -20
grep -rn "app.get\|app.post\|router\.\|express()" src/ --include="*.js" --include="*.ts" -l 2>/dev/null | head -20

# Identify data stores
grep -rn "connect\|Session\|engine\|MongoClient\|redis" src/ -l 2>/dev/null | head -10
```

List the entry points, data stores, and external services before proceeding.

## Step 2: Secret scan

Search for hardcoded secrets — the most common and most critical finding:

```bash
# Patterns that indicate hardcoded secrets
grep -rn \
  -e "password\s*=\s*['\"][^'\"${\[]" \
  -e "secret\s*=\s*['\"][^'\"${\[]" \
  -e "api_key\s*=\s*['\"][^'\"${\[]" \
  -e "token\s*=\s*['\"][^'\"${\[]" \
  -e "-----BEGIN.*PRIVATE KEY" \
  --include="*.py" --include="*.js" --include="*.ts" --include="*.yaml" --include="*.yml" \
  --include="*.json" --include="*.env*" \
  . 2>/dev/null | grep -v "test\|spec\|example\|sample\|\.git"
```

Also check git history for accidentally committed secrets:
```bash
git log --all --oneline 2>/dev/null | head -20
# Flag if .env files, private keys, or credentials appear in filenames
git log --all --name-only --pretty=format: 2>/dev/null | grep -iE "\.env$|id_rsa|\.pem|credentials|secrets" | sort -u | head -20
```

## Step 3: OWASP Top 10 checklist

### A01 — Broken Access Control
- [ ] All routes/endpoints enforce authentication before returning data
- [ ] Authorization checks happen server-side (not just hidden in UI)
- [ ] File paths are sanitized — no user input in `open()`, `Path()`, or file operations
- [ ] Directory traversal impossible: `../` sequences rejected or resolved safely
- [ ] JWT/session tokens validated on every request, not just at login

```bash
# Look for unprotected routes
grep -rn "def \|async def \|app\.\(get\|post\|put\|delete\)" src/ --include="*.py" -A3 2>/dev/null | grep -v "login\|auth\|require\|verify\|token" | head -20
```

### A02 — Cryptographic Failures
- [ ] Sensitive data (passwords, PII) encrypted at rest
- [ ] TLS enforced for all external calls — no `verify=False`, no `http://` for sensitive endpoints
- [ ] Passwords hashed with bcrypt/argon2/scrypt — not MD5/SHA1/plain storage
- [ ] No weak random: `random.random()` or `Math.random()` for security purposes

```bash
grep -rn "verify=False\|ssl=False\|verify=0\|NODE_TLS_REJECT_UNAUTHORIZED" . --include="*.py" --include="*.js" --include="*.ts" 2>/dev/null
grep -rn "md5\|sha1\|hashlib\.\(md5\|sha1\)" src/ --include="*.py" 2>/dev/null | grep -v "test\|#"
grep -rn "random\.random\(\)\|Math\.random()" src/ 2>/dev/null | grep -iv "test\|seed\|color\|shuffle" | head -10
```

### A03 — Injection
- [ ] SQL: parameterized queries only — no string formatting with user input
- [ ] Command injection: no `subprocess.shell=True` with user input, no `os.system()` with variables
- [ ] NoSQL injection: MongoDB queries sanitized
- [ ] Template injection: Jinja2/Twig templates don't render user strings

```bash
# SQL injection candidates
grep -rn "execute\|query" src/ --include="*.py" -A1 2>/dev/null | grep -E '"%|format\(|f".*{' | head -20
# Shell injection candidates
grep -rn "subprocess\|os\.system\|os\.popen\|shell=True" src/ --include="*.py" 2>/dev/null | head -20
```

### A04 — Insecure Design
- [ ] Rate limiting on authentication endpoints
- [ ] Account lockout after N failed login attempts
- [ ] Password reset tokens expire and are single-use
- [ ] Sensitive operations require re-authentication

### A05 — Security Misconfiguration
- [ ] Debug mode disabled in production (`DEBUG=False`, not `app.run(debug=True)`)
- [ ] Stack traces not exposed to end users
- [ ] Default credentials changed
- [ ] Unnecessary HTTP methods disabled (DELETE, TRACE, OPTIONS)

```bash
grep -rn "DEBUG\s*=\s*True\|debug=True\|app\.run(" . --include="*.py" --include="*.env*" 2>/dev/null | grep -v "test\|#"
```

### A06 — Vulnerable Components
```bash
# Python: check for known CVEs in dependencies
pip audit 2>/dev/null || safety check 2>/dev/null || echo "Install pip-audit: pip install pip-audit"

# Node: check for vulnerabilities
npm audit 2>/dev/null || echo "Run npm audit in project"
```

### A07 — Authentication Failures
- [ ] Session IDs are sufficiently random and regenerated after login
- [ ] Logout invalidates server-side session, not just client cookie
- [ ] Multi-factor authentication available for sensitive operations
- [ ] Brute-force protection on login endpoint

### A08 — Software and Data Integrity
- [ ] Dependencies pinned to exact versions in production (`==` not `>=`)
- [ ] Package integrity verified (hashes in `requirements.txt` or `package-lock.json`)
- [ ] CI/CD pipeline does not execute untrusted scripts

### A09 — Logging & Monitoring
- [ ] Authentication events logged (success and failure)
- [ ] Errors logged with enough context to investigate
- [ ] No PII or secrets in logs
- [ ] Log injection prevented (user input sanitized before logging)

```bash
grep -rn "logger\.\|logging\.\|console\.log" src/ --include="*.py" --include="*.js" -l 2>/dev/null | head -10
```

### A10 — SSRF (Server-Side Request Forgery)
- [ ] URLs passed to HTTP clients are validated against an allowlist
- [ ] Internal metadata endpoints (169.254.169.254, localhost) blocked
- [ ] User-controlled URLs cannot target internal services

```bash
grep -rn "requests\.get\|httpx\.get\|fetch(" src/ --include="*.py" --include="*.js" -B2 2>/dev/null | grep -E "url|href|endpoint" | head -20
```

## Step 4: IBM APIC / ACE security (if applicable)

- [ ] `X-IBM-Client-Id` / `X-IBM-Client-Secret` — stored in vault, never hardcoded
- [ ] OAuth2 tokens not logged — check ACE ESQL compute nodes for trace outputs
- [ ] API definitions use HTTPS-only invoke URLs (no `http://` in `target-url`)
- [ ] Rate limiting and quota policies configured in APIC
- [ ] Consumer subscriptions scoped to minimum required plans

```bash
grep -rn "target-url\|http://" . --include="*.yaml" --include="*.yml" 2>/dev/null | grep -v "localhost\|127\.0\.0\.1\|#" | head -10
```

## Step 5: Report

```
## Security Audit Report — <project/scope>
Date: <YYYY-MM-DD>

### Attack Surface
- Entry points: <list>
- Data stores: <list>
- External services: <list>

### Findings

| ID | Severity | Category | File | Line | Description |
|----|----------|----------|------|------|-------------|
| S1 | 🔴 Critical | Injection | src/db.py | 42 | SQL built with f-string — use parameterized query |
| S2 | 🟡 High | Secrets | config.py | 8 | Hardcoded API key — move to environment variable |
| S3 | 🟡 High | Crypto | auth.py | 15 | MD5 used for password hashing — use bcrypt |
| S4 | 🟢 Medium | Config | app.py | 3 | debug=True in app.run() — disable in production |

Severity guide:
- 🔴 Critical — exploitable without authentication, data breach risk. Fix before deploy.
- 🟡 High — exploitable with low effort or in specific conditions. Fix in current sprint.
- 🟢 Medium — requires specific conditions or provides limited access. Fix in next sprint.
- 🔵 Low — defence-in-depth, best practice. Fix when convenient.

### Dependency CVEs
<output of pip audit / npm audit, or "None found">

### Secrets Found
<list of files:lines, or "None found">

### Recommendations
1. <highest priority fix>
2. <second priority>
3. <third priority>

### Passed Checks
- <what was checked and found clean>
```
