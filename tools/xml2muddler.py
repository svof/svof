#!/usr/bin/env python3
"""
xml2muddler.py -- convert a Mudlet package XML into a muddler project.

Written for svof. Deliberately avoids the three data-loss bugs found in
DeMuddler, all reported upstream:
  * duplicate sibling folder names -> disambiguated directories, nothing overwritten
  * leaf items alongside subfolders -> always emitted
  * same-named items in one directory -> script inlined rather than silently sharing a file

Filename convention: muddler looks up "$name.lua" with spaces replaced by
underscores. Any name that cannot round-trip through that rule (e.g. contains
'/') has its script inlined into the JSON instead, because muddler would
otherwise silently produce an empty script.

Usage:
    python xml2muddler.py <input.xml> <output_dir> [--package NAME]
"""
import argparse, json, os, re, sys
import xml.etree.ElementTree as ET

# Mudlet <integer> pattern codes -> muddler type strings.
# Codes 0-5,7 derived empirically from svof data; 6 from muddler docs.
PATTERN_TYPES = {
    "0": "substring", "1": "regex", "2": "startOfLine", "3": "exactMatch",
    "4": "lua", "5": "spacer", "6": "color", "7": "prompt",
}

ILLEGAL = set('<>:"/\\|?*')

# Mudlet's on-disk spelling for a colour pattern, "FG<n>BG<m>", holds a legacy
# palette index -- NOT an ANSI number. XMLimport::remapColorsToAnsiNumber
# rewrites every one of them on load and re-spells the result as
# ANSI_COLORS_F{fg}_B{bg}. Its remap regex only matches the legacy spelling, so
# a package that already ships the modern spelling is never remapped again.
#
# That is the trap: copying the numbers across verbatim and letting muddler
# re-spell them as ANSI_COLORS_F{n}_B{m} hands Mudlet a legacy index in a field
# it now reads as ANSI. The trigger then waits on a colour the game never
# sends, and for a multiline trigger that kills the whole trigger, because the
# colour line is an AND-condition. Remap here so the project holds true ANSI.
#
# Transcribed from Mudlet src/XMLimport.cpp (its fg and bg switches are
# identical); the sentinels are from src/TTrigger.cpp -- scmDefault -2 and
# scmIgnored -1, spelled DEFAULT and IGNORE by createColorPatternText.
LEGACY_TO_ANSI = {
    -2: "IGNORE",      # "ignored" under the old numbering
    0:  "DEFAULT",     # default colour
    1:  "8",           # light black (dark gray)
    2:  "0",           # black
    3:  "9",           # light red
    4:  "1",           # red
    5:  "10",          # light green
    6:  "2",           # green
    7:  "11",          # light yellow
    8:  "3",           # yellow
    9:  "12",          # light blue
    10: "4",           # blue
    11: "13",          # light magenta
    12: "5",           # magenta
    13: "14",          # light cyan
    14: "6",           # cyan
    15: "15",          # light white
    16: "7",           # white (light gray)
}


def legacy_colour_to_ansi(n):
    """One half of a legacy FG<n>BG<m> pair -> the spelling Mudlet now uses.

    Anything outside the remapped range passes through unchanged, matching the
    `default:` arm of Mudlet's switch."""
    return LEGACY_TO_ANSI.get(n, str(n))


PACKAGES = {
    "TriggerPackage": ("triggers", "Trigger", "TriggerGroup"),
    "AliasPackage":   ("aliases",  "Alias",   "AliasGroup"),
    "ScriptPackage":  ("scripts",  "Script",  "ScriptGroup"),
    "TimerPackage":   ("timers",   "Timer",   "TimerGroup"),
    "KeyPackage":     ("keys",     "Key",     "KeyGroup"),
    "ActionPackage":  ("buttons",  "Action",  "ActionGroup"),
}

warnings = []


def warn(msg):
    warnings.append(msg)


def text(node, tag, default=""):
    v = node.findtext(tag)
    return default if v is None else v


def lua_filename(name):
    """muddler's lookup rule: spaces -> underscores. Returns None if the
    resulting name would not be a usable filename."""
    cand = name.replace(" ", "_")
    if not cand or any(ch in ILLEGAL for ch in cand):
        return None
    if cand in (".", ".."):
        return None
    return cand + ".lua"


def safe_dirname(name):
    """Directory name for a folder. Illegal chars replaced; caller
    disambiguates collisions."""
    out = "".join("_" if ch in ILLEGAL else ch for ch in name)
    out = out.strip().rstrip(".")
    return out or "unnamed"


def yn(node, attr, default="no"):
    v = node.get(attr)
    return v if v in ("yes", "no") else default


# ---------------------------------------------------------------- item builders

def build_trigger(n):
    d = {
        "name": text(n, "name"),
        "isActive": yn(n, "isActive", "yes"),
        "isFolder": yn(n, "isFolder"),
        "multiline": yn(n, "isMultiline"),
        "multilineDelta": text(n, "conditonLineDelta", "0"),
        "filter": yn(n, "isFilterTrigger"),
        # perl /g. Dropping this silently changes what the trigger captures:
        # without it Mudlet stops at the first match on the line, so a rift
        # line holding several "[ N ] herb" entries yields one match set
        # instead of one per entry, and svo.riftline() records only the first.
        "matchall": yn(n, "isPerlSlashGOption"),
        "fireLength": text(n, "mStayOpen", "0"),
        "highlight": yn(n, "isColorizerTrigger"),
    }
    fg, bg = text(n, "mFgColor"), text(n, "mBgColor")
    if fg: d["highlightFG"] = fg
    if bg: d["highlightBG"] = bg
    snd = text(n, "mSoundFile")
    if snd: d["soundFile"] = snd
    cmd = text(n, "mCommand")
    if cmd: d["command"] = cmd

    pats, codes = n.find("regexCodeList"), n.find("regexCodePropertyList")
    plist = []
    if pats is not None:
        pt = [p.text or "" for p in pats]
        ct = [c.text or "" for c in codes] if codes is not None else []
        if len(ct) != len(pt):
            warn(f"trigger {d['name']!r}: {len(pt)} patterns but {len(ct)} type codes")
        for i, p in enumerate(pt):
            code = ct[i] if i < len(ct) else "1"
            typ = PATTERN_TYPES.get(code)
            if typ is None:
                warn(f"trigger {d['name']!r}: unknown pattern type code {code!r}, defaulting to regex")
                typ = "regex"
            if typ == "color":
                # Mudlet stores colour patterns as "FG<n>BG<m>"; muddler wants
                # "<fg>,<bg>" and splits on the comma (it crashes without one).
                # The numbers are legacy palette indices and must be remapped,
                # not copied across -- see LEGACY_TO_ANSI.
                m = re.match(r"^FG(-?\d+)BG(-?\d+)$", p.strip())
                if m:
                    fg = legacy_colour_to_ansi(int(m.group(1)))
                    bg = legacy_colour_to_ansi(int(m.group(2)))
                    p = f"{fg},{bg}"
                else:
                    warn(f"trigger {d['name']!r}: unrecognised colour pattern {p!r} "
                         f"-- left as-is, muddler may reject it")
            plist.append({"pattern": p, "type": typ})
    d["patterns"] = plist
    return d


def build_alias(n):
    d = {
        "name": text(n, "name"),
        "isActive": yn(n, "isActive", "yes"),
        "isFolder": yn(n, "isFolder"),
        "regex": text(n, "regex"),
    }
    cmd = text(n, "command")
    if cmd: d["command"] = cmd
    return d


def build_script(n):
    d = {
        "name": text(n, "name"),
        "isActive": yn(n, "isActive", "yes"),
        "isFolder": yn(n, "isFolder"),
    }
    eh = n.find("eventHandlerList")
    events = [e.text or "" for e in eh] if eh is not None else []
    if events:
        d["eventHandlerList"] = events
    return d


def build_timer(n):
    d = {
        "name": text(n, "name"),
        "isActive": yn(n, "isActive", "yes"),
        "isFolder": yn(n, "isFolder"),
        "time": text(n, "time", "0"),
    }
    cmd = text(n, "command")
    if cmd: d["command"] = cmd
    return d


def build_key(n):
    d = {
        "name": text(n, "name"),
        "isActive": yn(n, "isActive", "yes"),
        "isFolder": yn(n, "isFolder"),
        "keyCode": text(n, "keyCode", "0"),
        "keyModifier": text(n, "keyModifier", "0"),
    }
    cmd = text(n, "command")
    if cmd: d["command"] = cmd
    return d


def build_button(n):
    # Mudlet calls these Action/ActionGroup in the xml and buttons everywhere
    # else; muddler's item type is "buttons". The layout numbers are bare
    # integers Mudlet is unforgiving about, so they are always carried rather
    # than emitted only when non-default.
    d = {
        "name": text(n, "name"),
        "isActive": yn(n, "isActive", "yes"),
        "isFolder": yn(n, "isFolder"),
        "isPushButton": yn(n, "isPushButton"),
        "isFlatButton": yn(n, "isFlatButton"),
        "useCustomLayout": yn(n, "useCustomLayout"),
        "orientation": text(n, "orientation", "0"),
        "location": text(n, "location", "0"),
        "posX": text(n, "posX", "0"),
        "posY": text(n, "posY", "0"),
        "mButtonState": text(n, "mButtonState", "1"),
        "sizeX": text(n, "sizeX", "0"),
        "sizeY": text(n, "sizeY", "0"),
        "buttonColumn": text(n, "buttonColumn", "1"),
        "buttonRotation": text(n, "buttonRotation", "0"),
    }
    for tag in ("css", "commandButtonUp", "commandButtonDown", "icon", "buttonColor"):
        v = text(n, tag)
        if v:
            d[tag] = v
    return d


BUILDERS = {
    "Trigger": build_trigger, "Alias": build_alias, "Script": build_script,
    "Timer": build_timer, "Key": build_key, "Action": build_button,
}


# ---------------------------------------------------------------- emission

class Emitter:
    def __init__(self, outdir, kind):
        self.root = os.path.join(outdir, "src", kind)
        self.kind = kind
        self.stats = {"items": 0, "folders": 0, "lua_files": 0, "inlined": 0}

    def _colliding_filenames(self, nodes, leaf_tag, group_tag):
        """Names in this directory that would map to the same .lua file.

        muddler loads "$name.lua" implicitly for any item whose script is
        empty, so if two items in a directory share a name the one with a
        genuinely empty script would silently inherit the other's code. Every
        item in a colliding set therefore has to be inlined instead.
        """
        counts = {}
        def scan(ns):
            for n in ns:
                if n.tag not in (leaf_tag, group_tag):
                    continue
                fn = lua_filename(text(n, "name"))
                if fn:
                    counts[fn.lower()] = counts.get(fn.lower(), 0) + 1
                is_folder = yn(n, "isFolder") == "yes" or n.tag == group_tag
                if not is_folder:
                    # chained children share this directory
                    scan([c for c in n if c.tag in (leaf_tag, group_tag)])
        scan(nodes)
        return {k for k, v in counts.items() if v > 1}

    def emit_dir(self, dirpath, nodes, leaf_tag, group_tag):
        """Emit one directory level. `nodes` is the list of XML child elements."""
        os.makedirs(dirpath, exist_ok=True)
        entries = []
        used_dirnames = {}
        used_luanames = set()
        self._collisions = self._colliding_filenames(nodes, leaf_tag, group_tag)
        saved_collisions_for_this_level = self._collisions

        for n in nodes:
            if n.tag not in (leaf_tag, group_tag):
                continue
            is_folder = yn(n, "isFolder") == "yes" or n.tag == group_tag
            item = BUILDERS[leaf_tag](n)
            item["isFolder"] = "yes" if is_folder else "no"
            name = item["name"]
            script = text(n, "script")
            kids = [c for c in n if c.tag in (leaf_tag, group_tag)]

            if is_folder:
                self.stats["folders"] += 1
                # A name that cannot be a directory (contains '/', ':' etc.)
                # must live entirely in the parent json, otherwise we would
                # emit a correctly-named empty group AND a renamed directory
                # holding the real children.
                if safe_dirname(name) != name:
                    warn(f"[{self.kind}] folder {name!r}: name is not usable as a "
                         f"directory -- emitted inline in the parent json")
                    fentry = dict(item)
                    self._place_script(dirpath, name, script, used_luanames, fentry)
                    if kids:
                        fentry["children"] = self._emit_children(
                            dirpath, kids, leaf_tag, group_tag, used_luanames)
                    entries.append(fentry)
                    continue
                base = safe_dirname(name)
                key = base.lower()
                if key in used_dirnames:
                    # A sibling directory of this name already exists. Renaming
                    # it would rename the Mudlet group, so emit this one inline
                    # under its true name instead -- muddler merges same-named
                    # sibling groups, which keeps every child and the name.
                    warn(f"[{self.kind}] duplicate folder name {name!r} in "
                         f"{os.path.relpath(dirpath, self.root)!r} -- emitted inline "
                         f"and merged with the earlier group of the same name")
                    fentry = dict(item)
                    self._place_script(dirpath, name, script, used_luanames, fentry)
                    if kids:
                        fentry["children"] = self._emit_children(
                            dirpath, kids, leaf_tag, group_tag, used_luanames)
                    entries.append(fentry)
                    continue
                used_dirnames[key] = 1
                sub = os.path.join(dirpath, base)
                # Always declare the folder in the PARENT json. muddler would
                # otherwise infer the group from the directory alone and reset
                # its attributes to defaults -- notably isActive, so a disabled
                # group would come back enabled. Children still come from the
                # directory; muddler merges the declaration with it.
                fentry = dict(item)
                self._place_script(dirpath, name, script, used_luanames, fentry)
                entries.append(fentry)
                if kids:
                    self.emit_dir(sub, kids, leaf_tag, group_tag)
                    self._collisions = saved_collisions_for_this_level
                else:
                    os.makedirs(sub, exist_ok=True)
            else:
                self.stats["items"] += 1
                self._place_script(dirpath, name, script, used_luanames, item)
                if kids:
                    # chained item: children nest in JSON, their .lua files land
                    # in this same directory (that is where the json lives).
                    item["children"] = self._emit_children(
                        dirpath, kids, leaf_tag, group_tag, used_luanames)
                entries.append(item)

        if entries:
            with open(os.path.join(dirpath, f"{self.kind}.json"), "w",
                      encoding="utf-8", newline="\n") as f:
                json.dump(entries, f, indent=2, ensure_ascii=False)
                f.write("\n")

    def _emit_children(self, dirpath, kids, leaf_tag, group_tag, used_luanames):
        out = []
        for n in kids:
            item = BUILDERS[leaf_tag](n)
            item["isFolder"] = yn(n, "isFolder")
            self.stats["items"] += 1
            self._place_script(dirpath, item["name"], text(n, "script"),
                               used_luanames, item)
            sub = [c for c in n if c.tag in (leaf_tag, group_tag)]
            if sub:
                item["children"] = self._emit_children(
                    dirpath, sub, leaf_tag, group_tag, used_luanames)
            out.append(item)
        return out

    def _place_script(self, dirpath, name, script, used_luanames, item):
        """Write script to <name>.lua if safely possible; else inline it.
        Returns True if an external file was written."""
        if not script.strip():
            return False
        fn = lua_filename(name)
        if fn is None:
            warn(f"[{self.kind}] {name!r}: name cannot map to a .lua filename "
                 f"(muddler only maps spaces) -- script inlined into JSON")
            item["script"] = script
            self.stats["inlined"] += 1
            return False
        if fn.lower() in getattr(self, "_collisions", set()):
            # Another item here has the same name. muddler would load this
            # file implicitly for whichever of them has an empty script, so
            # none of them may use it.
            item["script"] = script
            self.stats["inlined"] += 1
            return False
        if fn.lower() in used_luanames:
            warn(f"[{self.kind}] {name!r} in {os.path.relpath(dirpath, self.root)!r}: "
                 f"{fn} already used by another item -- script inlined into JSON")
            item["script"] = script
            self.stats["inlined"] += 1
            return False
        used_luanames.add(fn.lower())
        with open(os.path.join(dirpath, fn), "w", encoding="utf-8", newline="\n") as f:
            f.write(script)
        self.stats["lua_files"] += 1
        return True


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("xml")
    ap.add_argument("outdir")
    ap.add_argument("--package")
    ap.add_argument("--version", default="1.0.0")
    ap.add_argument("--author", default="Svof contributors")
    a = ap.parse_args()

    pkg = a.package or os.path.splitext(os.path.basename(a.xml))[0]
    root = ET.parse(a.xml).getroot()

    os.makedirs(a.outdir, exist_ok=True)
    mfile = {"package": pkg, "title": pkg, "version": a.version, "author": a.author}
    with open(os.path.join(a.outdir, "mfile"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(mfile, f, indent=2)
        f.write("\n")

    totals = {}
    for pkgtag, (kind, leaf, group) in PACKAGES.items():
        node = root.find(pkgtag)
        if node is None:
            continue
        kids = [c for c in node if c.tag in (leaf, group)]
        if not kids:
            continue
        em = Emitter(a.outdir, kind)
        em.emit_dir(em.root, kids, leaf, group)
        totals[kind] = em.stats

    # things muddler has no place for
    help_url = root.findtext("HelpPackage/helpURL")
    if help_url:
        warn(f"HelpPackage/helpURL is not representable in muddler: {help_url!r}")

    # Any other *Package the module carries is silently dropped otherwise. That
    # is how the 8-button ActionPackage went missing without a word: the loop
    # above only visits tags in PACKAGES, and anything else falls off the end.
    # Buttons no longer fall off that end - ActionPackage is in PACKAGES and
    # build_button emits them - but the warning stays, because the next item
    # type Mudlet adds would go the same way.
    for child in root:
        if not child.tag.endswith("Package") or child.tag in PACKAGES:
            continue
        if child.tag == "HelpPackage":
            continue
        n = sum(1 for _ in child.iter() if _ is not child)
        if n:
            warn(f"{child.tag} is not handled and was dropped "
                 f"({n} element(s) below it) - nothing in muddler emits these")

    print(f"package: {pkg}")
    for k, s in totals.items():
        print(f"  {k:9s} items={s['items']:5d} folders={s['folders']:3d} "
              f"lua={s['lua_files']:5d} inlined={s['inlined']:3d}")
    if warnings:
        print(f"\nWARNINGS ({len(warnings)}):")
        for w in warnings:
            print("  - " + w)
    else:
        print("\nno warnings")


if __name__ == "__main__":
    main()
