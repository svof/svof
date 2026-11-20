"""Test for NameDB's classes column: the SQL in ndb.classes_sql
(src/scripts/svo (namedb)/NameDB/ndb.init.lua), run in a real SQLite.

People can hold several classes and switch between them. Everything that
learns a class writes the current one to people.class, and two SQLite triggers
add each one written to people.classes. This takes the statements from the
shipped file, builds a people table the way Mudlet's db:create does, and
writes classes the ways Mudlet's db:add and db:update and svof's
ndb.fixed_set do. It proves the SQL, not Mudlet's LuaSQL or the game.

Run: python tools/test_ndb_classes.py
Exits 0 and prints "ALL PASS" on success, exits 1 and prints failures.
"""
import re
import sqlite3
import sys

SRC = "src/scripts/svo (namedb)/NameDB/ndb.init.lua"

with open(SRC, encoding="utf-8") as f:
    source = f.read()
block = re.search(r"ndb\.classes_sql = \{(.*?)\n\}", source, re.S)
if not block:
    sys.exit("ndb.classes_sql not found in %s - update this test's anchor" % SRC)
statements = re.findall(r"\[\[(.*?)\]\]", block.group(1), re.S)
if len(statements) != 3:
    sys.exit("expected 3 statements in ndb.classes_sql, found %d" % len(statements))

checks, failures = 0, []


def eq(actual, expected, label):
    global checks
    checks += 1
    if actual != expected:
        failures.append("%s: expected %r, got %r" % (label, expected, actual))


def fresh(rows=()):
    db = sqlite3.connect(":memory:")
    # the shape db:create builds: _row_id first, then the schema's columns
    db.execute('CREATE TABLE people ("_row_id" INTEGER PRIMARY KEY AUTOINCREMENT, '
               '"name" TEXT NULL DEFAULT "", "class" TEXT NULL DEFAULT "", '
               '"city" TEXT NULL DEFAULT "", "classes" TEXT NULL DEFAULT "", '
               'UNIQUE ("name") ON CONFLICT REPLACE)')
    for name, cls in rows:
        db.execute('INSERT INTO people ("name", "class") VALUES (?, ?)', (name, cls))
    for sql in statements:
        db.execute(sql)
    return db


def classes(db, name):
    return db.execute('SELECT classes FROM people WHERE name = ?', (name,)).fetchone()[0]


def add(db, name, cls, city="rogue"):
    # db:add: INSERT of the fields given
    db.execute('INSERT INTO people ("name", "class", "city") VALUES (?, ?, ?)', (name, cls, city))


def update(db, name, **fields):
    # db:update after db:merge_unique's fetch: every column the row has, from
    # the fetched values with the new ones laid over them
    row = dict(zip(["_row_id", "name", "class", "city", "classes"],
                   db.execute('SELECT _row_id, name, class, city, classes FROM people WHERE name = ?',
                              (name,)).fetchone()))
    row.update(fields)
    db.execute('UPDATE OR REPLACE people SET "name" = ?, "class" = ?, "city" = ?, "classes" = ? '
               'WHERE _row_id = ?', (row["name"], row["class"], row["city"], row["classes"], row["_row_id"]))


def fixed_set(db, name, cls):
    # ndb.fixed_set: UPDATE OR <violations> people SET "class" = ... WHERE ...
    db.execute('UPDATE OR REPLACE people SET "class" = ? WHERE "name" = ?', (cls, name))


# the backfill, for people whose class was known before the column existed
db = fresh([("Alpha", "monk"), ("Bravo", ""), ("Charlie", "Dragon"), ("Delta", "Serpent")])
eq(classes(db, "Alpha"), "monk", "a class known before the column is filled in")
eq(classes(db, "Bravo"), "", "no class, nothing filled in")
eq(classes(db, "Charlie"), "", "dragon is a form, not a class")
eq(classes(db, "Delta"), "serpent", "classes are stored lower-case")
for sql in statements:
    db.execute(sql)
eq(classes(db, "Alpha"), "monk", "running the statements again changes nothing")

# writes through each path
db = fresh()
add(db, "Echo", "runewarden")
eq(classes(db, "Echo"), "runewarden", "a new person's class is recorded")
update(db, "Echo", **{"class": "bard"})
eq(classes(db, "Echo"), "runewarden,bard", "a second class is added, in the order seen")
update(db, "Echo", city="Eleusis")
eq(classes(db, "Echo"), "runewarden,bard", "an update that keeps the class adds nothing")
fixed_set(db, "Echo", "runewarden")
eq(classes(db, "Echo"), "runewarden,bard", "switching back to a known class doesn't repeat it")
fixed_set(db, "Echo", "Monk")
eq(classes(db, "Echo"), "runewarden,bard,monk", "fixed_set, as ndb.setclass uses, records it too, lower-cased")
update(db, "Echo", **{"class": "MONK"})
eq(classes(db, "Echo"), "runewarden,bard,monk", "case doesn't make it a new class")
update(db, "Echo", **{"class": "dragon"})
eq(classes(db, "Echo"), "runewarden,bard,monk", "turning dragon adds no class")
eq(db.execute("SELECT class FROM people WHERE name = 'Echo'").fetchone()[0], "dragon",
   "and class still holds what was written: the current one")
update(db, "Echo", **{"class": ""})
eq(classes(db, "Echo"), "runewarden,bard,monk", "an empty class adds nothing")

# one class's name inside another's mustn't count as known
db = fresh()
add(db, "Foxtrot", "magi")
update(db, "Foxtrot", **{"class": "mag"})
eq(classes(db, "Foxtrot"), "magi,mag", "a name that is part of a known one is still new")

if failures:
    print("%d of %d checks FAILED:" % (len(failures), checks))
    for f in failures:
        print("  " + f)
    sys.exit(1)
print("ALL PASS (%d checks)" % checks)
