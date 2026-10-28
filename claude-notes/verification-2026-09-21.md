# Verification pass, 2026-09-21

Reading `src/` in full to confirm the spec (`reference/svof-system-spec.md`)
and the architecture map (`reference/svof-src-architecture.md`) against the
tree at `82e7f14`.

Status key: **OK** confirmed as written, **GAP** true but incomplete,
**WRONG** contradicted by the source, **NEW** something neither document says.

---

## Spec, section 4: loading and class change

Read `svo_init_system.lua` and `svo.classchange.lua` in full.

- **OK** 22 required subsystems, in the order the spec lists.
- **OK** 10 addon loaders, in the order the spec lists. A commented-out
  `peopletracker` sits in the required list as well as the addon list.
- **OK** the sequence: `svo.signals = nil`, run every loader,
  `svo.signals.systemstart:emit()`, `svo.systemloaded = true`,
  `raiseEvent("svo system loaded")`.
- **OK** classchange quotes exactly, and general defences are stashed and
  re-applied.
- **WRONG** "It bails out early and silently if Penlight is not loaded, if any
  required subsystem is missing, or if Mudlet is older than 3.20." The Mudlet
  branch is **not** silent. It prints
  `"Can't load Svof: your Mudlet is too old..."` through `cecho`. The other two
  bails are silent. The guard is
  `if not mudletOlderThan or mudletOlderThan(3,20)`, so it also bails when the
  function itself is absent.
- **GAP** the spec stops at `raiseEvent`. Four more things happen after it and
  before the addons: `svo.signals.gmcpcharname:emit()` when `gmcp.Char.Name`
  already exists, the version echo with a `homepage` link, then the addon
  loop, then `if force_init then sendSocket("\n") end`.
- **NEW** `svo_init_system` is a global, not on `svo`, and opens with
  `if svo.systemloaded then return end`. Classchange therefore has to set
  `svo.systemloaded = false` before calling it, which is why that line reads
  the way it does.
- **NEW** classchange's stash loop runs before the `svo.me.class ~= newclass`
  test, and it deletes `svo.defc[k]` outright for any held defence with no
  `defs_data` record. That deletion happens on every class change event, even
  one that turns out to be a no-op.

## Spec, section 9: the action system

Read `Action_system.lua` in full, 382 lines.

- **OK** the four steps of `doaction`: arm a `tempTimer`, register in
  `svo.actions` under `act.name` with a `completed` closure dispatching
  `act[other_action or 'oncompleted'](arg)`, record in
  `bals_in_use[act.balance][act.name]` and `actions_performed[act.action_name]`,
  then `pcall(act.onstart)`.
- **OK** every query the spec lists exists: `usingbal`, `doingaction`,
  `findbybal`, `findbybals`, `checkany`, `haveorwill`.
- **OK** the section 19 salve finding, exactly as described. `completed` does
  `debugf("[error] %s does not exist for %s!", ...)` and then calls
  `act[other_action or 'oncompleted'](arg)` **unconditionally** on the next
  line, and `svo.actionfinished` wraps the call in `pcall`. So a missing branch
  logs, raises, is swallowed, and the balance correction never runs.
- **GAP** "takes a balance sub-table" describes one of two modes. `doaction`
  also accepts two strings, `svo.doaction('healhealth', 'sip')`, and resolves
  them through `svo.assert`. The comment calls this the external API kept for
  compatibility. `Funnies.lua` documents the two-string form to users, so it is
  the public one.
- **GAP** the timeout formula omits a branch.
  `affs.seriousconcussion and sys.sync` gives `syncdelay() + .3` instead of the
  `customwait` sum, so a concussed character under aeon uses a different clock
  entirely.
- **GAP** "On timeout it increments `sys.lagcount`, calls `ontimeout` if
  present" loses the gate between them. `ontimeout`, the stupidity inference,
  and `make_gnomes_work` only run while `sys.lagcount < sys.lagcountmax + 1`.
  At exactly that boundary it echoes a lag warning and calls
  `sk.increase_lagconf()` instead. Past it, a timeout does nothing at all.
- **NEW** `svo.will_take_balance` is aliased to
  `svo.codepaste.balanceful_codepaste`, which is what defence conditions call.
  Neither document mentions the alias, and the defence conditions read
  `codepaste.balanceful_defs_codepaste`, a different name. Check both exist.
- **NEW** `valid_sync_action` splits on `^(%w+)_(%w+)$`. `%w` excludes the
  underscore, so an action name containing one cannot round-trip through the
  sync priority format. Worth checking whether any dict key has an underscore.
- **NEW** `actionclear` calls `act.oncancel` under `pcall`, and `killaction`
  calls `act.onkill` unprotected. Neither branch is in either document's list
  of resolution branches.

## Spec, section 6: the dictionary preamble, lines 24 to 400

Read in full. **Neither document describes this region.** The spec's shape
table jumps from `svo.loader.dict = function()` at 25 to
`if not next(svo.dict)` at 401, so roughly 375 lines of helpers are missing
from both maps. What lives there:

- **Ten derived shortlists, declared `svo.X = svo.X or {}` at lines 41 to 50.**
  `dict_balanceful`, `dict_balanceless`, `dict_balanceful_def`,
  `dict_balanceless_def`, `dict_herb`, `dict_misc`, `dict_misc_def`,
  `dict_purgative`, `dict_salve_def`, `dict_smoke_def`. The spec says
  `dict_setup` rebuilds eight of them and the dragonform handler builds the
  other two, which is right, but it does not say they are declared here first.
  That declaration is what stops `balanceful_defs_codepaste` iterating a nil,
  so it matters: **checked, and there is no crash of the #853 shape here.**
- **Four shared helpers, not two.** `tekura_ability_isadvisable` (55) and
  `shikudo_ability_isadvisable` (75) are the pair both documents name, plus
  `tekura_stance_oncompleted` (95) and `shikudo_form_oncompleted` (113), which
  neither mentions. Step 8 of the guide says `path = 'tekura'` retires "both
  helpers"; it would have to deal with four.
- **The isadvisable pair is not byte-identical apart from the path string.**
  The parameter differs too, `new_stance` against `new_form`. Cosmetic, but the
  guide states the stronger claim.
- **Nineteen `codepaste.*` helpers**, of which both documents name only
  `pyre_holds`, `remove_burns`, `remove_focusable`, `balanceful_defs_codepaste`
  and the three smoke gates.

### Two things in that region worth knowing

**`codepaste.balanceful_codepaste` and `codepaste.balanceful_defs_codepaste`
are different functions.** The first is `Action_system.lua:200`, an alias of
`svo.will_take_balance`, which walks `bals_in_use.physical` for a
`balanceful_act`. The second is `Dictionary...lua:335`, which walks
`svo.dict_balanceful_def` asking `svo.doingaction`. Defence conditions call the
second, 135 times in the dictionary and twice in `Defences.lua`. The names are
one token apart and answer different questions, so do not treat a reference to
one as a reference to the other.

**`codepaste.nonmorphdefs` is defined only under
`if svo.haveskillset('metamorphosis')`.** For any other class it is nil. 22
morph definitions call it unguarded, all of them metamorphosis morphs, so it
holds today for the same reason `svo.dict.rage` holds: the caller only exists
when the callee does. Step 8 lists `nonmorphdefs` as a spec field, and a
generated field has no such guarantee unless the generator keeps the gate.

**The three smoke gates have side effects and run inside `isadvisable`.**
`codepaste.smoke_elm_pipe` calls `sk.warn 'noelmid'` and sets
`sk.forcelight_elm = true` before returning. `isadvisable` is called every tick
for every affliction you hold, so a missing pipe id warns once per tick unless
`sk.warn` throttles. Confirmed against `deadening`, whose condition is
`(affs.deadening and codepaste.smoke_elm_pipe()) or false`. The guide's Step 5
helper keeps this by calling the same gate from the generated condition, which
is faithful, but neither document says the gate is impure.

- **OK** `deadening` matches the guide's smoke description exactly, including
  the order inside `empty`: `empty.smoke_elm()`, then `svo.lostbal_smoke()`,
  then `sk.elm_smokepuff()`.
- **NEW** the dictionary file header, lines 13 to 21, carries its own
  nine-bullet checklist for adding an affliction. That is a third copy of the
  list the guide counts as eleven steps and the spec as nine places, and it
  sits in the file the work would change.

---

# Architecture map

## Inventory, lines 34 to 71

- **OK** the file table is exact on every one of its six rows: `scripts/` 147
  and 55, `triggers/` 2,420 and 249, `aliases/` 170 and 25, `buttons/` 8 and 3,
  `keys/` 1 and 3, `resources/` 1 and 0. Totals 2,747 `.lua`, 335 `.json`,
  3,083 files, and the one extensionless file is `src/resources/default_prios`.
- **OK** the manifest item table is exact, confirmed a second way. Its folders
  plus leaf items sum to 3,182, and `tools/check_src_tree.py` independently
  prints `3182 declared items`. Its 64 inline trigger scripts match that gate's
  `64 items carry their script inlined in the json`.
- **OK** "every `.lua` file on disk is reachable from a manifest, no orphans".
  `check_src_tree.py` prints `SRC TREE OK - every .lua is reachable and no two
  items share a file`.

### The byte counts are LF measurements, and this checkout is CRLF

All three byte figures look wrong on Windows and are not. The delta is exactly
the line count in each case, which is the signature of one CR per line:

| figure | document (LF) | measured here (CRLF) | delta | lines |
|---|---:|---:|---:|---:|
| `scripts/` Lua bytes | 1,919,846 | 1,973,586 | 53,740 | 53,740 |
| `triggers/` Lua bytes | 161,087 | 163,984 | 2,897 | 2,897 |
| `triggers.json` bytes | 1,455,959 | 1,512,904 | 56,945 | 56,945 |

Three for three, to the byte. **The document is right and a Windows checkout
will never reproduce it.** This is the exact class of bug `CLAUDE.md` records
biting three times, in the duplicated-resource check and the reference-xml hash
pin. Anyone re-deriving these figures locally must normalise line endings first,
or compare against the git blob rather than the working tree.

Worth adding to the document as a note beside the figures, since a future
reader on Windows will otherwise "correct" three right numbers.

### One figure is not reproducible from its own description

"1,488 function definitions at column zero." The extractor is not described, and
the document immediately says the real count is higher because it misses
functions defined inside a table or closure, so the figure is explicitly
partial. My closest column-zero reading, `^function `, `^local function ` and
`^NAME = function`, gives **1,473**, a difference of 15. Five other variants give
1,124, 105, 244, 1,229 and 1,402. Not evidence the document is wrong: evidence
the claim cannot be checked without the extractor. Either publish the pattern
beside the number or drop the number.

### A discrepancy between two tools that is not a disagreement

`check_src_tree.py` says `2746 .lua files under src/`; the document and the
filesystem say 2,747. The gate excludes `src/resources/ndb-help.lua`, which is
shipped content rather than a declared item. Both figures are right for what
they count. The #853 commit message quotes the gate's 2,746, so the two numbers
will keep appearing side by side.

## Architecture map, "State", lines 260 to 288

**WRONG, and it is the most important error in the document.**

> **`svo.affs`** maps affliction name to `true`, or to a count for stacking
> afflictions.

It does not. `Curing_skeleton.lua:1293`, inside `old_internal_addaff`:

```lua
  svo.affs[name] = {
    p = new_aff,
    sw = new_aff.sw or createStopWatch()
  }
```

`svo.affs[name]` is a two-field table, never `true` and never a number. The
count lives at `svo.affs[name].p.count`, which is the same table as
`svo.dict[name].count`, and `svo.affl[name].count` is the public mirror written
by `svo.updateaffcount`.

**This is the exact misreading that caused the bug #853 fixed.** Five burn
conditions read `affs.pyre.count`, got nil, and raised out of an unprotected
`isadvisable`, aborting `svo.onprompt`. The spec has it right in section 10 and
in section 19. The architecture map states the wrong model as fact, in the
section a reader consults precisely to learn the shape of the state, so it will
reproduce the defect in whoever trusts it. Correct it before the document is
used for anything.

**GAP, same section.** "Six tables carry essentially all runtime state" names
`me`, `affs`, `defc`, `bals`, `conf`, `dict`. It omits the other three
affliction tables the spec's section 10 names and that behaviour depends on:
`svo.affl` (the public list, keyed by svof name, raising `svo got aff` and
`svo lost aff`), `svo.gaffl` (the raw GMCP mirror, keyed by **game** name), and
`svo.affsp` (suspicions set by triggers before confirmation). It also omits
`svo.gdefc`, the defence equivalent of `gaffl`. Confusing `affs` with `affl` or
`gaffl` is a documented source of real bugs, so a state section that lists one
of four is worse than none.

### What the source does confirm, in the same read

- **OK** spec section 10's table, every row, read out of `old_internal_addaff`
  and `svo.rmaff`.
- **OK** `svo.affl[name].count` is only set when `svo.affs[name].p.count ~= nil`.
- **OK** `rmaff` is quiet by design and the comment says so. `if not affs[old]
  then return end` sits above the `svo.dict[old].onremoved` call, so a name that
  is not currently afflicted returns before the dictionary is consulted.
- **OK** `svo.addaffdict` is exactly `old_internal_addaff`.
- **OK** 267 entries in the literal, 189 carrying `gone`, 15 carrying
  `general_cure`, 8 carrying `aff` with no `gone`, and those 8 are precisely the
  `check*` predictions the guide's Step 2 calls out.

## Two defects in the public removal API, in neither document

Found while checking the state model. Both are in `Curing_skeleton.lua`, both
have **no caller anywhere in `src/`**, so they are reachable only from a user's
own script, and both are **pre-existing**: the identical text is in
`svo (curing skeleton, controllers, action system).xml` at 1373 and 1400.

**1. `svo.removeaff` recurses into itself forever.** `Curing_skeleton.lua:1391`:

```lua
  if affs[which] then
    if svo.dict[which].gone then
      svo.dict[which].gone.oncompleted()
    else
      svo.removeaff(which)     -- <- calls itself, nothing has changed
    end
```

Nothing between the two calls alters `affs[which]` or `svo.dict[which].gone`,
so the else branch is an unbounded self-call and ends in a stack overflow. It
is reachable for the 8 entries that carry `aff` and no `gone`, all of them the
`check*` predictions, which is exactly the set the assert above it lets
through. Almost certainly meant to be `svo.rmaff(which)`.

The sibling twenty lines down shows why. `svo.removeafflevel` is the same
function with one branch changed, and its else arm calls `svo.removeaff(which)`,
where that is a **different** function and the fallback makes sense. One of the
two was copied from the other and the call was never retargeted. That is the
copy-paste defect shape the spec's section 6.6 names as dominant here.

**2. `svo.removeafflevel` nil-calls on 174 of 189 entries.** Its gone branch is
`svo.dict[which].gone.general_cure(amount or 1, not keep)`, but only 15 of the
189 `gone` sub-tables define `general_cure`: the four humours, `crackedribs`,
`crescendo`, `horror`, `pressure`, `pyre`, `skullfractures`, `torntendons`,
`wristfractures` and the three `unweaving*`. Its assert only checks that the
name is a known affliction, so it accepts all 180 and raises on everything that
is not levelled. Loud rather than silent, so less dangerous than the first, but
the guard is checking the wrong property.

Neither is conversion damage and neither needs fixing today. Both want a static
check of the kind the spec's section 18.3 already proposes for `rmaff` naming.

## Architecture map, the signal bus and events, lines 289 to 381

Mostly exact. Five figures confirmed to the unit, one materially wrong.

- **OK** luanotify is 13,764 bytes across `signal.lua` and `double_queue.lua`.
  Measured 14,162 here, minus 398 lines, equals 13,764. A fifth LF confirmation.
- **OK** `raiseEvent` is called with exactly **51** distinct event names, and no
  call uses single quotes.
- **OK** `svo config changed` is raised exactly **68** times, across 12 files.
- **OK** exactly **41** items carry an `eventHandlerList` in the manifests.
- **OK** `svo_events` subscribes to **19** events and `svo_gevents` to **4**.
- **OK** the four-line `pcall` wrapper is quoted correctly.

### WRONG: the signal count, and the same way it was wrong before

> `Setup.lua` builds 53 signals, and the elistsorter addon creates one more of
> its own, `elistcaptured`, for 54 in total.

`luanotify.signal.new()` is called **65 times in `Setup.lua`**. The 53 are the
dotted form, `signals.X = signals.X or luanotify.signal.new()`. Lines 984 to 995
create **12 more** in bracket form, and the group listing in the document misses
every one:

```
mmapper updated pdb    svo config changed      svo defup changed
svo got balance        svo ignore changed      svo keepup changed
svo lost balance       svo prio changed        svo serverignore changed
svo switched defence mode                      svo system loaded
svo done defup
```

Two more exist outside `Setup.lua`: `elistcaptured` in the elistsorter, which
the document has, and **`svo.signals["namedb finished honors"]` at
`ndb_main_code.lua:912`, which it does not**. So the real total is **67**, not
54.

Three things follow, and they matter more than the count:

- **These 12 are named after Mudlet events**, which cuts across the document's
  clean split in the next section, "Signals are internal, Mudlet events are the
  public surface". Twelve signals carry the public event names exactly.
- **They are created by plain assignment, with no `or` guard.** The other 53 are
  `X = X or new()` and survive a reload with their connected handlers intact.
  These 12, plus `elistcaptured` and the NameDB one, are replaced outright every
  time the file re-runs, so anything connected to them is silently dropped on a
  class change. That is a behavioural difference, not a style one.
- **The cause is the error the document warns about in its own preamble.**
  It says the second pass "found and corrected two figures, the signal count
  and four of the dictionary balance-key counts". The signal count was corrected
  once and is still short, because both passes matched the dotted spelling and
  the bracket spelling was never in view. Same root cause as the spec's section
  21 entries about `svo.dict.lipread  = {` and the four three-dots-deep
  assignments.

## Architecture map, the balance list, lines 276 to 280

**WRONG on three names, incomplete by four.** The authoritative list is the
reset function at `Alias_functions.lua:950` onward, read in full.

- There is **no `arms` balance**, and no `left arm` or `right arm`. The real
  names are **`leftarm`** and **`rightarm`**, one word. The only bracket access
  anywhere is `bals[balance]` with a variable.
- Four real balances are missing: **`entities`** (Domination, gates the Arctar
  defence), **`hydra`** (Druid, gates `check_balanceful_acts`), and
  **`humour`** and **`homunculus`** (Physiology, both read by the custom
  prompt).
- So the set is **25** names, not 22: 19 of the document's are right.

**GAP** "maps balance name to `true` when you have it" misses a sentinel.
`leftarm` and `rightarm` initialise to the **string `'unset'`**, not `true`.
Every other balance initialises to `true`. `'unset'` is truthy, so the limb
balances read as held until the game says otherwise, which is deliberate and is
the only place a balance holds a non-boolean.

**NEW** `svo.bals` is class-dependent and neither document says so. Fourteen
balances are set unconditionally; the rest appear only under a skillset gate:
`voice` (voicecraft), `hydra` (Druid), `entities` (domination), `prayer`
(zeal), `shrugging` (venom), `fitness` (seven skillsets), `rage` (the four rage
skillsets), `humour` and `homunculus` (physiology), `word` (terminus),
`anathema` (anathema).

- **OK** the 17 `lostbal_*` functions the spec's section 6.4 lists are exactly
  the 17 that exist, by name.

## Architecture map, "Findings", lines 3178 to 3284

This section is the most accurate part of the document. Nine claims reproduce
exactly, one is wrong, and one is not reproducible from its description.

### Exact

- **OK 2,317 triggers in the main tree**, counted as non-folder items across
  `svo (aliases, triggers)`. All trees together give **2,541**, which is the
  inventory table's leaf count. Both to the unit.
- **OK 106 base configuration options.**
- **OK the default priority lists hold 422 entries across ten balances, 211 of
  them slowcuring.** Measured per balance: sip 6, physical 49, moss 2, smoke 9,
  slowcuring 211, purgative 5, salve 41, focus 19, misc 26, herb 54.
- **OK 28 of the 32 loaders are hot-reloadable**, and the four without a
  `if svo.systemloaded then svo.loader.X() end` tail are exactly `setup`,
  `enchanter`, `fishdist` and `mindnet`.
- **OK the `blistered` finding, in full.** `svo diag` has exactly **149**
  children, exactly **one** has an empty body, and it is `blistered`, pattern
  `suffering from horribly blistered skin.`, exactMatch, `isActive: yes`. There
  is no `blistered.lua` on disk: the blank script is inline in the manifest, so
  it is one of the 64 inline scripts. **`pyre` is not among the 149.** This
  independently confirms the `svof-dead-diag-triggers` memory on every point.
- **OK `checkparalysis` is hardcoded off** with `if true then` and the original
  condition preserved as a comment beneath, carrying the comment "disabled, as
  fling no longer works and illusions are not so prevalent".
- **OK `string.ordinalSuffix` is defined twice**, `svo_Utilities.lua:100` and
  NameDB's `Third-party/Ordinal.lua:1`.
- **OK `svo.reenchant` is defined twice in one file**, `enchanter_script.lua`
  at 871 and 1240.
- **OK the `vsl` alias exists in both** the limbcounter and the burncounter
  alias manifests.

### WRONG: "The dictionary holds 265 actions"

It holds **267** in the literal, which the spec, `derive_svof_facts.py` and a
tokenising read all agree on. I can show exactly where 265 came from, and it is
the formatting-assumption error again:

- **`horror` (line 1079) and `revealed` (line 5060) are indented two spaces.**
  Every other entry uses four. A `^    NAME = {` spelling misses both.
- That same spelling also picks up one **false positive**, a nested `physical`
  sub-table that happens to sit at four spaces.
- So the naive spelling yields 266 names, of which 265 are real entries.
  **265 is precisely what you get.**

The claim is also scoped wrongly, in the way the spec's section 21 already logs
for an earlier reading. The literal is one of three construction sites. Counting
it and calling the result "the dictionary" understates by more than half: the
real figures are 579 definitions over 542 distinct names, of which 287 are
defences.

Two entries out of 267 is a small error with a large lesson, because it is the
fourth instance of the same cause in this codebase: `svo.dict.lipread  = {` with
two spaces, the four three-dots-deep assignments, the 16 one-line delegations,
and now two entries indented differently from their 265 neighbours.

### Not reproducible from its description

"106 base options plus up to 23 skillset-conditional ones." The 106 confirms
exactly. The 23 does not fall out of any obvious reading of `Config_system.lua`:
there are no config entries indented inside a gate, and the file carries 18
skillset or class gates. The conditional options are presumably registered from
elsewhere. Like the 1,488 function count, this needs its method stated or
dropped.

### A structural detail both documents get slightly wrong

The naming-rules section describes how **folders** map to directories. It does
not cover **nested children of a non-folder trigger**, which is how the diag
tree is actually built. `svo diag` is `isFolder: no`: it is a multiline trigger,
`multilineDelta: 1`, `fireLength: 250`, matching `You are:`, that holds the gate
open while its 149 `children` match individual lines. Those children's scripts
are written into the **parent** directory, which is why `General/` holds 424
`.lua` files against 178 manifest items at its own level. Any tool reconciling
manifests against the filesystem has to walk `children`, not just `isFolder`
directories, or it reports hundreds of phantom orphans.
