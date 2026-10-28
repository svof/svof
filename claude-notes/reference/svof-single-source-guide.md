# Making `svo.dict` the single source of truth

Adding one affliction to svof takes eleven edits across five files. Nine of them
are the same edit: typing the affliction's name into another list. This is the
plan for reducing that to two, in six steps you can land and revert one at a
time.

---

## Before you start

**This is step 5 of the affliction name-space backlog. Four steps come first.**
Agreed with the repository owner on 2026-08-23; the full sequence is in
`claude/svof-system-spec.md` section 18.2.

| | work | state |
|---|---|---|
| 1 | Rename svof afflictions to match their GMCP names until `sstosvoa` is all identities plus `false`. Pull request 850, `flamefisted`, is the template. | first batch merged |
| 2 | The three remaining Striking fists: `galed`, `icing`, `voided`. | next |
| 3 | The four mangled limbs, the highest risk of the lot. | queued |
| 4 | Delete `svotossa` and `svotossd` and the gates that read them. | queued |
| **5** | **This document.** | **planned** |

Do not start before steps 1 to 3, for two reasons:

- **Every rename touches the same nine registration points this document
  collapses.** Done first, each rename is a find-and-replace across nine known
  places following a template 850 already proved. Done after, each one has to be
  re-expressed against a structure that no longer looks like the template.
- **Renames are structural to `verify_merged` and this work is not.** A rename
  must be declared in `ITEM_RENAME` with its `.lua` file renamed to match, and
  cannot be baselined. Everything here is a content difference that baselines
  normally. Keeping them apart keeps each commit's failure mode legible.

Step 3 is the exception. Its checker reads the lists as they stand and needs
nothing from the renames, so it can land today.

### How the numbers here are verified

Seven scripts re-derive every measurable claim from `src/` and exit non-zero on a
mismatch. They live in `svof-cowork-export/from-cowork/tools/`, **not** in the
repo's own `tools/`, which holds the build gates and is a different set
entirely. Run each from that directory with the repo root as the argument:

| script | what it settles |
|---|---|
| `check_guide_claims.py` | every count quoted below, expected against measured |
| `check_alsofocus.py` | focus-block equivalence, by truth table rather than text |
| `check_rage.py` | Step 6: the eight clauses against each other, which classes can reach the state they disagree on, and whether the one-line rewrite is faithful |
| `check_derived_lists.py` | Step 3 itself: what each list would derive from today |
| `check_defs_data.py` | Step 7: every `defs_data` key, who reads it, how the two tables are gated, and where a defence fact is written twice |
| `check_basicdef_spec.py` | Step 8: the six defup factorings by truth table, and every defence definition sorted into exactly one bucket |
| `check_formatting_hazards.py` | the spellings in svof that a regex gets wrong, asserted so one cannot reintroduce them |

Together they check 229 claims plus all 20 focus blocks. `decompose_defs.py`
prints the working behind Step 8's table without asserting anything, and
`lua_tokens.py` is the tokeniser the defence tools read the source with. Run them against a
current checkout: the one this was written from predates pull request 853.

Several claims in earlier drafts were wrong and the scripts are why they are not
wrong now. The specific mistakes, and what caused each, are recorded in
`claude/svof-system-spec.md` section 21 rather than here.

---

## The problem

Take `clumsiness`. Its name appears in:

| where | what the list means |
|---|---|
| `svo.dict` | the entry itself |
| `afflist` in *Simple aff trigger functions* | has a simple trigger, 154 names |
| the loop in *Diag trigger functions* | shows in DIAGNOSE, 151 names, `voyria` twice |
| `generic_cures_data` in *Main trigger functions* | can be cured passively, 111 names |
| the `tree` list in *Main trigger functions* | tree cures it, 85 names |
| `treecurables` in *Empty cure handling* | tree cures it, again, 80 names |
| the `kelp` map in *Main trigger functions* | kelp cures it |
| the `kelp` map in *Empty cure handling* | kelp cures it, again |
| `sstosvoa` in the dictionary | the game's name for it |
| `aff_abbrev` in *@affs* | its prompt tag |
| `default_prios` | its default priority |

Every one of those is a fact the entry could carry. None is enforced. Miss one
and nothing complains: the affliction quietly does not work in that one way.

**They have already drifted.** Comparing the nine herb lists in *Empty cure
handling* against the dictionary's own `eatcure` fields, four disagree. `ash` is
missing `crescendo` on the dictionary side; `bloodroot`, `kelp` and `pear` are
each missing one affliction the dictionary says they cure (`pyramides`,
`parasite`, `waterbubble`). The two tree lists disagree in 27 names.

Some of those differences are deliberate. `waterbubble` is a defence, so leaving
it out of an empty-cure handler is probably right. Nothing in the codebase can
tell you which is which, and that is the real cost: not the typing, but that no
mechanism distinguishes a deliberate exception from a missed edit.

---

## The idea

Two changes. **The first delivers the whole benefit. The second is optional.**

**Change A puts the facts on the entry and builds the lists from them.** Add a
few plain fields, have `dict_setup` build those eleven lists at load, delete the
hand-written ones. It touches no function: `isadvisable`, `oncompleted` and
`onstart` stay exactly as written. You add information and delete duplication.

**Change B generates the repetitive entries.** 122 of the 267 entries in the
main literal are near-identical boilerplate. A helper can build those from a
short description, the way `svo.basicdef` already builds simple defence entries
in 157 calls today.

Keep them apart. Change A is the point; Change B is a convenience some entries
take and others do not. An affliction with complicated logic, the burn ladder or
`healhealth`, takes Change A, skips Change B, and still gets every benefit.

### One entry, before and after

`clumsiness` today:

```lua
    clumsiness = {
      herb = {
        isadvisable = function()
          return (affs.clumsiness) or false
        end,

        oncompleted = function()
          svo.rmaff('clumsiness')
          svo.lostbal_herb()
        end,

        eatcure = {'kelp', 'aurum'},
        onstart = function() svo.eat(svo.dict.clumsiness.herb) end,

        empty = function() empty.eat_kelp() end
      },
      aff = {
        oncompleted = function()
          svo.addaffdict(svo.dict.clumsiness)
        end,
      },
      gone = {
        oncompleted = function() svo.rmaff('clumsiness') end,
      }
    },
```

After Change A, four lines added and nothing removed:

```lua
    clumsiness = {
      abbrev        = 'cl',     -- prompt tag
      tree          = true,     -- tree, dragonheal and shrugging cure it
      prio          = 233,      -- default priority
      simpletrigger = true,     -- has a simple trigger
      -- no gamename: the game calls it 'clumsiness' too
      -- nothing about focus: having no focus block IS the flag

      herb = { ... },           -- unchanged
      aff  = { ... },           -- unchanged
      gone = { ... },           -- unchanged
    },
```

After Change B as well:

```lua
    clumsiness = basicaff('clumsiness', {
      action        = 'eat',
      cure          = 'kelp',     -- aurum is derived, see Step 5b
      abbrev        = 'cl',
      tree          = true,
      prio          = 233,
      simpletrigger = true,
    }),
```

`basicaff` returns exactly the table above it. Same keys, same functions.

**The fields are flat values, not a nested table.** `dict_setup` walks every
entry and treats table-valued fields as balances, so a `meta = {}` would be
stamped with a name and a priority and become a phantom balance. Flat values
fall straight through, which is why `gamename`, `count` and `description`
already sit at the top level of real entries.

### This is not a change to how svof works

Three reasons, all checkable in the tree.

- **svof consumes a table, not a syntax.** The curing skeleton calls
  `j.p.salve.isadvisable()`. Nothing in `src/` inspects those functions: no
  `debug.getinfo`, no `string.dump`, no comparing them for equality. Whether the
  table was typed or returned by a helper is invisible.
- **`svo.basicdef` already does this**, in 157 calls over 134 names. The readme
  calls it one of the two supported ways to declare a defence.
- **`dict_setup` already generates parts of entries.** It fills in `name`,
  `balance`, `action_name` and priorities, adds a default `noeffect` to every
  herb balance, and builds a whole `gone` table for any defence lacking one.

The one thing that *would* be a core change is teaching the skeleton to
interpret conditions as data, reading `unless = {'madness'}` at runtime instead
of calling a function. Nothing here proposes that. Where shorthand like `unless`
appears in Change B it is read once at load and compiled into an ordinary
closure; after load there is no `unless` on the entry, just a function.

---

## Step 1. Add the fields

**Put the flat values on the entries. Nothing reads them yet, so nothing can
break.**

Work in batches by field rather than by affliction: all the `tree = true` flags
in one commit, all the `abbrev` values in the next. Each batch has an existing
list to copy from, so it is transcription with a source of truth, not judgement.

The one exception is `tree`, where the two existing lists disagree in 27 names.
That batch is the largest piece of judgement in the whole plan. Budget for it.

### Field names must not collide with balance names

This is the one way Step 1 can break something despite nothing reading the new
fields. `Curing_skeleton.lua` decides whether an affliction is focus-curable
like this:

```lua
    if ... and j.p.focus and ... and j.p.focus.isadvisable() and ... then
```

`j.p` is the entry, so `j.p.focus` means *does this entry have a focus balance*.
A `focus = true` field makes that true for an entry with no focus block, and the
next line calls `true.isadvisable()`: "attempt to index a boolean value", in the
focus curing pass.

The balance names in use are `aff`, `gone`, `waitingfor`, `herb`, `salve`,
`physical`, `misc`, `focus`, `smoke`, `sip`, `purgative`, `happened`, `moss`,
`map`, `tempmap`, `boosted`, `weakened`. Nothing may collide with those.
`abbrev`, `tree`, `prio` and `simpletrigger` are clear; `gamename` is already a
real field and is reused rather than added.

### Proving it

Build and run the gates. Adding a field changes the script text, so
`verify_merged.py` reports new content differences and the accepted-difference
count rises. That is expected: regenerate the baseline in the same commit. Any
*structural* finding means something went wrong. Stop, and do not rebaseline.

---

## Step 2. Build the derived tables

**Extend `svo.dict_setup()` with one pass that reads the new fields. Still
nothing consumes the results.**

```lua
  svo.aff_simple, svo.aff_generic, svo.aff_diag = {}, {}, {}
  svo.aff_tree,   svo.aff_focus                 = {}, {}
  svo.aff_abbrev, svo.cures_by_item             = {}, {}
  svo.sstosvoa_derived                          = {}

  for name, entry in pairs(svo.dict) do
    if entry.simpletrigger then svo.aff_simple[#svo.aff_simple+1]   = name end
    if entry.generic       then svo.aff_generic[#svo.aff_generic+1] = name end
    if entry.diag          then svo.aff_diag[#svo.aff_diag+1]       = name end
    if entry.tree          then svo.aff_tree[#svo.aff_tree+1]       = name end
    if entry.abbrev        then svo.aff_abbrev[name] = entry.abbrev end

    -- focus is the one list that IS derivable from shape, because having a
    -- focus block is what "focus can cure this" means. `focusempty = false`
    -- is the opt-out, and `fear` is the only entry needing it: see Step 5d.
    if entry.focus and entry.focusempty ~= false then
      svo.aff_focus[#svo.aff_focus+1] = name
    end

    -- gamename already exists and Serverside.lua already reads it this way.
    -- `gmcp = false` is the opt-out for the 26 names mapped to false in
    -- sstosvoa today, meaning "the game reports this, do not take it from GMCP".
    if entry.gmcp ~= false then
      svo.sstosvoa_derived[entry.gamename or name] = name
    end

    for _, balance in ipairs{'herb', 'salve', 'smoke', 'sip', 'purgative'} do
      local b = entry[balance]
      local items = b and (b.eatcure or b.applycure or b.smokecure or b.sipcure)
      if items then
        for _, item in ipairs(items) do
          svo.cures_by_item[item] = svo.cures_by_item[item] or {}
          local l = svo.cures_by_item[item]
          l[#l+1] = name
        end
      end
    end
  end

  -- pairs() does not iterate in a stable order. Sort everything.
  table.sort(svo.aff_simple)
  table.sort(svo.aff_generic)
  table.sort(svo.aff_diag)
  table.sort(svo.aff_tree)
  table.sort(svo.aff_focus)
  for _, l in pairs(svo.cures_by_item) do table.sort(l) end
```

**Sorting is not optional.** Lua's `pairs()` gives a different order on different
runs, and this project has already been bitten by that shape of bug: the muddler
directory-read-order problem, where the same sources built a differently ordered
package on Linux than on Windows. Treat an unsorted derived list as a defect even
where it currently looks harmless.

### Why the fields are declared and not inferred

The obvious shortcut is to infer each list from the entry's shape. Derive
`afflist` from "has an `aff` sub-table", `generic_cures_data` from "has a `gone`
sub-table". **All four such inferences are wrong.** Measured against the real
lists:

| inferred from | gives | the real list | verdict |
|---|---:|---|---|
| `entry.aff` | 180 | `afflist`, 154 | 26 too many |
| `entry.gone` | 189 | `generic_cures_data`, 111 | 80 too many, 2 missing |
| `entry.aff` | 180 | the diag loop, 151 | 35 too many, 6 missing |
| `entry.focus` | 20 | `focuscurables`, 18 | 2 too many |

The extras are entries that have an `aff` sub-table and are deliberately absent
from `afflist`: the eight `check*` predictions, the four counted fracture types,
and `hoisted`, `insomnia`, `latched`, `mindravaged`, `mucous`, `paradox`,
`parestoarms`, `parestolegs`, `pressure`, `tension`, `unknowncure` and the three
`unweaving*`.

**The missing side matters more**, because it shows the lists are not
projections of the dictionary at all. `generic_cures_data` contains `healhealth`
and `healmana`, which are not afflictions and have no `aff` sub-table. The diag
loop contains `godfeelings` and five fluid levels, likewise. Those names would
vanish silently the moment you switched the consumer over.

So each of the eleven lists is a fact the entry **could** know, not one it
already knows. Step 1 is where it learns it, and the field is the point.

Two lists behave differently:

- **`focus` really is derivable from shape**, because having a `focus` block is
  the definition of focus-curable. It gives 20 against `focuscurables`' 18, and
  the extras are `fear`, whose block is deliberately disabled, and `fulminated`,
  whose block is live and whose absence from the list is a bug. So the
  derivation fixes one and needs an opt-out for the other.
- **`tree` has two lists that already disagree in 27 names.** Deriving both from
  one `tree = true` forces a decision on all 27.

---

## Step 3. Write the checker before deleting anything

**Land this first. It reads the lists as they are and needs nothing else.**

A script that derives each list from the dictionary and diffs it against the
literal holding the same information. Run against the tree as it stands, before
any field is added, it prints the work Step 1 has to do:

```
python3 check_derived_lists.py

  aff_simple    vs afflist                  0 declared, 154 in the list
  aff_diag      vs diag loop                0 declared, 151 in the list
                   (152 tokens: voyria listed twice)
  aff_generic   vs generic_cures_data       0 declared, 111 in the list
                   (112 tokens: hallucinations listed twice)
  aff_tree      vs tree list                0 declared,  85 in the list
  aff_tree      vs treecurables            85 and  80, disagreeing in 27 names
                   only in tree list:    bleeding, bound, flamefisted, flushings, galed, icing, laceratedthroat, mildconcussion, mycalium, prone, pyramides, rebbies, sandfever, slashedthroat, tension, voided
                   only in treecurables: crackedribs, disrupt, fulminated, paralysis, skullfractures, torntendons, unknownany, unknowncrippledarm, unknowncrippledleg, unknownmental, wristfractures
  aff_focus     vs focuscurables           20 blocks,    18 in the list
                   only a block: fear         condition disabled, correct to exclude
                   only a block: fulminated   condition is LIVE, missing from the list
  note: empty.eat_bloodroot is redefined after the loop; using the live one
        generated paralysis, pyramides
        live      paralysis, slickness
  cures_by_item.ash         vs empty map        5 !=   6
                   only in the empty map:  crescendo
  cures_by_item.bellwort    vs empty map        9 ==   9 OK
  cures_by_item.bloodroot   vs empty map        3 !=   2
                   only in the dictionary: pyramides
  cures_by_item.ginger      vs empty map        4 ==   4 OK
  cures_by_item.ginseng     vs empty map        7 ==   7 OK
  cures_by_item.goldenseal  vs empty map       12 ==  12 OK
  cures_by_item.kelp        vs empty map        8 !=   7
                   only in the dictionary: parasite
  cures_by_item.lobelia     vs empty map        9 ==   9 OK
  cures_by_item.pear        vs empty map        2 !=   1
                   only in the dictionary: waterbubble
```

The counts on the left climb as Step 1 transcribes each list onto the entries,
and the run is green when every derived set equals its literal. Give it a
baseline file the way `verify_merged.py` has one, so it fails on anything new.
Run it as a report first and promote it to a gate once the baseline settles.

Every difference it prints is a decision waiting to be made. Four are already
known and none needs the refactor to fix: `parasite`, `pyramides` and
`waterbubble` are in the dictionary's cure lists and missing from the matching
empty handler, and `fulminated` has a live focus block and is missing from
`focuscurables`. All four are invisible without a checker, which is the argument
for writing it first.

**The `bloodroot` note in that output is worth reading twice.** *Empty cure
handling* generates `empty.eat_<herb>` in a loop and then **redefines**
`empty.eat_bloodroot` below it. A checker reading the generated map alone reports
the wrong set for that one herb. This one reads the live definition and says so.

---

## Step 4. Switch the consumers, one per commit

**Now delete the hand-written lists. One list, one commit, easiest to prove
first.**

1. `afflist` in *Simple aff trigger functions* to `svo.aff_simple`
2. the loop in *Diag trigger functions* to `svo.aff_diag`
3. `generic_cures_data` in *Main trigger functions* to `svo.aff_generic`
4. the `tree` list and `treecurables` to `svo.aff_tree`
5. both herb maps to `svo.cures_by_item`
6. `aff_abbrev` in *@affs* to `svo.aff_abbrev`
7. `sstosvoa` to the derived table

Step 4.1 turns this:

```lua
  local afflist = {'ablaze', 'severeburn', ... }   -- 154 names

  for _,j in ipairs(afflist) do
    valid['simple' .. j] = function () ... end
  end
```

into this:

```lua
  for _,j in ipairs(svo.aff_simple) do
    valid['simple' .. j] = function () ... end
  end
```

The checker proved the two identical before you deleted the literal. That is the
whole safety argument.

**Step 4.5 does more than delete a list.** The herb map in *Empty cure handling*
is not a copy of the same information, it is the **definition** of the empty
handlers:

```lua
for herbname, herbaffs in pairs({ kelp = {...}, goldenseal = {...}, ... }) do
  empty['eat_'..herbname] = function()
    svo.lostbal_herb()
    if not affs.madness then svo.rmaff(herbaffs)
    else svo.rmaff(table.n_complement(herbaffs, madness_affs)) end
  end
end
```

`empty.eat_kelp` clears whatever that hardcoded list says kelp cures. The moment
the map becomes `svo.cures_by_item`, the empty handlers are built from the
dictionary and the drift stops being a decision you have to make. It becomes
impossible, and the missing `parasite` fixes itself.

**At the end of Step 4, adding an affliction is two steps instead of eleven:**
write the entry, add the triggers.

---

## Step 5. Generate the simple entries

**Optional, and only after Steps 1 to 4.** Before then a helper would move the
boilerplate around without reducing the number of places you edit.

### 5a. What `empty` and `noeffect` mean

An action resolves down one of several named branches. Three matter here, and
each tells svof that a *different* thing it believed was wrong:

| branch | what the game said | what svof learns |
|---|---|---|
| `oncompleted` | the cure worked | the affliction is gone |
| `empty` | the cure happened and cured nothing | **my affliction tracking was wrong**: I had none of the things this cure treats |
| `noeffect` | the attempt did nothing at all | **my balance tracking was wrong**: I was still off this balance |

`noeffect` is the off-balance case. You have paralysis and slickness, both
bloodroot. You eat bloodroot, it cures paralysis, you eat again straight away for
the slickness and the game says no effect, because herb balance has not returned.
svof thought it had the balance or it would not have tried, so the useful thing
is to record that it does not.

`empty` is the affliction-tracking case. The cure went off properly and cured
nothing, so you had none of the things that cure treats and svof clears them all.
It is a self-correction, and it also catches an affliction force-added by hand.

The mechanism is in `Action_system.lua`: an action's `completed` handler calls
`act[other_action or 'oncompleted'](arg)`, where `other_action` is the branch
name. `svo.valid.plant_had_no_effect` and `svo.valid.salve_had_no_effect` pick
`'noeffect'`; `svo.valid.plant_cured_nothing` and its siblings pick `'empty'`.

**`empty` belongs to the cure, not the affliction.** Every kelp-cured affliction
points at the same `empty.eat_kelp`, so the entry never has to name its handler:
it follows from `cures`. Across the 86 entries that have one there are two
idioms, and which applies also follows from the cure:

- **the cure treats several afflictions** (herbs, the elm and valerian pipes):
  call `empty.<cure>()`, which clears all of them.
- **the cure treats exactly one** (limb salves, epidermal to a named part): call
  the entry's own `oncompleted()`, because "clear the one thing this could have
  cured" and "it got cured" are the same operation.

Both follow from `svo.cures_by_item`: more than one affliction means the first
idiom, otherwise the second.

**`svo.lostbal_herb()` records that herb balance was spent. It does not give it
back.** It sets `bals.herb = false`, starts the watch, and arms the fallback
timer (`conf.ai_resetherbbal`) that restores balance if the game never says you
got it back. That is why the call appears in `oncompleted`, `empty` and
`noeffect` alike: eating the herb costs the balance whether or not it cured
anything, so every path where the cure physically happened must record it.

What *is* inconsistent is where the call sits. For herbs it is inside the shared
`empty.eat_<herb>` handler; for salves and smokes it is in the entry's own
`empty`. Same call, different place. **The helper must reproduce the placement
exactly rather than tidy it**, or herbs get it twice and salves not at all.

**`noeffect` has a default for herbs and nothing else.** `dict_setup` does this
and only this:

```lua
    if balance.herb and not balance.herb.noeffect then
      balance.herb.noeffect = function()
        svo.lostbal_herb(true)
      end
    end
```

The `true` is the flag `lostbal_herb` reads to skip the minimum-balance block
when you are voided. So 59 herb entries carry no `noeffect` and are covered
anyway, while 20 salve entries have none and are not: see *Related findings*.
**The helper should install the same default for salve, smoke, sip and
purgative**, which removes boilerplate and closes that gap in one move.

A handful state their own and are genuinely special: `insomnia` and `blind`
(eating the herb and nothing happening means the *defence* is already up, so
`defences.got(...)`), `deaf`, and `checkasthma` (a prediction being withdrawn).
Those pass straight through the field-by-field merge.

### 5b. Eaten and smoked cures come in pairs; salves and elixirs do not

Eaten and smoked cures exist in two forms, a herb and a mineral, and the two
treat the same afflictions. A two-item cure list is those two names:

```lua
    eatcure   = {'bloodroot', 'magnesium'}   -- eat bloodroot, or magnesium
    smokecure = {'valerian', 'realgar'}      -- smoke valerian, or realgar
```

Not "a valerian pipe carrying realgar". `Main_trigger_functions.lua:2453` is the
code that depends on the real meaning:

```lua
      local alternative
      if action.eatcure[1] == eaten then alternative = action.eatcure[2]
      else alternative = action.eatcure[1] end

      echo'\n' svo.echof("Don't have %s, will try %s next time.", eaten, alternative)
```

Because the pairing belongs to the cure and never varies, the entry names only
one: `cure = 'kelp'` gives `{'kelp', 'aurum'}`. The one name in both sets is
`skullcap`: eaten it pairs with `azurite`, smoked with `malachite`, which is why
the smoke builder has its own table.

**Salves and elixirs have no second form, and the ones in the file are dead.**
Transmutation cures no longer exist in Achaea. `renewal`, `reconstructive`,
`sensory`, `exothermic`, `density`, `vitality`, `mentality`, `antigen`,
`endothermia`, `hovering`, `haste` and `toxin` are leftovers, and the helper must
**not** derive them. `cure = 'mending'` gives `{'mending'}`, full stop.

`applycure = {'mending'}` on `crushedthroat`, `blindaff` and the five burns is
the correct current shape. It is the 39 two-item `applycure` lists and 7 two-item
`sipcure` lists that are stale.

Removing them is optional and separate. Nothing outside the dictionary reads
`applycure` or `sipcure`, so the dead names cost nothing at runtime.
`reconstructive` and `renewal` appear nowhere else in `src/` and are safe to
strip. **`vitality` is not**: it is also a live Metamorphosis defence
(`defs_data:set('vitality', { type = 'metamorphosis' })`) and
`sk.morphsforskill.vitality`. A find-and-replace across those twelve names would
break it, which is the exact shape of bulk edit this repo has been bitten by.

### 5c. `notwhiledoing`

`unless`, `also` and `notwhiledoing` are names invented for the helper; none
exists in svof today. `notwhiledoing` controls a single conjunct,
`not svo.doingaction(<name>)`. `svo.doingaction` (`Action_system.lua:352`) is a
one-liner, `return actions_performed[which] and true or false`, so the conjunct
means *do not start this cure if an action for that thing is already in flight*.

Across the 185 real conditions on a cure balance:

| | count |
|---|---:|
| check `not doingaction(<self>)` | 61 |
| check `doingaction` of something **else** | 4 |
| no `doingaction` check at all | **120** |

**So it defaults off**, and the split by balance is what makes it worth a flag
rather than a rule:

| balance | with the check | total |
|---|---:|---:|
| focus | **18** | 20 |
| herb | 25 | 68 |
| misc | 11 | 26 |
| salve | 1 | 45 |
| smoke | 1 | 13 |
| sip | 1 | 6 |
| purgative | 1 | 5 |

Nearly every focus balance wants it and almost no salve does. If a `focus` block
is ever generated, that is the one place the default should flip.

It cannot be a plain boolean, because ten entries name a *different* action:

```
   prone.misc       -> doingaction('paralysis')
   blind.herb       -> doingaction('waitingonblind')
   deaf.herb        -> doingaction('waitingondeaf')
   sleep.misc       -> doingaction('curingsleep')
   impale.misc      -> doingaction('curingimpale')
   dragonflex.misc  -> doingaction('impale')
   rebounding.smoke -> doingaction('waitingonrebounding')
   speed.purgative  -> doingaction('curingspeed')
   sileris.misc     -> doingaction('waitingforsileris')
   healhealth.moss  -> doingaction('transmute')
```

So `notwhiledoing = true` for this affliction's own action, or
`notwhiledoing = 'paralysis'` for another one's.

### 5d. Focus is a second route, not a second affliction

Focus is an **alternative route to curing the same affliction**. The curing
skeleton chooses between it and the normal cure depending on the situation, and
the `focus` block only says what to do if focus is the route it picks.

**"Focus-curable" therefore needs no flag**: it is exactly "this entry has a
`focus` block", which is why Step 2 derives that one list from shape. The
derivation gives 20 against `focuscurables`' 18. `fear`'s block exists with
`isadvisable = function() return false end` and the real condition commented out
beneath, so it is deliberately disabled and needs an explicit opt-out.
`fulminated`'s block is live and its absence from the list is a bug that the
derivation fixes on the way past.

**The block itself is generatable.** All 20 are the same six lines, varying only
in the condition:

```lua
      focus = {
        isadvisable = function() ... end,
        oncompleted = function() svo.rmaff('X') svo.lostbal_focus() end,
        action      = 'focus',
        onstart     = function() send('focus', conf.commandecho) end,
        empty       = function() svo.lostbal_focus() empty.focus() end
      },
```

**The focus condition cannot inherit the normal route's `unless`.**
`check_alsofocus.py` translates both conditions into Python over the
restricted grammar these blocks use and evaluates them over every combination of
the atoms involved. Inheriting reproduces the real condition for only 14 of 19,
failing on `fear`, `fulminated`, `generosity`, `pacifism` and `stupidity`. The
two routes exclude different things:

```lua
  -- stupidity, normal cure:
  return (affs.stupidity and not svo.doingaction('stupidity')
          and not svo.usingbal('focus')) or false
  -- stupidity, focus route:
  return (affs.stupidity and not svo.doingaction('stupidity')
          and not affs.madness) or false
```

"Do not eat the herb if we are already using focus balance" and "do not focus
under madness" are not the same rule and neither implies the other. **So
`alsofocus` takes its own options.** The same script confirms all 20 blocks are
expressible, by truth table, with these specs:

| affliction | spec |
|---|---|
| agoraphobia, anorexia, claustrophobia, dizziness, epilepsy, shyness | `alsofocus = true` |
| confusion, dementia, fulminated, hallucinations, loneliness, masochism, paranoia, recklessness, stupidity, vertigo | `alsofocus = { unless = {'madness'} }` |
| unknownmental | `alsofocus = { notwhiledoing = false }` |
| pacifism, generosity | `alsofocus = true`, with the rage clause supplied by `rage = true` (Step 6) |
| fear | `alsofocus = false`, keep the block, disable the condition |

In full, `pacifism`:

```lua
    pacifism = basicaff('pacifism', {
      action        = 'eat',
      cure          = 'bellwort',
      notwhiledoing = true,
      alsofocus     = true,
      tree          = true,
      abbrev        = 'pac',
      gamename      = 'pacified',

      gone = {
        oncompleted = function()
          svo.rmaff('pacifism')
          codepaste.remove_focusable()
        end,
      },
    }),
```

and `vertigo`, which needs the exclusion on the focus route only:

```lua
    vertigo = basicaff('vertigo', {
      action        = 'eat',
      cure          = 'lobelia',
      notwhiledoing = true,
      unless        = {'madness'},                 -- the herb route
      alsofocus     = { unless = {'madness'} },    -- the focus route, separately
      tree          = true,
      abbrev        = 'vert',
    }),
```

### The helper

```lua
local EAT_ALT = {
  goldenseal = 'plumbum',  bellwort  = 'cuprum',      lobelia  = 'argentum',
  ginseng    = 'ferrum',   kelp      = 'aurum',       ash      = 'stannum',
  ginger     = 'antimony', bloodroot = 'magnesium',   irid     = 'potash',
  pear       = 'calcite',  bayberry  = 'arsenic',     cohosh   = 'gypsum',
  echinacea  = 'dolomite', hawthorn  = 'calamine',    kola     = 'quartz',
  myrrh      = 'bisemutum', sileris  = 'quicksilver', skullcap = 'azurite',
}

-- skullcap is the one name in both: eaten it pairs with azurite, smoked with
-- malachite, so smoking needs its own table.
local SMOKE_ALT = { elm = 'cinnabar', valerian = 'realgar', skullcap = 'malachite' }

-- How each kind of action works, taken from what the dictionary does today:
-- 71 onstart handlers call svo.eat, 45 call svo.apply with a body part,
-- 7 call svo.sip, and 12 send a pipe id.
--
-- `after` records that the balance was spent. svo.lostbal_herb() sets
-- bals.herb = false and arms the fallback timer that restores it if the game
-- never says you got it back - it does NOT hand balance back. It has to run
-- on every path where the cure physically happened, cure or no cure, because
-- eating the herb costs the balance either way.
--
-- `empty` fires when the cure went off and cured nothing - see Step 5a. Which
-- handler to call follows from the cure, so the entry does not state it.
-- One placement quirk to preserve: the lostbal call sits INSIDE
-- empty.eat_<herb>, but for salves and smokes it sits in the entry's own
-- empty. Same call either way, different place.
local ACTIONS = {
  eat = {
    balance = 'herb',      field = 'eatcure',
    start   = function(t, spec) svo.eat(t) end,
    after   = function(spec)    svo.lostbal_herb() end,
    empty   = function(spec)
      return function() svo.empty[spec.empty]() end
    end,
  },

  apply = {
    balance = 'salve',     field = 'applycure',
    start   = function(t, spec) svo.apply(t, spec.part and (" to "..spec.part)) end,
    after   = function(spec)    svo.lostbal_salve() end,
    empty   = function(spec)
      return function() svo.lostbal_salve() svo.empty[spec.empty]() end
    end,
  },

  -- sip and purgative are two different balances, and both are sipped, which
  -- is a trap. The six entries on the `sip` balance all call lostbal_sip;
  -- `purgative` is its own balance with five entries, only one of which
  -- (voyria) calls lostbal_purgative. An earlier draft of this helper mapped
  -- the sip action onto the purgative balance and called the wrong lostbal.
  sip = {
    balance = 'sip',       field = 'sipcure',
    start   = function(t, spec) svo.sip(t) end,
    after   = function(spec)    svo.lostbal_sip() end,
    empty   = function(spec)
      return function() svo.lostbal_sip() svo.empty[spec.empty]() end
    end,
  },

  -- smoke is the most regular of the four: every part of it follows from
  -- which pipe you name, so `pipe = 'elm'` is the entire description.
  smoke = {
    balance = 'smoke',     field = 'smokecure',
    cures   = function(spec) return { spec.pipe, SMOKE_ALT[spec.pipe] } end,
    gate    = function(spec) return svo.codepaste['smoke_'..spec.pipe..'_pipe']() end,
    start   = function(t, spec)
      send("smoke " .. svo.pipes[spec.pipe].id, svo.conf.commandecho)
    end,
    after   = function(spec)
      svo.lostbal_smoke()
      svo.sk[spec.pipe..'_smokepuff']()
    end,
    empty   = function(spec)
      return function()
        svo.empty['smoke_'..spec.pipe]()
        svo.lostbal_smoke()
        svo.sk[spec.pipe..'_smokepuff']()
      end
    end,
  },
}

-- Everything the spec does not state is generated. Everything it does state
-- wins, field by field.
function svo.basicaff(name, spec)
  local a       = ACTIONS[spec.action]
  local balance = spec.balance or (a and a.balance)
  local entry   = {}

  -- 1. the cure balance
  if a and balance then
    local b = {
      isadvisable = function()
        if not svo.affs[name] then return false end
        -- off unless asked for; `true` means this affliction's own action,
        -- a string means some other action. See Step 5c.
        if spec.notwhiledoing then
          local what = spec.notwhiledoing == true and name or spec.notwhiledoing
          if svo.doingaction(what) then return false end
        end
        for _, other in ipairs(spec.unless or {}) do
          if svo.affs[other] then return false end
        end
        if a.gate and not a.gate(spec) then return false end
        if spec.also and not spec.also() then return false end
        return true
      end,

      oncompleted = function()
        svo.rmaff(name)
        if spec.balance and spec.balance ~= a.balance then
          svo['lostbal_'..spec.balance]()   -- pressure: eats, but costs smoke
        else
          a.after(spec)
        end
      end,

      onstart = function() a.start(svo.dict[name][balance], spec) end,
    }
    b[a.field] = spec.cures
                 or (a.cures and a.cures(spec))
                 or (spec.cure and (EAT_ALT[spec.cure]
                       and { spec.cure, EAT_ALT[spec.cure] }
                       or  { spec.cure }))
    if spec.empty or a.cures then
      b.empty = a.empty(spec)
    end
    entry[balance] = b
  end

  -- 2. the standard aff and gone handlers
  entry.aff  = { oncompleted = function() svo.addaffdict(svo.dict[name]) end }
  entry.gone = { oncompleted = function() svo.rmaff(name) end }

  -- 3. anything the spec states wins. Sub-tables merge FIELD BY FIELD, so
  --    stating one isadvisable does not cost you the generated onstart.
  local consumed = { action=true, balance=true, cure=true, cures=true, empty=true,
                     part=true, pipe=true, unless=true, notwhiledoing=true, also=true }
  for k, v in pairs(spec) do
    if not consumed[k] then
      if type(v) == 'table' and type(entry[k]) == 'table' then
        for field, value in pairs(v) do entry[k][field] = value end
      else
        entry[k] = v
      end
    end
  end

  return entry
end
```

**The field-by-field merge in part 3 is the important bit.** It means an
affliction needing one custom handler writes only that handler:

```lua
    asthma = basicaff('asthma', {
      action = 'eat',
      cure   = 'kelp',
      abbrev = 'ast',
      tree   = true,

      -- only this handler differs from the generated one
      aff = {
        oncompleted = function()
          svo.addaffdict(svo.dict.asthma)
          local r = svo.findbybal('smoke')
          if r then svo.killaction(svo.dict[r.action_name].smoke) end
          signals.after_lifevision_processing:unblock(cnrl.checkwarning)
          codepaste.badaeon()
        end,
      },
    }),
```

`herb`, `gone` and the metadata are generated; the `aff` table's `oncompleted`
is yours.

Smoke afflictions come out shortest, because naming the pipe decides the cure
list, the `codepaste.smoke_<pipe>_pipe()` check, the `send`, the
`sk.<pipe>_smokepuff()` afterwards and the empty handler. `deadening` is 28 lines
today and becomes:

```lua
    deadening = basicaff('deadening', {
      action = 'smoke',
      pipe   = 'elm',
      abbrev = 'dea',
    }),
```

Eleven of the thirteen smoke entries fit exactly. The two that do not are
`checkasthma`, a prediction rather than a cure, and `pressure`, covered below.

### Proving a converted entry is faithful

The build gates compare script text, so they will flag the change and tell you
nothing useful. The proof has to be behavioural. Keep the old entry under a
scratch name for one commit and compare:

```lua
local new = svo.dict.lethargy
local old = svo.dict.__lethargy_before

same_keys(new, old, 'lethargy')
same_keys(new.herb, old.herb, 'lethargy.herb')

-- every combination of the afflictions the condition mentions
for _, state in ipairs(combinations{'lethargy', 'madness', 'hypochondria'}) do
  svo.affs = state
  eq(new.herb.isadvisable(), old.herb.isadvisable(),
     'isadvisable under ' .. describe(state))
end
```

Eight states for three afflictions. It matches on all eight or the conversion is
wrong. Then break it on purpose, drop `hypochondria` from the `unless` list, and
confirm two of the eight fail. **A test nobody has made fail is not evidence.**

Convert in batches by shape. The 27 entries shaped `{aff, gone, herb}` are the
obvious first batch.

---

## Step 6. One boolean for rage

**Optional, and the only step that changes what the system does in play.**

Rage cures six afflictions: `inlove`, `justice`, `generosity`, `pacifism`,
`peace` and `pyre`. That one fact is written in **three** places today, and two
of them already disagree.

| where | what it says |
|---|---|
| eight `isadvisable` clauses across the six entries | do not eat the bellwort, rage is coming |
| `rage.misc.isadvisable`, line 14134 | `affs.inlove or affs.justice or affs.generosity or affs.pacifism or affs.peace or affs.pyre` |
| `rage.misc.empty`, line 14147 | clears five of them, no `pyre` |

### The field

```lua
    peace = basicaff('peace', {
      action = 'eat', cure = 'bellwort', tree = true, rage = true, abbrev = 'pea',
    }),
```

`rage = true` sits beside `tree = true` and means the same kind of thing. It is
a flat boolean, so `dict_setup` skips it like every other scalar, and it cannot
be mistaken for a balance the way `focus = true` would have been: nothing reads
`j.p.rage`, there is no `check_rage`, and rage is not a curing-loop balance.

### Where the term goes

**Inside the `isadvisable` that `basicaff` generates**, in part 1 of the helper
in Step 5. It is one more link in the chain of early returns already there, and
it goes **last**:

```lua
      isadvisable = function()
        if not svo.affs[name] then return false end
        if spec.notwhiledoing then
          local what = spec.notwhiledoing == true and name or spec.notwhiledoing
          if svo.doingaction(what) then return false end
        end
        for _, other in ipairs(spec.unless or {}) do
          if svo.affs[other] then return false end
        end
        if a.gate and not a.gate(spec) then return false end
        if spec.also and not spec.also() then return false end
        if spec.rage and svo.rage_is_coming() then return false end   -- <- here
        return true
      end,
```

Last because it is the most expensive test in the chain. Every check above it is
a table lookup; `svo.rage_is_coming()` calls `rage.misc.isadvisable`, which runs
a `pcall` over every strategy in `svo.rage`. Position does not change the answer,
only how often that loop runs.

**`rage` is deliberately absent from the helper's `consumed` list.** That means
part 3's merge also copies `rage = true` onto the finished entry, which is what
`dict_setup` reads to build `svo.dict_ragecurable`. One field, two consumers: the
closure reads `spec.rage` at cure time, and the entry carries `entry.rage` for
the derivation.

### An entry that skips the helper writes the term itself

Change A works without `basicaff`, so an entry with a hand-written condition
replaces its eight-skillset clause with one call. `pyre` today:

```lua
        isadvisable = function()
          return (affs.pyre and (not (svo.haveskillset('discipline') or svo.haveskillset('malignity') or
          svo.haveskillset('valour') or svo.haveskillset('dominion')) or not svo.dict.rage.misc.isadvisable())) or false
        end,
```

and after:

```lua
        isadvisable = function()
          return (affs.pyre and not svo.rage_is_coming()) or false
        end,
```

Those are equivalent over every reachable state, checked rather than asserted.
The class list was doing two jobs: naming who has rage, and guarding the nil
index for everyone else. `rage_is_coming` does both, so the names are not needed.
Applied to `generosity.herb` the same rewrite also removes the drift in Step 6b,
because there is no longer a list of classes to leave one out of.

The entry still needs `rage = true` alongside, since the condition and the
derivation are separate consumers.

### On rage itself

`dict_setup` collects the flags and rage stops naming anybody:

```lua
  -- in dict_setup
  svo.dict_ragecurable = {}
  for action, entry in pairs(svo.dict) do
    if entry.rage then svo.dict_ragecurable[action] = true end
  end
```

```lua
  -- svo.dict.rage, after
  isadvisable = function()
    if not (conf.rage and bals.rage and svo.have_ragecurable()
            and not defc.dragonform and svo.can_usemana()) then return false end
    for name, func in pairs(svo.rage) do
      if not me.disabledragefunc[name] then
        local s,m = pcall(func[1])
        if s and m then return true end
      end
    end
  end,

  empty = function()
    for name in pairs(svo.dict_ragecurable) do
      svo.rmaff(name)
      if svo.dict[name].count then svo.dict[name].count = 0 end
    end
    svo.lostbal_rage()
  end,
```

with two one-line helpers:

```lua
function svo.have_ragecurable()
  for name in pairs(svo.dict_ragecurable) do
    if svo.affs[name] then return true end
  end
end

function svo.rage_is_coming()
  return svo.dict.rage and svo.dict.rage.misc.isadvisable()
end
```

Three copies become one, and the `empty` drift stops being expressible.

### Two Lua details that decide whether this is faithful

**`svo.dict.rage` does not always exist.** It is created only under
`discipline`, `malignity`, `valour` or `dominion`, at line 14129. The
`svo.dict.rage and ...` in `rage_is_coming` is a nil guard, not decoration. The
existing clauses do the same job with `not (svo.haveskillset(...)) or ...`, where
the short-circuit is what stops `svo.dict.rage.misc` raising on other classes.

**`rage.misc.isadvisable` returns nil, not false**, when the gate passes but no
strategy matches, because the strategy loop falls off the end. Both the current
clause and `rage_is_coming` consume it as a truth value, so nil behaves as false.
It is a trap only for code comparing to `false`.

There is no recursion risk: rage's condition reads `svo.affs[name]`, never the
afflictions' own `isadvisable`.

### What changes in play

Three things, none of them a pure refactor. Land them in their own commit and
say so, because no gate can see any of it.

1. **`generosity.herb` gains `dominion`.** It omits it today while the same
   affliction's focus route has it. `available_skills` is built from the current
   class alone and each rage skillset belongs to exactly one class (`discipline`
   runewarden, `malignity` infernal, `valour` paladin, `dominion` unnamable), so
   this is **every Unnamable, every time rage is advisable**: the herb route eats
   a bellwort while that character's focus route stands down. Ten reachable
   class-and-rage states, differing in one.
2. **Rage's `empty` starts clearing `pyre`.** `isadvisable` fires on six and
   `empty` clears five. If rage cured nothing you had none of the six, so
   clearing all six is the correct reading, but it is a change.
3. **Clearing a counted affliction resets its count.** `pyre` has no
   `onremoved`, so `svo.rmaff('pyre')` alone leaves `svo.dict.pyre.count` stale.
   Every other site that clears pyre resets it explicitly. The generated handler
   above does it for any entry with a `count`, which also fixes
   `empty.eat_bellwort`, where the omission exists today.

Which behaviour is *correct* for generosity is a question about how rage and
generosity interact in play, not one the code answers.

### What stays hand-written

Three entries consult another entry's `isadvisable` and are not rage.

- **`webbed` and `roped`** defer to `dragonflex` and `dwinnu`. Both are
  hand-written entries carrying `dontbatch`, `helpless` and `impale` handlers,
  so they keep hand-written conditions either way. The dwinnu half is the same
  shape as rage, confirmed over all 128 states of its atoms. The dragonflex half
  carries an extra `bals.rightarm and bals.leftarm`, which matters in 21 of 4096
  states and has no equivalent anywhere else. Worth asking in play whether a
  broken arm actually stops you dragonflexing: if it does, that check belongs
  inside `dragonflex.misc.isadvisable` and both clauses collapse.
- **`checkasthma.smoke`** defers to `checkasthma.misc`, one entry choosing
  between two of its own routes. Not "another action handles this", and not this
  scheme's business.

A general mechanism would serve one owner and leave these three untouched
anyway. That is why this step is a boolean and not a framework.

---

## The awkward afflictions

Three that look like they break the plan, and do not.

**`voyria` cannot be cured while you have latency.**

```lua
        isadvisable = function()
          return not affs.latency and ((affs.voyria) or false)
        end,
```

One extra condition. Under Change B that is `unless = {'latency'}`. Under Change
A alone you leave the function exactly as it is and add the fields. Either way
it is fine.

**`pressure` eats a herb but costs smoke balance.** Its entry is filed under
`smoke`, the action is `svo.eat`, the item list is called `eatcure`, and it
spends smoke balance. So `action` says what is physically done and `balance` says
what it costs, with `balance` defaulting to whatever `action` implies:

```lua
    pressure = basicaff('pressure', {
      action  = 'eat',      -- eats a herb
      balance = 'smoke',    -- but costs smoke balance
      cure    = 'pear',
      counted = true,
    }),
```

Two words now overlap, so be clear about them: `action = 'smoke'` means puff the
pipe, which is what `deadening` does; `balance = 'smoke'` means this costs smoke
balance, which is what `pressure` does while eating a herb. Pressure sets the
second and not the first. Its `cured`, `noeffect`, `general_cure` and
`general_cured` handlers pass through the merge like any other stated field.

**The burn ladder should not be generated, and does not have to be.** `ablaze`
to `severeburn` to `extremeburn` to `charredburn` to `meltingburn` is one state
machine across five entries: curing a level steps down to the previous one,
`generic_reducelevel` walks it with `sk.current_burn()` and `sk.previous_burn()`,
gaining one calls `codepaste.remove_burns()`, `severeburn.salve` is flagged
`irregular`, there is an `all` handler for the whole ladder, and `ablaze` carries
a torch and Elemental Lord special case in three places.

**Change A does not care.** Leave all five exactly as written, add

```lua
      gamename = 'burning',
      abbrev   = 'abl',
      tree     = true,
      prio     = 41,
```

and they join every derived list like anything else. That is the general answer
to "what about the complicated ones": the benefit comes from the fields and the
derivation, not from the helper.

---

## Step 7. Defences: what should move, and what should not

**Optional, independent of Steps 1 to 6, and smaller than it looks.**

The defence half of svof is split across `svo.dict` and `svo.defs_data`. That
looks like the affliction problem again. It mostly is not.

### The split is not duplication

The two tables answer different questions:

| table | question | who needs it |
|---|---|---|
| `svo.dict[name]` | how do I **raise** this | only a class with the skill |
| `svo.defs_data[name]` | what does the game **print** | anyone who can hold it |

The gating proves it is deliberate, not drift. 81 of 317 `defs_data` names are
ungated where only 16 of 134 `basicdef` names are, and ten names are recognised
for everyone but raised by only some classes:

```
breakthrough  comprehend  constitution  mindnet     nightsight
resistance    shroud      toughness     transcend   vanish
```

`nightsight` is the clean case. Anyone can hold it from a tattoo, so the lines
are ungated; only Kaido can command it, so the dict entry is gated on `kaido`.
Merging the tables would force one gate on both halves and either stop svof
recognising a defence it can see, or offer to raise one it cannot.

The ordering is load-bearing too. `defs_data` is a `pl.OrderedMap`; the consumer
loop appends to `defences.def_types[type]` in iteration order and `show_defs`
walks that with `ipairs`, so insertion order is the order `vdefs` prints in.
`svo.dict` is a plain table, and `pairs` over it is unordered.

**So the 2,172 lines of game text stay where they are.** Move the four things
below instead, none of which is trigger text.

### 7a. Delete what nothing reads

Four keys, no behaviour change, one commit.

| key | state |
|---|---|
| `on_free`, `off_free`, `offs` | the consumer loop branches on each; no record sets any |
| `defs_data[def].onshow` | read twice in `show_defs`; never set. The `onshow` in *Alias functions* belongs to the config table |
| `tooltip` | set on five records, written by `defences.complete_def`, never read |
| `defences.complete_def` | no caller in `src/`. Keep it if addons use it, but say so in a comment |

### 7b. Give `bedevil` and `evasion` a dict entry, or a `nodef`

30 `defs_data` records have no dict entry. 28 carry `nodef`, `invisibledef` or
`custom_def_type` and are recognise-only on purpose. `bedevil` (Zeal) and
`evasion` (Woodlore) carry none of them, so the consumer loop hands each a
`defdefup` and `defkeepup` slot in every mode. A user who adds either to defup
gets `bedevil (?)` in `sk.have_defup_defs` forever, because nothing can raise
it.

Two fixes, and which is right is a question about the game:

```lua
basicdef('bedevil', 'bedevil')      -- if the command exists and is ours to send
-- or
defs_data:set('bedevil', { type = 'zeal', nodef = true, ... })
```

Read from the code, not observed in play.

### 7c. One serverside name per defence

The same fact is written in two directions:

| where | direction |
|---|---|
| `basicdef(..., gamename)` -> `svo.dict[name].gamename` | svof to serverside, read by `Serverside.lua:79` and `:108` |
| `svo.dict.sstosvod` | serverside to svof, reversed into `svotossd` at load |

32 names carry a `gamename`. 17 also appear in `sstosvod`, and today they agree.
The other 15 have a `gamename` and no `sstosvod` entry, so svof can send a
priority for them and cannot read a serverside line naming them:

```
breakthrough  cloaking     cohesion   comprehend  extrusion
fireshroud    mentalclarity rupture   skysight    strata
susurrating   tempest      transcend  tremorsense vanish
```

This is Change A's shape exactly, and it fits the same fix: state the serverside
name once on the entry, derive `sstosvod` and `svotossd` in `dict_setup` the way
Step 2 derives the affliction maps, and let the checker fail when they diverge.
`sstosvod` keeps its 37 `false` entries and its 121 identity entries as
hand-written exceptions, because those say "serverside knows this name and svof
deliberately does not", which no entry can imply.

### 7d. Leave `specialskip` where it is, and fix the comment

19 of the 29 `specialskip` conditions restate a condition the dict entry's
`isadvisable` already carries, term for term:

```lua
-- defs_data
specialskip = function() return not defc.dragonform end,
-- svo.dict.dragonarmour.physical.isadvisable, same condition, again
```

Tempting, and wrong to merge. The two mean different things:

- `isadvisable` false means **not now**. Defup keeps waiting.
- `specialskip` true means **never, stop waiting**.

Moving `specialskip` onto the entry would put the duplicate one line closer
without removing it. The duplication only goes away if `sk.have_defup_defs`
learns to ask the entry a third question, which is a behaviour change and wants
its own investigation.

The comment above it is already wrong and can be fixed today:

```lua
-- can't just check if we need and don't have, because some might have conflicts.
-- hence, just check isadvisable; this checks it for us and skips conflicts.
function sk.have_defup_defs()
```

It does not call `isadvisable`. It reads `defdefup`, `defc`, `specialskip`,
`svo.ignore`, `type` and `nodef`.

### 7e. While you are here: the arbitrary balance pick

Three places do this to find a defence's balance:

```lua
-- Defences.lua:3374, :3409, :3630
for kk,vv in pairs(svo.dict[defname]) do
  if type(vv) == 'table' and kk ~= 'gone' then bal = kk break end
end
```

with the comment "rely on the fact that defs only have 1 item in them". Three
entries break that: `deathsight` (`herb`, `physical`), `thirdeye` (`herb`,
`misc`) and `insomnia` (`herb`, `misc`, `aff`). `pairs` order is undefined, so
which balance those three route through can differ between loads.

Every `basicdef` entry has exactly one sub-table, so the fix is small: prefer
`physical` when present, else the single non-`gone` table, and echo a warning
when there is more than one candidate.

### What this step does not do

It does not touch a single line of game text, it does not change how any
defence is recognised, and it leaves `defs_data` as the recognition table. The
readme's instructions for adding a defence stay two steps, not one.

---

## Step 8. Give `basicdef` a spec table, like `basicaff`

**Optional, independent of every other step, and the largest single reduction
in the dictionary.**

There are two ways to declare a defence today and they look nothing alike.

```lua
-- 157 calls, positional
basicdef('sturdiness', "stand firm", false, 'standingfirm')
basicdef('listen', 'listen', false, false, true)

-- 166 definitions, written out
svo.dict.chargeshield = {
  physical = {
    balanceful_act = true, def = true,
    isadvisable = function()
      return (not defc.chargeshield and ((sys.deffing and defdefup[defs.mode].chargeshield)
        or (conf.keepup and defkeepup[defs.mode].chargeshield)) and not
        codepaste.balanceful_defs_codepaste() and sys.canoutr and not affs.paralysis
        and not affs.prone and defc.air) or false
    end,
    oncompleted = function() defences.got('chargeshield') end,
    action = 'chargeshield',
    onstart = function() send('chargeshield', conf.commandecho) end
  }
}
```

That second one is `basicdef` plus `defc.air`. Most of them are.

### What the 166 actually are

Every defence definition, decomposed into its top-level conjuncts by
`decompose_defs.py`. No sampling and no regex: the dictionary is
tokenised, comments are discarded before any structure is read, and the table
nesting is rebuilt from tokens, so nothing depends on how somebody laid the
source out. Each definition lands in exactly one row and the rows sum to 175.

| | definitions | what it means |
|---|---:|---|
| a plain conjunction, every term nameable as a field | **134** | `basicdef` plus a handful of conditions |
| a plain conjunction with one term a field cannot name | 20 | the same, plus one closure |
| already delegates to a shared helper | 16 | Tekura and Shikudo did this in 2 helpers |
| genuinely multi-statement | 5 | `block`, `shadowcloak`, `unbowed`, `vitality` twice |

**170 of the 172 become one call**, and the other 2 keep a hand-written
condition inside a spec table. With the 157 that already are, that is
**327 of the 329 defence definitions**.

Every one of the 175 carries an `isadvisable`, including the 21 that sit on a
`herb`, `misc`, `purgative`, `salve` or `smoke` balance rather than `physical`.
There is no "cure-style, out of scope" bucket: `blind` and `deaf` each have a
class-gated `misc` route assigned by `svo.dict.blind.misc = {`, three dots deep,
which is exactly the spelling an earlier regex here could not see.

### The one thing to check first: the defup clause

Six different factorings of the defup/keepup test are in use. Before assuming
they are stylistic, `check_basicdef_spec.py` runs all 32 states of the
five atoms. **Three of the six are the same truth function.**

| factoring | definitions | verdict |
|---|---:|---|
| `not defc and ((deffing and defdefup) or (keepup and defkeepup))` | 130 | this is `basicdef`'s own |
| the same with `not defc` distributed into each arm | | identical, all 32 states |
| the same again with a redundant third disjunct | | identical; the third arm repeats the second |
| `not defc` split out of one arm only | | identical once its separate `not defc` is counted |
| keepup arm also requires `not sys.deffing` | 22 | **differs in 1 state of 32** |
| keepup arm also lowers an unwanted defence | 2 | **differs in 3 states of 32** |

The one state `defupfirst` changes: you are in defup, the defence is in keepup
but not in defup, and you do not have it. The plain form raises it anyway. That
is a real preference, so it is a field, not a bug to normalise away.

`toggleoff` differs in three states, two of which are the whole point: the
defence is up and you do not want it, so lower it. Only `riding` and
`selfishness` use it, and `block` does the same thing with a separate
statement.

### The spec

```lua
basicdef('chargeshield', {
  command  = 'chargeshield',
  requires = {'air'},
})

basicdef('bulk', {
  command  = 'anathema bulk',
  notdragon = true, bal = 'anathema',
  canoutr = false,
})

basicdef('frostblessing', {
  command  = "pray frost",
  bal = 'prayer', mana = 750,
  canoutr = false, notparalysed = false,
})
```

Twenty-one fields cover all 134, measured rather than guessed:

| kind | fields |
|---|---|
| the command | `command`, `balanceless`, `gamename`, `undeffable` |
| the balance it lives on | `balance` (default `physical`) |
| defup semantics | `defupfirst`, `toggleoff` |
| gates on by default, matching `basicdef` today | `canoutr`, `notparalysed`, `notprone`, `notdoing` |
| gates off by default | `notdragon`, `indragon`, `morph`, `nonmorphdefs`, `morphsforskill`, `inamorph`, `nowilltakebal`, `notlyrestep`, `notmanualdefcheck`, `canusemana` |
| lists | `requires`, `excludes`, `excludesaffs`, `bal`, `conf` |
| numbers | `mana`, `kai` |
| class path | `path` |
| the escape hatch | `also = function() ... end` |
| full override | `isadvisable = function() ... end` |

`notdoing` must take an action name, not only a boolean: 13 definitions wait on
an action other than their own (`waitingonblind`, `waitingondeaf`,
`waitingforsileris`, `waitingformace`, `waitingforviridian`, `curingspeed` and
the two dragon ones).

`morph = true` emits both `not affs.cantmorph` and `not
svo.doingaction('waitingformorph')`, because 29 of the 30 metamorphosis
definitions carry both. `affinity` carries only the second. Whether that is
deliberate is a question about the game, so convert it with the pair and check
in play, or give it `morph = false, notmorphing = true` and keep today's
behaviour exactly.

`path = 'tekura'` retires `tekura_ability_isadvisable` and
`shikudo_ability_isadvisable`, which are byte-identical apart from that string,
and folds their 16 entries in.

`also` is the whole answer to the 17 awkward ones. It is ANDed on last, after
every table lookup, for the same reason the rage term goes last in Step 6:

```lua
basicdef('devour', {
  command = 'anathema devour', notdragon = true, bal = 'anathema',
  requires = {'mouths', 'tentacles'},
})

basicdef('bindall', {
  command = "bind all", defupfirst = true, mana = 750,
  requires = {'air', 'earth', 'water'}, excludes = {'spirit'},
  canoutr = false, notparalysed = false, notprone = false,
  also = function() return svo.haveskillset('weatherweaving') or defc.fire end,
})
```

### Three defects found while reading, which the conversion must not carry over

**`shield`'s arm guard has never fired.** It reads
`not (affs.mangledleftarm and affs.mangledlrightarm)`. That second name is
misspelt, appears exactly once in the whole tree, and `svo.affs` has no
`__index`, so the read is nil and the guard is always true.

Correcting the spelling is not the fix. The same conjunction already carries
`sys.canoutr`, and `canoutr` is false whenever each arm is crippled, mangled or
mutilated, which the corrected clause is a strict subset of. **Delete the
clause.** Verified by reading the `canoutr` handler at `Setup.lua:206`, not
inferred from the name.

**Four entries return nil, not false.** `disperse`, `hiding`, `shadowveil` and
`waterbubble` omit the trailing `or false`. Every caller today consumes the result as a truth
value so nothing is broken, but a caller comparing to `false` would be wrong,
and `basicdef` would fix all three by construction.

**Ten definitions carry a redundant third disjunct** in the defup clause,
`((X or Y)) or Y`. Also fixed by construction.

### Order of work

Same discipline as Step 5, and for the same reason: the risk is not the helper,
it is the 146 conversions.

1. Extend `basicdef` to accept a table as its second argument, keeping the
   positional form working. Nothing converts yet, nothing changes.
2. Convert the 157 existing calls to the table form. The generated code must be
   byte-identical; if it is not, the helper is wrong.
3. Convert the 134 field-only definitions, in batches by skillset, each batch
   proved by truth table before it lands.
4. Convert the 20 that need `also`.
5. Convert the 16 helper-delegating ones and delete both helpers.
6. Leave the 5 multi-statement ones as `isadvisable = function() ... end` inside
   a spec table, so they still gain `gamename`, `requires` and the rest.
7. Fold in the 4 `svo.dict.blind.misc` and `svo.dict.deaf.misc` sub-table
   assignments, which are ordinary defence definitions on the `misc` balance
   and want `balance = 'misc'` in the spec.
8. Retire the positional form.

### Read the source, not a shape you expect

This step was measured twice. The first pass used regexes and was wrong in
three ways, all of them assumptions about formatting rather than about code:
`svo.dict.lipread  = {` writes two spaces before the `=`; four definitions are
three dots deep; two live in *Defences* rather than the dictionary; and sixteen
write the whole function on one line. The tools now tokenise instead, and
`check_formatting_hazards.py` asserts each of those spellings so a future
regex fails loudly rather than undercounting.

---

## What "done" looks like

The readme's eleven steps become two:

1. Write the dictionary entry, including its fields.
2. Add the triggers for the lines the game sends.

Everything else, the diag list, the tree list, the herb maps, the prompt tag, the
serverside name, the default priority, follows from the entry, and the checker
fails if it stops following.

Triggers stay filed by skillset, which is right: a trigger belongs to the ability
that causes it, not to the affliction.

### Order of work

| | step | touches | reversible alone |
|---|---|---|---|
| 3 | write `check_derived_lists.py` and its baseline | tools only | yes, and it can land today |
| 1 | add the fields to entries | dictionary only | yes |
| 2 | build the derived tables in `dict_setup` | dictionary only | yes |
| 4 | switch the 7 consumers, one commit each | 5 files | yes, per commit |
| | *the whole benefit is delivered here* | | |
| 5 | `basicaff` and convert the simple entries | dictionary | yes, per batch |
| 6 | `rage = true` and the derived set | dictionary | yes |
| 7 | the four defence changes | dictionary, *Defences* | yes, per part |
| 8 | `basicdef(name, spec)` and the 146 conversions | dictionary | yes, per batch |

Steps 1 to 5 are refactors: the same decisions, written once instead of eleven
times. **Step 6 is the only one that changes behaviour in play**, in the three
ways listed under it. Steps 7 and 8 are independent of all of them and of each
other; 7a and 7d's comment fix are safe today.

---

## Related findings, not part of this work

Both were found while reading for this plan. Neither needs the refactor, and the
detail is in `claude/svof-system-spec.md` section 19.

**20 salve entries have no `noeffect` branch.** `dict_setup` defaults `noeffect`
for herbs only. `svo.valid.salve_had_no_effect` resolves through
`svo.findbybal('salve')`, whichever salve action is in flight, so these twenty
can be that action with no branch to take. `Action_system.lua` logs an error and
then calls the nil anyway, `svo.actionfinished` wraps it in `pcall`, and the
balance correction never happens, so svof keeps thinking it has salve balance.
Read from the code, not observed. Step 5a's helper closes the gap as a
side effect of installing the same default for the other balances.

**The pyre count read was fixed by pull request 853**, which is merged. All five
burn conditions read `affs.pyre.count` where the count lives at `affs.pyre.p.count`,
and the read raised out of an unprotected `isadvisable` and aborted
`svo.onprompt`. It belongs here only for why it survived: one rule, *pyre at
level+1 blocks curing that burn*, written out five times with five different
numbers, so the mistake was written five times and no single entry looked wrong.
