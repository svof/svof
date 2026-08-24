#!/usr/bin/env python3
"""
check_package.py -- open the .mpackage users actually install and check it.

Everything else in CI verifies build/svof.xml. That file is a *sibling* of the
archive that ships, not the thing itself, so nothing ever confirmed that the
archive is a readable zip, that it carries the runtime data files, or that its
copy of svof.xml is the one the object-diff blessed. `ls -la build/` stood in
for that and exits 0 on an empty directory.

Four checks:

  1. the archive exists, is a valid zip, and is not suspiciously small
  2. it contains every file it is supposed to, and each is non-empty
  3. its svof.xml is byte-for-byte the one verify_merged.py checked, so that
     verdict transfers to the artifact
  4. its config.lua parses as Lua

Four matters more than it looks. muddler writes the whole README into
`description = [[...]]` with no escaping, so a single `]]` anywhere in the
README - `svo.echof([[hello]])` in an example, say - closes the long string
early and the file stops parsing. Host::getPackageConfig luaL_loadstrings it
and returns an empty table on error, printing nothing outside debug mode, so
version, author, title and description all come back blank and Setup.lua pins
svo.version to its hardcoded fallback forever. Reproduced by appending one
line to README.md. mfile now sets a real description, which is what keeps the
README out of that string in the first place; this is the check that says so
if it ever gets back in.

    python tools/check_package.py
    python tools/check_package.py --package build/svof.mpackage --luac "$(which luac)"
"""
import argparse
import os
import subprocess
import sys
import tempfile
import zipfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# name -> smallest size that is not obviously a stub
REQUIRED = {
    "svof.xml": 1_000_000,
    "config.lua": 50,
    "default_prios": 1000,
    "ndb-help.lua": 1000,
}

MIN_ARCHIVE_BYTES = 100_000

# Fields Mudlet reads back out of config.lua. Blank means the package manager
# shows nothing and svo.version never leaves its fallback.
REQUIRED_FIELDS = ("mpackage", "title", "author", "version", "description")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--package", default=os.path.join(REPO, "build", "svof.mpackage"))
    ap.add_argument("--xml", default=os.path.join(REPO, "build", "svof.xml"),
                    help="the xml the object-diff verified, to compare against")
    ap.add_argument("--luac", help="luac to parse config.lua with")
    a = ap.parse_args()

    problems = []

    if not os.path.exists(a.package):
        print("[FAIL] no package at %s" % a.package)
        return 1
    size = os.path.getsize(a.package)
    print("package: %s (%d bytes)" % (a.package, size))
    if size < MIN_ARCHIVE_BYTES:
        problems.append("the archive is %d bytes, expected at least %d"
                        % (size, MIN_ARCHIVE_BYTES))

    if not zipfile.is_zipfile(a.package):
        print("[FAIL] %s is not a zip - Mudlet cannot install it" % a.package)
        return 1

    with zipfile.ZipFile(a.package) as z:
        bad = z.testzip()
        if bad:
            problems.append("corrupt entry in the archive: %s" % bad)
        names = set(z.namelist())
        print("contents: %s" % ", ".join(sorted(names)))

        for name, floor in sorted(REQUIRED.items()):
            if name not in names:
                problems.append("%s is missing from the package" % name)
                continue
            got = z.getinfo(name).file_size
            if got < floor:
                problems.append("%s is %d bytes, expected at least %d"
                                % (name, got, floor))

        if "svof.xml" in names and os.path.exists(a.xml):
            with open(a.xml, "rb") as fh:
                on_disk = fh.read()
            packaged = z.read("svof.xml")
            if packaged != on_disk:
                problems.append(
                    "the svof.xml inside the package differs from %s - the "
                    "object-diff verified one and users install the other"
                    % os.path.relpath(a.xml, REPO))
            else:
                print("svof.xml in the package is identical to the verified one "
                      "(%d bytes)" % len(packaged))

        if "config.lua" in names:
            config = z.read("config.lua").decode("utf-8", "replace")
            for field in REQUIRED_FIELDS:
                if ("\n%s = " % field) not in ("\n" + config):
                    problems.append("config.lua has no %s field" % field)
            if a.luac:
                with tempfile.TemporaryDirectory() as tmp:
                    path = os.path.join(tmp, "config.lua")
                    with open(path, "w", encoding="utf-8", newline="\n") as fh:
                        fh.write(config)
                    r = subprocess.run([a.luac, "-p", path],
                                       capture_output=True, text=True)
                if r.returncode != 0:
                    problems.append(
                        "config.lua does not parse: %s\n"
                        "        Mudlet reads this with luaL_loadstring and "
                        "returns an empty table on error, printing nothing - "
                        "so every package field silently comes back blank."
                        % (r.stderr or r.stdout).strip())
                else:
                    print("config.lua parses cleanly")
            else:
                print("config.lua field check only - pass --luac to parse it")

    for p in problems:
        print("[FAIL] " + p)
    print()
    if problems:
        print("PACKAGE CHECK FAILED - %d problem(s)" % len(problems))
        return 1
    print("PACKAGE OK - the archive users install is complete and readable")
    return 0


if __name__ == "__main__":
    sys.exit(main())
