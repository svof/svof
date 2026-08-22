#!/usr/bin/env python3
"""
check_lua_syntax.py -- parse every piece of Lua in the project.

Covers both places code lives: the .lua files under src/, and the scripts
inlined into the json (items whose name cannot become a filename, or which
share one with a sibling).

Uses `luac -p`, which parses without executing.

**Mudlet runs Lua 5.1, so only a 5.1 luac gives a trustworthy answer.** A
newer one reports constructs that are perfectly legal here (see below), and
the danger is not the noise - it is that someone believes it and "fixes"
working code to satisfy a parser Mudlet never runs. So this reports the
version it used, says loudly when that is not 5.1, and takes --strict-version
to refuse outright, which is what CI does.

luac is found in this order: --luac, then $LUAC, then PATH, preferring a 5.1
binary over any other.

    python tools/check_lua_syntax.py
    python tools/check_lua_syntax.py --luac "C:/lua51/luac.exe"
    python tools/check_lua_syntax.py --strict-version     # CI
"""
import argparse, glob, json, os, re, shutil, subprocess, sys, tempfile

# Derive the tree from this file, the way the sibling tools do. These globs
# used to be CWD-relative, so running the check from anywhere but the repo root
# matched zero files and still printed "all chunks parse cleanly", exit 0.
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(REPO, "src")

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
WANTED = "5.1"

# In preference order: an explicitly-5.1 binary, then a plain one, then the
# newer versions. No absolute paths - whatever is on PATH is what this machine
# has, and a path baked in here would only ever be right on one machine.
LUAC_NAMES = ("luac5.1", "luac51", "luac",
              "luac5.4", "luac54", "luac5.3", "luac53",
              "luac5.2", "luac52", "luac5.5", "luac55")


def find_luac():
    env = os.environ.get("LUAC")
    if env and (os.path.exists(env) or shutil.which(env)):
        return env
    for name in LUAC_NAMES:
        p = shutil.which(name)
        if p:
            return p
    return None


def luac_version(luac):
    """The x.y this luac speaks, or None if it will not say."""
    try:
        r = subprocess.run([luac, "-v"], capture_output=True, text=True)
    except OSError:
        return None
    m = re.search(r"Lua\s+(\d+\.\d+)", (r.stdout or "") + (r.stderr or ""))
    return m.group(1) if m else None


def parse_check(luac, path):
    r = subprocess.run([luac, "-p", path], capture_output=True, text=True)
    if r.returncode == 0:
        return None
    msg = (r.stderr or r.stdout).strip().splitlines()
    return msg[0] if msg else "unknown parse error"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--luac", default=None)
    ap.add_argument("--strict-version", action="store_true",
                    help="refuse to run unless luac is %s, as Mudlet is" % WANTED)
    a = ap.parse_args()

    luac = a.luac or find_luac()
    if not luac or not (os.path.exists(luac) or shutil.which(luac)):
        sys.exit("no luac found. Put one on PATH, set $LUAC, or pass "
                 "--luac /path/to/luac")
    a.luac = luac

    version = luac_version(luac)
    print("using: %s  (Lua %s)" % (luac, version or "version unknown"))

    if version != WANTED:
        told = version or "an unknown version"
        if a.strict_version:
            sys.exit("\nrefusing to run: this is Lua %s, and Mudlet runs %s.\n"
                     "Checking svof against the wrong grammar is worse than not "
                     "checking it." % (told, WANTED))
        print()
        print("!" * 72)
        print("  This luac is Lua %s. Mudlet runs %s." % (told, WANTED))
        print("  Anything reported below may be legal 5.1 that this parser")
        print("  rejects, not a real error. Known cases:")
        print("    goto as an identifier     - a keyword only from 5.2")
        print("    invalid escape sequence   - 5.1 allows \\w, \\/ and friends")
        print("    assign to const variable  - 5.4 semantics, vendored Penlight")
        print("  Do NOT change working code to satisfy this. Get a 5.1 luac.")
        print("!" * 72)
    print()

    failures = []

    # 1. every .lua file
    # src/resources holds data files shipped with the package, not scripts:
    # ndb-help.lua is a bare table read back with loadstring("return "..s)
    lua_files = [f for f in sorted(glob.glob(os.path.join(SRC, "**", "*.lua"),
                                             recursive=True))
                 if not os.path.relpath(f, SRC).replace("\\", "/")
                          .startswith("resources/")]
    for f in lua_files:
        err = parse_check(a.luac, f)
        if err:
            failures.append((f, err))

    # 2. every script inlined into json
    inlined = 0
    tmpdir = tempfile.mkdtemp()
    for jf in sorted(glob.glob(os.path.join(SRC, "**", "*.json"), recursive=True)):
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

    # A floor, because "checked nothing" and "checked everything and it was
    # fine" printed the same line and both exited 0.
    MIN_LUA, MIN_INLINE = 1000, 20
    if len(lua_files) < MIN_LUA or inlined < MIN_INLINE:
        print(f"REFUSING: found {len(lua_files)} lua files and {inlined} inlined "
              f"scripts under {SRC}")
        print(f"          expected at least {MIN_LUA} and {MIN_INLINE} - the tree "
              f"is missing, or the globs stopped matching it")
        return 1

    print(f"lua files checked   : {len(lua_files)}")
    print(f"inlined scripts     : {inlined}")
    print(f"total chunks parsed : {len(lua_files) + inlined}")
    print()
    if failures:
        print(f"SYNTAX ERRORS ({len(failures)}):")
        for where, err in failures:
            print(f"  {where}")
            print(f"      {err}")
        if version != WANTED:
            print()
            print(f"  Reported by Lua {version or '?'}, not {WANTED}. "
                  f"Check each against 5.1 before believing it.")
        return 1
    print("all chunks parse cleanly")
    return 0


if __name__ == "__main__":
    sys.exit(main())
