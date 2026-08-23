#!/usr/bin/env python3
"""verify_merged.py -- check the merged single package against every original module.

Each module contributes a set of uniquely-named top-level items, so the merged
package can be checked module by module: pull that module's items out of the
merged XML and compare them against the module's own XML, object by object.

Compares structure, names, scripts, patterns and pattern types, alias regexes,
event handlers and the behavioural flags. Also checks that the top-level items
appear in the intended load order.

Two kinds of problem are reported.

  Structural  - something is missing, duplicated, in the wrong place or out of
                order. Never acceptable, always fatal.
  Content     - an item's script or flags differ from the original. Most of
                these are deliberate: the module machinery is gone, the updater
                and migration guard are new, and a few load-order assumptions
                had to change. Those live in a baseline file.

The reference side is pinned. The 25 module xmls at the repo root are what the
package is compared against, and they are ordinary files in the same working
tree - so a change applied to BOTH sides was invisible by construction.
Appending send('quit') to a script in the reference xml and in src/ verified
clean, exit 0. Their hashes are now recorded in tools/reference_xmls.json and
checked before anything else, so editing a reference is a deliberate,
reviewable act instead of a silent one.

    python tools/verify_merged.py <merged.xml>
    python tools/verify_merged.py <merged.xml> --baseline tools/verify_baseline.json
    python tools/verify_merged.py <merged.xml> --write-baseline tools/verify_baseline.json
    python tools/verify_merged.py --write-reference    # re-record the xml hashes
"""
import argparse, hashlib, json, os, sys
import xml.etree.ElementTree as ET

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import verify as V
from merge_svof import MERGE_ORDER, NO_WRAPPER_KINDS, REPO, wrapper_element

LEAF_OF = V.LEAF_OF

REFERENCE = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                         "reference_xmls.json")


def reference_hashes():
    """sha256 of each module xml's content, independent of checkout line
    endings.

    These 25 files are stored in git as LF; core.autocrlf=true rewrites them
    to CRLF on a Windows checkout. Hashing the raw bytes made the first
    version of this pin Windows-specific - every hash recorded on Windows
    failed on Linux CI, all 25 at once, not because anything had changed but
    because the reference was never platform-independent. Stripping CR before
    hashing means the same content hashes the same on both.
    """
    out = {}
    for module in MERGE_ORDER:
        path = os.path.join(REPO, module + ".xml")
        # A missing reference used to be a raw traceback out of this open(),
        # which also made check_reference's "has gone missing" branch below
        # unreachable - it can only fire if this function can return without a
        # file. Skip it here and let that branch say so properly.
        if not os.path.exists(path):
            continue
        with open(path, "rb") as fh:
            data = fh.read()
        out[module + ".xml"] = hashlib.sha256(data.replace(b"\r\n", b"\n")).hexdigest()
    return out


def check_reference():
    """Refuse to compare against a reference that has moved.

    Everything this gate reports is relative to these 25 files. Editing one is
    sometimes right - the conversion renamed items that could not become
    filenames, and had to rename their call sites here too - but it changes
    what "verified" means, so it has to be recorded on purpose.
    """
    if not os.path.exists(REFERENCE):
        return ["reference record %s is missing - regenerate it with "
                "--write-reference" % os.path.basename(REFERENCE)]
    with open(REFERENCE, encoding="utf-8") as fh:
        recorded = json.load(fh)["sha256"]
    now = reference_hashes()

    problems = []
    for name in sorted(set(recorded) | set(now)):
        if name not in recorded:
            problems.append("reference xml %r is not recorded" % name)
        elif name not in now:
            problems.append("reference xml %r has gone missing" % name)
        elif recorded[name] != now[name]:
            problems.append(
                "reference xml %r has changed since it was recorded - the "
                "comparison below would be against a moved reference" % name)
    return problems


def digest(*parts):
    h = hashlib.sha256()
    for p in parts:
        h.update(repr(p).encode("utf-8"))
        h.update(b"\0")
    return h.hexdigest()[:16]


# Root children Mudlet knows about. HelpPackage and VariablePackage carry no
# items, so nothing here compares them, but a root child outside this set is a
# wrapper Mudlet will not recognise and is worth failing on rather than
# silently ignoring.
KNOWN_PACKAGES = {k + "Package" for k in LEAF_OF} | {"HelpPackage", "VariablePackage"}


def top_level(root, kind):
    """(name, element) for each top-level item of this kind.

    Only <XxxPackage> is searched. Mudlet dispatches on the wrapper tag and
    sends anything else to readUnknownElement - a qDebug line - so a trigger
    tree that ends up under <ScriptPackage> imports as nothing at all. Taking
    any wrapper's children made that invisible: moving svo (aliases, triggers)
    with its 2317 triggers into ScriptPackage left the package installable,
    listed in the package manager, with not one trigger able to fire, and this
    gate reported it verified. A one-character typo in the wrapper tag read the
    same way."""
    group = LEAF_OF[kind]
    wrapper = kind + "Package"
    out = []
    for pkg in list(root):
        if pkg.tag != wrapper:
            continue
        for c in list(pkg):
            if c.tag in (kind, group):
                out.append((c.findtext("name") or "", c))
    return out


# muddler writes a type default into these on every node it emits, folder or
# not. A folder has no colours, no key and no trigger type, so they carry no
# meaning on a wrapper and the merge does not set them - comparing them would
# report five differences per wrapper that say nothing. Everything that does
# mean something on a folder - isActive, isFolder, the script body, patterns,
# event handlers, commands - is compared.
WRAPPER_DEFAULTED = {"triggerType", "highlightFg", "highlightBg",
                     "colorTriggerFgColor", "colorTriggerBgColor",
                     "keyCode", "keyModifier"}


def describe_tree(elem, kind):
    """Flatten one item and its descendants into comparable descriptors."""
    group = LEAF_OF[kind]
    out = []

    def walk(node, prefix):
        seen = {}
        for c in list(node):
            if c.tag not in (kind, group):
                continue
            nm = c.findtext("name") or ""
            seen[nm] = seen.get(nm, 0) + 1
            suffix = "" if seen[nm] == 1 else "#%d" % seen[nm]
            p = prefix + "/" + nm + suffix
            out.append((p, V.describe(c, kind)))
            walk(c, p)

    out.append(("", V.describe(elem, kind)))
    walk(elem, "")
    return out


def compare(merged):
    """Returns (structural, content, order_report)."""
    structural, content = [], []
    order_report = {}

    for kind in LEAF_OF:
        group = LEAF_OF[kind]
        # Each module's items sit inside a folder named after the module.
        # Whether a wrapper exists is decided by the merger from the module
        # itself, so decide it the same way here rather than guessing from the
        # merged side: a module that already was a single folder of its own
        # name is used as-is and has no extra wrapper around it.
        merged_roots = {nm: el for nm, el in top_level(merged, kind)}

        merged_by_name = {}
        self_named = set()
        for module in MERGE_ORDER:
            mod_root = ET.parse(os.path.join(REPO, module + ".xml")).getroot()
            mod_top = top_level(mod_root, kind)
            if not mod_top:
                continue
            if kind in NO_WRAPPER_KINDS:
                # This kind ships without a per-module wrapper, so the module's
                # own top-level items sit directly at the package top level.
                # Anything missing is reported by the load-order pass below.
                for nm, _el in mod_top:
                    if nm in merged_roots:
                        merged_by_name.setdefault(nm, []).append(merged_roots[nm])
                continue

            holder = merged_roots.get(module)
            if holder is None:
                structural.append("%-8s %s: no top-level entry in the merged package"
                                  % (kind, module))
                continue
            is_self_named = (len(mod_top) == 1 and mod_top[0][0] == module
                             and mod_top[0][1].tag == group)
            if is_self_named:
                self_named.add(module)
                merged_by_name.setdefault(module, []).append(holder)
            else:
                # The wrapper itself, not just what it holds. A wrapper is an
                # ordinary group node: it can carry a script body, and
                # isActive="no" on it deactivates every item below it. Nothing
                # compared these - 51 of the 54 - so injecting
                # error("SABOTAGE") plus isActive="no" into one verified clean.
                # There is no original to compare against, since the merge
                # invents them, so compare against what the merge is defined to
                # produce.
                want = V.describe(wrapper_element(group, module), kind)
                got = V.describe(holder, kind)
                for k in sorted(set(want) | set(got)):
                    if k in WRAPPER_DEFAULTED:
                        continue
                    if want.get(k) != got.get(k):
                        structural.append(
                            "%-8s %s: module wrapper [%s] is %r, expected %r"
                            % (kind, module, k, got.get(k), want.get(k)))
                for c in holder:
                    if c.tag in (kind, group):
                        merged_by_name.setdefault(c.findtext("name") or "", []).append(c)

        expected_order = []
        for module in MERGE_ORDER:
            mod_root = ET.parse(os.path.join(REPO, module + ".xml")).getroot()
            mod_top = top_level(mod_root, kind)
            if not mod_top:
                continue
            for nm, el in mod_top:
                expected_order.append(nm)
                if nm not in merged_by_name or not merged_by_name[nm]:
                    structural.append("%-8s %s: top-level %r MISSING from merged package"
                                      % (kind, module, nm))
                    continue
                melem = merged_by_name[nm].pop(0)
                a = describe_tree(el, kind)
                b = describe_tree(melem, kind)
                def diff_one(path, da, db):
                    for k in sorted(set(da) | set(db)):
                        if da.get(k) != db.get(k):
                            content.append({
                                "id": "item|%s|%s|%s%s|%s" % (kind, module, nm, path, k),
                                "digest": digest(da.get(k), db.get(k)),
                                "text": "%-8s %s %s%s [%s]" % (kind, module, nm, path, k),
                                "original": da.get(k),
                                "merged": db.get(k),
                            })

                if len(a) != len(b):
                    # An item was added or removed inside this tree - deliberate
                    # for the bootstrap folders. Record the count, then keep
                    # going: this used to `continue`, which skipped the whole
                    # subtree and made the gate blind to exactly the trees it
                    # most needed to watch. The only two count-differing trees
                    # hold the updater, the migration guard and svo_init_system,
                    # so replacing a body with error("sabotage") still verified
                    # clean. Compare whatever both sides do have, keyed by path.
                    content.append({
                        "id": "count|%s|%s|%s" % (kind, module, nm),
                        "digest": digest(len(a), len(b)),
                        "text": "%-8s %s / %r: %d items originally, %d in merged"
                                % (kind, module, nm, len(a), len(b)),
                    })
                    amap, bmap = dict(a), dict(b)
                    for path in sorted(set(amap) - set(bmap)):
                        content.append({
                            "id": "gone|%s|%s|%s%s" % (kind, module, nm, path),
                            "digest": digest(path, None),
                            "text": "%-8s %s %s%s [only in the originals]"
                                    % (kind, module, nm, path),
                        })
                    for path in sorted(set(bmap) - set(amap)):
                        # Digest the descriptor, not just the path. An item that
                        # exists only in the package has nothing to compare
                        # against, so a path-only digest never moves and the
                        # body is unreviewed forever - which is the whole
                        # problem here, since the updater and the migration
                        # guard are exactly such items. Including the descriptor
                        # means editing one of them fails the gate until the
                        # baseline is regenerated deliberately.
                        d = bmap[path]
                        content.append({
                            "id": "added|%s|%s|%s%s" % (kind, module, nm, path),
                            "digest": digest(None, path,
                                             *[(k, d[k]) for k in sorted(d)]),
                            "text": "%-8s %s %s%s [only in the package]"
                                    % (kind, module, nm, path),
                        })
                    for path in sorted(set(amap) & set(bmap)):
                        diff_one(path, amap[path], bmap[path])
                    continue

                for (pa, da), (pb, db) in zip(a, b):
                    if pa != pb:
                        structural.append("%-8s %s: path %r != %r" % (kind, module, pa, pb))
                        break
                    diff_one(pa, da, db)

        for n, v in merged_by_name.items():
            if v:
                structural.append("%-8s merged package has unexpected top-level %r" % (kind, n))

        # flatten the merged tree the same way: a module wrapper contributes
        # the names inside it, anything else contributes its own name
        actual_order = []
        for nm, el in top_level(merged, kind):
            if nm in set(MERGE_ORDER) and nm not in self_named and el.tag == group:
                actual_order.extend((c.findtext("name") or "") for c in el
                                    if c.tag in (kind, group))
            else:
                actual_order.append(nm)
        order_report[kind] = (expected_order, actual_order)

    for kind, (exp, act) in order_report.items():
        # `if exp and ...` meant a kind the 25 references contribute nothing to
        # was never checked for anything: no expectation, no load-order line,
        # no leftover check. The built package already emits an empty
        # <TimerPackage>, so src/timers/ was an unguarded way in - a Timer
        # running send("quit") added there passed the gate.
        if exp != act:
            where = next((i for i, (e, x) in enumerate(zip(exp, act)) if e != x), len(exp))
            structural.append(
                "%-8s LOAD ORDER changed at position %d: expected %r, got %r"
                % (kind, where,
                   exp[where] if where < len(exp) else "<end>",
                   act[where] if where < len(act) else "<end>"))
    return structural, content, order_report


def short(v):
    s = str(v)
    return s if len(s) <= 200 else s[:200] + " ..."


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("merged", nargs="?")
    ap.add_argument("--baseline", help="fail only on differences not listed here")
    ap.add_argument("--write-baseline", help="record the current content differences")
    ap.add_argument("--write-reference", action="store_true",
                    help="record the reference xml hashes and exit")
    a = ap.parse_args()

    if a.write_reference:
        payload = {
            "note": "sha256 of each module xml the package is verified against. "
                    "These are the reference, so a change to one changes what "
                    "'verified' means - verify_merged.py refuses to run until it "
                    "is re-recorded here, deliberately, in the same commit.",
            "sha256": reference_hashes(),
        }
        with open(REFERENCE, "w", encoding="utf-8", newline="\n") as fh:
            json.dump(payload, fh, indent=2)
            fh.write("\n")
        print("wrote %s: %d reference xmls" % (REFERENCE, len(payload["sha256"])))
        return 0

    if not a.merged:
        ap.error("the merged package xml is required")

    moved = check_reference()
    if moved:
        for m in moved:
            print("[FAIL] " + m)
        print("\nThe reference xmls are what this gate measures against. If the "
              "change was intended,\nre-record them in the same commit:\n"
              "    python tools/verify_merged.py --write-reference")
        return 1

    merged = ET.parse(a.merged).getroot()
    structural, content, order_report = compare(merged)

    # Mudlet dispatches strictly on the root child's tag, so a wrapper it does
    # not know is read by readUnknownElement and everything inside it is
    # dropped. Nothing below would notice: each kind only ever looks inside its
    # own wrapper.
    for pkg in list(merged):
        if pkg.tag not in KNOWN_PACKAGES:
            structural.insert(0, "root child %r is not a package wrapper Mudlet "
                                 "reads - everything inside it is dropped on "
                                 "import" % pkg.tag)

    for kind, (exp, act) in order_report.items():
        if exp or act:
            print("[%s] %-8s load order preserved (%d top-level items)"
                  % ("OK " if exp == act else "FAIL", kind, len(exp)))
    print()

    if a.write_baseline:
        # Refuse BEFORE writing. This block used to write the file and then
        # announce it was "refusing", which is the worst of both readings: the
        # message said nothing had happened while the baseline on disk had
        # already been replaced. 79 accepted entries silently became 62 in the
        # working tree, on a run that reported a structural failure and exited
        # 1.
        if structural:
            print("refusing to bless a structural problem - %s NOT written:"
                  % a.write_baseline)
            for problem in structural:
                print("  [FAIL] " + problem)
            return 1
        payload = {
            "note": "Content differences from the original module xmls that are "
                    "deliberate. verify_merged.py --baseline fails on anything not "
                    "listed here, and on any of these whose content has changed. "
                    "Regenerate only when you meant to change one.",
            "source": os.path.basename(a.merged),
            "accepted": sorted(({"id": c["id"], "digest": c["digest"], "text": c["text"]}
                                for c in content), key=lambda c: c["id"]),
        }
        with open(a.write_baseline, "w", encoding="utf-8", newline="\n") as f:
            json.dump(payload, f, indent=2)
            f.write("\n")
        print("wrote %s: %d accepted differences" % (a.write_baseline, len(content)))
        return 0

    for s in structural:
        print("[FAIL] " + s)

    if not a.baseline:
        for c in content:
            print("[DIFF] " + c["text"])
        print("\n%d structural problem(s), %d content difference(s)"
              % (len(structural), len(content)))
        print("run with --baseline to fail only on differences that are not expected")
        return 1 if structural or content else 0

    base = json.load(open(a.baseline, encoding="utf-8"))
    accepted = {e["id"]: e["digest"] for e in base["accepted"]}
    seen, new, changed = set(), [], []
    for c in content:
        seen.add(c["id"])
        if c["id"] not in accepted:
            new.append(c)
        elif accepted[c["id"]] != c["digest"]:
            changed.append(c)
    gone = sorted(set(accepted) - seen)

    for c in new:
        print("[FAIL] unexpected difference: " + c["text"])
        print("           original: %r" % short(c.get("original")))
        print("           merged  : %r" % short(c.get("merged")))
    for c in changed:
        print("[FAIL] a known difference changed: " + c["text"])
        print("           original: %r" % short(c.get("original")))
        print("           merged  : %r" % short(c.get("merged")))
    for g in gone:
        print("[FAIL] baselined difference no longer present: " + g)
        print("           the merged package now matches the original here. If that "
              "was intended, regenerate the baseline.")

    bad = len(structural) + len(new) + len(changed) + len(gone)
    print()
    if bad == 0:
        print("MERGED PACKAGE VERIFIED - every module's items present, unchanged, in order")
        print("  %d expected differences, all matching the baseline" % len(accepted))
        return 0
    print("MERGE VERIFICATION FAILED - %d problem(s)" % bad)
    return 1


if __name__ == "__main__":
    sys.exit(main())
