"""
Writes, or checks, src/resources/trigger_catalog.lua: every line pattern of
svof's own triggers, with the trigger it belongs to.

A definition's lines must not be ones svof already watches for, or a line
would count for both. Defences are records, so vcustomdef checks a
definition against them, but svof's afflictions are recognised by about
2,500 trigger items, which Lua can't read back in Mudlet. This catalog is
how vcustomaff knows them.

It holds, folder by folder, each trigger's exact, substring, start-of-line and regex
patterns, the ones a game line is matched against. Lua function, prompt,
colour and spacer patterns don't match line text and are left out, as are
the patterns of a filter trigger's children, which match what it captured,
and a pattern that matches lines in general, such as ^ or .+, which every
definition's line would clash with. A pattern counts as general when it
matches one of the unrelated lines in PROBES, a regex tried with Python's
re, which reads these patterns as PCRE does.

A trigger matches a line the way Mudlet runs it:

- an AND trigger with a line delta of 0 matches a line that all its
  patterns match, so it's marked all, and is general only when one probe
  matches them all. Apostasy's Def strip is start "Your " and a regex, and
  "Your " alone is any line starting so. With a delta of more, its patterns
  are lines apart, so each is kept, as a line svof waits for
- a trigger's children run on the line it matched, and, for a fire length
  of more than 0, on that many lines after. A child of a fire length of 0
  matches only with its parent, so it carries the parent's patterns as
  need: Chaosrays hit / red is "red" on a line "You are hit by a" starts.
  An AND trigger whose patterns are lines apart fires on its last line,
  which its patterns needn't match, so its children are kept as lines svof
  waits for: Ate's are the cure lines after "You eat", a spacer of 1 on.
  The children of a longer chain match only inside it: svo diag's, the
  DIAGNOSE lines, are marked diag, and are checked against a definition's
  DIAGNOSE lines, while other chains' are left out, as lines svof reads
  only after a line of its own, such as the channels or honours lists.

  python tools/trigger_catalog.py          check the file is current
  python tools/trigger_catalog.py --write  write it

The check fails when a trigger's patterns change and the file hasn't, the
way tools/defence_catalog.lua does: regenerate it in the same commit. It
compares the generated text with the file's after normalising line
endings, as Windows checks it out with CRLF.
"""

import json
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TRIGGERS = os.path.join(REPO, "src", "triggers")
OUT = os.path.join(REPO, "src", "resources", "trigger_catalog.lua")

KINDS = {"exactMatch": "exact", "substring": "sub", "startOfLine": "start", "regex": "regex"}

# lines no trigger should match; a pattern matching any of them matches lines
# in general. The hyphen is the prompt's flags pattern's, which matches any
# line with a hyphenated word in it, and "You" starts most of the game's lines,
# as Damaged arm's start-of-line pattern does, whose script decides
PROBES = ["", "Zq9 xyzzy plugh 42.", "The quick brown fox jumps over the lazy dog.", "a",
          "A well-known line.", "You see nothing special."]


def lua_string(s):
    out = ['"']
    for ch in s:
        if ch == "\\":
            out.append("\\\\")
        elif ch == '"':
            out.append('\\"')
        elif ch == "\n":
            out.append("\\n")
        elif ch == "\r":
            out.append("\\r")
        elif ord(ch) < 32 or ord(ch) == 127:
            out.append("\\%03d" % ord(ch))
        else:
            out.append(ch)
    out.append('"')
    return "".join(out)


DIAG_CHAIN = "svo diag"


def matches(kind, pattern, line):
    if kind == "exact":
        return line == pattern
    if kind == "sub":
        return pattern in line
    if kind == "start":
        return line.startswith(pattern)
    try:
        return re.search(pattern, line) is not None
    except re.error:
        # Python can't read it; keep it, and let Mudlet's PCRE decide
        return False


# whether a condition, (patterns, all), matches line: all of them or any
def cond_matches(cond, line):
    pats, every = cond
    hits = (matches(k, t, line) for k, t in pats)
    return all(hits) if every else any(hits)


# whether a trigger matching cond, on a line each of need matches too,
# matches lines in general
def general(cond, need):
    return any(cond_matches(cond, p) and all(cond_matches(n, p) for n in need) for p in PROBES)


# A filter trigger's children are matched against what it captured, not a
# game line, such as the prompt's flags under "Capture flags", so they and
# theirs are left out. need is the conditions of the parents a child
# matches only with, and diag whether it's in svo diag's chain
def walk(items, folder, path, entries, skipped, filtered=False, need=(), diag=False, window=None):
    for item in items:
        name = item.get("name", "")
        here = path + [name]
        pats = []
        for p in item.get("patterns", []):
            kind = KINDS.get(p.get("type"))
            text = p.get("pattern", "")
            if kind and text != "":
                pats.append((kind, text))
        every = (item.get("multiline") == "yes" and item.get("multilineDelta", "0") in ("0", "") and len(pats) > 1
                 and not any(p.get("type") == "spacer" for p in item.get("patterns", [])))
        where = folder + " / " + " / ".join(here)
        if filtered or window:
            pats = []
        elif every:
            if general((pats, True), need):
                skipped.append((where, " & ".join(t for _, t in pats)))
                pats = []
        else:
            kept = []
            for kind, text in pats:
                if general(([(kind, text)], False), need):
                    skipped.append((where, text))
                else:
                    kept.append((kind, text))
            pats = kept
        if pats:
            entries.append((folder, " / ".join(here), pats, every, list(need), diag))
        child_need, child_diag, child_window = need, diag, window
        own = [(k, t) for k, t in ((KINDS.get(p.get("type")), p.get("pattern", "")) for p in item.get("patterns", []))
               if k and t != ""]
        # an AND trigger whose patterns are lines apart fires on its last
        # line, which its own patterns needn't match: Ate's children are the
        # cure lines on the line after "You eat", a spacer of 1 on
        spans = item.get("multiline") == "yes" and (item.get("multilineDelta", "0") not in ("0", "")
                                                    or any(p.get("type") == "spacer" for p in item.get("patterns", [])))
        if own and item.get("isFolder") != "yes":
            fire = int(item.get("fireLength") or 0)
            if name == DIAG_CHAIN:
                child_need, child_diag = (), True
            elif spans:
                child_need = ()
            elif fire == 0:
                child_need = tuple(need) + ((own, every),)
            else:
                child_window = where
        walk(item.get("children", []), folder, here, entries, skipped,
             filtered or item.get("filter") == "yes", child_need, child_diag, child_window)


def collect():
    entries, skipped = [], []
    files = []
    for root, dirs, names in os.walk(TRIGGERS):
        if "triggers.json" in names:
            files.append(os.path.join(root, "triggers.json"))
    # by path, so the same sources write the same file on every platform
    files.sort(key=lambda f: os.path.relpath(f, TRIGGERS).replace(os.sep, "/"))
    for f in files:
        rel = os.path.relpath(os.path.dirname(f), TRIGGERS).replace(os.sep, "/")
        folder = "" if rel == "." else rel.replace("/", " / ")
        with open(f, encoding="utf-8") as fh:
            walk(json.load(fh), folder, [], entries, skipped)
    return entries, skipped


def render(entries):
    lines = [
        "-- Every line pattern of svof's own triggers: generated by",
        "-- tools/trigger_catalog.py from src/triggers. Don't edit it by hand.",
        "-- Each entry is a folder's path, then its triggers, each the trigger's",
        "-- name (with the triggers it's nested under), then its patterns, each a",
        "-- kind (exact, sub, start or regex) and the pattern. A trigger matches a",
        "-- line one of its patterns matches, or, marked all, that they all do; with",
        "-- need, only a line each of its parents' conditions there matches too,",
        "-- and, marked diag, only in DIAGNOSE's output.",
        "return {",
    ]

    def pat_list(pats):
        return ", ".join("{ %s, %s }" % (lua_string(k), lua_string(t)) for k, t in pats)

    current = None
    for folder, item, pats, every, need, diag in entries:
        if folder != current:
            if current is not None:
                lines.append("  },")
            lines.append("  { %s," % lua_string(folder))
            current = folder
        extra = ""
        if every:
            extra += ", all = true"
        if need:
            extra += ", need = { %s }" % ", ".join(
                "{ %s%s }" % (pat_list(p), ", all = true" if e else "") for p, e in need)
        if diag:
            extra += ", diag = true"
        lines.append("    { %s, %s%s }," % (lua_string(item), pat_list(pats), extra))
    if current is not None:
        lines.append("  },")
    lines.append("}")
    return "\n".join(lines) + "\n"


def main():
    entries, skipped = collect()
    text = render(entries)
    count = sum(len(e[2]) for e in entries)
    if "--write" in sys.argv[1:]:
        with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(text)
        print("wrote %s: %d patterns from %d triggers, %d general patterns left out"
              % (os.path.relpath(OUT, REPO), count, len(entries), len(skipped)))
        return 0
    try:
        with open(OUT, encoding="utf-8", newline="") as fh:
            current = fh.read().replace("\r\n", "\n")
    except FileNotFoundError:
        print("FAIL: %s is missing; run tools/trigger_catalog.py --write" % os.path.relpath(OUT, REPO))
        return 1
    if current != text:
        print("FAIL: %s is out of date; run tools/trigger_catalog.py --write in this commit"
              % os.path.relpath(OUT, REPO))
        return 1
    print("OK: %s is current: %d patterns from %d triggers, %d general patterns left out"
          % (os.path.relpath(OUT, REPO), count, len(entries), len(skipped)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
