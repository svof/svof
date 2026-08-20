#!/usr/bin/env python3
"""
merge_svof.py -- merge every svof module XML into a single muddler project.

svof historically shipped as 24 Mudlet modules installed by a 25th bootstrap
module, with load order set by modules_list and setModulePriority. A muddler
project builds one package, so that ordering has to be reproduced by the order
items appear in the tree instead.

muddler takes the order of a directory's json as authoritative, so the root
<type>.json here lists the top-level groups explicitly, in MERGE_ORDER.

    python tools/merge_svof.py            # writes ./src and ./mfile
    python tools/merge_svof.py --out DIR  # writes somewhere else
"""
import argparse, json, os, shutil, sys
import xml.etree.ElementTree as ET

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import xml2muddler as x2m

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Load order, reproducing what modules_list plus setModulePriority did:
#   - the bootstrap module first, since it creates the svo namespace
#   - then modules_list order for everything at the default priority
#   - then the three modules that set priority 1, which loaded last
BOOTSTRAP = ["svo (install me in module manager)"]

CORE_AND_ADDONS = [
    "svo (actions dictionary)",
    "svo (alias and defence functions)",
    "svo (curing skeleton, controllers, action system)",
    "svo (custom prompt, serverside)",
    "svo (install, config, pipes, rift, parry, prios)",
    "svo (setup, misc, empty, funnies, dor)",
    "svo (trigger functions)",
    "svo (aliases, triggers)",
    "svo (elistsorter)",
    "svo (fishdist)",
    "svo (inker)",
    "svo (mindnet)",
    "svo (peopletracker)",
    "svo (reboundingsileristracker)",
    "svo (refiller)",
    "svo (runeidentifier)",
    "svo (stormhammertarget)",
    "svo (limbcounter)",
    "svo (burncounter)",
    "svo (priestreport)",
    "svo (enchanter)",
]

# these called setModulePriority(..., 1), so they loaded after the rest
PRIORITY_LAST = [
    "svo (namedb)",
    "svo (logger)",
    "svo (offering)",
]

MERGE_ORDER = BOOTSTRAP + CORE_AND_ADDONS + PRIORITY_LAST


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=REPO)
    ap.add_argument("--package", default="svof")
    ap.add_argument("--version", default="64")  # svof's existing numbering
    a = ap.parse_args()

    missing = [m for m in MERGE_ORDER
               if not os.path.exists(os.path.join(REPO, m + ".xml"))]
    if missing:
        sys.exit("missing module xml: " + ", ".join(missing))
    present = {f[:-4] for f in os.listdir(REPO) if f.endswith(".xml")}
    unlisted = present - set(MERGE_ORDER)
    if unlisted:
        sys.exit("module xml not in MERGE_ORDER (refusing to silently drop): "
                 + ", ".join(sorted(unlisted)))

    src = os.path.join(a.out, "src")
    if os.path.isdir(src):
        shutil.rmtree(src)

    # gather each package type's top-level nodes across every module, in order
    roots = {name: ET.parse(os.path.join(REPO, name + ".xml")).getroot()
             for name in MERGE_ORDER}

    totals = {}
    for pkgtag, (kind, leaf, group) in x2m.PACKAGES.items():
        combined = []
        for name in MERGE_ORDER:
            node = roots[name].find(pkgtag)
            if node is None:
                continue
            kids = [c for c in node if c.tag in (leaf, group)]
            if kids:
                combined.extend(kids)
        if not combined:
            continue
        em = x2m.Emitter(a.out, kind)
        em.emit_dir(em.root, combined, leaf, group)
        totals[kind] = em.stats

    mfile = {
        "package": a.package,
        "title": "svof",
        "version": a.version,
        "author": "Svof contributors",
        "outputFile": True,
    }
    with open(os.path.join(a.out, "mfile"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(mfile, f, indent=2)
        f.write("\n")

    print(f"package: {a.package}   modules merged: {len(MERGE_ORDER)}")
    for k, s in totals.items():
        print(f"  {k:9s} items={s['items']:5d} folders={s['folders']:4d} "
              f"lua={s['lua_files']:5d} inlined={s['inlined']:3d}")
    if x2m.warnings:
        print(f"\nwarnings ({len(x2m.warnings)}):")
        for w in x2m.warnings[:12]:
            print("  - " + w)
        if len(x2m.warnings) > 12:
            print(f"  ... and {len(x2m.warnings) - 12} more")


if __name__ == "__main__":
    main()
