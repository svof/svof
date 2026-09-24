#!/usr/bin/env python3
"""
check_dict_fields.py -- a dictionary entry's top-level keys, checked both ways.

`svo.dict_setup()` decides what a top-level key on an entry means by its TYPE,
not by its name:

    for action, balance in pairs(svo.dict) do
      for balancename, balancedata in pairs(balance) do
        if type(balancedata) == 'table' then
          if not balancedata.name then balancedata.name = ... end
          ...
          balancedata.spriority  = balancedata.spriority or 0
          balancedata.aspriority = balancedata.aspriority or 0

So a table is a balance and a scalar is a plain field, and each has its own way
of going wrong. Both are silent.

A SCALAR NAMED LIKE A BALANCE breaks the curing loop. `Curing_skeleton.lua:332`
reads

    ... and j.p.focus and ... and j.p.focus.isadvisable() and ...

where `j.p` is the entry, so `j.p.focus` means "does this entry have a focus
balance". Put `focus = true` on an entry with no focus block and that test
passes, the next term indexes a boolean, and the focus curing pass raises. This
is the one way the single-source work can break something while nothing yet
reads the field it added, which is why this check exists before the fields do.

A TABLE NOT NAMED LIKE A BALANCE becomes a phantom one. dict_setup stamps it
with a name, a balance and an action_name, and unless it is one of the five
names excluded from priorities it is handed a spriority and an aspriority and
joins the priority allocation. A `meta = {}` added for bookkeeping turns into
something the curing loop can be asked to prioritise. This has already bitten:
`svo.dict.lovers.map` is emptied by hand at the end of dict_setup, under the
comment "we don't want stuff in svo.dict.lovers.map!".

Both lists below are pinned rather than discovered, so adding either kind of
key fails here until somebody writes it down. That is the point: a new balance
is a real change to how curing works and a new flat field is not, and the two
must not be able to arrive by accident.

    python tools/check_dict_fields.py
"""
import io
import os
import re
import sys
from collections import defaultdict

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DICT_PATH = os.path.join(
    REPO, "src", "scripts", "svo (actions dictionary)",
    "Dictionary_of_actions_(affs-defs-misc).lua")

# Table-valued top-level keys. Each one is a balance: dict_setup gives it a
# name and, unless excluded below, a place in the priority lists.
#
# The last six are not cure balances and are worth knowing before you read a
# surprising one as a mistake:
#   map, tempmap   lovers only, and dict_setup empties `lovers.map` by hand
#   boosted        paradox only
#   weakened       paradox only
#   happened       givewarning, gotbalance, gothit, stolebalance
#   moss           healhealth, healmana
BALANCES = {
    "aff", "gone", "waitingfor", "herb", "salve", "physical", "misc", "focus",
    "smoke", "sip", "purgative", "happened", "moss", "map", "tempmap",
    "boosted", "weakened",
}

# Balances dict_setup deliberately keeps out of the priority lists, because a
# priority for them makes no sense. Listed for the reader; nothing below
# branches on it.
NO_PRIORITY = {"aff", "gone", "waitingfor", "boosted", "weakened"}

# Scalar top-level keys. These fall straight through dict_setup, which is why
# the single-source work puts its new facts here rather than in a nested table.
FIELDS = {
    "gamename":           "what serverside calls this",
    "name":               "the entry's own name, usually filled in by dict_setup",
    "count":              "how many of this affliction are stacked",
    "description":        "free text, shown by vaff and friends",
    "onremoved":          "runs after the affliction leaves svo.affs",
    "onadded":            "runs after it is added",
    "onservereignore":    "returns true if serverside should ignore this",
    "reckhp":             "unknownany and unknownmental",
    "reckmana":           "unknownany and unknownmental",
    "blocked":            "rebounding and speed",
    "blocked_herb":       "paradox",
    "saw_with_checkable": "relapsing",
    "rewieldables":       "rewield",
    "templifevision":     "checkstun",
    "tempactions":        "checkstun",
    "time":               "checkstun",
    "applying":           "sileris",
}

# svo.dict entries that are name maps rather than actions. Their top-level keys
# are game and svof affliction names, not fields, so reading them as fields
# reports a few hundred false positives.
NAME_MAPS = {"sstosvoa", "sstosvod", "svotossa", "svotossd"}

# If the literal walk stops working, every set below comes back empty and an
# empty set collides with nothing. Floors, not expected values.
ENTRY_FLOOR = 200
BALANCE_FLOOR = 10
FIELD_FLOOR = 5


def read(path):
    """Source with line endings normalised, so a Windows checkout and the Linux
    runner read the same text. Two checks in this repo have already shipped
    without this and failed on CI."""
    with io.open(path, "rb") as fh:
        return fh.read().replace(b"\r\n", b"\n").decode("utf-8", "replace")


def entries(src):
    """{entry: {key: body}} for table-valued keys, and {entry: whole body}.

    Hand-walks the source so a brace inside a string or a comment cannot move
    the depth count.
    """
    i = src.index("svo.dict = {")
    j = src.index("{", i)
    depth, k, n = 0, j, len(src)
    cur = bal = bopen = eopen = None
    tables, whole = {}, {}
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
                tables.setdefault(cur, {})[bal] = src[bopen:k + 1]
                bal = None
            elif depth == 2 and cur:
                whole[cur] = src[eopen:k + 1]
                cur = None
            depth -= 1
            if depth == 0:
                break
        k += 1
    return tables, whole


def top_level_keys(body):
    """{key: is_table} for the entry's own keys, nested ones excluded.

    Everything below the entry's own depth is dropped, but a table VALUE leaves
    a sentinel behind so `herb = {` can be told apart from `count = 3`.

    Reading the flattened text without that marker makes every balance look
    like a scalar, and filtering those back out by name then hides the one case
    this check exists for: a scalar NAMED like a balance. That is exactly how
    the first version of this passed a `focus = true` sabotage.

    A `{` inside a function body leaves no sentinel that matters, because the
    sentinel only counts when it follows the `=` directly.
    """
    inner, out, depth = body[1:-1], [], 0
    for ch in inner:
        if ch == "{":
            depth += 1
            if depth == 1:
                out.append("\0")
        elif ch == "}":
            depth -= 1
        elif depth == 0:
            out.append(ch)
    return {m.group(1): bool(m.group(2)) for m in
            re.finditer(r"(?:^|[\n,])\s*([A-Za-z_]\w*)\s*=[ \t]*(\0?)",
                        "".join(out))}


def main():
    if not os.path.exists(DICT_PATH):
        print("[FAIL] %s does not exist" % DICT_PATH)
        return 1

    tables, whole = entries(read(DICT_PATH))

    problems = []
    if len(whole) < ENTRY_FLOOR:
        problems.append("read only %d dictionary entries, expected at least %d "
                        "- the literal walk is not working"
                        % (len(whole), ENTRY_FLOOR))

    used_balances = defaultdict(list)
    for name, keys in tables.items():
        for k in keys:
            used_balances[k].append(name)

    used_fields = defaultdict(list)
    for name, body in whole.items():
        if name in NAME_MAPS:
            continue
        for k, is_table in top_level_keys(body).items():
            if not is_table:
                used_fields[k].append(name)

    if len(used_balances) < BALANCE_FLOOR:
        problems.append("found only %d balances, expected at least %d - this "
                        "check is reading less than it should"
                        % (len(used_balances), BALANCE_FLOOR))
    if len(used_fields) < FIELD_FLOOR:
        problems.append("found only %d flat fields, expected at least %d - "
                        "this check is reading less than it should"
                        % (len(used_fields), FIELD_FLOOR))

    # 1. a scalar named like a balance: the curing loop indexes a boolean
    for field in sorted(set(used_fields) & BALANCES):
        problems.append(
            "%s is a balance name, and these entries use it as a flat field: "
            "%s. Curing_skeleton.lua:332 reads `j.p.%s and ... "
            "j.p.%s.isadvisable()`, so this makes the guard pass and the next "
            "term index a non-table. Rename the field."
            % (field, ", ".join(sorted(used_fields[field])[:6]), field, field))

    # 2. a table not named like a balance: dict_setup invents one
    for bal in sorted(set(used_balances) - BALANCES):
        problems.append(
            "%r is a table-valued key on %s and is not a known balance. "
            "dict_setup stamps every table with a name and a priority, so this "
            "becomes a balance the curing loop can be asked to prioritise. Add "
            "it to BALANCES here if it is meant to be one."
            % (bal, ", ".join(sorted(used_balances[bal])[:6])))

    # 3. a flat field nobody has written down
    for field in sorted(set(used_fields) - set(FIELDS) - BALANCES):
        problems.append(
            "%r is a flat field on %s and is not listed in FIELDS. Add it with "
            "a note on what it does, so the next person adding one has to look "
            "at this list first."
            % (field, ", ".join(sorted(used_fields[field])[:6])))

    # 4. a name written down that nothing uses any more
    for field in sorted(set(FIELDS) - set(used_fields)):
        problems.append(
            "%r is listed in FIELDS and no entry uses it. Remove it, or say "
            "why it is kept." % field)
    for bal in sorted(BALANCES - set(used_balances)):
        problems.append(
            "%r is listed in BALANCES and no entry uses it. Remove it, or say "
            "why it is kept." % bal)

    print("%d entries, %d balances, %d flat fields"
          % (len(whole), len(used_balances), len(used_fields)))
    print("  balances: %s" % ", ".join(sorted(used_balances)))
    print("  fields:   %s" % ", ".join(sorted(used_fields)))
    print()

    for p in problems:
        print("[FAIL] " + p)
    if problems:
        print("\nDICT FIELDS FAILED - %d problem(s)" % len(problems))
        return 1
    print("DICT FIELDS OK - no flat field shadows a balance, and every "
          "top-level key is accounted for")
    return 0


if __name__ == "__main__":
    sys.exit(main())
