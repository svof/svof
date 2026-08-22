#!/usr/bin/env python3
"""Fail if any source names a Mudlet item that does not exist.

Two checks, because they catch different things.

1. Pre-rename names. Items whose names could not become filenames were renamed
   during the conversion (tools/renames_filenames.csv). rename_unfilenameable.py
   only rewrote the <name> elements, so every call site had to be found by hand
   - and two were missed: enableTrigger"City/House/Order enemies" (paren-less,
   so a "enableTrigger(" sweep skipped it) and
   setTriggerStayOpen("svo Capture elist/elist2/venomlist", 0). Neither raised;
   the enemy list simply stopped being captured and the elist capture stopped
   closing early.

2. Names that resolve to nothing at all. The CSV records 56 renames, but the
   conversion performed 136: 57 for illegal characters and 79 more to
   disambiguate duplicate siblings. The dedup ones are the riskier class,
   because the old name still resolves to *something* - enableTrigger("Limb
   damage") quietly goes from reaching 4 triggers to reaching 1. Rather than
   extend the record and hope it stays complete, ask the question that actually
   matters: does this name exist? That covers every rename, recorded or not,
   plus the long-bracket call form the first check cannot see.

Mudlet does not raise on an unknown item name - all of this fails silently.

    python tools/check_renamed_callsites.py
"""
import argparse
import collections
import csv
import io
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
CSV = os.path.join(HERE, "renames_filenames.csv")
REPO = os.path.dirname(HERE)
SRC = os.path.join(REPO, "src")
KNOWN = os.path.join(HERE, "known_unresolved_names.json")

# Prose that happens to match an old name. ndb-help's cheatsheet lists the
# in-game commands a user types; "qw/qw2" there means "qw or qw2" and has
# nothing to do with the alias item that was renamed for its filename.
ALLOW = {("src/resources/ndb-help.lua", "qw/qw2")}

# src/<dir>/ holds items of this kind
KIND_DIR = {
    "triggers": "trigger", "aliases": "alias", "scripts": "script",
    "keys": "key", "timers": "timer", "buttons": "button",
}

# Mudlet calls whose first string argument is an item name. Every one of these
# is a silent no-op when the name does not resolve.
NAME_FUNCS = {
    "enableTrigger": "trigger", "disableTrigger": "trigger",
    "setTriggerStayOpen": "trigger",
    "enableAlias": "alias", "disableAlias": "alias",
    "enableKey": "key", "disableKey": "key",
    "enableTimer": "timer", "disableTimer": "timer",
    "enableScript": "script", "disableScript": "script",
}

# Lua's three string literal forms.
_STR = r'"((?:[^"\\]|\\.)*)"' r"|'((?:[^'\\]|\\.)*)'" r"|\[\[(.*?)\]\]"

# The call may be paren-less - enableTrigger"name" is how one of the two
# original misses hid from a "enableTrigger(" sweep.
CALL_RE = re.compile(
    r"\b(" + "|".join(NAME_FUNCS) + r")\s*(?:\(\s*)?(?:" + _STR + r")", re.S)

# exists()/isActive() name the kind in a second argument.
KIND_RE = re.compile(
    r"\b(exists|isActive)\s*\(\s*(?:" + _STR + r")\s*,\s*"
    r"""(?:"([a-z]+)"|'([a-z]+)')""", re.S)

# A literal that is immediately concatenated is only a fragment of the real
# name: enableTrigger("svo " .. class .. " limbcounter") must not be read as a
# reference to an item called "svo ".
CONCAT_RE = re.compile(r"\s*\.\.")

Finding = collections.namedtuple("Finding", "file line func kind name")


def _rel(path):
    return os.path.relpath(path, REPO).replace(os.sep, "/")


def _sources(src):
    for root, _, files in os.walk(src):
        for fn in files:
            if fn.endswith((".lua", ".json")):
                yield os.path.join(root, fn)


def collect_names(src):
    """Every item name that exists, keyed by kind."""
    names = collections.defaultdict(set)

    def walk(items, kind):
        for it in items if isinstance(items, list) else [items]:
            if not isinstance(it, dict):
                continue
            if it.get("name"):
                names[kind].add(it["name"])
            walk(it.get("children", []) or [], kind)

    for top, kind in KIND_DIR.items():
        base = os.path.join(src, top)
        if not os.path.isdir(base):
            continue
        for root, _, files in os.walk(base):
            for fn in files:
                if not fn.endswith(".json"):
                    continue
                path = os.path.join(root, fn)
                with io.open(path, encoding="utf-8") as fh:
                    walk(json.load(fh), kind)
    return names


def find_unresolved(src, names):
    """Literal item names that do not resolve to any item of that kind.

    Returns (findings, number of literal references examined)."""
    out = []
    seen = [0]
    for path in _sources(src):
        rel = _rel(path)
        text = io.open(path, encoding="utf-8", errors="replace").read()

        def record(match, func, kind, name):
            if name is None or kind not in names:
                return
            if CONCAT_RE.match(text[match.end():]):
                return
            seen[0] += 1
            if name not in names[kind]:
                out.append(Finding(rel, text[:match.start()].count("\n") + 1,
                                   func, kind, name))

        for m in CALL_RE.finditer(text):
            record(m, m.group(1), NAME_FUNCS[m.group(1)],
                   m.group(2) or m.group(3) or m.group(4))

        for m in KIND_RE.finditer(text):
            record(m, m.group(1), m.group(5) or m.group(6),
                   m.group(2) or m.group(3) or m.group(4))
    return out, seen[0]


def find_prerename(src):
    """References to a name as it was before the conversion renamed it."""
    with io.open(CSV, encoding="utf-8") as f:
        renames = [(r["old_name"], r["new_name"]) for r in csv.DictReader(f)
                   if r["old_name"] != r["new_name"]]

    out = []
    for path in _sources(src):
        rel = _rel(path)
        text = io.open(path, encoding="utf-8", errors="replace").read()
        for old, new in renames:
            if (rel, old) in ALLOW:
                continue
            for m in re.finditer(r'["\']' + re.escape(old) + r'["\']', text):
                out.append((rel, text[:m.start()].count("\n") + 1, old, new))
    return renames, out


def load_known():
    """Dead references that predate the conversion.

    These name items that are absent from the 25 pre-conversion module xmls as
    well as from src/, so they were already silent no-ops before any of this -
    not conversion damage. They are recorded rather than fixed because picking
    the name each one *meant* is a behaviour change and belongs in its own
    commit. The point of recording them is that anything NEW fails the gate.
    """
    if not os.path.exists(KNOWN):
        return set()
    with io.open(KNOWN, encoding="utf-8") as fh:
        return {(e["file"], e["name"]) for e in json.load(fh)["known"]}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--write-known", action="store_true",
                    help="record the current unresolved names as pre-existing")
    a = ap.parse_args()

    names = collect_names(SRC)
    total = sum(len(v) for v in names.values())

    renames, stale = find_prerename(SRC)
    unresolved, examined = find_unresolved(SRC, names)

    if a.write_known:
        entries = sorted({(f.file, f.name) for f in unresolved})
        with io.open(KNOWN, "w", encoding="utf-8", newline="\n") as fh:
            json.dump({"known": [{"file": f, "name": n} for f, n in entries]},
                      fh, indent=2, ensure_ascii=False)
            fh.write("\n")
        print("wrote %s: %d pre-existing dead references" % (KNOWN, len(entries)))
        return 0

    known = load_known()
    new = [f for f in unresolved if (f.file, f.name) not in known]

    print("checked %d recorded renames, and %d literal item names against the "
          "%d items in src/" % (len(renames), examined, total))

    rc = 0
    if stale:
        print("\n%d stale reference(s) to names that no longer exist:" % len(stale))
        for rel, line, old, new_name in stale:
            print("  %s:%d\n      %r should be %r" % (rel, line, old, new_name))
        rc = 1
    else:
        print("no stale references to pre-rename item names")

    if new:
        print("\n%d name(s) that resolve to no item:" % len(new))
        for f in new:
            print("  %s:%d\n      %s(%r) - no %s by that name"
                  % (f.file, f.line, f.func, f.name, f.kind))
        print("\nMudlet does not raise on an unknown item name - these fail silently.")
        print("If this is deliberate, record it with --write-known.")
        rc = 1
    else:
        print("every literal item name resolves (%d known pre-existing dead "
              "reference(s) ignored)" % len(known))

    return rc


if __name__ == "__main__":
    sys.exit(main())
