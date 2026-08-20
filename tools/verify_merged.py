#!/usr/bin/env python3
"""
verify_merged.py -- check the merged single package against every original module.

Each module contributes a set of uniquely-named top-level items, so the merged
package can be checked module by module: pull that module's items out of the
merged XML and compare them against the module's own XML, object by object.

Compares structure, names, scripts, patterns and pattern types, alias regexes,
event handlers and the behavioural flags. Also checks that the top-level items
appear in the intended load order. Exits non-zero on any difference.

    python tools/verify_merged.py <merged.xml>
"""
import sys, os
import xml.etree.ElementTree as ET

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import verify as V
from merge_svof import MERGE_ORDER, REPO

LEAF_OF = V.LEAF_OF


def top_level(root, kind):
    """(name, element) for each top-level item of this kind."""
    group = LEAF_OF[kind]
    out = []
    for pkg in list(root):
        for c in list(pkg):
            if c.tag in (kind, group):
                out.append((c.findtext("name") or "", c))
    return out


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
            suffix = "" if seen[nm] == 1 else f"#{seen[nm]}"
            p = f"{prefix}/{nm}{suffix}"
            out.append((p, V.describe(c, kind)))
            walk(c, p)

    out.append(("", V.describe(elem, kind)))
    walk(elem, "")
    return out


def main():
    merged_path = sys.argv[1]
    merged = ET.parse(merged_path).getroot()

    total_diffs = 0
    order_report = {}

    for kind in LEAF_OF:
        merged_top = top_level(merged, kind)
        merged_by_name = {}
        for nm, el in merged_top:
            merged_by_name.setdefault(nm, []).append(el)

        expected_order = []
        for module in MERGE_ORDER:
            mod_root = ET.parse(os.path.join(REPO, module + ".xml")).getroot()
            mod_top = top_level(mod_root, kind)
            if not mod_top:
                continue
            for nm, el in mod_top:
                expected_order.append(nm)
                if nm not in merged_by_name or not merged_by_name[nm]:
                    print(f"[FAIL] {kind:8s} {module}: top-level {nm!r} MISSING from merged package")
                    total_diffs += 1
                    continue
                melem = merged_by_name[nm].pop(0)
                a = describe_tree(el, kind)
                b = describe_tree(melem, kind)
                if len(a) != len(b):
                    print(f"[FAIL] {kind:8s} {module} / {nm!r}: {len(a)} items originally, {len(b)} in merged")
                    total_diffs += 1
                    continue
                for (pa, da), (pb, db) in zip(a, b):
                    if pa != pb:
                        print(f"[FAIL] {kind:8s} {module}: path {pa!r} != {pb!r}")
                        total_diffs += 1
                        break
                    for k in sorted(set(da) | set(db)):
                        if da.get(k) != db.get(k):
                            print(f"[FAIL] {kind:8s} {module} {nm}{pa} [{k}]")
                            print(f"           original: {da.get(k)!r}")
                            print(f"           merged  : {db.get(k)!r}")
                            total_diffs += 1

        leftovers = [n for n, v in merged_by_name.items() if v]
        for n in leftovers:
            print(f"[FAIL] {kind:8s} merged package has unexpected top-level {n!r}")
            total_diffs += 1

        actual_order = [nm for nm, _ in merged_top]
        order_report[kind] = (expected_order, actual_order)

    print()
    for kind, (exp, act) in order_report.items():
        if not exp:
            continue
        ok = exp == act
        print(f"[{'OK ' if ok else 'FAIL'}] {kind:8s} load order preserved "
              f"({len(exp)} top-level items)")
        if not ok:
            for i, (e, x) in enumerate(zip(exp, act)):
                if e != x:
                    print(f"    first difference at position {i}: expected {e!r}, got {x!r}")
                    break
            total_diffs += 1

    print()
    if total_diffs == 0:
        print("MERGED PACKAGE VERIFIED - every module's items present, unchanged, in order")
        return 0
    print(f"MERGE VERIFICATION FAILED - {total_diffs} problem(s)")
    return 1


if __name__ == "__main__":
    sys.exit(main())
