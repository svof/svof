#!/usr/bin/env python3
"""
compare_dict_behaviour.py -- what svo.dict entries do now, against what they
did at another revision.

tools/dict_behaviour.lua runs every function on every dictionary entry in
every state that decides what it does, for one class at a time, and
describes what each did (see that file). This loads a revision's src/
beside this checkout's, with these tools, and prints, for every function
that differs, the states in which it does and its result before and after
in each:

    python tools/compare_dict_behaviour.py origin/in-client-svof [--class Monk] [NAME ...]

It is for a change that rewrites entries without meaning to change what
they do, such as one made by basicaff or basicdef instead of by hand: run
it against the revision before, and it should find nothing. It exits 1
when anything differs, an entry is new or gone, or a class can't be
described. With no --class it compares every class svof knows, one Lua
process per class; with no NAME, every entry.

A revision whose files the current tools/svof_world.lua can't find can't
be compared this way. --lua names the interpreter (default lua): Mudlet's
Lua 5.1 and Lua 5.5 give the same descriptions.
"""

import argparse
import concurrent.futures
import io
import os
import subprocess
import sys
import tarfile
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
ENGINE = os.path.join("tools", "dict_behaviour.lua")


def run(cmd, cwd=ROOT):
    p = subprocess.run(cmd, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                       stdin=subprocess.DEVNULL)
    return p.returncode, p.stdout.decode("utf-8", "replace"), p.stderr.decode("utf-8", "replace")


def classes(lua):
    """Every class svof knows, from the engine itself."""
    code = ("local B = dofile('tools/dict_behaviour.lua') "
            "for _, c in ipairs(B.classes()) do print(c) end")
    rc, out, err = run([lua, "-e", code])
    if rc != 0:
        sys.exit("could not list the classes:\n" + err + out)
    names = [l.strip() for l in out.splitlines() if l.strip()]
    if len(names) < 20:
        sys.exit("only %d classes listed - expected every class svof knows:\n%s" % (len(names), out))
    return names


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("rev", help="the git revision to compare with, such as origin/in-client-svof")
    ap.add_argument("names", nargs="*", help="only these entries")
    ap.add_argument("--class", dest="classes", action="append", help="only this class (repeatable)")
    ap.add_argument("--lua", default="lua", help="the Lua interpreter")
    ap.add_argument("--jobs", type=int, default=os.cpu_count() or 2)
    a = ap.parse_intermixed_args()

    names = a.classes or classes(a.lua)
    with tempfile.TemporaryDirectory() as tmp:
        p = subprocess.run(["git", "archive", "--format=tar", a.rev, "src"], cwd=ROOT,
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if p.returncode != 0:
            sys.exit("git archive %s failed: %s" % (a.rev, p.stderr.decode()))
        with tarfile.open(fileobj=io.BytesIO(p.stdout)) as tar:
            # the "data" filter refuses anything outside tmp, where Python has it
            if hasattr(tarfile, "data_filter"):
                tar.extractall(tmp, filter="data")
            else:
                tar.extractall(tmp)
        root = tmp.replace("\\", "/") + "/"

        def one(cls):
            return cls, run([a.lua, ENGINE, "--against", root, "--class", cls] + a.names)

        bad = 0
        with concurrent.futures.ThreadPoolExecutor(max_workers=a.jobs) as pool:
            for cls, (rc, out, err) in pool.map(one, names):
                if rc != 0 or err.strip():
                    bad += 1
                sys.stdout.write(out)
                if err.strip():
                    sys.stdout.write(err)
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
