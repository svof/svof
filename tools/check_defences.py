#!/usr/bin/env python3
"""
check_defences.py -- fail on a defence record whose game lines cannot work.

Every defence svof recognises is a record in Defences.lua:

    defs_data:set('mass', { type = 'general',
      def  = "You are extremely heavy and difficult to move.",
      offr = {[[^You are pulled out of the room by \\w+ and \\w+ whip\\!$]]},
      off  = {"You feel your density return to normal."}})

At systemstart svof turns each line into a temp trigger: on, off, def,
on_only, on_free and off_free into exact-match triggers, onr, offr and defr
into regex triggers, offs into substring triggers. Three ways to write one
wrong are silent, and all three are in the 2018 module xmls:

  * A regex in an exact-match key. The trigger waits for a line that really
    starts with "^", which the game never sends. Six Shikudo forms and
    spinning have one.
  * A value with no key. `off = "a", "b"` makes "b" the table's [1], which
    nothing reads. rest has one.
  * A regex that starts with a stray quote, `[["^You ...` for `[[^You ...`.
    It compiles, and it never matches. croonmirror has one.

This reads every record, whatever skillset gates it, and checks every line
in it for those, plus two more: a key written twice in one record (Lua
keeps the last, silently), and a regex Python's re cannot compile.

What it cannot see is whether a line is the game's real wording; that needs
the game. Records and entries are joined by name at runtime and gated
separately by class, so whether every entry has a record is checked by
tools/test_defences.lua, which runs the real code for every class.

The findings svof has today are recorded below in KNOWN, so a new one fails
at once, and fixing one fails until it is removed from KNOWN.

    python tools/check_defences.py
"""
import io
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
DEFENCES = os.path.join(REPO, "src", "scripts", "svo (alias and defence functions)", "Defences.lua")

EXACT_KEYS = {"on", "off", "def", "on_only", "on_free", "off_free"}
REGEX_KEYS = {"onr", "offr", "defr"}
SUBSTRING_KEYS = {"offs"}
LINE_KEYS = EXACT_KEYS | REGEX_KEYS | SUBSTRING_KEYS

# What makes a string a regex rather than a line of game text. Game text has
# full stops, brackets and question marks; it has no anchors and no escapes.
REGEX_SIGNS = re.compile(r"^\^|(?<!\\)\$$|\\[wdsSWDb.()\[\]!?+*]|\.[+*]|\(\?:")

# The pre-existing findings, by (record, key, kind). Remove a line in the
# commit that fixes it.
KNOWN = {
    ("tykonos", "off", "regex in exact"),   # defect 3: the six Shikudo forms
    ("willow", "off", "regex in exact"),
    ("rain", "off", "regex in exact"),
    ("oak", "off", "regex in exact"),
    ("gaital", "off", "regex in exact"),
    ("maelstrom", "off", "regex in exact"),
    # defect 21: "Susurrations already surround you. " ends in a space, so
    # unless the game sends one the exact match never fires
    ("susurrating", "on", "edge whitespace"),
}

# Below this, the reading is broken rather than the source clean.
RECORD_FLOOR = 350
LINE_FLOOR = 1200

KEYWORD_OPEN = {"function", "if", "do"}


def read(path):
    with io.open(path, "rb") as fh:
        return fh.read().replace(b"\r\n", b"\n").decode("utf-8", "replace")


def long_bracket(src, i):
    """Length of the level-n opening long bracket at src[i], or None."""
    m = re.match(r"\[(=*)\[", src[i:])
    return m.group(1) if m else None


def tokens(src, start):
    """Yields (kind, text, pos) from src[start] on: 'str' (decoded), 'name',
    'sym' and 'num'. Skips comments and whitespace."""
    i, n = start, len(src)
    while i < n:
        c = src[i]
        if c.isspace():
            i += 1
        elif src.startswith("--", i):
            eq = long_bracket(src, i + 2)
            if eq is not None:
                end = src.find("]" + eq + "]", i)
                i = n if end < 0 else end + len(eq) + 2
            else:
                end = src.find("\n", i)
                i = n if end < 0 else end + 1
        elif c in "'\"":
            j, out = i + 1, []
            while j < n and src[j] != c:
                if src[j] == "\\" and j + 1 < n:
                    nxt = src[j + 1]
                    out.append({"n": "\n", "t": "\t", "\\": "\\", "'": "'", '"': '"'}.get(nxt, nxt))
                    j += 2
                else:
                    out.append(src[j])
                    j += 1
            yield ("str", "".join(out), i)
            i = j + 1
        elif c == "[" and long_bracket(src, i) is not None:
            eq = long_bracket(src, i)
            body_start = i + len(eq) + 2
            end = src.find("]" + eq + "]", body_start)
            yield ("str", src[body_start:end], i)
            i = end + len(eq) + 2
        elif c.isalpha() or c == "_":
            m = re.match(r"[A-Za-z_]\w*", src[i:])
            yield ("name", m.group(0), i)
            i += len(m.group(0))
        elif c.isdigit():
            m = re.match(r"[\d.xXa-fA-F]+", src[i:])
            yield ("num", m.group(0), i)
            i += len(m.group(0))
        else:
            two = src[i:i + 2]
            if two in ("==", "~=", "<=", ">=", ".."):
                yield ("sym", two, i)
                i += 2
            else:
                yield ("sym", c, i)
                i += 1


def record_items(src, brace):
    """The top-level items of the table opening at src[brace]: a list of
    (key or None, [value tokens]). A key is a name, or "[<expr>]" as written."""
    items, current, key = [], [], None
    braces = parens = blocks = 0
    toks = tokens(src, brace)
    next(toks)  # the opening brace
    for kind, text, pos in toks:
        top = braces == 0 and parens == 0 and blocks == 0
        if top and kind == "sym" and text in ",;":
            items.append((key, current))
            current, key = [], None
            continue
        if top and kind == "sym" and text == "}":
            if current or key:
                items.append((key, current))
            return items
        if top and kind == "sym" and text == "=" and key is None and len(current) == 1 and current[0][0] == "name":
            key, current = current[0][1], []
            continue
        if kind == "sym":
            if text == "{":
                braces += 1
            elif text == "}":
                braces -= 1
            elif text in "([":
                parens += 1
            elif text in ")]":
                parens -= 1
        elif kind == "name":
            if text in KEYWORD_OPEN or text == "repeat":
                blocks += 1
            elif text in ("end", "until"):
                blocks -= 1
        current.append((kind, text, pos))
    raise ValueError("unterminated table at %d" % brace)


def strings_of(value):
    """The string literals a value is made of: one string, or a table of them.
    None if the value is anything else."""
    if len(value) == 1 and value[0][0] == "str":
        return [value[0][1]]
    if value and value[0] == ("sym", "{", value[0][2]) and value[-1][:2] == ("sym", "}"):
        inner = [t for t in value[1:-1] if not (t[0] == "sym" and t[1] in ",;")]
        if all(t[0] == "str" for t in inner):
            return [t[1] for t in inner]
    return None


def records(src):
    """(name, position of the table's brace, line) for every
    defs_data:set('<name>', {...}) in code, not in a comment."""
    shape = [("name", "defs_data"), ("sym", ":"), ("name", "set"), ("sym", "("), ("str", None),
             ("sym", ","), ("sym", "{")]
    window = []
    for tok in tokens(src, 0):
        window = (window + [tok])[-len(shape):]
        if len(window) == len(shape) and all(
                w[0] == k and (v is None or w[1] == v) for w, (k, v) in zip(window, shape)):
            yield window[4][1], window[6][2], src.count("\n", 0, window[0][2]) + 1


def check(src):
    """(records read, lines read, findings as {(record, key, kind): [where]})"""
    findings = {}
    nrecords = nlines = 0

    def found(name, key, kind, line, text):
        findings.setdefault((name, key, kind), []).append("Defences.lua:%d %r" % (line, text[:70]))

    for name, brace, line in records(src):
        nrecords += 1
        seen = set()
        for key, value in record_items(src, brace):
            if key is None:
                strs = strings_of(value)
                found(name, "[1]", "positional", line, strs[0] if strs else "?")
                continue
            if key in seen:
                found(name, key, "key twice", line, key)
            seen.add(key)
            if key not in LINE_KEYS:
                continue
            strs = strings_of(value)
            if strs is None:
                found(name, key, "not a line or a list of lines", line, key)
                continue
            for s in strs:
                nlines += 1
                if key in EXACT_KEYS or key in SUBSTRING_KEYS:
                    if REGEX_SIGNS.search(s):
                        found(name, key, "regex in exact" if key in EXACT_KEYS else "regex in substring", line, s)
                    if s != s.strip():
                        found(name, key, "edge whitespace", line, s)
                else:
                    if s[:1] in "'\"":
                        found(name, key, "stray quote", line, s)
                    try:
                        re.compile(s)
                    except re.error as e:
                        found(name, key, "does not compile (%s)" % e, line, s)
    return nrecords, nlines, findings


def main():
    nrecords, nlines, findings = check(read(DEFENCES))
    problems = []
    if nrecords < RECORD_FLOOR:
        problems.append("read only %d records, expected at least %d" % (nrecords, RECORD_FLOOR))
    if nlines < LINE_FLOOR:
        problems.append("read only %d lines, expected at least %d" % (nlines, LINE_FLOOR))

    print("%d defence records read from Defences.lua, %d game lines checked" % (nrecords, nlines))
    new = sorted(k for k in findings if k not in KNOWN)
    fixed = sorted(k for k in KNOWN if k not in findings)
    for k in new:
        print("[FAIL] %s.%s: %s" % k)
        for where in findings[k]:
            print("           " + where)
    for k in fixed:
        print("[FAIL] %s.%s (%s) is fixed; remove it from KNOWN in this script" % k)
    for p in problems:
        print("[FAIL] " + p + " - this check is reading less than it should")
    bad = len(new) + len(fixed) + len(problems)
    if bad:
        print("\nDEFENCE RECORDS FAILED - %d problem(s)" % bad)
        return 1
    print("no new problem in the defence records (%d known pre-existing ignored)" % len(KNOWN))
    return 0


if __name__ == "__main__":
    sys.exit(main())
