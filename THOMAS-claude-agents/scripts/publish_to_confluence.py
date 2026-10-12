#!/usr/bin/env python3
"""
Publish docs/presentation/index.html to the Agentic-Claude Library in Confluence.

Each section of the HTML maps to a Confluence page.  Known pages (in KNOWN_PAGES)
are updated in-place by ID.  New sections are created automatically under the
correct parent (determined by nav group), and their IDs are persisted to
scripts/page_ids.json so subsequent runs update rather than re-create them.

Target structure (AAI space):
  📦 Agentic-Claude — Library (v1.2)  [1926398064]
  ├── 📖 Overview                      ← updated from #overview section
  ├── 🗺️ Data Model                    ← updated from #data-model section
  ├── 🧠 Context & Memory              ← updated from #memory section
  ├── 🧩 All Teams
  │   ├── 🧩 Feature Team (v1.1)       ← updated from #team-feature
  │   └── … (all teams)
  ├── 🤖 All Agents & Relations        ← updated from #agents
  │   └── … (all agents)
  ├── ⚡ All Skills                    ← updated from #skills
  │   └── … (all skills)
  ├── 🚀 Versioning & Distribution     ← updated from #versioning
  └── 🔒 Hooks & Guardrails            ← updated from #hooks-guardrails

New sections added to index.html are automatically created on Confluence on the
next push — no manual ID registration needed.

REQUIRED ENV:
  CONFLUENCE_BASE_URL     e.g. https://yoursite.atlassian.net/wiki
  CONFLUENCE_SPACE_KEY    target space key, e.g. AAI
  CONFLUENCE_USER         account email (Cloud)
  CONFLUENCE_API_TOKEN    API token (Cloud) or Personal Access Token (Server/DC)

OPTIONAL ENV:
  CONFLUENCE_AUTH         "basic" (default) or "bearer" (Server/DC PAT)
  CONFLUENCE_API_PREFIX   REST prefix; default "/rest/api"
  PRESENTATION_HTML       path to source HTML; default docs/presentation/index.html
  DRY_RUN                 "true" to write storage XML locally without calling the API
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

try:
    import requests
    from bs4 import BeautifulSoup, Tag
except ImportError:
    sys.exit("Missing deps. Install with: pip install requests beautifulsoup4 lxml")

PAGE_IDS_FILE = Path(__file__).resolve().parent / "page_ids.json"


SVG_NS = "http://www.w3.org/2000/svg"
REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_HTML = REPO_ROOT / "docs" / "presentation" / "index.html"

STRIP_ATTRS = ("class", "style", "onclick", "viewbox", "font-family", "data-page")
ALLOWED = {
    "h1", "h2", "h3", "h4", "h5", "h6", "p", "ul", "ol", "li", "table",
    "thead", "tbody", "tr", "td", "th", "strong", "b", "em", "i", "code",
    "pre", "br", "hr", "a", "blockquote",
}

_BANNER = (
    '<ac:structured-macro ac:name="warning"><ac:rich-text-body>'
    "<p><strong>Auto-generated from git</strong> — do not edit here. "
    "Source: <code>docs/presentation/index.html</code>. "
    "Changes are overwritten on the next publish.</p>"
    "</ac:rich-text-body></ac:structured-macro>"
)


def env(name: str, default: str | None = None, required: bool = False) -> str | None:
    val = os.environ.get(name, default)
    if required and not val:
        sys.exit(f"ERROR: required env var {name} is not set")
    return val


# --------------------------------------------------------------------------- #
# Helpers
# --------------------------------------------------------------------------- #

def slugify(text: str) -> str:
    keep = [c.lower() if c.isalnum() else "-" for c in text.strip()]
    return "".join(keep).strip("-")[:60] or "diagram"


def extract_svgs(soup: BeautifulSoup, section: Tag, prefix: str, svgs: dict[str, str]) -> None:
    """Replace each inline <svg> with an <ac:image> referencing a saved attachment."""
    for i, svg in enumerate(section.find_all("svg")):
        name = f"{prefix}-{i}.svg" if i else f"{prefix}.svg"
        svg.attrs["xmlns"] = SVG_NS
        width = svg.get("width") or "820"
        svgs[name] = str(svg)
        img = soup.new_tag("ac:image")
        img.attrs["ac:width"] = str(width).replace("px", "") or "820"
        ref = soup.new_tag("ri:attachment")
        ref.attrs["ri:filename"] = name
        img.append(ref)
        svg.replace_with(img)


def to_info_panel(soup: BeautifulSoup, callout: Tag) -> Tag:
    macro = soup.new_tag("ac:structured-macro")
    macro.attrs["ac:name"] = "info"
    body = soup.new_tag("ac:rich-text-body")
    for child in list(callout.contents):
        body.append(child.extract())
    macro.append(body)
    return macro


def clean(node: Tag, soup: BeautifulSoup) -> None:
    for child in list(node.children):
        if not isinstance(child, Tag):
            continue
        if child.name.startswith(("ac:", "ri:")):
            continue
        clean(child, soup)
        for attr in STRIP_ATTRS:
            child.attrs.pop(attr, None)
        if child.name == "a":
            if not child.get("href"):
                child.unwrap()
            continue
        if child.name not in ALLOWED:
            child.unwrap()


# --------------------------------------------------------------------------- #
# Semantic transforms — run before clean() to preserve structure
# --------------------------------------------------------------------------- #

def transform_stats(soup: BeautifulSoup, section: Tag) -> None:
    for row in section.find_all(class_="stat-row"):
        stats = row.find_all(class_="stat")
        if not stats:
            row.decompose()
            continue
        table = soup.new_tag("table")
        thead = soup.new_tag("thead")
        tr_h = soup.new_tag("tr")
        tbody = soup.new_tag("tbody")
        tr_b = soup.new_tag("tr")
        for stat in stats:
            n_tag = stat.find(class_="n")
            l_tag = stat.find(class_="l")
            th = soup.new_tag("th")
            th.string = l_tag.get_text(strip=True) if l_tag else "—"
            td = soup.new_tag("td")
            strong = soup.new_tag("strong")
            strong.string = n_tag.get_text(strip=True) if n_tag else "—"
            td.append(strong)
            tr_h.append(th)
            tr_b.append(td)
        thead.append(tr_h)
        tbody.append(tr_b)
        table.append(thead)
        table.append(tbody)
        row.replace_with(table)


def transform_pills(soup: BeautifulSoup, section: Tag) -> None:
    for container in section.find_all(["div", "p"]):
        direct_pills = [
            c for c in container.children
            if isinstance(c, Tag) and "pill" in (c.get("class") or [])
        ]
        if len(direct_pills) < 2:
            continue
        model_v = [p.get_text(strip=True).replace("model: ", "")
                   for p in direct_pills if "model" in (p.get("class") or [])]
        mem_v = [p.get_text(strip=True).replace("memory: ", "")
                 for p in direct_pills if "mem" in (p.get("class") or [])]
        tool_v = [p.get_text(strip=True)
                  for p in direct_pills if "tool" in (p.get("class") or [])]
        if not (model_v or mem_v or tool_v):
            continue
        table = soup.new_tag("table")
        for label, values in [("Model", model_v), ("Memory", mem_v), ("Tools", tool_v)]:
            if not values:
                continue
            tr = soup.new_tag("tr")
            th = soup.new_tag("th")
            th.string = label
            td = soup.new_tag("td")
            for i, v in enumerate(values):
                if i > 0:
                    td.append(", ")
                code_tag = soup.new_tag("code")
                code_tag.string = v
                td.append(code_tag)
            tr.append(th)
            tr.append(td)
            table.append(tr)
        container.replace_with(table)


def transform_flow(soup: BeautifulSoup, section: Tag) -> None:
    for flow in section.find_all(class_="flow"):
        steps = [s.get_text(strip=True) for s in flow.find_all(class_="step")]
        if not steps:
            flow.decompose()
            continue
        ol = soup.new_tag("ol")
        for step in steps:
            li = soup.new_tag("li")
            li.string = step
            ol.append(li)
        flow.replace_with(ol)


def transform_xrefs(soup: BeautifulSoup, section: Tag) -> None:
    for xref in section.find_all(class_="xref"):
        labels = [a.get_text(strip=True).lstrip("→").strip() for a in xref.find_all("a")]
        if not labels:
            xref.decompose()
            continue
        p = soup.new_tag("p")
        em = soup.new_tag("em")
        em.string = "See also: " + " · ".join(labels)
        p.append(em)
        xref.replace_with(p)


# --------------------------------------------------------------------------- #
# HTML -> per-section Confluence storage format
# --------------------------------------------------------------------------- #

def parse_nav_groups(soup: BeautifulSoup) -> dict[str, list[str]]:
    """Return {group_label: [section_id, ...]} from the sidebar nav."""
    groups: dict[str, list[str]] = {}
    for group in soup.select("nav.nav .nav-group"):
        label_el = group.find(class_="label")
        label = label_el.get_text(strip=True) if label_el else "Other"
        ids = [a["href"].lstrip("#") for a in group.find_all("a", href=True)]
        if ids:
            groups[label] = ids
    return groups


def convert_all(html: str, child_prefix: str = "") -> tuple[
    dict[str, list[str]],              # nav_groups: {group_label: [sec_id, ...]}
    list[tuple[str, str, str, dict[str, str]]]  # sections: (sec_id, title, body, svgs)
]:
    """Parse nav groups and convert every section. Returns (nav_groups, sections)."""
    soup = BeautifulSoup(html, "lxml")
    nav_groups = parse_nav_groups(soup)
    result: list[tuple[str, str, str, dict[str, str]]] = []

    for section in soup.find_all("section", class_="page"):
        sec_id = section.get("id", "section")
        svgs: dict[str, str] = {}

        title_tag = section.find(class_="page-title")
        raw_title = title_tag.get_text(strip=True) if title_tag else sec_id
        page_title = f"{child_prefix}{raw_title}" if child_prefix else raw_title

        for crumb in section.find_all(class_="crumbs"):
            crumb.decompose()
        if title_tag:
            title_tag.decompose()

        transform_stats(soup, section)
        transform_pills(soup, section)
        transform_flow(soup, section)
        transform_xrefs(soup, section)
        extract_svgs(soup, section, slugify(raw_title), svgs)
        for callout in section.find_all(class_="callout"):
            callout.replace_with(to_info_panel(soup, callout))
        clean(section, soup)

        toc = (
            '<ac:structured-macro ac:name="toc">'
            '<ac:parameter ac:name="maxLevel">2</ac:parameter>'
            '</ac:structured-macro>'
        ) if section.find(["h2", "h3"]) else ""

        inner = "".join(str(c) for c in section.contents).strip()
        body = _BANNER + "\n" + toc + "\n" + inner if toc else _BANNER + "\n" + inner

        result.append((sec_id, page_title, body, svgs))

    return nav_groups, result


# --------------------------------------------------------------------------- #
# Nav group → parent Confluence page ID
# Controls where auto-created pages land when a new section is added.
# --------------------------------------------------------------------------- #
LIBRARY_ROOT = "1926398064"

NAV_GROUP_PARENTS: dict[str, str] = {
    "Concepts":   LIBRARY_ROOT,          # Overview, Data Model, Memory
    "Teams":      "2040725594",          # 🧩 All Teams
    "Agents":     "2041217100",          # 🤖 All Agents & Relations
    "Skills":     "2040692795",          # ⚡ All Skills
    "Deployment": LIBRARY_ROOT,          # Hooks, Versioning → directly under Library
}


# --------------------------------------------------------------------------- #
# Confluence page ID map — section_id → (page_id, parent_id)
# page_id  : existing Confluence page to update (keeps its title)
# parent_id: where to create the page if it doesn't exist yet
# --------------------------------------------------------------------------- #
KNOWN_PAGES: dict[str, tuple[str, str]] = {
    "overview":            ("2040528932", "1926398064"),  # 📖 Overview
    "data-model":          ("2040823858", "1926398064"),  # 🗺️ Data Model
    "memory":              ("2040823878", "1926398064"),  # 🧠 Context & Memory
    "teams":               ("2040725594", "1926398064"),  # 🧩 All Teams
    "team-feature":        ("2041774114", "2040725594"),  # 🧩 Feature Team (v1.1)
    "team-release":        ("2041937921", "2040725594"),  # 🧩 Release Team (v1.1)
    "team-full":           ("2041708560", "2040725594"),  # 🧩 Full Team (v1.1)
    "agents":              ("2041217100", "1926398064"),  # 🤖 All Agents & Relations
    "agent-po":            ("2041511977", "2041217100"),  # 🤖 Product Owner Assistant (v1.1)
    "agent-architect":     ("2041806858", "2041217100"),  # 🤖 Architect (v1.0)
    "agent-developer":     ("2040889432", "2041217100"),  # 🤖 Developer (v1.1)
    "agent-tester":        ("2041053233", "2041217100"),  # 🤖 Tester (v1.1)
    "agent-devops":        ("2041249812", "2041217100"),  # 🤖 DevOps (v1.1)
    "agent-documentarian": ("2041118745", "2041217100"),  # 🤖 Documentarian (v1.1)
    "skills":              ("2040692795", "1926398064"),  # ⚡ All Skills
    "skill-develop":       ("2041446434", "2040692795"),  # ⚡ /develop (v1.1)
    "skill-test":          ("2041413674", "2040692795"),  # ⚡ /test (v1.1)
    "skill-deploy":        ("2041118766", "2040692795"),  # ⚡ /deploy (v1.1)
    "skill-review":        ("2041708580", "2040692795"),  # ⚡ /review (v1.1)
    "skill-document":      ("2040791734", "2040692795"),  # ⚡ /document (v1.1)
    "skill-postman":       ("2041675803", "2040692795"),  # ⚡ /postman-collection-generator (v1.0)
    "versioning":          ("2042200159", "1926398064"),  # 🚀 Versioning & Distribution
    "hooks-guardrails":    ("2043150402", "1926398064"),  # 🔒 Hooks & Guardrails
}


# --------------------------------------------------------------------------- #
# Confluence REST client
# --------------------------------------------------------------------------- #

class Confluence:
    def __init__(self):
        self.base = env("CONFLUENCE_BASE_URL", required=True).rstrip("/")
        self.api = self.base + env("CONFLUENCE_API_PREFIX", "/rest/api")
        self.space = env("CONFLUENCE_SPACE_KEY", required=True)
        self.user = env("CONFLUENCE_USER")
        self.token = env("CONFLUENCE_API_TOKEN", required=True)
        self.s = requests.Session()
        auth_mode = env("CONFLUENCE_AUTH", "basic")
        if auth_mode == "bearer":
            self.s.headers["Authorization"] = f"Bearer {self.token}"
        else:
            self.s.auth = (self.user, self.token)

    def _ok(self, r: requests.Response) -> requests.Response:
        if not r.ok:
            sys.exit(f"Confluence API {r.status_code} on {r.request.method} {r.url}\n{r.text[:800]}")
        return r

    def update_page(self, page_id: str, body: str) -> None:
        """Update an existing page's body, preserving its title and hierarchy."""
        r = self._ok(self.s.get(f"{self.api}/content/{page_id}",
                                params={"expand": "version"}))
        p = r.json()
        ver = p["version"]["number"] + 1
        payload = {
            "type": "page",
            "title": p["title"],
            "space": {"key": self.space},
            "version": {"number": ver},
            "body": {"storage": {"value": body, "representation": "storage"}},
        }
        self._ok(self.s.put(f"{self.api}/content/{page_id}", json=payload))
        print(f"  updated  [{page_id}] {p['title']} -> v{ver}")

    def find_page_by_title(self, title: str) -> str | None:
        """Return page_id if a page with this title exists in the space, else None."""
        r = self.s.get(f"{self.api}/content",
                       params={"title": title, "spaceKey": self.space,
                               "expand": "version", "limit": 1})
        if r.ok:
            results = r.json().get("results", [])
            if results:
                return results[0]["id"]
        return None

    def create_page(self, title: str, parent_id: str, body: str) -> str:
        """Create a new page under parent_id and return the new page_id."""
        payload = {
            "type": "page",
            "title": title,
            "space": {"key": self.space},
            "ancestors": [{"id": parent_id}],
            "body": {"storage": {"value": body, "representation": "storage"}},
        }
        r = self._ok(self.s.post(f"{self.api}/content", json=payload))
        page_id = r.json()["id"]
        print(f"  created  [{page_id}] {title}")
        return page_id

    def attach_svg(self, page_id: str, name: str, svg: str) -> None:
        """Upload an SVG as an attachment (POST — creates only; no update on this instance)."""
        headers = {"X-Atlassian-Token": "no-check"}
        # Check if it already exists — skip if present (API rejects duplicates with 400)
        r = self.s.get(f"{self.api}/content/{page_id}/child/attachment",
                       params={"filename": name, "limit": 1})
        if r.ok and r.json().get("results"):
            return  # attachment already there; no-op
        files = {"file": (name, svg.encode("utf-8"), "image/svg+xml")}
        r = self.s.post(f"{self.api}/content/{page_id}/child/attachment",
                        headers=headers, files=files)
        status = "ok" if r.ok else f"FAIL {r.status_code}"
        print(f"    [{status}] {name}")


def load_page_ids() -> dict[str, tuple[str, str]]:
    """Load persisted page IDs from page_ids.json (merged on top of KNOWN_PAGES)."""
    if PAGE_IDS_FILE.exists():
        try:
            data = json.loads(PAGE_IDS_FILE.read_text(encoding="utf-8"))
            return {k: tuple(v) for k, v in data.items()}
        except Exception:
            pass
    return {}


def save_page_ids(extra: dict[str, tuple[str, str]]) -> None:
    """Merge extra entries into page_ids.json."""
    existing: dict[str, list[str]] = {}
    if PAGE_IDS_FILE.exists():
        try:
            existing = json.loads(PAGE_IDS_FILE.read_text(encoding="utf-8"))
        except Exception:
            pass
    existing.update({k: list(v) for k, v in extra.items()})
    PAGE_IDS_FILE.write_text(json.dumps(existing, indent=2, ensure_ascii=False),
                             encoding="utf-8")


def main() -> None:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    html_path = Path(env("PRESENTATION_HTML", str(DEFAULT_HTML)))
    if not html_path.exists():
        sys.exit(f"Source HTML not found: {html_path}")

    nav_groups, sections = convert_all(html_path.read_text(encoding="utf-8"))
    total_svgs = sum(len(s[3]) for s in sections)
    print(f"Converted {html_path.name}: {len(sections)} sections, {total_svgs} diagram(s)\n")

    # Build reverse map: section_id → nav group label
    sec_to_group: dict[str, str] = {}
    for group_label, ids in nav_groups.items():
        for sid in ids:
            sec_to_group[sid] = group_label

    if env("DRY_RUN", "false").lower() == "true":
        preview = html_path.parent / ".preview"
        preview.mkdir(exist_ok=True)
        for sec_id, _, body, svgs in sections:
            (preview / f"{sec_id}.xml").write_text(body, encoding="utf-8")
            for name, svg in svgs.items():
                (preview / name).write_text(svg, encoding="utf-8")
        print(f"DRY_RUN: wrote {preview}; no API calls")
        return

    cf = Confluence()

    # Merge hardcoded IDs + persisted IDs from page_ids.json
    page_map: dict[str, tuple[str, str]] = {**KNOWN_PAGES, **load_page_ids()}
    newly_created: dict[str, tuple[str, str]] = {}

    for sec_id, title, body, svgs in sections:
        mapping = page_map.get(sec_id)

        if mapping:
            page_id, parent_id = mapping
        else:
            # Auto-create: find parent from nav group, or fall back to Library root
            group = sec_to_group.get(sec_id, "")
            parent_id = NAV_GROUP_PARENTS.get(group, LIBRARY_ROOT)

            # Check if the page already exists on Confluence (e.g. created manually)
            existing_id = cf.find_page_by_title(title)
            if existing_id:
                print(f"  found    [{existing_id}] {title} (was unmapped — registering)")
                page_id = existing_id
            else:
                page_id = cf.create_page(title, parent_id, body)
                # Body already set on create; skip the update below
                for name, svg in svgs.items():
                    cf.attach_svg(page_id, name, svg)
                newly_created[sec_id] = (page_id, parent_id)
                continue  # page body already written by create_page

            newly_created[sec_id] = (page_id, parent_id)

        cf.update_page(page_id, body)
        for name, svg in svgs.items():
            cf.attach_svg(page_id, name, svg)

    if newly_created:
        save_page_ids(newly_created)
        print(f"\nNew pages registered in {PAGE_IDS_FILE.name}: "
              + ", ".join(newly_created.keys()))

    lib_url = f"{cf.base}/spaces/{cf.space}/pages/{LIBRARY_ROOT}"
    print(f"\nDone: {lib_url}")


if __name__ == "__main__":
    main()
