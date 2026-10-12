#!/usr/bin/env node
// version: 1.0.0
/*
 * pre-commit-guard.js -- cross-platform PreToolUse(Bash) hook for the Agentic-Claude library.
 *
 * Runs on Windows / macOS / Linux (Node ships with Claude Code, so `node` is available
 * wherever the hook runs). Wired via .claude/settings.json. Versioned on purpose.
 *
 * Blocks `git commit` against THIS repo only, until BOTH:
 *   1. CLAUDE.md's inventory references every agents/, skills/, and teams/*.md by name
 *      (matched as a backticked `name`, so incidental prose mentions do not count).
 *   2. Every AGENT.md / SKILL.md has valid `name:` and `description:` frontmatter.
 *
 * A human is still the only committer; this just refuses commits when the library drifted,
 * forcing the repo-improvement-team to sync the inventory + docs first.
 */
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const allow = () => process.exit(0);

// 1. Read the hook payload (JSON) from stdin; allow if absent/unparseable.
let payload;
try { payload = JSON.parse(fs.readFileSync(0, 'utf8')); } catch { allow(); }
const cmd = (payload && payload.tool_input && payload.tool_input.command) || '';
if (!/git\b[\s\S]*\bcommit\b/.test(cmd)) allow();          // only gate commits

// 2. Only act if the commit targets THIS repo (honor `git -C <path>`, else cwd).
const repoRoot = path.resolve(__dirname, '..', '..');      // .claude/hooks -> repo root
let target = process.cwd();
const c = cmd.match(/-C\s+"?([^"\s]+)"?/);
if (c) target = c[1];
let top;
try {
  top = execSync(`git -C "${target}" rev-parse --show-toplevel`, { stdio: ['ignore', 'pipe', 'ignore'] }).toString().trim();
} catch { allow(); }
try { if (fs.realpathSync(top) !== fs.realpathSync(repoRoot)) allow(); } catch { allow(); }

// 3. Run the checks.
const claudeMd = path.join(repoRoot, 'CLAUDE.md');
if (!fs.existsSync(claudeMd)) allow();
const doc = fs.readFileSync(claudeMd, 'utf8');
const problems = [];

const dirs = (rel) => {
  try { return fs.readdirSync(path.join(repoRoot, rel), { withFileTypes: true }).filter(d => d.isDirectory()).map(d => d.name); }
  catch { return []; }
};
const inDoc = (name) => doc.includes('`' + name + '`') || doc.includes('`/' + name + '`');

// 3a. Inventory sync
for (const a of dirs('agents')) if (!inDoc(a)) problems.push('inventory: agent not listed in CLAUDE.md -> ' + a);
for (const s of dirs('skills')) if (!inDoc(s)) problems.push('inventory: skill not listed in CLAUDE.md -> ' + s);
let teams = [];
try { teams = fs.readdirSync(path.join(repoRoot, 'teams')).filter(f => f.endsWith('.md')).map(f => f.replace(/\.md$/, '')); } catch {}
for (const t of teams) if (!inDoc(t)) problems.push('inventory: team not listed in CLAUDE.md -> ' + t);

// 3b. Frontmatter lint
const lint = (file) => {
  let txt;
  try { txt = fs.readFileSync(file, 'utf8'); } catch { return; }
  const rel = path.relative(repoRoot, file).replace(/\\/g, '/');
  if (!txt.startsWith('---')) { problems.push('frontmatter: missing `---` block -> ' + rel); return; }
  const end = txt.indexOf('\n---', 3);
  const fm = end > 0 ? txt.slice(0, end) : txt;
  if (!/\bname:\s*\S/.test(fm)) problems.push('frontmatter: missing name -> ' + rel);
  if (!/\bdescription:\s*\S/.test(fm)) problems.push('frontmatter: missing description -> ' + rel);
};
for (const a of dirs('agents')) lint(path.join(repoRoot, 'agents', a, 'AGENT.md'));
for (const s of dirs('skills')) lint(path.join(repoRoot, 'skills', s, 'SKILL.md'));

// 3c. Versioning checks (guard v1.0.0)
const parseVer = (t) => { const m = /version:\s*([0-9]+\.[0-9]+\.[0-9]+)/.exec(t || ''); return m ? m[1] : null; };

// Twin-parity: the .ps1 and .js guards must declare the same version header.
try {
  const psVer = parseVer(fs.readFileSync(path.join(__dirname, 'pre-commit-guard.ps1'), 'utf8'));
  const jsVer = parseVer(fs.readFileSync(path.join(__dirname, 'pre-commit-guard.js'), 'utf8'));
  if (psVer && jsVer && psVer !== jsVer) problems.push(`twin-parity: hook versions differ -> .ps1=${psVer} .js=${jsVer}`);
} catch {}

// Bump-on-change: a staged versioned object whose version did not change blocks the commit.
const isVersioned = (p) => /^agents\/[^/]+\/AGENT\.md$/.test(p) || /^skills\/[^/]+\/SKILL\.md$/.test(p) || /^teams\/[^/]+\.md$/.test(p) || /^\.claude\/hooks\/pre-commit-guard\.(ps1|js)$/.test(p);
const showVer = (ref) => { try { return parseVer(execSync(`git -C "${target}" show "${ref}"`, { stdio: ['ignore', 'pipe', 'ignore'] }).toString()); } catch { return null; } };
let staged = '';
try { staged = execSync(`git -C "${target}" diff --cached --name-status -M`, { stdio: ['ignore', 'pipe', 'ignore'] }).toString(); } catch {}
for (const row of staged.split('\n')) {
  const line = row.trim(); if (!line) continue;
  const f = line.split('\t');
  const code = f[0][0];
  const oldPath = f[1];
  const newPath = code === 'R' ? f[2] : f[1];
  if (!isVersioned(newPath)) continue;
  if (code === 'D') continue;
  const newVer = showVer(`:${newPath}`);
  if (code === 'A') { if (!newVer) problems.push('version: new object missing a version -> ' + newPath); continue; }
  if (code === 'R') {
    const oldVer = showVer(`HEAD:${oldPath}`);
    if (oldVer && newVer && oldVer === newVer) process.stderr.write('  ! warn: renamed without version bump -> ' + oldPath + ' -> ' + newPath + '\n');
    continue;
  }
  // Modified
  const oldVer = showVer(`HEAD:${newPath}`);
  if (!oldVer) continue;               // HEAD had no version -> newly versioned, skip compare
  if (!newVer) { problems.push('version: object lost its version -> ' + newPath); continue; }
  if (oldVer === newVer) problems.push('version: not bumped (still ' + newVer + ') -> ' + newPath);
}

if (problems.length) {
  process.stderr.write('BLOCKED by .claude/hooks/pre-commit-guard.js -- the library drifted; convene the repo-improvement-team before committing.\n');
  for (const p of problems) process.stderr.write('  - ' + p + '\n');
  process.exit(2);   // exit 2 => Claude Code blocks the tool call and shows this to the model
}
process.exit(0);
