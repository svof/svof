#!/usr/bin/env python3
"""
restore_addon_stubs.py -- one-off repair.

The 13 addon group scripts were blanked wholesale on the assumption that they
only set a module priority. Most of them also held real code - namespace
initialisation, and in two cases whole functions - which went with it.

This rebuilds each from its pre-conversion content, removing only the parts
that genuinely have no meaning in a single package:

    function <name>Prio(...) ... end
    registerAnonymousEventHandler("sysInstall", "<name>Prio", true)
    svo.modules_version = svo.modules_version or {}
    svo.modules_version["..."] = <n>

Everything else is kept exactly as it was.

    python tools/restore_addon_stubs.py <rev-with-original-content>
"""
import glob, os, re, subprocess, sys

PRIO_FUNC = re.compile(r"^function \w*[Pp]rio\(.*?^end\n", re.S | re.M)
PRIO_REG = re.compile(r"^registerAnonymousEventHandler\(\s*\"sysInstall\"\s*,\s*\"\w*[Pp]rio\"[^\n]*\n", re.M)
MV_DECL = re.compile(r"^[ \t]*svo\.modules_version = svo\.modules_version or \{\}[ \t]*\r?\n?", re.M)
MV_SET = re.compile(r"^[ \t]*svo\.modules_version\[[^\]]+\][ \t]*=[ \t]*[\d.]+[ \t]*\r?\n?", re.M)

HEADER = ("-- The module priority this group used to set on install has no meaning in a\n"
          "-- single package: load order comes from where these items sit in the tree.\n")


def strip(text):
    text = PRIO_FUNC.sub("", text)
    text = PRIO_REG.sub("", text)
    text = MV_DECL.sub("", text)
    text = MV_SET.sub("", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def main():
    rev = sys.argv[1]
    listing = subprocess.run(["git", "ls-tree", "-r", "--name-only", rev, "src/scripts/"],
                             capture_output=True).stdout.decode("utf-8").split("\n")
    repaired = []
    for old_path in listing:
        if not old_path.endswith(".lua"):
            continue
        blob = subprocess.run(["git", "show", f"{rev}:{old_path}"], capture_output=True)
        if blob.returncode != 0:
            continue
        original = blob.stdout.decode("utf-8", errors="replace")
        if "setModulePriority" not in original:
            continue

        base = os.path.basename(old_path)
        hits = [p for p in glob.glob(f"src/scripts/*/{base}")] or \
               [p for p in glob.glob(f"src/scripts/{base}")]
        if len(hits) != 1:
            print(f"  !! cannot place {base} ({len(hits)} candidates)")
            continue
        new_path = hits[0]

        body = strip(original)
        out = HEADER + ("\n" + body + "\n" if body else "")
        with open(new_path, "w", encoding="utf-8", newline="\n") as f:
            f.write(out)
        kept = len([l for l in body.splitlines() if l.strip()])
        repaired.append((base, kept))

    print(f"repaired {len(repaired)} addon group scripts:")
    for name, kept in sorted(repaired):
        note = "namespace/code restored" if kept else "was only priority code"
        print(f"   {name:44s} {kept:4d} lines kept   {note}")


if __name__ == "__main__":
    sys.exit(main())
