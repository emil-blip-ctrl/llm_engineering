---
name: test
version: 1.1.0
type: methodological
category: quality-assurance
standards:
  - ISTQB Foundation Level syllabus
  - IEEE 829 Test Documentation
  - BDD / Gherkin (Cucumber)
description: >
  Run tests, analyze results, write missing tests, and report quality metrics.
  Checks infrastructure requirements, runs the suite, identifies coverage gaps,
  and optionally runs mutation testing. Use after /develop completes, or when
  the user says "test", "run tests", "validate", "coverage", or "check quality".
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Task, TodoWrite
---

# /test — Test Execution & Validation Workflow

## Step 1: Establish Scope and Infrastructure

Determine what to test:
- **After `/develop`**: test the files that were just changed
- **User-specified**: test exactly what was requested
- **General**: run the full test suite

Before running anything, read **`.claude/memory/team-findings.md`** for infrastructure notes — required fixtures, known flaky tests, DB setup requirements, or environment variables.

Check the project's test structure:

```bash
# Find test directories
find . -type d -name "tests" -not -path "*/node_modules/*" -not -path "*/.git/*" -not -path "*/.venv/*" 2>/dev/null

# Check test runner config
cat pytest.ini pyproject.toml setup.cfg 2>/dev/null | grep -A10 "\[tool.pytest\|pytest\]" || true
cat jest.config.* package.json 2>/dev/null | grep -A5 "jest" || true
```

## Step 2: Run Existing Tests

### Python (pytest)
```bash
# Run targeted tests first, then full suite
pytest -v --tb=short <changed_module_tests>
pytest -v --tb=short

# With coverage (when requested or when writing new tests)
pytest -v --cov=<module> --cov-report=term-missing --cov-fail-under=80
```

### JavaScript / TypeScript (Jest / Vitest)
```bash
npm test -- --coverage --verbose
npx vitest run --coverage
```

### Java (Maven)
```bash
mvn test -pl <module>
```

Capture: **total, passed, failed, errors, skipped**. Do not wait until all tests finish to report — send an intermediate update after the first test file batch.

## Step 3: Analyze Failures

For each failing test:
1. Read the test — what behavior does it assert?
2. Read the implementation — what does it actually do?
3. Determine the root cause:
   - **Bug in implementation** → describe the bug, do NOT fix it (developer's job)
   - **Test needs updating** → the implementation changed intentionally; update the test
   - **Flaky test** → note it, re-run to confirm, flag in team-findings.md
4. Report: test name, expected vs actual, likely cause

## Step 4: Write Missing Tests

If the changed code lacks test coverage:
1. Identify untested behaviors (use coverage report, code reading, or intuition)
2. Design test cases using ISTQB principles:
   - Boundary value analysis (min, max, min-1, max+1)
   - Equivalence partitioning (valid/invalid input classes)
   - Error guessing (what are the likely failure modes?)
3. Write tests following project conventions:
   - Name: `test_<what>_<condition>_<expected_outcome>`
   - One assertion per test (or closely related group)
   - No shared mutable state between tests
   - Mock external services (HTTP, DB, filesystem) in unit tests
4. Run new tests to confirm they pass

### Python patterns
```python
@pytest.mark.parametrize("input,expected", [
    ("valid_case",   expected_output),
    ("edge_case",    edge_output),
    ("",             ValueError),
])
def test_function_handles_inputs(input, expected):
    ...

# Async API mocking
import respx, httpx
@respx.mock
def test_api_call():
    respx.get("https://api.example.com/data").mock(return_value=httpx.Response(200, json={"ok": True}))
    ...
```

## Step 5: Mutation Testing (optional — run when coverage ≥ 80%)

When the test suite is healthy, validate test quality with mutation testing:

```bash
# Python
mutmut run --paths-to-mutate src/<module>
mutmut results

# Report surviving mutants (tests that didn't catch the mutation)
mutmut show <id>
```

Surviving mutants indicate tests that don't actually verify behavior. Report the top 3 most critical surviving mutants with suggested fixes.

## Step 6: Write to team-findings.md

If you found infrastructure issues, flaky tests, or missing fixtures, append to `.claude/memory/team-findings.md`:

```
[YYYY-MM-DD] tester — <finding, e.g. "integration tests require REDIS_URL env var — see conftest.py:14">
```

## Step 7: Report

```
## Test Results — <scope>

### Execution
- Suite  : <path>
- Runner : pytest / jest / mvn
- Total  : X  |  Passed: X  |  Failed: X  |  Errors: X  |  Skipped: X
- Coverage: X% (threshold: 80%)

### Failures
| # | Test | Expected | Got | Cause |
|---|------|----------|-----|-------|
| 1 | `test_name` | X | Y | Bug in `module.function:L42` |

### New Tests Written
- `tests/unit/test_feature.py` — X test cases covering: <behaviors>

### Mutation Testing (if run)
- Survivors: X  |  Critical: <top issue + suggested fix>

### Recommendations
- [ ] Fix bug in: `file.py:L42` (developer task)
- [ ] Add coverage for: <untested paths>
- [ ] Investigate flaky: `test_name` (re-runs inconsistently)
```
