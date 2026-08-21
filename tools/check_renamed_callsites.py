#!/usr/bin/env python3
"""Fail if any source still names an item by the name it had before the rename.

Items whose names could not become filenames were renamed during the conversion
(tools/renames_filenames.csv). rename_unfilenameable.py only rewrote the <name>
elements, so every call site had to be found by hand - and two were missed:
enableTrigger"City/House/Order enemies" (paren-less, so a "enableTrigger(" sweep
skipped it) and setTriggerStayOpen("svo Capture elist/elist2/venomlist", 0),
which Mudlet treats as a silent no-op on an unknown name. Neither raised an
error; the enemy list simply stopped being captured and the elist capture
stopped closing early.

This looks for the old name as a quoted string anywhere under src/, which needs
no knowledge of which Mudlet function is being called.
"""
import csv, io, os, re, sys

CSV = os.path.join(os.path.dirname(__file__), "renames_filenames.csv")
SRC = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "src")

# Prose that happens to match an old name. ndb-help's cheatsheet lists the
# in-game commands a user types; "qw/qw2" there means "qw or qw2" and has
# nothing to do with the alias item that was renamed for its filename.
ALLOW = {("src/resources/ndb-help.lua", "qw/qw2")}


def main():
    with io.open(CSV, encoding="utf-8") as f:
        renames = [(r["old_name"], r["new_name"]) for r in csv.DictReader(f)
                   if r["old_name"] != r["new_name"]]

    findings = []
    for root, _, files in os.walk(SRC):
        for fn in files:
            if not fn.endswith((".lua", ".json")):
                continue
            path = os.path.join(root, fn)
            rel = os.path.relpath(path, os.path.dirname(SRC)).replace(os.sep, "/")
            text = io.open(path, encoding="utf-8", errors="replace").read()
            for old, new in renames:
                if (rel, old) in ALLOW:
                    continue
                for m in re.finditer(r'["\']' + re.escape(old) + r'["\']', text):
                    findings.append((rel, text[:m.start()].count("\n") + 1, old, new))

    print("checked %d renames against %s" % (len(renames), SRC))
    if not findings:
        print("no stale references to pre-rename item names")
        return 0

    print("\n%d stale reference(s) to names that no longer exist:" % len(findings))
    for rel, line, old, new in findings:
        print("  %s:%d\n      %r should be %r" % (rel, line, old, new))
    print("\nMudlet does not raise on an unknown item name - these fail silently.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
