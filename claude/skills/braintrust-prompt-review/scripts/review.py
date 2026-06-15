#!/usr/bin/env python3
"""Detect Braintrust prompt pin changes and render an HTML diff.

Usage:
  review.py [--pr N | --branch NAME] [--repo OWNER/REPO] [--base BRANCH]
            [--out DIR] [--no-open]

Inputs:
  --pr N         Review a GitHub PR (via `gh pr diff`)
  --branch NAME  Review a local branch vs --base (default: current branch)
  --base BRANCH  Base branch for local-branch mode (default: main)
  --repo OWNER/REPO  Repo override for --pr (default: detected by gh)
  --out DIR      Output dir for HTML (default: ~/Downloads). Filenames are
                 prefixed with the scope slug (e.g. pr-25654-<prompt>.html).
  --no-open      Skip opening the result in a browser

Auth: BRAINTRUST_API_KEY must be set.
"""
from __future__ import annotations

import argparse
import difflib
import html
import json
import os
import re
import subprocess
import sys
import webbrowser
from dataclasses import dataclass
from pathlib import Path
from urllib.error import HTTPError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

API_URL = "https://api.braintrust.dev/v1"
API_KEY_ENV = "BRAINTRUST_API_KEY"

# Map source-path prefixes to the Braintrust project name they pin against.
# `get_module_name()` resolves to these at runtime in dscout code.
PROJECT_HINTS: list[tuple[str, str]] = [
    ("apps/astro/", "dscript"),
    ("apps/ai_mod/", "ai_mod"),
]


@dataclass
class PinChange:
    slug: str | None
    old: str | None
    new: str | None
    file: str | None

    @property
    def kind(self) -> str:
        if self.old and self.new:
            return "modified"
        if self.new:
            return "added"
        if self.old:
            return "removed"
        return "unknown"


# ---------- diff acquisition + parsing ----------


def get_diff(args: argparse.Namespace) -> str:
    if args.pr:
        cmd = ["gh", "pr", "diff", str(args.pr)]
        if args.repo:
            cmd += ["--repo", args.repo]
        return subprocess.run(cmd, capture_output=True, text=True, check=True).stdout
    branch = args.branch or "HEAD"
    base = args.base or "main"
    return subprocess.run(
        ["git", "diff", f"{base}...{branch}"],
        capture_output=True,
        text=True,
        check=True,
    ).stdout


VERSION_RE = re.compile(r'version=["\']([0-9a-f]+)["\']')
SLUG_RE = re.compile(r'slug=["\']([\w\-]+)["\']')


def parse_pin_changes(diff_text: str) -> list[PinChange]:
    """Walk a unified diff for `version=` changes near a `slug=` line.

    Heuristic: when we see a removed-then-added `version="..."` pair, we
    scan backward (within the current hunk) for the nearest `slug=`.
    Also catches pure-add (new prompt) and pure-remove (deleted pin) lines
    when they appear without a paired counterpart.
    """
    lines = diff_text.splitlines()
    file_path: str | None = None
    changes: list[PinChange] = []
    consumed: set[int] = set()  # diff line indices already paired

    for i, line in enumerate(lines):
        if line.startswith("+++ b/"):
            file_path = line[6:]
            continue
        if i in consumed:
            continue
        if line.startswith("-") and not line.startswith("---"):
            m_old = VERSION_RE.search(line)
            if not m_old:
                continue
            # Look for the paired + within the next handful of lines.
            new_ver: str | None = None
            paired_j: int | None = None
            for j in range(i + 1, min(i + 8, len(lines))):
                lj = lines[j]
                if lj.startswith("@@") or lj.startswith("+++"):
                    break
                if lj.startswith("+") and not lj.startswith("+++"):
                    m_new = VERSION_RE.search(lj)
                    if m_new:
                        new_ver = m_new.group(1)
                        paired_j = j
                        break
            slug = _scan_back_for_slug(lines, i)
            if paired_j is not None:
                consumed.add(paired_j)
            changes.append(
                PinChange(slug=slug, old=m_old.group(1), new=new_ver, file=file_path)
            )
        elif line.startswith("+") and not line.startswith("+++"):
            m_new = VERSION_RE.search(line)
            if not m_new:
                continue
            # Already-paired adds were skipped via `consumed` above.
            slug = _scan_back_for_slug(lines, i)
            changes.append(
                PinChange(slug=slug, old=None, new=m_new.group(1), file=file_path)
            )

    return changes


def _scan_back_for_slug(lines: list[str], start: int) -> str | None:
    for j in range(start - 1, max(start - 50, -1), -1):
        back = lines[j]
        if back.startswith("@@"):
            break
        m = SLUG_RE.search(back)
        if m:
            return m.group(1)
    return None


# ---------- Braintrust API ----------


def _api_get(path: str, params: dict | None = None) -> dict:
    key = os.environ.get(API_KEY_ENV)
    if not key:
        sys.exit(f"error: {API_KEY_ENV} env var is required")
    url = f"{API_URL}{path}"
    if params:
        url = f"{url}?{urlencode(params)}"
    req = Request(url, headers={"Authorization": f"Bearer {key}"})
    try:
        with urlopen(req) as resp:
            return json.loads(resp.read())
    except HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        sys.exit(f"error: Braintrust API {e.code} on {url}\n{body}")


def project_for_file(file_path: str | None) -> str | None:
    if not file_path:
        return None
    for prefix, name in PROJECT_HINTS:
        if file_path.startswith(prefix):
            return name
    return None


def find_prompt_id(slug: str, project_name: str | None) -> str:
    params: dict = {"slug": slug}
    if project_name:
        params["project_name"] = project_name
    data = _api_get("/prompt", params)
    objects = data.get("objects", [])
    if not objects:
        scope = f" project={project_name}" if project_name else ""
        sys.exit(f"error: no Braintrust prompt found for slug={slug}{scope}")
    if len(objects) > 1 and not project_name:
        names = [f'{o["project_id"]}' for o in objects]
        print(
            f"warn: slug={slug} matched {len(objects)} prompts; using first "
            f"({objects[0]['id']}). Project hint would disambiguate: {names}",
            file=sys.stderr,
        )
    return objects[0]["id"]


def fetch_prompt_version(prompt_id: str, version: str | None) -> dict:
    """Fetch a specific historical version, or HEAD if version is None."""
    params = {"version": version} if version else None
    return _api_get(f"/prompt/{prompt_id}", params)


# ---------- HTML rendering ----------


def message_text(prompt_obj: dict) -> str:
    msgs = prompt_obj.get("prompt_data", {}).get("prompt", {}).get("messages", [])
    parts: list[str] = []
    for m in msgs:
        parts.append(f"### role: {m.get('role', '?')}")
        parts.append(m.get("content", ""))
    return "\n".join(parts)


def _classify(line: str) -> str:
    if line.startswith("+++") or line.startswith("---"):
        return "file"
    if line.startswith("@@"):
        return "hunk"
    if line.startswith("+"):
        return "add"
    if line.startswith("-"):
        return "del"
    return "ctx"


def render_diff_page(
    change: PinChange,
    old_obj: dict,
    new_obj: dict,
    *,
    scope_label: str,
    scope_url: str | None,
) -> str:
    old_text = message_text(old_obj) if old_obj else ""
    new_text = message_text(new_obj) if new_obj else ""
    old_lines = old_text.splitlines()
    new_lines = new_text.splitlines()

    # n = full file ensures every line is shown (the user wants the whole prompt).
    big_n = max(len(old_lines), len(new_lines)) + 100

    fromfile = f"{change.slug} @ {change.old or '(new)'}"
    tofile = f"{change.slug} @ {change.new or '(removed)'}"
    diff_lines = list(
        difflib.unified_diff(
            old_lines, new_lines, fromfile=fromfile, tofile=tofile, lineterm="", n=big_n
        )
    )
    adds = sum(1 for l in diff_lines if l.startswith("+") and not l.startswith("+++"))
    dels = sum(1 for l in diff_lines if l.startswith("-") and not l.startswith("---"))

    diff_html_rows = []
    for line in diff_lines:
        cls = _classify(line)
        diff_html_rows.append(
            f'<div class="line {cls}">{html.escape(line) or "&nbsp;"}</div>'
        )
    diff_body = "\n".join(diff_html_rows)

    def meta_row(label: str, value: str) -> str:
        return (
            f"<tr><th>{html.escape(label)}</th>"
            f"<td><code>{html.escape(value)}</code></td></tr>"
        )

    old_opts = (old_obj or {}).get("prompt_data", {}).get("options", {}) or {}
    new_opts = (new_obj or {}).get("prompt_data", {}).get("options", {}) or {}
    ref_obj = new_obj or old_obj or {}

    scope_link = (
        f'<a href="{html.escape(scope_url)}">{html.escape(scope_label)}</a>'
        if scope_url
        else html.escape(scope_label)
    )

    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<title>{html.escape(change.slug or 'prompt')} diff &mdash; {html.escape(scope_label)}</title>
<style>
  :root {{
    --bg: #0d1117;
    --panel: #161b22;
    --panel-2: #1c2128;
    --text: #e6edf3;
    --muted: #8b949e;
    --add-bg: #1f3a26;
    --add-fg: #3fb950;
    --del-bg: #3b1f23;
    --del-fg: #f85149;
    --border: #30363d;
  }}
  * {{ box-sizing: border-box; }}
  body {{
    margin: 0;
    background: var(--bg);
    color: var(--text);
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif;
    font-size: 14px;
    line-height: 1.5;
  }}
  header {{
    background: var(--panel);
    border-bottom: 1px solid var(--border);
    padding: 20px 28px;
    position: sticky;
    top: 0;
    z-index: 10;
  }}
  header h1 {{ margin: 0 0 6px; font-size: 20px; font-weight: 600; }}
  header .sub {{ color: var(--muted); font-size: 13px; }}
  header .sub a {{ color: #58a6ff; text-decoration: none; }}
  header .sub a:hover {{ text-decoration: underline; }}
  .summary {{ display: flex; gap: 16px; margin-top: 12px; font-size: 13px; align-items: center; }}
  .chip {{ background: var(--panel-2); border: 1px solid var(--border); border-radius: 999px; padding: 2px 10px; }}
  .chip.add {{ color: var(--add-fg); }}
  .chip.del {{ color: var(--del-fg); }}
  button.toggle {{
    background: var(--panel-2); color: var(--text);
    border: 1px solid var(--border); border-radius: 6px;
    padding: 4px 10px; font-size: 12px; cursor: pointer;
  }}
  button.toggle:hover {{ border-color: var(--muted); }}
  main {{ padding: 0 28px 60px; }}
  section {{ margin-top: 28px; }}
  h2 {{
    font-size: 15px; text-transform: uppercase; letter-spacing: 0.06em;
    color: var(--muted); border-bottom: 1px solid var(--border); padding-bottom: 8px;
  }}
  table.meta {{ border-collapse: collapse; width: 100%; max-width: 720px; }}
  table.meta th, table.meta td {{
    text-align: left; padding: 6px 10px; border-bottom: 1px solid var(--border);
    font-weight: normal; vertical-align: top;
  }}
  table.meta th {{ color: var(--muted); width: 220px; }}
  code {{
    font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, monospace;
    background: var(--panel-2); padding: 1px 6px; border-radius: 4px; font-size: 12.5px;
  }}
  .diff {{ background: var(--panel); border: 1px solid var(--border); border-radius: 8px; overflow: hidden; margin-top: 8px; }}
  .diff .line {{
    font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, monospace;
    font-size: 12.5px; white-space: pre-wrap; padding: 1px 14px;
    border-left: 3px solid transparent;
  }}
  .line.add {{ background: var(--add-bg); color: var(--add-fg); border-left-color: var(--add-fg); }}
  .line.del {{ background: var(--del-bg); color: var(--del-fg); border-left-color: var(--del-fg); }}
  .line.hunk {{
    color: var(--muted); background: var(--panel-2);
    padding-top: 4px; padding-bottom: 4px;
    border-top: 1px solid var(--border); border-bottom: 1px solid var(--border);
  }}
  .line.file {{ color: var(--muted); background: var(--panel-2); font-weight: 600; }}
  .line.ctx {{ color: var(--text); opacity: 0.85; }}
  body.hide-ctx .line.ctx {{ display: none; }}
</style>
</head>
<body>
<header>
  <h1>{html.escape(change.slug or "prompt")} &mdash; prompt diff</h1>
  <div class="sub">
    {scope_link}
    &middot; Braintrust prompt <code>{html.escape(ref_obj.get("id", ""))}</code>
    &middot; <code>{html.escape(change.old or "(new)")}</code> &rarr;
    <code>{html.escape(change.new or "(removed)")}</code>
    {f'&middot; pinned in <code>{html.escape(change.file)}</code>' if change.file else ''}
  </div>
  <div class="summary">
    <span class="chip add">+{adds} added</span>
    <span class="chip del">-{dels} removed</span>
    <button class="toggle" onclick="document.body.classList.toggle('hide-ctx')">
      Toggle unchanged lines
    </button>
  </div>
</header>
<main>
  <section>
    <h2>Metadata</h2>
    <table class="meta">
      {meta_row("Slug", change.slug or "")}
      {meta_row("Prompt ID", ref_obj.get("id", ""))}
      {meta_row("Old pin", change.old or "(new prompt)")}
      {meta_row("New pin", change.new or "(removed)")}
      {meta_row("Old _xact_id", (old_obj or {}).get("_xact_id", ""))}
      {meta_row("New _xact_id", (new_obj or {}).get("_xact_id", ""))}
      {meta_row("Old created", (old_obj or {}).get("created", "") or "")}
      {meta_row("New created", (new_obj or {}).get("created", "") or "")}
      {meta_row("Old model", str(old_opts.get("model", "")))}
      {meta_row("New model", str(new_opts.get("model", "")))}
      {meta_row("Old params", json.dumps(old_opts.get("params", {})))}
      {meta_row("New params", json.dumps(new_opts.get("params", {})))}
    </table>
  </section>
  <section>
    <h2>Full prompt diff</h2>
    <div class="diff">
{diff_body}
    </div>
  </section>
</main>
</body>
</html>
"""


def render_index_page(
    entries: list[tuple[PinChange, str]],
    *,
    scope_label: str,
    scope_url: str | None,
) -> str:
    """Render an index page when there are multiple pin changes."""
    rows = []
    for change, rel_path in entries:
        kind_badge = {
            "modified": '<span class="chip">modified</span>',
            "added": '<span class="chip add">added</span>',
            "removed": '<span class="chip del">removed</span>',
        }.get(change.kind, "")
        rows.append(
            f'<tr>'
            f'<td><a href="{html.escape(rel_path)}">'
            f'<code>{html.escape(change.slug or "?")}</code></a></td>'
            f'<td>{kind_badge}</td>'
            f'<td><code>{html.escape(change.old or "")}</code></td>'
            f'<td><code>{html.escape(change.new or "")}</code></td>'
            f'<td><code>{html.escape(change.file or "")}</code></td>'
            f'</tr>'
        )

    scope_link = (
        f'<a href="{html.escape(scope_url)}">{html.escape(scope_label)}</a>'
        if scope_url
        else html.escape(scope_label)
    )

    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<title>Braintrust prompt pin changes &mdash; {html.escape(scope_label)}</title>
<style>
  body {{
    margin: 0; padding: 28px;
    background: #0d1117; color: #e6edf3;
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif;
    font-size: 14px;
  }}
  h1 {{ margin: 0 0 6px; font-size: 20px; }}
  .sub {{ color: #8b949e; font-size: 13px; margin-bottom: 20px; }}
  .sub a {{ color: #58a6ff; text-decoration: none; }}
  table {{ border-collapse: collapse; width: 100%; max-width: 1100px; }}
  th, td {{
    text-align: left; padding: 8px 12px;
    border-bottom: 1px solid #30363d;
  }}
  th {{ color: #8b949e; font-weight: 500; }}
  code {{
    font-family: ui-monospace, SFMono-Regular, "SF Mono", Menlo, Consolas, monospace;
    background: #1c2128; padding: 1px 6px; border-radius: 4px; font-size: 12.5px;
  }}
  .chip {{
    background: #1c2128; border: 1px solid #30363d; border-radius: 999px;
    padding: 2px 10px; font-size: 12px;
  }}
  .chip.add {{ color: #3fb950; }}
  .chip.del {{ color: #f85149; }}
  a {{ color: #58a6ff; text-decoration: none; }}
  a:hover {{ text-decoration: underline; }}
</style>
</head>
<body>
<h1>Braintrust prompt pin changes</h1>
<div class="sub">{scope_link} &middot; {len(entries)} prompt(s) changed</div>
<table>
  <tr><th>Prompt</th><th>Kind</th><th>Old pin</th><th>New pin</th><th>Pinned in</th></tr>
  {''.join(rows)}
</table>
</body>
</html>
"""


# ---------- orchestration ----------


def resolve_scope(args: argparse.Namespace) -> tuple[str, str | None, str]:
    """Return (label, url, slug) for the diff scope (PR or branch)."""
    if args.pr:
        repo = args.repo or _detect_repo()
        label = f"PR #{args.pr}" + (f" ({repo})" if repo else "")
        url = f"https://github.com/{repo}/pull/{args.pr}" if repo else None
        slug = f"pr-{args.pr}"
        return label, url, slug
    branch = args.branch or _current_branch() or "current"
    return f"branch {branch}", None, _slugify(branch)


def _detect_repo() -> str | None:
    try:
        out = subprocess.run(
            ["gh", "repo", "view", "--json", "nameWithOwner", "-q", ".nameWithOwner"],
            capture_output=True, text=True, check=True,
        ).stdout.strip()
        return out or None
    except subprocess.CalledProcessError:
        return None


def _current_branch() -> str | None:
    try:
        return subprocess.run(
            ["git", "branch", "--show-current"],
            capture_output=True, text=True, check=True,
        ).stdout.strip() or None
    except subprocess.CalledProcessError:
        return None


def _slugify(s: str) -> str:
    return re.sub(r"[^a-zA-Z0-9_-]+", "-", s).strip("-").lower() or "scope"


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    p.add_argument("--pr", type=int, help="GitHub PR number")
    p.add_argument("--branch", help="Local branch to diff (default: current)")
    p.add_argument("--base", default="main", help="Base branch (default: main)")
    p.add_argument("--repo", help="owner/repo for --pr (default: auto)")
    p.add_argument("--out", help="Output directory")
    p.add_argument("--no-open", action="store_true", help="Skip opening browser")
    args = p.parse_args()

    diff_text = get_diff(args)
    if not diff_text.strip():
        print("No diff content found.", file=sys.stderr)
        return 1

    changes = parse_pin_changes(diff_text)
    if not changes:
        print("No Braintrust prompt pin changes detected.")
        return 0

    label, url, scope_slug = resolve_scope(args)
    out_dir = Path(args.out).expanduser() if args.out else Path.home() / "Downloads"
    out_dir.mkdir(parents=True, exist_ok=True)

    print(f"Found {len(changes)} pin change(s) in {label}:", file=sys.stderr)
    for c in changes:
        print(
            f"  - {c.slug} [{c.kind}]: {c.old or '∅'} -> {c.new or '∅'} ({c.file})",
            file=sys.stderr,
        )

    rendered: list[tuple[PinChange, str]] = []
    for change in changes:
        if not change.slug:
            print(f"  skipping unresolvable change: {change}", file=sys.stderr)
            continue
        project = project_for_file(change.file)
        prompt_id = find_prompt_id(change.slug, project)
        old_obj = fetch_prompt_version(prompt_id, change.old) if change.old else None
        new_obj = fetch_prompt_version(prompt_id, change.new) if change.new else None

        html_out = render_diff_page(
            change, old_obj, new_obj, scope_label=label, scope_url=url
        )
        filename = f"{scope_slug}-{change.slug}.html"
        (out_dir / filename).write_text(html_out)
        rendered.append((change, filename))

    if not rendered:
        print("No renderable changes (could not resolve slugs).", file=sys.stderr)
        return 1

    if len(rendered) == 1:
        final_path = out_dir / rendered[0][1]
    else:
        index_html = render_index_page(rendered, scope_label=label, scope_url=url)
        final_path = out_dir / f"{scope_slug}-index.html"
        final_path.write_text(index_html)

    print(f"Wrote {final_path}")
    if not args.no_open:
        webbrowser.open(f"file://{final_path.resolve()}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
