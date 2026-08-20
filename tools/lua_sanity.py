#!/usr/bin/env python3
"""
lua_sanity.py -- crude structural check on Lua files.

This is NOT a parser and cannot prove a file is valid Lua. It strips comments
and string literals, then checks that block keywords balance against `end` and
that brackets pair up. It catches the mistakes that matter here - a missing
`end`, an unclosed paren - and nothing subtler.

Real validation is validate-syntax.lua, which needs a Lua interpreter.

    python tools/lua_sanity.py [files...]        (defaults to all of src/)
"""
import re, sys, glob, os

LONG_COMMENT = re.compile(r"--\[\[.*?\]\]", re.S)
LINE_COMMENT = re.compile(r"--[^\n]*")
LONG_STRING = re.compile(r"\[\[.*?\]\]", re.S)
DQ = re.compile(r'"(?:\\.|[^"\\])*"')
SQ = re.compile(r"'(?:\\.|[^'\\])*'")

OPENERS = ("function", "if", "for", "while")


def strip(text):
    text = LONG_COMMENT.sub("", text)
    text = LINE_COMMENT.sub("", text)
    text = LONG_STRING.sub('""', text)
    text = DQ.sub('""', text)
    text = SQ.sub("''", text)
    return text


def check(path):
    raw = open(path, encoding="utf-8", errors="replace").read()
    s = strip(raw)
    # every function/if/for/while opens a block closed by `end`;
    # `do` only opens one when it is not the `do` of a for/while
    blocks = sum(len(re.findall(r"\b%s\b" % k, s)) for k in OPENERS)
    bare_do = len(re.findall(r"\bdo\b", s)) - len(re.findall(r"\b(?:for|while)\b.*?\bdo\b", s, re.S))
    blocks += max(0, bare_do)
    ends = len(re.findall(r"\bend\b", s))
    problems = []
    if blocks != ends:
        problems.append("block/end off by %+d (blocks=%d ends=%d)" % (blocks - ends, blocks, ends))
    for open_c, close_c, label in (("(", ")", "parens"), ("{", "}", "braces"), ("[", "]", "brackets")):
        if s.count(open_c) != s.count(close_c):
            problems.append("%s unbalanced (%d vs %d)" % (label, s.count(open_c), s.count(close_c)))
    return problems


def main():
    files = sys.argv[1:] or sorted(glob.glob("src/**/*.lua", recursive=True))
    bad = 0
    for f in files:
        p = check(f)
        if p:
            bad += 1
            print("  %-60s %s" % (os.path.basename(f)[:60], "; ".join(p)))
    print("\nchecked %d file(s), %d with structural problems" % (len(files), bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
