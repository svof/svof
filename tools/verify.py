#!/usr/bin/env python3
"""
verify.py -- semantic round-trip check between an original Mudlet package XML
and the XML muddler rebuilt from the converted project.

Compares the full object tree: structure, names, scripts, patterns + pattern
types, alias regexes, event handlers and the behavioural flags. Exits non-zero
on any difference so it can gate CI.

Usage:
    python verify.py <original.xml> <rebuilt.xml>
"""
import sys, json
import xml.etree.ElementTree as ET

LEAF_OF = {
    "Trigger": "TriggerGroup", "Alias": "AliasGroup", "Script": "ScriptGroup",
    "Timer": "TimerGroup", "Key": "KeyGroup",
}
KINDS = list(LEAF_OF.keys())

# fields compared per object type: json key -> xml tag/attr extractor
def txt(n, tag):
    v = n.findtext(tag)
    return "" if v is None else v

def norm_script(s):
    # trailing-whitespace / newline normalisation only
    return "\n".join(line.rstrip() for line in (s or "").replace("\r\n", "\n").split("\n")).strip()

import re as _re

def _norm_colour(p):
    """Mudlet has two spellings for colour-trigger patterns: the legacy
    'FG6BG2' and the modern 'ANSI_COLORS_F{6}_B{2}'. muddler emits the modern
    one. Treat them as equivalent so the check does not flag a pure
    representation change."""
    m = _re.match(r"^ANSI_COLORS_F\{(-?\d+)\}_B\{(-?\d+)\}$", p)
    if m:
        return f"FG{m.group(1)}BG{m.group(2)}"
    return p

def patterns(n):
    pl, cl = n.find("regexCodeList"), n.find("regexCodePropertyList")
    pats = [_norm_colour(p.text or "") for p in pl] if pl is not None else []
    codes = [c.text or "" for c in cl] if cl is not None else []
    return list(zip(pats, codes))

def events(n):
    eh = n.find("eventHandlerList")
    return [e.text or "" for e in eh] if eh is not None else []

def describe(n, kind):
    d = {
        "isActive": n.get("isActive", "yes"),
        "isFolder": n.get("isFolder", "no"),
        "script": norm_script(txt(n, "script")),
    }
    if kind == "Trigger":
        d.update({
            "patterns": patterns(n),
            "multiline": n.get("isMultiline", "no"),
            "multilineDelta": txt(n, "conditonLineDelta") or "0",
            "fireLength": txt(n, "mStayOpen") or "0",
            "filter": n.get("isFilterTrigger", "no"),
            "command": txt(n, "mCommand"),
        })
    elif kind == "Alias":
        d.update({"regex": txt(n, "regex"), "command": txt(n, "command")})
    elif kind == "Script":
        d.update({"events": events(n)})
    elif kind == "Timer":
        d.update({"time": txt(n, "time"), "command": txt(n, "command")})
    elif kind == "Key":
        d.update({"keyCode": txt(n, "keyCode"), "keyModifier": txt(n, "keyModifier"),
                  "command": txt(n, "command")})
    return d

def collect(path, kind):
    """Return {logical_path: [descriptor,...]} keyed by name-path."""
    group = LEAF_OF[kind]
    out = {}
    def walk(node, prefix):
        # index siblings so identical names stay distinguishable
        seen = {}
        for c in list(node):
            if c.tag not in (kind, group):
                continue
            nm = c.findtext("name") or ""
            seen[nm] = seen.get(nm, 0) + 1
            suffix = "" if seen[nm] == 1 else f"#{seen[nm]}"
            p = f"{prefix}/{nm}{suffix}"
            out.setdefault(p, []).append(describe(c, kind))
            walk(c, p)
    for pkg in list(ET.parse(path).getroot()):
        walk(pkg, "")
    return out

def main():
    orig_p, new_p = sys.argv[1], sys.argv[2]
    total_diffs = 0
    for kind in KINDS:
        a, b = collect(orig_p, kind), collect(new_p, kind)
        if not a and not b:
            continue
        only_a = sorted(set(a) - set(b))
        only_b = sorted(set(b) - set(a))
        shared = sorted(set(a) & set(b))

        diffs = []
        for p in shared:
            for i, (da, db) in enumerate(zip(a[p], b[p])):
                for k in sorted(set(da) | set(db)):
                    va, vb = da.get(k), db.get(k)
                    if va != vb:
                        diffs.append((p, k, va, vb))

        n = len(only_a) + len(only_b) + len(diffs)
        total_diffs += n
        status = "OK " if n == 0 else "FAIL"
        print(f"[{status}] {kind:8s} original={len(a):5d} rebuilt={len(b):5d} "
              f"missing={len(only_a)} extra={len(only_b)} fielddiffs={len(diffs)}")
        for p in only_a[:15]:
            print(f"    MISSING : {p}")
        for p in only_b[:15]:
            print(f"    EXTRA   : {p}")
        for p, k, va, vb in diffs[:15]:
            print(f"    DIFF    : {p} [{k}]")
            print(f"        orig: {va!r}")
            print(f"        new : {vb!r}")

    print()
    if total_diffs == 0:
        print("ROUND TRIP CLEAN - no differences")
        return 0
    print(f"ROUND TRIP FAILED - {total_diffs} difference(s)")
    return 1

if __name__ == "__main__":
    sys.exit(main())
