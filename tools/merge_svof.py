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

# For every item type except buttons the per-module wrapper folder below is
# purely organisational: it reproduces the module boundary in Mudlet's editor
# and changes nothing at runtime. Buttons are the exception, because for them
# the nesting depth *is* the UI. Mudlet builds one toolbar per child of the
# package node (ActionUnit::regenerateEasyButtonBars) and renders anything
# deeper as a menu, so an extra level turns the toolbar into a dropdown:
#
#   with a wrapper     svof -> svo (aliases, triggers) -> svo -> 8 buttons
#                      renders as a single [svo v] dropdown
#   without            svof -> svo -> 8 buttons
#                      renders as [Show affs] [Show prios v], as the module did
#
# Only one module ships buttons, so there is nothing to disambiguate by wrapping.
NO_WRAPPER_KINDS = {"Action"}


def wrapper_element(group, name):
    """The per-module folder the merge puts a module's items inside.

    Built here rather than inline so verify_merged.py can check the wrappers in
    the built package against the same definition. 51 of the 54 wrappers were
    never compared to anything at all, and a wrapper is a plausible place for
    damage to land: it is an ordinary group node, so it can carry a script body
    and an isActive of its own, and isActive="no" on one silently deactivates
    everything below it. src/scripts/svo_(limbcounter).lua already ships as
    exactly this kind of wrapper body, so it is reachable from an ordinary
    change to src/."""
    wrapper = ET.Element(group, {"isActive": "yes", "isFolder": "yes"})
    ET.SubElement(wrapper, "name").text = name
    ET.SubElement(wrapper, "script").text = ""
    return wrapper


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=REPO)
    ap.add_argument("--package", default="svof")
    ap.add_argument("--version", default="65")  # svof's existing numbering
    ap.add_argument("--force", action="store_true",
                    help="regenerate over an existing src/, discarding hand-written changes")
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
    resources = os.path.join(src, "resources")
    if os.path.isdir(src) and not a.force:
        sys.exit(
            "src/ already exists.\n\n"
            "This was a one-time conversion: src/ is the source of truth now, and\n"
            "the module xmls are kept only as the reference it is verified against.\n"
            "Rerunning rebuilds src/ from those xmls and would discard everything\n"
            "written since - the module machinery removal, the updater, the\n"
            "migration guard, and every hand-written .lua.\n\n"
            "src/resources/ is preserved across a --force run - nothing here can\n"
            "regenerate it, since it holds the runtime data files muddler copies\n"
            "into the package - but nothing else is.\n\n"
            "Pass --force if you really mean to regenerate, and expect to restore\n"
            "hand-written changes afterwards."
        )
    if os.path.isdir(src):
        # src/resources/ is not generated from anything: it holds default_prios
        # and ndb-help.lua, which muddler copies to the package root and which
        # svo.installationfolder() then reads at runtime. rmtree took it with
        # everything else and nothing recreated it, so a --force run left the
        # built package without its data files and the guard text above did not
        # mention it. Carry it across.
        keep = None
        if os.path.isdir(resources):
            keep = os.path.join(a.out, ".svof-resources-tmp")
            if os.path.isdir(keep):
                shutil.rmtree(keep)
            shutil.move(resources, keep)
        shutil.rmtree(src)
        if keep:
            os.makedirs(src, exist_ok=True)
            shutil.move(keep, resources)
            print("kept src/resources/ (%d file(s)) - it is not generated"
                  % len(os.listdir(resources)))

    # gather each package type's top-level nodes across every module, in order
    roots = {name: ET.parse(os.path.join(REPO, name + ".xml")).getroot()
             for name in MERGE_ORDER}

    # The same warning xml2muddler.py carries, for the same reason. This is the
    # tool that actually produced src/, and it had no such check: ActionPackage
    # was absent from PACKAGES and 170 elements of button went with it, in
    # silence, and stayed missing until someone counted items in a real Mudlet.
    # The next item type Mudlet adds would go the same way.
    for name in MERGE_ORDER:
        for child in roots[name]:
            if (not child.tag.endswith("Package") or child.tag in x2m.PACKAGES
                    or child.tag == "HelpPackage"):
                continue
            n = sum(1 for _ in child.iter() if _ is not child)
            if n:
                x2m.warn("%s in %s is not handled and was dropped (%d element(s) "
                         "below it)" % (child.tag, name, n))

    totals = {}
    for pkgtag, (kind, leaf, group) in x2m.PACKAGES.items():
        combined = []
        for name in MERGE_ORDER:
            node = roots[name].find(pkgtag)
            if node is None:
                continue
            kids = [c for c in node if c.tag in (leaf, group)]
            if not kids:
                continue
            if leaf in NO_WRAPPER_KINDS:
                # nesting depth is load-bearing here - see NO_WRAPPER_KINDS
                combined.extend(kids)
                continue
            # Each module used to be its own tree in Mudlet's editor, and that
            # boundary was what grouped its items. Without a folder to stand in
            # for it, everything a module kept at its own top level lands in one
            # flat list of siblings and reads as scattered.
            if len(kids) == 1 and kids[0].tag == group and (kids[0].findtext("name") or "") == name:
                # already a single folder named after the module - don't nest it
                # inside another folder with the same name
                combined.append(kids[0])
                continue
            wrapper = wrapper_element(group, name)
            for k in kids:
                wrapper.append(k)
            combined.append(wrapper)
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
