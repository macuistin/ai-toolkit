#!/usr/bin/env python3
"""vq — read-only vault query for Claude. Never writes anything.

Tag-first lookup over the frontmatter tags maintained by tagger.py (see Notes/tagging-conventions.md).

  find TERM... [--not TERM...] [--any] [--since 14d|YYYY-MM-DD] [--until D] [--path PREFIX]
       [--grep REGEX] [--limit N] [--hubs] [--json]
      TERM is a full tag (person/alex-mclean), a namespace wildcard (project/*), or a bare
      name that resolves to any namespace (alex-mclean, alex, privacyhome, 1on1, postmortem).
      All TERMs must match (AND) unless --any. Newest first.
      Hub files (type/log, index, dashboard, tracking, archive) are hidden unless --hubs.
      --grep prints matching lines (line numbers) inside the matched files only.
  related PATH [--limit N] [--json]   links, backlinks and notes sharing project/person/topic tags
  tags [NAMESPACE]                     tag vocabulary with counts (e.g. `tags person`)
  info PATH                            tags, date, size, title, summary, links, backlinks of one file

Output is compact text: `date  size  path | title | tags` (size in KB; files >40KB: grep, don't read).
Python 3.10 stdlib only.
"""
import argparse
import datetime as dt
import glob
import json
import os
import re
import sys
from collections import Counter

HUBS = {"type/log", "type/index", "type/dashboard", "type/tracking", "type/archive"}
FM_RE = re.compile(r"\A---\n(.*?)\n---[ \t]*(?:\n|\Z)", re.S)
LINK_RE = re.compile(r"\[\[([^\]|#\n]+)(?:#[^\]|\n]*)?(?:\|[^\]\n]*)?\]\]")
DATE_RE = re.compile(r"(\d{4}-\d\d-\d\d)")


def vault():
    v = os.environ.get("VAULT")
    if v:
        return v
    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if os.path.exists(os.path.join(here, "MEMORY.md")):
        return here
    c = [os.environ["SECOND_BRAIN_PATH"]] if os.environ.get("SECOND_BRAIN_PATH") and os.path.isdir(os.environ["SECOND_BRAIN_PATH"]) else []
    if not c:
        sys.exit("vault folder not mounted — use the Obsidian MCP search tool instead")
    return c[0]


V = vault()


class Note:
    __slots__ = ("path", "tags", "date", "size", "title", "summary", "body", "links")

    def __init__(self, rel):
        full = os.path.join(V, rel)
        text = open(full, encoding="utf-8", errors="replace").read()
        m = FM_RE.match(text)
        fm = m.group(1) if m else ""
        self.body = text[m.end():] if m else text
        self.path = rel
        self.tags = tags_of(fm)
        self.size = os.path.getsize(full)
        self.date = content_date(rel, fm, self.body, full)
        self.title, self.summary = head(self.body, rel)
        self.links = None

    def link_targets(self):
        if self.links is None:
            self.links = {resolve(x.strip()) for x in LINK_RE.findall(self.body)} - {None, self.path}
        return self.links


TODAY = dt.date.today().isoformat()
UPD_RE = re.compile(r"(?i)(?:last (?:updated|synced|rebuilt|verified)|updated|as of)[^0-9\n]{0,15}(\d{4}-\d\d-\d\d)")


def content_date(rel, fm, body, full):
    """Filename date > frontmatter date > newest 'last updated/synced' or ## heading date > newest date in body > mtime.
    (mtime alone is useless: the tagger rewrites every file.)"""
    d = DATE_RE.search(os.path.basename(rel))
    if d:
        return d.group(1)
    fd = re.search(r"(?m)^date:\s*(\d{4}-\d\d-\d\d)", fm)
    if fd:
        return fd.group(1)
    cands = [x for x in UPD_RE.findall(body) if x <= TODAY]
    cands += [x for x in re.findall(r"(?m)^#{1,4} .*?(\d{4}-\d\d-\d\d)", body) if x <= TODAY]
    if not cands:
        cands = [x for x in DATE_RE.findall(body) if x <= TODAY]
    if cands:
        return max(cands)
    return dt.date.fromtimestamp(os.path.getmtime(full)).isoformat()


def tags_of(fm):
    m = re.search(r"(?m)^tags\s*:\s*\[(.*?)\]\s*$", fm)
    if m:
        return [t.strip().strip("'\"").lower() for t in m.group(1).split(",") if t.strip()]
    m = re.search(r"(?ms)^tags\s*:\s*\n((?:\s+-\s*.+\n?)+)", fm)
    if m:
        return [re.sub(r"^\s+-\s*", "", x).strip().lower() for x in m.group(1).splitlines() if x.strip()]
    return []


def head(body, rel):
    title, summary = None, None
    lines = body.splitlines()
    for i, ln in enumerate(lines):
        s = ln.strip()
        if not title and s.startswith("# "):
            title = s[2:].strip()
            continue
        if re.match(r"(?i)^##\s+summary", s):
            for nx in lines[i + 1:i + 6]:
                if nx.strip() and not nx.startswith("#"):
                    summary = nx.strip()
                    break
            if summary:
                break
    if not summary:
        for ln in lines:
            s = ln.strip()
            if not s or s.startswith(("#", "---", "|", "```")) or re.match(r"(?i)^>?\s*(auto-synced|last synced|_last)", s):
                continue
            summary = s.lstrip("> ").strip()
            break
    title = title or os.path.basename(rel)[:-3]
    return title[:90], (summary or "")[:160]


ALL = None
BY_STEM = None


def notes():
    global ALL, BY_STEM
    if ALL is None:
        ALL, BY_STEM = {}, {}
        for root, dirs, fs in os.walk(V):
            dirs[:] = [d for d in dirs if not d.startswith(".") and d not in ("__pycache__", "_scripts")]
            for f in fs:
                if f.endswith(".md"):
                    rel = os.path.relpath(os.path.join(root, f), V)
                    try:
                        n = Note(rel)
                    except OSError:
                        continue
                    ALL[rel] = n
                    BY_STEM.setdefault(f[:-3].lower(), rel)
    return ALL


def resolve(target):
    notes()
    t = target if target.endswith(".md") else target + ".md"
    if t in ALL:
        return t
    return BY_STEM.get(os.path.basename(target).lower().removesuffix(".md"))


def vocab():
    c = Counter()
    for n in notes().values():
        c.update(n.tags)
    return c


def expand(term, voc):
    """Return the set of tags a TERM matches."""
    term = term.lower().lstrip("#")
    if term.endswith("/*"):
        ns = term[:-1]
        return {t for t in voc if t.startswith(ns)}
    if "/" in term:
        return {t for t in voc if t == term or t.startswith(term + "-") or t.startswith(term + "/")} or {term}
    exact = {t for t in voc if "/" in t and t.split("/", 1)[1] == term}
    if exact:
        return exact
    return {t for t in voc if "/" in t and t.split("/", 1)[1].startswith(term + "-")} or \
        {t for t in voc if "/" in t and term in t.split("/", 1)[1]}


def parse_since(s):
    if not s:
        return None
    m = re.fullmatch(r"(\d+)([dwm])", s)
    if m:
        n, u = int(m.group(1)), m.group(2)
        days = n * {"d": 1, "w": 7, "m": 30}[u]
        return (dt.date.today() - dt.timedelta(days=days)).isoformat()
    return s


def short(tags, cap=8):
    skip = ("source/",)
    t = [x for x in tags if not x.startswith(skip)]
    return " ".join(t[:cap]) + (f" +{len(t) - cap}" if len(t) > cap else "")


def line(n):
    return f"{n.date}  {n.size / 1024:5.1f}K  {n.path} | {n.title} | {short(n.tags)}" + \
        (f"\n      ↳ {n.summary}" if n.summary else "")


def out(rows, a, extra=None):
    if a.json:
        print(json.dumps([{"path": n.path, "date": n.date, "kb": round(n.size / 1024, 1), "title": n.title,
                           "summary": n.summary, "tags": n.tags} for n in rows] + ([extra] if extra else []),
                         ensure_ascii=False, indent=1))
    else:
        for n in rows:
            print(line(n))


def cmd_find(a):
    voc = vocab()
    want = [(t, expand(t, voc)) for t in a.terms]
    unknown = [t for t, s in want if not s]
    if unknown:
        print(f"no tag matches: {', '.join(unknown)} — try `vq.py tags` or fall back to index/grep", file=sys.stderr)
    nots = set().union(*[expand(t, voc) for t in (a.not_ or [])]) if a.not_ else set()
    since, until = parse_since(a.since), a.until
    rows = []
    for n in notes().values():
        ts = set(n.tags)
        if not a.hubs and ts & HUBS and not any(HUBS & s for _, s in want):
            continue
        if a.path and not n.path.startswith(a.path):
            continue
        if want:
            hits = [bool(ts & s) for _, s in want]
            if not (any(hits) if a.any else all(hits)):
                continue
        if ts & nots:
            continue
        if since and n.date < since or until and n.date > until:
            continue
        rows.append(n)
    rows.sort(key=lambda n: (n.date, n.path), reverse=True)
    total = len(rows)
    if a.grep:
        rx = re.compile(a.grep, re.I)
        shown = hit = 0
        for n in rows:
            m = [(i + 1, ln.strip()) for i, ln in enumerate(n.body.splitlines()) if rx.search(ln)]
            if m:
                hit += 1
                if shown < a.limit:
                    shown += 1
                    print(f"{n.date}  {n.path}  ({len(m)} hits)")
                    for i, ln in m[:6]:
                        print(f"   {i}: {ln[:200]}")
        print(f"# {total} files matched tags, {hit} contain /{a.grep}/, {shown} shown", file=sys.stderr)
        return
    rows = rows[:a.limit]
    out(rows, a)
    if not a.json:
        print(f"# {len(rows)} of {total} shown" + (" (raise --limit)" if total > len(rows) else ""), file=sys.stderr)


def cmd_related(a):
    rel = resolve(a.path) or a.path
    allp = notes()
    if rel not in allp:
        sys.exit(f"not found: {a.path}")
    me = allp[rel]
    out_links = me.link_targets()
    back = {p for p, n in allp.items() if p != rel and rel in n.link_targets()}
    key = {t for t in me.tags if t.startswith(("project/", "person/", "topic/"))}
    scored = []
    for p, n in allp.items():
        if p == rel or set(n.tags) & HUBS:
            continue
        shared = key & set(n.tags) if "type/knowledge" not in n.tags else set()
        s = len(shared) + 3 * (p in out_links) + 3 * (p in back)
        if s >= 2:
            scored.append((s, n.date, n))
    scored.sort(key=lambda x: (x[0], x[1]), reverse=True)
    print(f"# {rel} — {len(out_links)} links, {len(back)} backlinks; tags: {short(me.tags)}")
    for s, _, n in scored[:a.limit]:
        why = ("→" if n.path in out_links else "") + ("←" if n.path in back else "")
        print(f"{why:2} {s:2}  " + line(n))


def cmd_tags(a):
    for t, c in sorted(vocab().items(), key=lambda x: (-x[1], x[0])):
        if not a.ns or t.startswith(a.ns.rstrip("/") + "/"):
            print(f"{c:4}  {t}")


def cmd_info(a):
    rel = resolve(a.path) or a.path
    allp = notes()
    if rel not in allp:
        sys.exit(f"not found: {a.path}")
    n = allp[rel]
    back = sorted(p for p, x in allp.items() if p != rel and rel in x.link_targets())
    print(json.dumps({"path": n.path, "date": n.date, "kb": round(n.size / 1024, 1), "title": n.title,
                      "summary": n.summary, "tags": n.tags, "links": sorted(n.link_targets()),
                      "backlinks": back}, ensure_ascii=False, indent=1))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sp = ap.add_subparsers(dest="cmd", required=True)
    x = sp.add_parser("find")
    x.add_argument("terms", nargs="*")
    x.add_argument("--not", dest="not_", nargs="+")
    x.add_argument("--any", action="store_true")
    x.add_argument("--since")
    x.add_argument("--until")
    x.add_argument("--path")
    x.add_argument("--grep")
    x.add_argument("--limit", type=int, default=15)
    x.add_argument("--hubs", action="store_true")
    x.add_argument("--json", action="store_true")
    x.set_defaults(f=cmd_find)
    x = sp.add_parser("related"); x.add_argument("path"); x.add_argument("--limit", type=int, default=12)
    x.add_argument("--json", action="store_true"); x.set_defaults(f=cmd_related)
    x = sp.add_parser("tags"); x.add_argument("ns", nargs="?"); x.set_defaults(f=cmd_tags)
    x = sp.add_parser("info"); x.add_argument("path"); x.set_defaults(f=cmd_info)
    a = ap.parse_args()
    a.f(a)


if __name__ == "__main__":
    main()
