#!/usr/bin/env python3
"""
check_lua_syntax.py -- parse every piece of Lua in the project.

Covers both places code lives: the .lua files under src/, and the scripts
inlined into the json (items whose name cannot become a filename, or which
share one with a sibling).

Uses `luac -p`, which parses without executing. Mudlet runs Lua 5.1, so this
checks the grammar of a newer interpreter - close enough to catch real syntax
errors, but a 5.1-only construct would not be flagged. Pass --luac to point at
a 5.1 luac if one is available.

    python tools/check_lua_syntax.py
    python tools/check_lua_syntax.py --luac "C:/lua51/luac.exe"
"""
import argparse, glob, json, os, shutil, subprocess, sys, tempfile

# Mudlet runs Lua 5.1, so that is the version to validate against. Checking with
# a newer luac reports these, none of which are errors under 5.1:
#
#   "<name> expected near 'goto'"   goto became a keyword in 5.2; it is an
#                                   ordinary identifier in 5.1
#   "invalid escape sequence"       5.1 accepts unknown escapes such as \w and
#                                   \/ inside double-quoted strings; 5.2+ do not
#   "assign to const variable"      5.4+ semantics, seen in vendored Penlight
#
# All of these exist in code that ships and works, so a newer luac is useful for
# catching genuine mistakes but will always report the four above.
def find_luac():
    for name in ("luac5.1", "luac51", "luac"):
        p = shutil.which(name)
        if p:
            return p
    for p in (r"C:\lua\luac55.exe", r"C:\lua\luac.exe"):
        if os.path.exists(p):
            return p
    return None


def parse_check(luac, path):
    r = subprocess.run([luac, "-p", path], capture_output=True, text=True)
    if r.returncode == 0:
        return None
    msg = (r.stderr or r.stdout).strip().splitlines()
    return msg[0] if msg else "unknown parse error"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--luac", default=None)
    a = ap.parse_args()

    luac = a.luac or find_luac()
    if not luac or not (os.path.exists(luac) or shutil.which(luac)):
        sys.exit("no luac found; pass --luac /path/to/luac")
    a.luac = luac
    ver = subprocess.run([luac, "-v"], capture_output=True, text=True)
    print("using:", luac, "|", (ver.stdout or ver.stderr).strip().splitlines()[0] if (ver.stdout or ver.stderr) else "?")

    failures = []

    # 1. every .lua file
    lua_files = sorted(glob.glob("src/**/*.lua", recursive=True))
    for f in lua_files:
        err = parse_check(a.luac, f)
        if err:
            failures.append((f, err))

    # 2. every script inlined into json
    inlined = 0
    tmpdir = tempfile.mkdtemp()
    for jf in sorted(glob.glob("src/**/*.json", recursive=True)):
        stack = list(json.load(open(jf, encoding="utf-8")))
        while stack:
            it = stack.pop()
            stack.extend(it.get("children") or [])
            script = it.get("script")
            if not script:
                continue
            inlined += 1
            tmp = os.path.join(tmpdir, "inline.lua")
            with open(tmp, "w", encoding="utf-8", newline="\n") as fh:
                fh.write(script)
            err = parse_check(a.luac, tmp)
            if err:
                failures.append((f"{jf} :: {it.get('name')}", err.replace(tmp, "<inline>")))

    print(f"lua files checked   : {len(lua_files)}")
    print(f"inlined scripts     : {inlined}")
    print(f"total chunks parsed : {len(lua_files) + inlined}")
    print()
    if failures:
        print(f"SYNTAX ERRORS ({len(failures)}):")
        for where, err in failures:
            print(f"  {where}")
            print(f"      {err}")
        return 1
    print("all chunks parse cleanly")
    return 0


if __name__ == "__main__":
    sys.exit(main())
