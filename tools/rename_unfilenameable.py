#!/usr/bin/env python3
"""
rename_unfilenameable.py -- rename items whose names cannot become filenames.

muddler resolves an item's script by looking for "<name>.lua", replacing spaces
with underscores and nothing else. A name containing a character that is not
legal in a filename therefore cannot use an external file, and its code has to
be inlined into the json instead.

That is tolerable for a one-line trigger and not tolerable for the actions
dictionary, which is half a megabyte and the most edited file in the system.

Renames are chosen to read naturally rather than by blind substitution:

    '/'      -> '-'          Stuttering/clumsiness -> Stuttering-clumsiness
    ' *'     -> ''           (tn *) Turn things on -> (tn) Turn things on
    ' :(' etc-> ''           you lose :(           -> you lose

    python tools/rename_unfilenameable.py            # dry run
    python tools/rename_unfilenameable.py --apply
"""
import argparse, csv, glob, os, re, shutil, sys
import xml.etree.ElementTree as ET
from xml.sax.saxutils import escape

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ILLEGAL = set('<>:"/\\|?*')
NAME_RE = re.compile(r"<name>(.*?)</name>", re.S)


def new_name(old):
    n = old
    n = re.sub(r"\s*:\(", "", n)          # trailing sad face
    n = re.sub(r"\s*:\|", "", n)          # trailing shrug face
    n = re.sub(r"\s+\*", "", n)           # "(tn *)" -> "(tn)"
    n = n.replace("/", "-")
    n = "".join(c for c in n if c not in ILLEGAL)
    n = re.sub(r"\s{2,}", " ", n).strip()
    return n


def named_elements(root):
    out = []
    def walk(node):
        for c in list(node):
            if c.find("name") is not None:
                out.append(c)
            walk(c)
    walk(root)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--csv", default=os.path.join(REPO, "tools", "renames_filenames.csv"))
    a = ap.parse_args()

    rows = []
    for path in sorted(glob.glob(os.path.join(REPO, "svo (*).xml"))):
        text = open(path, encoding="utf-8", newline="").read()
        root = ET.fromstring(text)
        elements = named_elements(root)
        matches = list(NAME_RE.finditer(text))
        if len(elements) != len(matches):
            print(f"  !! {os.path.basename(path)}: element/tag count mismatch, skipped")
            continue

        edits = []
        for i, elem in enumerate(elements):
            raw = matches[i].group(1)
            # Test the decoded name: '<' and '>' arrive as &lt; / &gt; in the
            # raw text, so checking that would miss them, while muddler sees
            # the decoded form.
            decoded = elem.findtext("name") or ""
            if not (set(decoded) & ILLEGAL):
                continue
            old = decoded
            new = new_name(old)
            if not new or new == old:
                print(f"  !! {old!r}: cannot derive a usable name, skipped")
                continue
            edits.append((matches[i].start(1), matches[i].end(1), old, new, elem.tag))

        for _, _, old, new, tag in edits:
            rows.append({"file": os.path.basename(path), "type": tag,
                         "old_name": old, "new_name": new})

        for start, end, old, new, tag in sorted(edits, key=lambda e: -e[0]):
            # Re-escape. The name compared and rewritten here is the DECODED
            # one - it has to be, since '<' arrives as &lt; and checking the
            # raw text would miss it - but what goes back is raw XML. Splicing
            # a decoded name in unescaped means an '&' in a name produces a
            # reference xml that no longer parses. Latent today, since no name
            # has both an illegal character and an '&', but ten names carry
            # &amp; and it is one '/' away from being live.
            text = text[:start] + escape(new) + text[end:]

        if edits and a.apply:
            # The reference xmls are the only copy of the pre-conversion
            # system, and this rewrites them in place. Keep the original beside
            # it rather than trusting that whoever runs this has a clean tree.
            backup = path + ".pre-rename"
            if not os.path.exists(backup):
                shutil.copyfile(path, backup)
            with open(path, "w", encoding="utf-8", newline="") as f:
                f.write(text)
        if edits:
            print(f"  {os.path.basename(path):48s} {len(edits)} renamed")

    # Only a real run may touch the record, and only when it has something to
    # record. Writing it on a dry run rewrote the CSV as a bare header, and
    # check_renamed_callsites.py is driven entirely by that CSV, so the gate
    # then went green having checked nothing at all. Guarding only the dry run
    # left the same hole one step away: the renames are applied now, so a
    # second --apply finds nothing and truncates the record just as thoroughly.
    if a.apply and rows:
        existing = 0
        if os.path.exists(a.csv):
            with open(a.csv, encoding="utf-8") as fh:
                existing = sum(1 for _ in csv.DictReader(fh))
        if len(rows) < existing:
            print(f"\nREFUSED: this run found {len(rows)} renames but {a.csv} "
                  f"already records {existing}. Writing would lose the "
                  f"difference; the record is what the CI gate checks against.")
            return 1
        with open(a.csv, "w", encoding="utf-8", newline="") as fh:
            w = csv.DictWriter(fh, fieldnames=["file", "type", "old_name", "new_name"])
            w.writeheader()
            w.writerows(rows)

    if a.apply:
        if rows:
            print(f"\nAPPLIED: {len(rows)} renames -> {a.csv}")
        else:
            print(f"\nAPPLIED: nothing to rename; {a.csv} left alone")
    else:
        print(f"\nDRY RUN: {len(rows)} renames found; {a.csv} left alone")
    return 0


if __name__ == "__main__":
    sys.exit(main())
