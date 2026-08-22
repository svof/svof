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

# Floors. Every check here reports what it found, and "found nothing" read
# exactly like "found nothing wrong": deleting src/ gave "0 literal item names
# ... every literal item name resolves", exit 0. These are set well below the
# real figures (2890 items, 194 references, 56 recorded renames) so ordinary
# growth or pruning does not trip them, but an empty or half-read tree does.
MIN_ITEMS = 2000
MIN_REFERENCES = 100
MIN_RENAMES = 40

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


def _files(src):
    for root, _, files in os.walk(src):
        for fn in sorted(files):
            if fn.endswith((".lua", ".json")):
                yield os.path.join(root, fn)


def _chunks(src):
    """(label, lua source) for everything in src/ that is Lua.

    A .json is not Lua, and reading one as raw text found nothing at all: the
    scan reported {'.json': 0, '.lua': 194}, so the 64 scripts inlined into
    the json - the ones whose item name cannot be a filename or collides with
    a non-sibling - were never examined by either check. Those are exactly the
    items whose names had to be rewritten, which makes them the likeliest
    place for a stale call site to survive. Parse the json and yield each
    inlined body as the Lua it is.
    """
    for path in _files(src):
        rel = _rel(path)
        if path.endswith(".lua"):
            yield rel, io.open(path, encoding="utf-8", errors="replace").read()
            continue
        with io.open(path, encoding="utf-8") as fh:
            data = json.load(fh)

        def walk(items, trail):
            for it in items if isinstance(items, list) else [items]:
                if not isinstance(it, dict):
                    continue
                here = trail + [it.get("name") or "?"]
                if it.get("script"):
                    yield rel + "#" + "/".join(here), it["script"]
                for chunk in walk(it.get("children") or [], here):
                    yield chunk

        for chunk in walk(data, []):
            yield chunk


def collect_names(src):
    """Every item name that exists, keyed by kind.

    A kind whose directory is absent gets an empty set rather than no entry at
    all. Skipping it meant every reference of that kind was skipped too - and
    src/timers/ does not exist, so enableTimer("anything") was unchecked by
    construction. An absent directory means no items of that kind exist, which
    is the answer this check is asking for, not a reason to stop asking.
    """
    names = collections.defaultdict(set)

    def walk(items, kind):
        for it in items if isinstance(items, list) else [items]:
            if not isinstance(it, dict):
                continue
            if it.get("name"):
                names[kind].add(it["name"])
            walk(it.get("children", []) or [], kind)

    for top, kind in KIND_DIR.items():
        names[kind]  # defaultdict: the kind exists even with no directory
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
    for rel, text in _chunks(src):

        def record(match, func, kind, name, rel=rel, text=text):
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
    for rel, text in _chunks(src):
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
        # Keyed by kind too. Keying on (file, name) alone meant a NEW dead
        # reference of a different kind - enableAlias("Applied") beside the
        # recorded enableTrigger("Applied") - was absorbed by the existing
        # entry and never reported.
        return {(e["file"], e.get("kind"), e["name"])
                for e in json.load(fh)["known"]}


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
        entries = sorted({(f.file, f.kind, f.name) for f in unresolved})
        with io.open(KNOWN, "w", encoding="utf-8", newline="\n") as fh:
            json.dump({"known": [{"file": f, "kind": k, "name": n}
                                 for f, k, n in entries]},
                      fh, indent=2, ensure_ascii=False)
            fh.write("\n")
        print("wrote %s: %d pre-existing dead references" % (KNOWN, len(entries)))
        return 0

    known = load_known()
    new = [f for f in unresolved if (f.file, f.kind, f.name) not in known]

    print("checked %d recorded renames, and %d literal item names against the "
          "%d items in src/" % (len(renames), examined, total))

    rc = 0

    # Floors before findings. Everything below reports what it found, and
    # nothing distinguished "found nothing wrong" from "found nothing": with
    # src/ absent this printed "0 literal item names ... every literal item
    # name resolves" and exited 0, where the sibling syntax gate refuses.
    if not os.path.isdir(SRC):
        print("\n%s does not exist - there is nothing to check" % _rel(SRC))
        return 1
    for label, got, floor in (("items in src/", total, MIN_ITEMS),
                              ("literal references", examined, MIN_REFERENCES),
                              ("recorded renames", len(renames), MIN_RENAMES)):
        if got < floor:
            print("\nonly %d %s, expected at least %d - this check is reading "
                  "less than it should, so its silence means nothing"
                  % (got, label, floor))
            rc = 1
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
