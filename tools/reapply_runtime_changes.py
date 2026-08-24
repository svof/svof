#!/usr/bin/env python3
"""
reapply_runtime_changes.py -- one-off: restore hand-written changes to src/
after a regeneration moved everything into per-module folders.

src/ was generated from the module xmls, then edited by hand to replace the
module machinery. Regenerating rebuilds src/ from the xmls and so discards
those edits. This copies them back at their new paths.

Once src/ is the source of truth this script has no purpose - it exists only
to cross the regeneration that introduced the module folders.

    python tools/reapply_runtime_changes.py <from-rev> <to-rev>
"""
import glob, os, subprocess, sys


def git(*args):
    return subprocess.run(["git"] + list(args), capture_output=True)


def find_new_path(old_rel):
    """src/<kind>/<rest>  ->  src/<kind>/<module>/<rest>"""
    parts = old_rel.replace("\\", "/").split("/")
    kind, rest = parts[1], "/".join(parts[2:])
    hits = [p for p in glob.glob(f"src/{kind}/*/{rest}")]
    if len(hits) == 1:
        return hits[0]
    # a file being added: its directory exists even though the file does not
    if rest.count("/") >= 1:
        parent = rest.rsplit("/", 1)[0]
        dirs = [d for d in glob.glob(f"src/{kind}/*/{parent}") if os.path.isdir(d)]
        if len(dirs) == 1:
            return os.path.join(dirs[0], rest.rsplit("/", 1)[1]).replace("\\", "/")
    else:
        # top-level file: it belongs to whichever module folder now holds it
        stem = rest
        dirs = [d for d in glob.glob(f"src/{kind}/*/{stem}")]
        if len(dirs) == 1:
            return dirs[0]
    return None


def main():
    frm, to = sys.argv[1], sys.argv[2]
    r = git("diff", "--name-status", frm, to, "--", "src/")
    lines = r.stdout.decode("utf-8").strip().splitlines()

    applied = deleted = 0
    unresolved = []
    for line in lines:
        status, path = line.split("\t", 1)
        status = status[0]
        new = find_new_path(path)
        if new is None:
            unresolved.append((status, path))
            continue
        if status == "D":
            if os.path.exists(new):
                os.remove(new)
                deleted += 1
            continue
        blob = git("show", f"{to}:{path}")
        if blob.returncode != 0:
            unresolved.append((status, path))
            continue
        os.makedirs(os.path.dirname(new), exist_ok=True)
        with open(new, "wb") as f:
            f.write(blob.stdout)
        applied += 1

    print(f"restored : {applied}")
    print(f"removed  : {deleted}")
    if unresolved:
        print(f"UNRESOLVED ({len(unresolved)}) - these need placing by hand:")
        for s, p in unresolved:
            print(f"   {s}  {p}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
