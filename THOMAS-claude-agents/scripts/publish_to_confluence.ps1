# publish_to_confluence.ps1 — render docs/presentation/index.html to a Confluence page.
#
# Manual publish helper (no CI). Requires uv (https://docs.astral.sh/uv/); it pulls
# the Python deps (requests, beautifulsoup4, lxml) into an ephemeral environment.
#
# Usage:
#   ./scripts/publish_to_confluence.ps1 -DryRun     # convert + write .preview/, no API calls
#   ./scripts/publish_to_confluence.ps1             # live publish (requires CONFLUENCE_* env vars)
#
# Confluence target & credentials come from environment variables — see
# docs/presentation/PUBLISHING.md for the full list.

param(
    [switch]$DryRun,
    [switch]$NoInsecureHosts   # drop the corp-proxy TLS bypass for PyPI (use on networks without TLS inspection)
)

$ErrorActionPreference = "Stop"
$root   = Split-Path -Parent $PSScriptRoot
$script = Join-Path $PSScriptRoot "publish_to_confluence.py"

$uvArgs = @("run", "--with", "beautifulsoup4", "--with", "lxml", "--with", "requests")
if (-not $NoInsecureHosts) {
    # TCS proxy does TLS inspection; uv won't trust PyPI without this.
    $uvArgs += @("--allow-insecure-host", "pypi.org", "--allow-insecure-host", "files.pythonhosted.org")
}
$uvArgs += @("python", $script)

$env:DRY_RUN = if ($DryRun) { "true" } else { "false" }

Push-Location $root
try {
    & uv @uvArgs
} finally {
    Pop-Location
}
