#!/usr/bin/env python3
"""
check_src_tree.py -- catch the ways an edit to src/ can silently produce nothing.

The readme says every item is its own `.lua` and that is what you edit. What it
cannot say is that muddler will tell you when an edit does not land, because it
will not. Two shapes of mistake produce a clean build and a package missing the
code:

  An orphan .lua. muddler works from the json: it walks the items declared
  there and looks for a file per item. A `.lua` with no entry in the sibling
  json is read by nothing, reported by nothing, and shipped as nothing. Adding
  an item by creating the file - the obvious move, given the readme - is
  exactly this mistake.

  A filename collision. The lookup is `name:gsub(" ", "_") .. ".lua"`, and that
  is not injective: "svo count show" and "svo_count_show" resolve to the same
  file, so two items silently share one script and whichever loses is gone.
  xml2muddler.py guards this at conversion time; nothing reproduced the guard
  for hand edits.

A third, quieter one: a name whose file differs only in case. That resolves on
a Windows checkout and not on the Linux runner that builds the release, which
is the same class of platform-dependent breakage as the group ordering bug.

    python tools/check_src_tree.py
"""
import io
import json
import os
import sys
from collections import defaultdict

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(REPO, "src")

# src/<dir>/ holds items of this kind, declared in <json_name>
KINDS = {
    "triggers": "triggers.json",
    "aliases": "aliases.json",
    "scripts": "scripts.json",
    "keys": "keys.json",
    "timers": "timers.json",
    "buttons": "buttons.json",
}

# Not an item tree - muddler copies this to the package root verbatim.
SKIP = {"resources"}

# Below these, no item count is plausible enough to be a floor, but an empty
# src/ must not read as "nothing wrong". See check_renamed_callsites.py.
MIN_ITEMS = 2000


def filename_for(name):
    """What muddler will look for, given an item name."""
    return name.replace(" ", "_") + ".lua"


def main():
    if not os.path.isdir(SRC):
        print("[FAIL] %s does not exist" % SRC)
        return 1

    problems = []
    items = 0
    files = 0
    inlined = [0]

    for kind, json_name in sorted(KINDS.items()):
        base = os.path.join(SRC, kind)
        if not os.path.isdir(base):
            continue
        for root, dirs, filenames in os.walk(base):
            dirs[:] = [d for d in dirs if d not in SKIP]
            rel = os.path.relpath(root, REPO).replace(os.sep, "/")

            manifest = os.path.join(root, json_name)
            declared = []
            if os.path.exists(manifest):
                with io.open(manifest, encoding="utf-8") as fh:
                    try:
                        declared = json.load(fh)
                    except ValueError as e:
                        problems.append("%s/%s is not valid json: %s"
                                        % (rel, json_name, e))
                        continue
            elif any(f.endswith(".lua") for f in filenames):
                problems.append(
                    "%s has .lua files but no %s, so muddler reads none of them"
                    % (rel, json_name))
                continue
            else:
                continue

            wanted = defaultdict(list)

            # Children declared inline in the json live in the SAME directory
            # as their parent - only a group that gets its own subdirectory has
            # a separate json. Missing that recursion made 98 perfectly good
            # files look orphaned.
            def claim(entries):
                for item in entries if isinstance(entries, list) else [entries]:
                    if not isinstance(item, dict) or not item.get("name"):
                        continue
                    global_items[0] += 1
                    # An item whose script is inlined in the json does not want
                    # a file, and cannot collide with one. This is how the
                    # conversion handled duplicate siblings, which resolve to
                    # one filename by definition - 'svo cured generosity'
                    # appears twice under General and both bodies live in the
                    # json.
                    if not item.get("script"):
                        wanted[filename_for(item["name"])].append(item["name"])
                    else:
                        global_inlined[0] += 1
                    claim(item.get("children") or [])

            global_items, global_inlined = [items], inlined
            claim(declared)
            items = global_items[0]

            for fn, names in sorted(wanted.items()):
                if len(names) > 1:
                    problems.append(
                        "%s: %s all resolve to %s - muddler's lookup replaces "
                        "spaces with underscores and nothing else, so they "
                        "would share one script"
                        % (rel, ", ".join(repr(n) for n in sorted(names)), fn))

            present = {f for f in filenames if f.endswith(".lua")}
            files += len(present)

            for fn in sorted(present - set(wanted)):
                lowered = {w.lower(): w for w in wanted}
                if fn.lower() in lowered:
                    problems.append(
                        "%s/%s differs only in case from %s, which is what "
                        "muddler looks for - this resolves on Windows and not "
                        "on the Linux runner that builds the release"
                        % (rel, fn, lowered[fn.lower()]))
                else:
                    problems.append(
                        "%s/%s is claimed by no item in %s - nothing reads it "
                        "and nothing ships it"
                        % (rel, fn, json_name))

    print("checked %d declared items against %d .lua files under src/ "
          "(%d items carry their script inlined in the json)"
          % (items, files, inlined[0]))

    if items < MIN_ITEMS:
        print("[FAIL] only %d items found, expected at least %d - this check "
              "is reading less than it should" % (items, MIN_ITEMS))
        problems.append("item floor")

    for p in problems:
        print("[FAIL] " + p)
    print()
    if problems:
        print("SRC TREE FAILED - %d problem(s)" % len(problems))
        return 1
    print("SRC TREE OK - every .lua is reachable and no two items share a file")
    return 0


if __name__ == "__main__":
    sys.exit(main())
