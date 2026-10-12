# Publishing the presentation to Confluence

[`index.html`](index.html) is a self-contained presentation of the Agentic-Claude
library. [`scripts/publish_to_confluence.py`](../../scripts/publish_to_confluence.py)
renders it into a **single, read-only Confluence page** that stays in sync with git.

## What the script does

- Stacks every `<section class="page">` into one page, with a **TOC macro** and per-section **anchors** for navigation.
- Converts `.stat-row` blocks to **summary tables** (e.g. "6 Agents / 6 Skills / …").
- Converts `.pill` badge groups to **metadata tables** (Model / Memory / Tools) with `code`-formatted values.
- Converts `.flow` step sequences to **numbered lists**.
- Converts `.xref` link bars to compact **"See also:"** paragraphs.
- Extracts inline **SVG diagrams**, attaches them to the page, and embeds them.
- Converts `.callout` blocks to Confluence **info panels**; strips presentational `class`/`style`/`onclick`.
- Adds a **"Auto-generated from git — do not edit"** warning banner at the top.
- Optionally applies a **read-only restriction** so only the publishing account can edit.
- **Idempotent**: re-running overwrites the same page (matched by title) and bumps its version.

## Prerequisites

- [uv](https://docs.astral.sh/uv/) installed and on PATH. The wrapper pulls
  `requests`, `beautifulsoup4`, and `lxml` into an ephemeral environment — nothing
  to install globally.

---

## Auto-update (CI — recommended)

The GitHub Actions workflow [`.github/workflows/publish-confluence.yml`](../../.github/workflows/publish-confluence.yml)
publishes automatically on every push to `main` that touches `index.html` or
the publish script.

### Setup (one time)

1. Go to **Settings → Secrets → Actions** in the GitHub repo.
2. Add the required secrets:

| Secret | Example value |
|--------|---------------|
| `CONFLUENCE_BASE_URL` | `https://yoursite.atlassian.net/wiki` |
| `CONFLUENCE_SPACE_KEY` | `ARCH` |
| `CONFLUENCE_API_TOKEN` | _(your API token or PAT)_ |
| `CONFLUENCE_USER` | `you@tcs.ch` _(Cloud only)_ |

3. Optional secrets: `CONFLUENCE_AUTH` (`bearer` for Server/DC PAT), `CONFLUENCE_PAGE_TITLE`, `CONFLUENCE_PARENT_ID`.

After that, every merge to `main` that changes `index.html` triggers a publish automatically.
You can also trigger it manually from the **Actions** tab → **Publish to Confluence** → **Run workflow**.

---

## Auto-update (local git hook — optional)

For immediate feedback during local development, install a `post-commit` hook:

```powershell
./scripts/install-git-hook.ps1
```

The hook fires after every commit that includes `docs/presentation/index.html`.
It reads `CONFLUENCE_*` from your environment or from a `.env` file at the repo root.

**Uninstall:**
```powershell
./scripts/install-git-hook.ps1 -Uninstall
```

---

## Manual publish

### 1. Preview (no Confluence needed)

```powershell
./scripts/publish_to_confluence.ps1 -DryRun
```

Writes `docs/presentation/.preview/confluence-storage.xml` + the extracted `*.svg`
(git-ignored) so you can inspect the converted storage format before publishing.

### 2. Live publish

```powershell
# --- Confluence Cloud ---
$env:CONFLUENCE_BASE_URL  = "https://yoursite.atlassian.net/wiki"
$env:CONFLUENCE_SPACE_KEY = "ARCH"
$env:CONFLUENCE_PAGE_TITLE= "Agentic-Claude — Agent & Skill Library"
$env:CONFLUENCE_USER      = "you@tcs.ch"          # Atlassian account email
$env:CONFLUENCE_API_TOKEN = "<api-token>"          # id.atlassian.com → API tokens

./scripts/publish_to_confluence.ps1
```

For **Confluence Server / Data Center** (e.g. `confluence.tcsgroup.ch`), use a
Personal Access Token with bearer auth:

```powershell
$env:CONFLUENCE_BASE_URL  = "https://confluence.tcsgroup.ch"
$env:CONFLUENCE_AUTH      = "bearer"
$env:CONFLUENCE_API_TOKEN = "<personal-access-token>"
$env:CONFLUENCE_SPACE_KEY = "ARCH"
$env:CONFLUENCE_PAGE_TITLE= "Agentic-Claude — Agent & Skill Library"

./scripts/publish_to_confluence.ps1
```

---

## Environment variables reference

| Variable | Required | Notes |
|----------|----------|-------|
| `CONFLUENCE_BASE_URL` | yes | Cloud: `https://<site>.atlassian.net/wiki`; Server/DC: `https://host` |
| `CONFLUENCE_SPACE_KEY` | yes | Target space key |
| `CONFLUENCE_PAGE_TITLE` | no | Defaults to "Agentic-Claude — Agent & Skill Library" |
| `CONFLUENCE_API_TOKEN` | yes | API token (Cloud) or PAT (Server/DC) |
| `CONFLUENCE_USER` | Cloud only | Account email (basic auth); also the editor kept by the read-only restriction |
| `CONFLUENCE_AUTH` | no | `basic` (default) or `bearer` (Server/DC PAT) |
| `CONFLUENCE_PARENT_ID` | no | Parent page id to nest under |
| `CONFLUENCE_RESTRICT` | no | `true` (default) locks editing to `CONFLUENCE_USER` |
| `CONFLUENCE_API_PREFIX` | no | Defaults to `/rest/api` |
| `DRY_RUN` | no | `true` = preview only (the `-DryRun` switch sets this) |

> **Tip:** keep the token out of your shell history — set it for the session only,
> read it from a secret store, or put it in a `.env` file (already git-ignored).
> Never commit it.
