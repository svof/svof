#!/usr/bin/env python3
"""
check_derived_lists.py -- the same affliction fact, written in several places,
compared.

Adding one affliction to svof means typing its name into several lists spread
over five files. None of them is enforced, so missing one means the affliction
quietly does not work in that one way, and nothing complains. They have already
drifted: herb lists in *Empty cure handling* disagree with the dictionary's own
cure fields, and the tree triggers disagree with empty.treecurables.

This derives what it can from `svo.dict` and diffs it against whatever else
holds the same information - a literal, or, since the handler families were
inverted, the triggers. Counts are printed rather than written down here,
because a count in a comment near this gate has gone stale three times.

Some comparisons are real today because they derive from entry shape. Others
wait on a declared field and read 0 until it exists, and the left-hand count
climbing to meet the right-hand one is what adding that field looks like.

Differences that are deliberate live in a baseline file with a digest each, the
way verify_merged.py does it, so this fails on anything new AND on any change to
a difference already accepted:

    python tools/check_derived_lists.py --baseline tools/derived_lists_baseline.json

Without --baseline it lists everything and exits non-zero, which is fine for
looking and useless as a gate. When a difference is intended, regenerate in the
same commit that causes it:

    python tools/check_derived_lists.py --write-baseline tools/derived_lists_baseline.json

Three things this had to get right, each of which had already caught somebody:

  Every literal is read by brace-walking from its opening `{`, never by a
  greedy regex, because a regex that runs past the close silently absorbs the
  next table.

  `empty.eat_bloodroot` is generated in a loop and then REDEFINED below it.
  Reading the generated map alone reports the wrong set for that herb. This
  reads the live definition and says so.

  `fear`'s real focus condition is commented out beneath a bare `return false`,
  so matching raw text reads a deliberately disabled block as live. Comments go
  before any condition is read.

Two guards of its own. Every literal has a floor, because a reformat that breaks
one of these patterns makes it read zero names, and zero names compared against
zero declared names is a clean run reporting nothing. And every file is read
with line endings normalised, because these are stored in git as LF and
core.autocrlf rewrites them to CRLF on a Windows checkout - raw-byte reads have
failed on Linux CI twice in this repo already.
"""
import argparse
import hashlib
import io
import json
import os
import re
import sys
from collections import Counter

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPTS = os.path.join(REPO, "src", "scripts")

# The core script folder was renamed by #851; accept either so this runs on a
# checkout from before it.
CORE = None
for _cand in ("svo (core)", "svo (install me in module manager)"):
    if os.path.isdir(os.path.join(SCRIPTS, _cand)):
        CORE = _cand


def read(*parts):
    """Source with line endings normalised to LF.

    These files are stored as LF and arrive as CRLF on a Windows checkout. Every
    count below is of names, not bytes, so CRLF would not change a number - but
    the digests written into the baseline are over text, and a baseline recorded
    on Windows must match one measured on Linux CI. The duplicated-resource
    check and the reference-xml hash pin both shipped without this and both
    failed on CI.
    """
    path = os.path.join(SCRIPTS, *parts)
    with io.open(path, "rb") as fh:
        return fh.read().replace(b"\r\n", b"\n").decode("utf-8", "replace")


def digest(*parts):
    h = hashlib.sha256()
    for p in parts:
        h.update(repr(p).encode("utf-8"))
        h.update(b"\0")
    return h.hexdigest()[:16]


# --------------------------------------------------------------------------
# reading the dictionary literal
# --------------------------------------------------------------------------

def entries(src):
    """{entry: {balance: body}} and {entry: whole body}, from the main literal.

    Hand-walks the source rather than matching it, so a string or a comment
    holding a brace cannot move the depth count.
    """
    i = src.index("svo.dict = {")
    j = src.index("{", i)
    depth, k, n = 0, j, len(src)
    cur = bal = bopen = eopen = None
    bals, whole = {}, {}
    while k < n:
        if src.startswith("--[[", k):
            e = src.find("]]", k)
            k = n if e < 0 else e + 2
            continue
        if src.startswith("--", k):
            e = src.find("\n", k)
            k = n if e < 0 else e + 1
            continue
        c = src[k]
        if c in "\"'":
            k += 1
            while k < n and src[k] != c:
                if src[k] == "\\":
                    k += 1
                k += 1
            k += 1
            continue
        if c == "{":
            depth += 1
            if depth == 2:
                m = re.search(r"([A-Za-z_]\w*)\s*=\s*$", src[max(0, k - 80):k])
                cur = m.group(1) if m else None
                eopen = k
            elif depth == 3 and cur:
                m = re.search(r"([A-Za-z_]\w*)\s*=\s*$", src[max(0, k - 60):k])
                bal, bopen = (m.group(1) if m else None), k
        elif c == "}":
            if depth == 3 and cur and bal:
                bals.setdefault(cur, {})[bal] = src[bopen:k + 1]
                bal = None
            elif depth == 2 and cur:
                whole[cur] = src[eopen:k + 1]
                cur = None
            depth -= 1
            if depth == 0:
                break
        k += 1
    return bals, whole


def strip_comments(src):
    """Block and line comments blanked, so a commented-out body cannot be read
    as live code. Newlines are kept so offsets and line counts still line up."""
    out, i, n = list(src), 0, len(src)

    def wipe(a, b):
        for k in range(a, b):
            if out[k] != "\n":
                out[k] = " "

    while i < n:
        if src.startswith("--[[", i):
            e = src.find("]]", i)
            e = n if e < 0 else e + 2
            wipe(i, e)
            i = e
            continue
        if src.startswith("--", i):
            e = src.find("\n", i)
            e = n if e < 0 else e
            wipe(i, e)
            i = e
            continue
        i += 1
    return "".join(out)


def brace_body(src, open_idx):
    depth, k = 0, open_idx
    while k < len(src):
        if src[k] == "{":
            depth += 1
        elif src[k] == "}":
            depth -= 1
            if depth == 0:
                return src[open_idx:k + 1]
        k += 1
    return src[open_idx:]


def names_in(src, pattern):
    """Names inside the table the pattern opens.

    Brace-walks from the match. A greedy regex here runs past the closing brace
    and absorbs whatever table comes next, which is how an earlier pass over
    this same source over-counted.
    """
    m = re.search(pattern, src)
    if not m:
        return []
    return re.findall(r"'(\w+)'", brace_body(src, src.index("{", m.start())))


TRIGGERS = os.path.join(REPO, "src", "triggers")


def tree_trigger_names():
    """Affliction names the tree-cure triggers pass to svo.valid.tree_cured.

    Since the handlers were inverted this is where "svof recognises tree curing
    it" is written, so it is what empty.treecurables has to agree with. The
    other strings the handler accepts - 'burn', 'all burns' and
    '<fracture> cured' - are instructions to touchtree.misc.oncompleted rather
    than affliction names, so they are left out.
    """
    names = set()
    for d, _, fs in os.walk(TRIGGERS):
        for f in fs:
            if not f.endswith(".lua"):
                continue
            with io.open(os.path.join(d, f), "rb") as fh:
                body = fh.read().replace(b"\r\n", b"\n").decode("utf-8", "replace")
            for m in re.finditer(r"svo\.valid\.tree_cured\('([^']+)'\)", body):
                what = m.group(1)
                if what not in ("burn", "all burns") and not what.endswith(" cured"):
                    names.add(what)
    return sorted(names)


# --------------------------------------------------------------------------
# the literals, and the floor under each
# --------------------------------------------------------------------------

# A pattern that stops matching returns no names, and an empty derived side
# compared against an empty literal is a clean run that has checked nothing.
# These are floors, not expected values: well below today's counts, so a real
# edit passes and a broken read does not.
FLOORS = {
    "afflist": 100,
    "treecurables": 60,
    "tree triggers": 60,
    "focuscurables": 12,
}
FOCUS_BLOCK_FLOOR = 12
HERB_MAP_FLOOR = 6
CURES_BY_ITEM_FLOOR = 15
DICT_ENTRY_FLOOR = 200


def collect():
    """Everything read out of src/, or a list of reasons it could not be."""
    if CORE is None:
        return None, ["no core script folder under %s" % SCRIPTS]

    DICT = read("svo (actions dictionary)",
                "Dictionary_of_actions_(affs-defs-misc).lua")
    SIMPLE = read("svo (trigger functions)", "Simple_aff_trigger_functions.lua")
    EMPTY = read("svo (setup, misc, empty, funnies, dor)",
                 "Empty_cure_handling.lua")

    bals, whole = entries(DICT)

    # No diag entries. Diag_trigger_functions.lua used to hold two lists of
    # names that generated one handler each; they are now a single
    # svo.valid.diag(name, ...) that the trigger passes its own name to, so
    # there is no literal left here to compare a derived list against.
    literals = {
        "afflist": names_in(SIMPLE, r"local afflist = \{"),
        "treecurables": names_in(EMPTY, r"empty\.treecurables = \{"),
        "focuscurables": names_in(EMPTY, r"empty\.focuscurables = \{"),
        # Not a literal any more. The tree-cure handlers were inverted into
        # svo.valid.tree_cured(what), so "svof recognises tree curing this" is
        # written in the triggers now - which is where the game's wording lives
        # - and the triggers are what empty.treecurables has to agree with.
        "tree triggers": tree_trigger_names(),
    }

    fails = []
    if len(whole) < DICT_ENTRY_FLOOR:
        fails.append("read only %d dictionary entries, expected at least %d - "
                     "the literal walk is not working"
                     % (len(whole), DICT_ENTRY_FLOOR))
    for name, floor in sorted(FLOORS.items()):
        if len(literals[name]) < floor:
            fails.append("read only %d names from %r, expected at least %d - "
                         "the pattern for it has stopped matching"
                         % (len(literals[name]), name, floor))

    return (bals, whole, literals, EMPTY), fails


# --------------------------------------------------------------------------
# the comparisons
# --------------------------------------------------------------------------

# derived name -> (the field an entry would declare, the literals to compare to)
#
# Only aff_simple is left. The diag, generic and tree-cure handler families
# were each inverted into a single name-taking function, so none of them has a
# literal to compare a derived list against any more - and none wants a field
# on the entry either, since the trigger became the only place the fact is
# written. That supersedes those three parts of the guide's Step 1.
#
# What survives from the tree half is the disagreement between the tree
# triggers and empty.treecurables, which is a different fact and is compared
# further down.
DECLARED = [
    ("aff_simple", "simpletrigger", ["afflist"]),
]

CURE_BALANCES = ("herb", "salve", "smoke", "sip", "purgative")


def compare(data):
    """Returns (differences, lines). Differences are baselineable; lines are
    what a human reads."""
    bals, whole, literals, EMPTY = data
    diffs, out = [], []

    def diff(id_, text, *extra):
        diffs.append({"id": id_, "digest": digest(id_, *extra), "text": text})

    # --- lists that wait on a declared field ---------------------------------
    for derived, field, targets in DECLARED:
        have = sorted(n for n, b in whole.items()
                      if re.search(r"^\s+%s = true" % field, b, re.M))
        label = " + ".join(targets)
        lit = [n for t in targets for n in literals[t]]
        out.append("  %-13s vs %-33s %3d declared, %3d in the list"
                   % (derived, label, len(have), len(set(lit))))

        # A name in two of these loops is defined twice in one namespace and
        # the later definition wins, so the earlier one is dead code. Surface
        # it rather than quietly deduplicating.
        if len(targets) > 1:
            for i, a in enumerate(targets):
                for b_ in targets[i + 1:]:
                    for n in sorted(set(literals[a]) & set(literals[b_])):
                        out.append("  %-13s    (%s is in both %r and %r; the "
                                   "later handler wins)" % ("", n, a, b_))
                        diff("shadowed|%s|%s" % (derived, n),
                             "%s: %s is in both %s and %s, so the first "
                             "handler is overwritten" % (derived, n, a, b_))

        for name, count in sorted(Counter(lit).items()):
            if count > 1 and not (len(targets) > 1 and
                                  sum(1 for t in targets
                                      if name in literals[t]) > 1):
                out.append("  %-13s    (%d tokens: %s listed %d times)"
                           % ("", len(lit), name, count))
                diff("dupe|%s|%s" % (label, name),
                     "%s lists %s %d times" % (label, name, count), count)

        if have:
            for n in sorted(set(have) - set(lit)):
                out.append("                   only declared: %s" % n)
                diff("declared|%s|only_declared|%s" % (derived, n),
                     "%s: %s declares %s = true and is not in %s"
                     % (derived, n, field, label))
            for n in sorted(set(lit) - set(have)):
                out.append("                   only in list:  %s" % n)
                diff("declared|%s|only_in_list|%s" % (derived, n),
                     "%s: %s is in %s and does not declare %s = true"
                     % (derived, n, label, field))

    # --- two places that hold the same fact about tree, and disagree ---------
    # "tree can cure this" is written twice: in the triggers, which carry the
    # game's wording for each cure, and in empty.treecurables, which is what
    # gets cleared when a tree touch cures nothing. The second cannot be
    # derived from the first - a tree that cured nothing tells you about
    # afflictions you did NOT have - so both are real, and their disagreement
    # is a list of open questions rather than a bug to fix mechanically.
    t, tc = set(literals["tree triggers"]), set(literals["treecurables"])
    out.append("")
    out.append("  %-13s vs %-33s %3d and %3d, disagreeing in %d names"
               % ("tree triggers", "treecurables", len(t), len(tc), len(t ^ tc)))
    if t - tc:
        out.append("                   only a trigger:       %s"
                   % ", ".join(sorted(t - tc)))
    if tc - t:
        out.append("                   only in treecurables: %s"
                   % ", ".join(sorted(tc - t)))
    for n in sorted(t - tc):
        diff("tree|only_tree_list|%s" % n,
             "tree: %s has a tree-cure trigger and is not in treecurables" % n)
    for n in sorted(tc - t):
        diff("tree|only_treecurables|%s" % n,
             "tree: %s is in treecurables and has no tree-cure trigger" % n)

    # --- focus IS derivable from shape today ---------------------------------
    focus_blocks = {n for n, b in bals.items() if "focus" in b}
    fc = set(literals["focuscurables"])
    out.append("")
    out.append("  %-13s vs %-33s %3d blocks,   %3d in the list"
               % ("aff_focus", "focuscurables", len(focus_blocks), len(fc)))
    if len(focus_blocks) < FOCUS_BLOCK_FLOOR:
        diff("floor|focus_blocks",
             "read only %d focus blocks, expected at least %d"
             % (len(focus_blocks), FOCUS_BLOCK_FLOOR), len(focus_blocks))

    for n in sorted(focus_blocks - fc):
        # Comments out first: fear's real condition sits commented out beneath
        # a bare `return false`, so raw text reads a disabled block as live.
        cond = strip_comments(bals[n]["focus"])
        m = re.search(r"isadvisable = function\(\)(.*?)\bend\b", cond, re.S)
        disabled = bool(m and m.group(1).split() == ["return", "false"])
        why = ("condition disabled, correct to exclude" if disabled
               else "condition is LIVE, missing from the list")
        out.append("                   only a block: %-12s %s" % (n, why))
        # The digest carries live-or-disabled, so a block flipping state fails
        # the gate rather than passing on a name that has not changed.
        diff("focus|block_only|%s" % n,
             "focus: %s has a focus block and is not in focuscurables (%s)"
             % (n, "disabled" if disabled else "LIVE"),
             "disabled" if disabled else "live")
    for n in sorted(fc - focus_blocks):
        out.append("                   only in list: %s" % n)
        diff("focus|list_only|%s" % n,
             "focus: %s is in focuscurables and has no focus block" % n)

    # --- cures_by_item IS derivable from shape today -------------------------
    by_item = {}
    for n, b in bals.items():
        for bal in CURE_BALANCES:
            if bal not in b:
                continue
            m = re.search(r"(eatcure|applycure|smokecure|sipcure) = \{([^}]*)\}",
                          b[bal])
            if m:
                for item in re.findall(r"'(\w+)'", m.group(2)):
                    by_item.setdefault(item, set()).add(n)

    if len(by_item) < CURES_BY_ITEM_FLOOR:
        diff("floor|cures_by_item",
             "derived cures for only %d items, expected at least %d"
             % (len(by_item), CURES_BY_ITEM_FLOOR), len(by_item))

    gen = brace_body(EMPTY, EMPTY.index(
        "{", EMPTY.index("for herbname, herbaffs in pairs(")))
    empty_map = {m.group(1): set(re.findall(r"'(\w+)'", m.group(2)))
                 for m in re.finditer(r"(\w+) = \{([^}]*)\}", gen)}

    # A later `empty.eat_<herb> = function()` SHADOWS the generated one, so the
    # generated map is the wrong answer for any herb that is redefined. Today
    # that is bloodroot, and ginger exists only as a redefinition.
    out.append("")
    shadowed = {}
    for m in re.finditer(r"^empty\.eat_(\w+) = function", EMPTY, re.M):
        herb = m.group(1)
        end = EMPTY.index("\nend", m.start())
        shadowed[herb] = set(re.findall(r"'(\w+)'", EMPTY[m.start():end]))
    for herb in sorted(shadowed):
        affs = shadowed[herb]
        if herb in empty_map:
            out.append("  note: empty.eat_%s is redefined after the loop; using "
                       "the live one\n        generated %s\n        live      %s"
                       % (herb, ", ".join(sorted(empty_map[herb])),
                          ", ".join(sorted(affs))))
            diff("shadow|%s" % herb,
                 "empty.eat_%s is generated and then redefined; live set is %s"
                 % (herb, ", ".join(sorted(affs))),
                 sorted(affs), sorted(empty_map[herb]))
        empty_map[herb] = affs

    if len(empty_map) < HERB_MAP_FLOOR:
        diff("floor|empty_map",
             "read only %d herbs from the empty map, expected at least %d"
             % (len(empty_map), HERB_MAP_FLOOR), len(empty_map))

    out.append("")
    for herb in sorted(empty_map):
        d, l = by_item.get(herb, set()), empty_map[herb]
        same = d == l
        out.append("  cures_by_item.%-11s vs %-14s %3d %s %3d %s"
                   % (herb, "empty map", len(d), "==" if same else "!=", len(l),
                      "OK" if same else ""))
        if same:
            continue
        if d - l:
            out.append("                   only in the dictionary: %s"
                       % ", ".join(sorted(d - l)))
        if l - d:
            out.append("                   only in the empty map:  %s"
                       % ", ".join(sorted(l - d)))
        for n in sorted(d - l):
            diff("cures|%s|only_dictionary|%s" % (herb, n),
                 "cures: the dictionary says %s cures %s, empty.eat_%s does not "
                 "clear it" % (herb, n, herb))
        for n in sorted(l - d):
            diff("cures|%s|only_empty_map|%s" % (herb, n),
                 "cures: empty.eat_%s clears %s, no dictionary entry names %s "
                 "as its cure" % (herb, n, herb))

    return diffs, out


# --------------------------------------------------------------------------

NOTE = ("Differences between what svo.dict can derive and the literals holding "
        "the same information, that are deliberate. check_derived_lists.py "
        "--baseline fails on anything not listed here, and on any of these "
        "whose nature has changed. Regenerate only when you meant to change "
        "one, in the same commit that causes it.")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--baseline", help="fail only on differences not listed here")
    ap.add_argument("--write-baseline", help="record the current differences")
    a = ap.parse_args()

    data, fails = collect()
    for f in fails:
        print("[FAIL] " + f)
    if fails:
        print("\nDERIVED LISTS FAILED - the source could not be read as expected")
        return 1

    diffs, lines = compare(data)

    print("=" * 72)
    print("Derived from svo.dict, against the literals that hold it today")
    print("=" * 72)
    print()
    for line in lines:
        print(line)
    print()

    if a.write_baseline:
        payload = {
            "note": NOTE,
            "accepted": sorted(diffs, key=lambda c: c["id"]),
        }
        with io.open(a.write_baseline, "w", encoding="utf-8", newline="\n") as fh:
            json.dump(payload, fh, indent=2)
            fh.write("\n")
        print("wrote %s: %d accepted differences"
              % (a.write_baseline, len(diffs)))
        return 0

    if not a.baseline:
        print("=" * 72)
        print("%d difference(s). Run with --baseline to fail only on the ones "
              "that are not expected." % len(diffs))
        print("=" * 72)
        return 1 if diffs else 0

    with io.open(a.baseline, encoding="utf-8") as fh:
        base = json.load(fh)
    accepted = {e["id"]: e["digest"] for e in base["accepted"]}

    seen, new, changed = set(), [], []
    for c in diffs:
        seen.add(c["id"])
        if c["id"] not in accepted:
            new.append(c)
        elif accepted[c["id"]] != c["digest"]:
            changed.append(c)
    gone = sorted(set(accepted) - seen)

    for c in new:
        print("[FAIL] unexpected difference: " + c["text"])
    for c in changed:
        print("[FAIL] a known difference changed: " + c["text"])
    for g in gone:
        print("[FAIL] baselined difference no longer present: " + g)
        print("           the two sides now agree here. If that was intended, "
              "regenerate the baseline.")

    bad = len(new) + len(changed) + len(gone)
    print()
    if bad == 0:
        print("DERIVED LISTS OK - every difference matches the baseline")
        print("  %d expected differences" % len(accepted))
        return 0
    print("DERIVED LISTS FAILED - %d problem(s)" % bad)
    return 1


if __name__ == "__main__":
    sys.exit(main())
