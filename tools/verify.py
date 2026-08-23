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
    "Timer": "TimerGroup", "Key": "KeyGroup", "Action": "ActionGroup",
}
KINDS = list(LEAF_OF.keys())

# fields compared per object type: json key -> xml tag/attr extractor
def txt(n, tag):
    v = n.findtext(tag)
    return "" if v is None else v


def flag(n, attr):
    """A yes/no attribute, with absent and empty read as "no".

    Mudlet writes these out in full; muddler leaves them empty when false.
    Mudlet's reader tests `== "yes"`, so empty, absent and "no" all mean no -
    a spelling difference, not a behavioural one. Without this normalisation
    the baseline would fill with tens of thousands of entries that say nothing;
    the exact count depends on how you count, which is why one is not quoted
    here any more."""
    v = n.get(attr)
    return "no" if not v else v

def norm_script(s):
    # trailing-whitespace / newline normalisation only
    return "\n".join(line.rstrip() for line in (s or "").replace("\r\n", "\n").split("\n")).strip()

import re as _re

# The legacy->ANSI table lives with the converter that applies it, so the gate
# and the conversion can never disagree about what a legacy number means.
from xml2muddler import LEGACY_TO_ANSI

_MODERN = _re.compile(r"^ANSI_COLORS_F\{(-?\d+|DEFAULT|IGNORE)\}_B\{(-?\d+|DEFAULT|IGNORE)\}$")
_LEGACY = _re.compile(r"^FG(-?\d+)BG(-?\d+)$")


def _decode_colour(p):
    """Canonicalise a colour-trigger pattern to the colour pair Mudlet will
    actually match on, whichever of its two spellings the pattern is in.

    This used to re-spell the modern form as the legacy one and call the two
    equal. They are not equal: the legacy numbers are palette indices that
    XMLimport::remapColorsToAnsiNumber rewrites on load, so 'FG16BG2' and
    'ANSI_COLORS_F{16}_B{2}' name different colours. Normalising that away is
    exactly what let all 6 colour triggers ship converted to colours the game
    never sends, with this gate green.
    """
    m = _MODERN.match(p)
    if m:
        fg, bg = m.group(1), m.group(2)
    else:
        m = _LEGACY.match(p.strip())
        if not m:
            return p
        fg = LEGACY_TO_ANSI.get(int(m.group(1)), m.group(1))
        bg = LEGACY_TO_ANSI.get(int(m.group(2)), m.group(2))

    def canon(v):
        # Mudlet zero-pads to three digits on write; muddler does not.
        try:
            return str(int(v))
        except ValueError:
            return v

    return "ANSI(%s,%s)" % (canon(fg), canon(bg))

COLOUR_CODE = "6"


def patterns(n):
    pl, cl = n.find("regexCodeList"), n.find("regexCodePropertyList")
    pats = [p.text or "" for p in pl] if pl is not None else []
    codes = [c.text or "" for c in cl] if cl is not None else []
    # Decode only actual colour patterns, so a regex that merely looks like
    # "FG1BG2" is left exactly as written.
    return [(_decode_colour(p) if c == COLOUR_CODE else p, c)
            for p, c in zip(pats, codes)]

def events(n):
    eh = n.find("eventHandlerList")
    return [e.text or "" for e in eh] if eh is not None else []

def describe(n, kind):
    d = {
        # flag(), not n.get(..., "yes"). An absent isActive read as "yes" here
        # and as *inactive* in Mudlet (XMLimport tests == "yes"), and
        # Tree<T>::ancestorsActive() then deactivates the whole subtree - so
        # dropping the attribute from every group node disabled the system and
        # this gate said the package verified. Every other boolean was moved to
        # flag() when the missing trigger fields were added; this one was
        # skipped.
        "isActive": flag(n, "isActive"),
        "isFolder": flag(n, "isFolder"),
        "script": norm_script(txt(n, "script")),
    }
    if kind == "Trigger":
        d.update({
            "patterns": patterns(n),
            "multiline": n.get("isMultiline", "no"),
            "multilineDelta": txt(n, "conditonLineDelta") or "0",
            "fireLength": txt(n, "mStayOpen") or "0",
            "filter": flag(n, "isFilterTrigger"),
            "command": txt(n, "mCommand"),
            # perl /g. Absent here, the conversion dropped it on all 7 triggers
            # that had it and this gate still said the package verified - which
            # is how under-counted rift parsing shipped green.
            "matchall": flag(n, "isPerlSlashGOption"),
            "highlight": flag(n, "isColorizerTrigger"),
            "soundTrigger": flag(n, "isSoundTrigger"),
            "soundFile": txt(n, "mSoundFile"),
            # Below here was outside the gate's view. None of it changes
            # behaviour by itself, but it is all state Mudlet reads back, and
            # "the gate does not look at this" is how the perl /g loss and the
            # colour remap both got as far as they did.
            #
            # isColorTriggerFg and isColorTriggerBg are deliberately NOT here.
            # XMLexport writes them from mColorTriggerFgAnsi != scmIgnored and
            # XMLimport never reads them back, so they are export-only derived
            # state. Measured over the same pairing verify_merged uses: 5082
            # comparisons, 12 differences once flag() has normalised the
            # spelling - all of them derived, none of them behaviour.
            "temp": flag(n, "isTempTrigger"),
            "colorTrigger": flag(n, "isColorTrigger"),
            "triggerType": txt(n, "triggerType"),
            "highlightFg": txt(n, "mFgColor"),
            "highlightBg": txt(n, "mBgColor"),
            "colorTriggerFgColor": txt(n, "colorTriggerFgColor"),
            "colorTriggerBgColor": txt(n, "colorTriggerBgColor"),
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
    elif kind == "Action":
        # Buttons. Every attribute and layout number, because Mudlet reads them
        # all back and the conversion dropped the whole package once already.
        d.update({"isPushButton": n.get("isPushButton", "no"),
                  "isFlatButton": n.get("isFlatButton", "no"),
                  "useCustomLayout": n.get("useCustomLayout", "no"),
                  "css": txt(n, "css"),
                  "commandButtonUp": txt(n, "commandButtonUp"),
                  "commandButtonDown": txt(n, "commandButtonDown"),
                  "icon": txt(n, "icon")})
        for tag in ("orientation", "location", "posX", "posY", "mButtonState",
                    "sizeX", "sizeY", "buttonColumn", "buttonRotation"):
            d[tag] = txt(n, tag)
    return d

def collect(path, kind):
    """Return {logical_path: [descriptor,...]} keyed by name-path.

    Only the matching <XxxPackage> wrapper is searched. Mudlet dispatches on
    that tag and hands anything else to readUnknownElement, a qDebug line - so
    a trigger tree sitting in <ScriptPackage> never fires. Scanning every
    wrapper for the item tag made that invisible: the items were all present,
    all identical, and all dead."""
    group = LEAF_OF[kind]
    wrapper = kind + "Package"
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
        if pkg.tag != wrapper:
            continue
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
