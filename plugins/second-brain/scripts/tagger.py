#!/usr/bin/env python3
"""Vault tagger: deterministic frontmatter tags + inline-tag cleanup.

Rules live in _scripts/tag-rules.json; the convention is in Notes/tagging-conventions.md.

Commands
  run       [--dry-run] [--paths P ...]   fix-inline, then tag (what the scheduled jobs call)
  tag       [--dry-run] [--paths P ...]   recompute owned namespaces, add additive ones
  fix-inline[--dry-run] [--paths P ...]   escape inline #channel / #123 so they stop being tags
  report                                  tag counts per namespace + files with no type/ tag
  show      PATH                          print the tags the tagger would give one file

Owned namespaces (type/ meeting/ team/ source/ status/) are recomputed every run.
Additive namespaces (project/ person/ topic/ channel/) are only ever added, so tags added
by distill or by hand survive. Un-namespaced frontmatter tags are migrated via legacy_map.
Files modified in the last 120 s are skipped (another job may be writing them) unless
--paths or --no-guard is given. Python 3.10 stdlib only.
"""
import argparse
import glob
import json
import os
import re
import sys
import time
import unicodedata
from collections import Counter



def vault():
    v = os.environ.get("VAULT")
    if v:
        return v
    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if os.path.exists(os.path.join(here, "MEMORY.md")):
        return here
    c = [os.environ["SECOND_BRAIN_PATH"]] if os.environ.get("SECOND_BRAIN_PATH") and os.path.isdir(os.environ["SECOND_BRAIN_PATH"]) else []
    if not c:
        sys.exit("vault folder not mounted")
    return c[0]


V = vault()
RULES = json.load(open(os.path.join(V, "_scripts", "tag-rules.json"), encoding="utf-8"))
OWNED = tuple(n + "/" for n in RULES["owned"])
ADDITIVE = tuple(n + "/" for n in RULES["additive"])


def fold(s):
    return "".join(c for c in unicodedata.normalize("NFKD", s) if not unicodedata.combining(c))


START = time.time()
SEEN = {}


def files(paths=None, guard=True):
    if paths:
        for p in paths:
            p = p[len(V) + 1:] if p.startswith(V) else p
            if p.endswith(".md") and os.path.exists(os.path.join(V, p)):
                yield p
        return
    for root, dirs, fs in os.walk(V):
        dirs[:] = [d for d in dirs if not d.startswith(".") and d != "__pycache__"]
        for f in fs:
            if not f.endswith(".md"):
                continue
            full = os.path.join(root, f)
            rel = os.path.relpath(full, V)
            if any(rel.startswith(s) for s in RULES["skip"]):
                continue
            if guard and rel not in SEEN:
                SEEN[rel] = START - os.path.getmtime(full) < 120
            if guard and SEEN.get(rel):
                continue
            yield rel


def read(rel):
    with open(os.path.join(V, rel), encoding="utf-8") as fh:
        return fh.read()


def write(rel, text):
    full = os.path.join(V, rel)
    tmp = full + ".tagtmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        fh.write(text)
    os.replace(tmp, full)


# ---------------------------------------------------------------- frontmatter
FM_RE = re.compile(r"\A---\n(.*?)\n---[ \t]*(\n|\Z)", re.S)


def split(text):
    m = FM_RE.match(text)
    if not m:
        return None, text
    return m.group(1), text[m.end():]


def parse_tags(fm):
    """Return (tags, fm_lines_without_tags, index_where_tags_were)."""
    if fm is None:
        return [], [], 0
    lines = fm.split("\n")
    out, tags, idx, i = [], [], None, 0
    while i < len(lines):
        ln = lines[i]
        m = re.match(r"^tags\s*:\s*(.*)$", ln)
        if m and idx is None:
            idx = len(out)
            val = m.group(1).strip()
            if val.startswith("["):
                tags += [t.strip().strip("'\"") for t in val.strip("[]").split(",")]
            elif val:
                tags += [t.strip().strip("'\"") for t in re.split(r"[,\s]+", val)]
            i += 1
            while i < len(lines) and re.match(r"^\s+-\s*", lines[i]):
                tags.append(re.sub(r"^\s+-\s*", "", lines[i]).strip().strip("'\""))
                i += 1
            continue
        out.append(ln)
        i += 1
    tags = [t.lstrip("#") for t in tags if t and t.lstrip("#")]
    return tags, out, (len(out) if idx is None else idx)


def render(fm_lines, idx, tags, body, had_fm):
    line = "tags: [" + ", ".join(tags) + "]"
    lines = fm_lines[:idx] + [line] + fm_lines[idx:]
    lines = [ln for ln in lines if ln.strip() != "" or len(lines) == 1]
    return "---\n" + "\n".join(lines) + "\n---\n" + body


# ---------------------------------------------------------------- people
def people():
    """slug -> list of compiled regexes; first-name -> slug (unique only)."""
    idx = ""
    try:
        idx = read("People/index.md")
    except OSError:
        pass
    users = {}
    for name, user in re.findall(r"\|\s*([A-Z][\w'À-ɏ]+(?: [A-Z][\w'À-ɏ]+){1,3})\s*\(([a-z0-9]{3,})\)", idx):
        users[slug(fold(name))] = user
    found = {}
    for p in glob.glob(os.path.join(V, "People", "*.md")):
        b = os.path.basename(p)[:-3]
        if b in ("index", "CLAUDE", "README"):
            continue
        found[b.lower()] = b.replace("-", " ")
    pats, firsts = {}, Counter()
    first_of = {}
    extra = RULES.get("people_extra", {})
    for s in set(found) | set(extra):
        names = [found[s]] if s in found else []
        names += extra.get(s, [])
        if s in users:
            names.append(users[s])
        alts = []
        for n in names:
            n = fold(n)
            if " " in n:
                parts = n.split(" ")
                alts.append(r"\b" + r"\s*".join(re.escape(x) for x in parts) + r"\b")
                alts.append(r"\b" + re.escape(n.replace(" ", "-")) + r"\b")
            else:
                alts.append(r"\b" + re.escape(n) + r"\b")
        alts.append(r"People/" + re.escape(s.replace(" ", "-")))
        pats[s] = re.compile("|".join(alts), re.I)
        if s in found:
            f = found[s].split(" ")[0].lower()
            firsts[f] += 1
            first_of[f] = s
    first_of = {f: s for f, s in first_of.items() if firsts[f] == 1 and f != RULES.get("owner_slug", "owner")}
    return pats, first_of


def slug(s):
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")


PEOPLE, FIRST = people()
PROJ = {k: (v["path"], re.compile(v["re"], re.I)) for k, v in RULES["projects"].items()}
TOPIC = {k: re.compile(v) for k, v in RULES["topics"].items()}
KIND = [(t, re.compile(r, re.I)) for t, r in RULES["meeting_kind"]]
USAGE = re.compile(RULES["team"]["usage_keywords"], re.I)
CHANNELS = {os.path.basename(p)[:-3] for p in glob.glob(os.path.join(V, "Synced", "Channels", "*.md"))}


def two_attendees(body):
    m = re.search(r"(?im)^(?:\*\*attendees:?\*\*:?|attendees:)\s*\[?(.+?)\]?\s*$", body)
    if not m:
        return False
    names = [x for x in re.split(r",|;| and ", re.sub(r"\([^)]*\)", "", m.group(1))) if x.strip() and x.strip() != "—"]
    return len(names) == 2


def strip_code(body):
    body = re.sub(r"```.*?```", " ", body, flags=re.S)
    return re.sub(r"`[^`\n]*`", " ", body)


def compute(rel, body, old):
    name = os.path.basename(rel)
    stem = name[:-3]
    low = rel.replace("\\", "/")
    text = fold(strip_code(body))
    owned, add = [], []

    # type/
    t = RULES["type_by_name"].get(name) if "/" not in low or name in ("index.md", "README.md", "CLAUDE.md") else None
    if not t:
        for pre, tt in RULES["type_by_path"]:
            if low.startswith(pre):
                t = tt
                break
    if not t:
        t = RULES["type_by_name"].get(name, RULES["type_default"])
    if low.startswith("Archive/"):
        t = "type/archive"
    owned.append(t)

    # meeting/
    if t == "type/meeting":
        key = stem.lower().replace("_", "-")
        if low.startswith("Synced/1on1s/"):
            owned.append("meeting/1on1")
        else:
            for tag, rx in KIND:
                if rx.search(key):
                    owned.append(tag)
                    break
            else:
                if two_attendees(body) or "1on1" in old or "meeting/1on1" in old:
                    owned.append("meeting/1on1")

    # source/ status/
    owned.append("source/synced" if low.startswith("Synced/") else "source/vault")
    if low.startswith("Archive/"):
        owned.append("status/archived")

    # team/
    d = re.match(r"(\d{4}-\d\d-\d\d)", stem) or re.search(r"(\d{4}-\d\d-\d\d)$", stem)
    usage_hit = bool(USAGE.search(stem))
    if d:
        owned.append(RULES["team"]["before"] if d.group(1) < RULES["team"]["switch_date"] else RULES["team"]["after"])
    elif usage_hit or "UsagePipeline" in stem:
        owned.append(RULES["team"]["before"])
    elif t in ("type/meeting", "type/channel-digest") and USAGE.search(text[:3000]):
        owned.append(RULES["team"]["before"])
    else:
        owned.append(RULES["team"]["after"])

    # project/
    for p, (path, rx) in PROJ.items():
        hits = len(rx.findall(text))
        if (path and low.startswith(path)) or rx.search(stem) or hits >= RULES["project_min_hits"]:
            add.append("project/" + p)

    # person/
    for s, rx in PEOPLE.items():
        if s in RULES.get("people_exclude", []):
            continue
        if low == f"People/{s}.md".replace(" ", "-") or low.lower() == f"people/{s}.md" or rx.search(text) \
                or (low.startswith("Accomplishments/") and stem.lower() == s):
            add.append("person/" + s)
    if RULES.get("people_first_name_in_filename") and t == "type/meeting":
        for tok in re.split(r"[-_ ]+", stem.lower()):
            if tok in FIRST:
                add.append("person/" + FIRST[tok])

    # topic/
    for k, rx in TOPIC.items():
        if rx.search(stem) or len(rx.findall(text)) >= RULES["topic_min_hits"]:
            add.append("topic/" + k)
    if "meeting/postmortem" in owned:
        add.append("topic/postmortem")
    if "meeting/postmortem" in owned:
        add.append("topic/postmortem")

    # channel/
    if t == "type/channel-digest":
        c = re.sub(r"^\d{4}-\d\d-\d\d-", "", stem)
        c = re.sub(r"-digest$", "", c).lstrip("#")
        add.append("channel/" + slug(c))

    # merge with existing
    keep = []
    for tg in old:
        if tg.startswith(OWNED):
            continue
        if tg.startswith(ADDITIVE) or re.match(r"^[a-z][a-z-]*/[a-z0-9]", tg):
            keep.append(tg)
            continue
        lm = RULES.get("legacy_map", {})
        if tg in lm:
            m = lm[tg]
            if m and not m.startswith(OWNED):
                keep.append(m)
            continue
        keep.append(f"{RULES.get('legacy_default_ns', 'topic')}/{slug(tg)}")
    out = []
    for tg in owned + keep + add:
        tg = tg.strip().lower()
        if tg and tg not in out:
            out.append(tg)
    # stable order: owned first, then sorted additive
    head = [x for x in out if x.startswith(OWNED)]
    tail = sorted(x for x in out if not x.startswith(OWNED))
    return head + tail


def tag_file(rel, dry):
    text = read(rel)
    fm, body = split(text)
    old, fm_lines, idx = parse_tags(fm)
    new = compute(rel, body, old)
    if new == old:
        return None
    out = render(fm_lines, idx, new, body, fm is not None)
    if out != text and not dry:
        write(rel, out)
    return {"file": rel, "old": old, "new": new}


# ---------------------------------------------------------------- inline cleanup
PROTECT = re.compile(r"```.*?```|~~~.*?~~~|`[^`\n]*`|\[\[[^\]\n]*\]\]|\]\([^)\n]*\)|<[^>\n]*>|https?://[^\s)\]|>]+", re.S)
INLINE = re.compile(r"(?<![\w/&#\\])#([^\s#`\[\]()<>{},.;:!?\"'|*~=+^$%&@\\]+)")


def _fix_seg(seg):
    def rep(m):
        name = m.group(1)
        if re.match(r"\d", name):
            return "\\#" + name
        return "`#" + name + "`"
    return INLINE.sub(rep, seg)


def fix_text(body):
    out, last, n = [], 0, 0
    for m in PROTECT.finditer(body):
        seg = body[last:m.start()]
        f = _fix_seg(seg)
        n += f != seg
        out += [f, m.group(0)]
        last = m.end()
    seg = body[last:]
    f = _fix_seg(seg)
    out.append(f)
    return "".join(out)


def fix_file(rel, dry):
    text = read(rel)
    fm, body = split(text)
    # headings ("# Title") need a space so they never match; protect each heading marker
    new_body, prev = fix_text(body), None
    for _ in range(5):  # chained "#a/#b" mentions unlock one level per pass; iterate to a fixed point
        if new_body == prev:
            break
        prev, new_body = new_body, fix_text(new_body)
    if new_body == body:
        return None
    count = len(INLINE.findall(PROTECT.sub("", body)))
    if not dry:
        write(rel, (f"---\n{fm}\n---\n" if fm is not None else "") + new_body)
    return {"file": rel, "fixed": count}


# ---------------------------------------------------------------- commands
def cmd_fix(a):
    res = [r for r in (fix_file(f, a.dry_run) for f in files(a.paths, guard=not a.no_guard)) if r]
    return {"inlineFixedFiles": len(res), "inlineFixed": sum(r["fixed"] for r in res),
            "sample": res[:5] if a.dry_run else []}


def cmd_tag(a):
    res = [r for r in (tag_file(f, a.dry_run) for f in files(a.paths, guard=not a.no_guard)) if r]
    return {"taggedFiles": len(res), "sample": res[:5] if a.dry_run else []}


def cmd_run(a):
    r = cmd_fix(a)
    r.update(cmd_tag(a))
    return r


def cmd_report(a):
    c, untyped, n = Counter(), [], 0
    for f in files(None, guard=False):
        fm, _ = split(read(f))
        tags, _, _ = parse_tags(fm)
        n += 1
        if not any(t.startswith("type/") for t in tags):
            untyped.append(f)
        for t in tags:
            c[t] += 1
    ns = Counter()
    for t, k in c.items():
        ns[t.split("/")[0] if "/" in t else "(none)"] += 1
    return {"files": n, "untyped": untyped[:30], "untypedCount": len(untyped),
            "namespaces": dict(ns), "tags": dict(sorted(c.items(), key=lambda x: (-x[1], x[0])))}


def cmd_show(a):
    rel = a.path
    fm, body = split(read(rel))
    old, _, _ = parse_tags(fm)
    return {"file": rel, "old": old, "new": compute(rel, body, old)}


def main():
    ap = argparse.ArgumentParser()
    sp = ap.add_subparsers(dest="cmd", required=True)
    for name, f in (("run", cmd_run), ("tag", cmd_tag), ("fix-inline", cmd_fix)):
        x = sp.add_parser(name)
        x.add_argument("--dry-run", action="store_true")
        x.add_argument("--paths", nargs="*")
        x.add_argument("--no-guard", action="store_true", help="also touch files written in the last 120 s")
        x.set_defaults(f=f)
    x = sp.add_parser("report"); x.set_defaults(f=cmd_report)
    x = sp.add_parser("show"); x.add_argument("path"); x.set_defaults(f=cmd_show)
    a = ap.parse_args()
    print(json.dumps(a.f(a), indent=1, ensure_ascii=False))


if __name__ == "__main__":
    main()
