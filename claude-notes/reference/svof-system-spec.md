# svof system specification

A working reference for the svof curing system: what it is made of, how a turn
flows through it, and how `svo.dict` is shaped, since everything else hangs off
it.

Load this into a Claude Code session on the repo. It is a map, not a substitute
for reading. Where a section says how something behaves, it names the file and
line so you can check the claim in one jump.

---

## 0. Provenance and currency

Read this section before you trust anything else here.

### Where the content came from

Two sources, and they have different dates.

**Source A, the code reading.** Sections 4 to 17 were read out of the source, in
full, in the files named. Nothing there is generalised from a similar-looking
pattern elsewhere, and nothing is carried over from how other Mudlet systems
work.

That reading used a partial checkout containing `src/scripts` (19 `.lua` files,
about 36,800 lines), `src/resources/default_prios`, part of `tools/`, and the
three markdown docs. It did **not** contain `src/triggers`, `src/aliases`,
`src/timers`, `src/keys`, the 25 reference `svo (*.xml)` files, or most of
`svo (core)`. For scale, `CLAUDE.md` quotes 2,317 triggers in the built package.
Anything this document says about triggers, aliases, or the parts of
`svo (core)` beyond `svo_init_system`, `svo.classchange`, `Rage_curing_strats`,
and `@affs` is absent, not summarised.

**Source B, the Claude Code export of 2026-09-03.** Sections 0 to 3, 11, and 18
come from `svof-cowork-export`: a project spec plus eight memory files covering
2026-08-23 to 2026-08-31. That export is newer than the checkout and wins on any
conflict.

### The checkout is behind trunk

The checkout used for source A sits **after pull request 850 and before 853**.
Three pieces of evidence, all checked:

- `mfile` reports version 65. The export says version 66 is the current working
  branch.
- The `affs.pyre.count` read that 853 fixes is still present at five sites in
  `Dictionary_of_actions_(affs-defs-misc).lua`, lines 4576, 4652, 4697, 4742,
  and 4787.
- `tools/` holds `verify.py` and `test_lifevision_validate.lua` but lacks
  `verify_merged.py`, `check_lua_syntax.py`, `merge_svof.py`,
  `verify_baseline.json`, and `test_pyre_ladder.lua`.
- The `flamefisted` rename from 850 **is** present, and so are the GMCP
  reconciler comments from 846 and 847.

So treat every line number here as a landmark to search near, not an address to
trust, and re-derive the counts before you quote them.

### What has and has not been seen in play

An earlier draft of this document said none of svof's behaviour had been
observed in play. That was wrong, and the export corrects it:

- **Curing has been observed in two captured Achaea fights**: 54 of 54
  afflictions cured, zero Lua or regular expression errors.
- **The install, load, and update path has live coverage**:
  `C:\work\svof-live-testing` installs the built package into a real Mudlet
  4.22.0 and runs 24 load checks and 25 update checks, including a control that
  reproduces a fixed bug so the suite cannot silently stop meaning anything.
- **A capture with real defence resyncs is still wanted.** It is the missing
  live coverage for the defence List reconciler.
- **Sustained play testing has not happened.** Whether tracking and curing hold
  up under pressure over a long session is unknown.

Say what has been verified and what has not, and keep those three tiers apart.

### Re-deriving the numbers

Run `derive_svof_facts.py`. Where it disagrees with this document, the script is
right and the document is stale. It is one of the **analysis harnesses**, not one
of the repo's gates: see section 22 for where those live.

---

## 1. What svof is

svof is a curing system for the text game Achaea, running inside the Mudlet MUD
client. It tracks the character's afflictions and defences, cures them by a
configurable priority order, keeps defences raised, and ships addons for limb
counting, name highlighting, offering, logging, rift and inventory tracking, and
similar. It is written in Lua, with Mudlet triggers, aliases, timers, keys, and
buttons as the surrounding structure.

Upstream repository: `svof/svof`. Working fork: `TheLastDarkthorne/svof`.
Documentation site: https://svof.github.io/svof/

---

## 2. Repository, build, and gates

svof used to ship as 25 hand-edited Mudlet XML files installed as 24 modules
plus a bootstrap, with load order set by `modules_list` and `setModulePriority`.
It now builds as **one `svof.mpackage`** from per-item `.lua` and `.json`
sources under `src/`, using muddler. The module system is gone.

```
src/                      source of truth: per-item .lua + .json, by kind
src/resources/            copied to the package root, read at runtime
tools/                    gates, converter, test suites, baseline
build/                    muddler output: svof.xml and svof.mpackage
doc/                      documentation source for the site
mfile                     package metadata: name, version, author, description
svo (*.xml)               25 frozen reference files, never edited
CLAUDE.md                 the repository working notes
```

### Ground rules that must survive any plan

1. **`src/` is the source of truth.** The 25 root XML files are the reference
   the build is verified against, nothing more. Never edit them, and never
   regenerate `src/` from them. `tools/merge_svof.py` was a one-time conversion,
   and rerunning it discards everything written since. It carries a `--force`
   guard for that reason.
2. **Diff every file a bulk edit touches, before committing.** Scripted
   multi-file edits have destroyed real code in this repo three times, and each
   time tooling caught it rather than a person reading the diff.
3. **Verify with the tools and quote the numbers.** Do not call a build good
   without running the gates and saying what they printed.
4. **Read code in full.** Use grep to locate, never as the sole basis for a
   claim about behaviour. This repo punishes partial reading.
5. **No AI or Co-Authored-By attribution** in commits, pull requests, or issues.
6. **In public issues, refer to svof by name and link only.** Do not describe
   what it is.
7. **Add a `.lua` to the sibling `.json` first.** muddler builds from the JSON
   and looks for `name:gsub(" ","_")..".lua"`. A `.lua` with no JSON entry ships
   as nothing and warns about nothing.
8. **Add items inside an existing group.** The 126 top-level slots are frozen
   and checked against the reference XML files. A new one is a structural
   difference, and `--write-baseline` refuses to bless it.

### The gates

```
java -jar muddle-all.jar
python tools/verify_merged.py build/svof.xml --baseline tools/verify_baseline.json
python tools/check_package.py --luac <path to luac>
python tools/check_lua_syntax.py
python tools/check_renamed_callsites.py
python tools/check_src_tree.py
lua tools/test_gmcp_reconciler.lua
lua tools/test_pyre_ladder.lua
```

What each one exists for:

- `verify_merged.py` compares the built package object by object against all 25
  original XML files: structure, names, scripts, patterns, pattern types, alias
  regexes, event handlers, behavioural flags, and top-level load order. It
  splits problems into **structural** (missing, duplicated, misplaced, or
  reordered items), which are always fatal and cannot be baselined, and
  **content** (script and flag differences), where the deliberate ones live in
  `tools/verify_baseline.json` with a digest each. Regenerate the baseline with
  `--write-baseline` in the same commit that causes the difference.
- `check_package.py` opens the `.mpackage` that users install, which nothing
  else does. Every other gate verifies `build/svof.xml`, its sibling.
- `check_src_tree.py` catches a `.lua` with no entry in the sibling JSON, two
  item names resolving to one filename, and a filename differing from its item
  name only in case, which resolves on Windows and not on the Linux runner.
- `check_renamed_callsites.py` exists because Mudlet does not raise on an
  unknown item name. Enabling a trigger by a name that no longer exists is a
  silent no-op.
- `check_lua_syntax.py` parses about 2,800 chunks and must run under Lua 5.1. A
  5.2 or later `luac` reports 5 false errors, all legal 5.1, and prints a banner
  saying so. Never change code to satisfy a newer `luac`.
- `test_gmcp_reconciler.lua` extracts the six GMCP affliction and defence
  handlers from the real `Setup.lua` by anchor text and runs them under stubs,
  so the code under test cannot drift from what ships.
- `test_pyre_ladder.lua` is CI gate 1.7, added by 853.

Three gate facts that repeatedly cost time:

- **Build on Linux before believing a build.** Filesystem enumeration order
  differs between Windows and Linux, and that is a real source of silently
  reordered packages. Line-ending and path-separator differences between the two
  are harmless and expected.
- **Any new check that reads a file's raw bytes must be verified against the git
  blob, not the working tree.** A Windows checkout rewrites LF to CRLF, so a
  passing local run proves nothing about what Linux CI sees. This class of bug
  has bitten three times.
- **The accepted-difference count lives in `tools/verify_baseline.json` and the
  gate prints it.** Do not hardcode it in prose. Comment rot around that number
  happened three separate times before it was removed.

The gate had nine blind spots across three review rounds, all now closed. Do not
reintroduce them. The full list is in `CLAUDE.md`.

### Toolchain constraint

The build requires the fork `TheLastDarkthorne/muddler`, branch `svof-fixes`,
pinned to commit `45616f1`. Upstream muddler cannot build svof correctly. It
drops nested group attributes, zeroes `multilineDelta`, cannot represent a raw
key code, crashes on colour patterns, mis-orders groups by directory read order,
and ships a `Button` class that nothing constructs, so an 8-button toolbar
builds clean and button-free. All of it is reported upstream in muddler pull
requests 57, 59, and 60, and issue 58. Until those merge, the fork is required.

`muddle-all.jar` is not in the repository. Rebuild it:

```
git clone https://github.com/TheLastDarkthorne/muddler
git checkout --detach 45616f1
./gradlew --no-daemon shadowJar
```

That takes about 40 seconds. Without the jar, `verify_merged`, `check_package`,
and any baseline regeneration cannot run at all.

DeMuddler is not in the build path and must not be added to it. It was evaluated
and abandoned after three silent data-loss bugs.

### Renaming an item is structural

`verify_merged.py` builds comparison paths out of item **names**, so renaming
any leaf item reports `path 'x' != 'y'`, which is structural and cannot be
baselined. A deliberate rename must be declared:

- `GROUP_RENAME` for a module's top-level group.
- `ITEM_RENAME` for leaf items, keyed by kind and by the item's path in the
  original tree. `describe_tree` takes a `renames` argument passed only for the
  reference side, and carries both spellings down the walk.

Rename the `.lua` file to match, because the lookup is
`name:gsub(" ","_")..".lua"`. Then let `check_renamed_callsites.py` confirm
nothing still calls the old name.

`ITEM_RENAME` has three known hygiene gaps, all open:

- A stale or mistyped key is completely silent. `renames.get(orig_p, nm)` falls
  through and nothing records that a recorded rename matched zero paths. The fix
  is to assert every key was consumed at least once, matching the `MIN_ITEMS`,
  `MIN_REFERENCES`, and `MIN_RENAMES` floors `check_renamed_callsites.py`
  already carries.
- The map is not scoped to a module. It is passed to every top-level item of
  that kind across all 25 modules, so an unrelated tree with a matching path
  gets rewritten too.
- The `#N` dedup counter is keyed on the **original** name, so a rename landing
  on an existing sibling emits two identical paths and `dict(a)` silently keeps
  one.

---

## 3. Branches, pull requests, and release state

The conversion stack and the fixes on top of it went in as pull requests 845,
846, 847, 848, 850, 851, and 853. **All are merged into `in-client-svof`.** The
`gh stack` workflow described in `CLAUDE.md` no longer applies to them. New work
branches straight off `in-client-svof` as a standalone pull request.

- `origin` is `svof/svof`, `fork` is `TheLastDarkthorne/svof`.
- `in-client-svof` is trunk for the package work.
- `master` is the old pre-conversion line.
- `fork-version-66` is the current working branch, one commit ahead of
  `in-client-svof` with the version bump to 66. `in-client-svof` carries one
  commit that `fork-version-66` does not, restoring the pre-conversion README.
  **Those two need reconciling before a release.**

Open: **852**, branch `rename-config-hygiene`, five `verify_merged.py` fixes.
Tooling only, no baseline movement. **842** is still open; 853 superseded its
burn-entry half, but 842 is where the game mechanics came from.

### Existing users stay on the old version, deliberately

Decided by the repository owner on 2026-08-23, while the conversion is still
being tested. Merging the stack must not reach a single existing user, and it
does not. Do not "fix" this.

The old updater has two halves and the merge touches neither. The version check
polls `svof.github.io/svof/<releasechannel>/current_version.txt`, where
`inclient`, the default, holds 65, and the modules on `in-client-svof` already
report version 65, so both populations compare equal. The download pulls raw XML
from the branch root, and those 25 files are byte-identical to what they were.

The new updater is a completely disjoint mechanism: the GitHub Releases API and
an `svof.mpackage` asset. The release job never writes `current_version.txt`.

**The one way to break this** is bumping `inclient/current_version.txt` past 65
while the branch XML files stay frozen at 65. Old clients would then download,
land back on 65, see the higher number, and download again, in a loop that never
delivers anything. Move the two halves together, or retire the old channel
deliberately.

---

## 4. Loading and class change

`svo_init_system()` lives in `svo (core)/Load & init/svo_init_system.lua`, and
runs on `sysLoadEvent` and `sysInstall`.

Each subsystem file defines `svo.loader.<name> = function() ... end` and ends
with `if svo.systemloaded then svo.loader.<name>() end`, so saving a script in
Mudlet re-runs just that loader. `svo_init_system` runs 22 required subsystems in
a fixed dependency order, because a loader may need functions another one
defined:

```
setup, misc, empty, dict, sk, controllers, action, pipes, rift, diag,
valid_simple, valid_main, config, install, aliases, defences, prio,
parry, funnies, dor, customprompt, serverside
```

Then, in order, it clears `svo.signals`, runs every loader, emits
`svo.signals.systemstart`, sets `svo.systemloaded = true`, raises the
`svo system loaded` event, and finally runs 10 addon loaders: `limbcounter`,
`priestreporter`, `inker`, `mindnet`, `burncounter`, `elistsorter`, `enchanter`,
`refiller`, `peopletracker`, `fishdist`.

It bails out early and silently if Penlight is not loaded, if any required
subsystem is missing, or if Mudlet is older than 3.20.

**Anything needing the core must register on `svo system loaded`.** A zero-delay
temporary timer is not safe for this. As separate modules it was enough to get
behind the core. In one package a script can run before `svo_init_system` does.

Paths: `svo.installationfolder()` returns `<profile>/svof`, where Mudlet unpacks
the package, so files read at runtime must live in `src/resources/`. User data
lives under `<profile>/svo/`, and the conversion did not move it.

### Class change

`svo (core)/Load & init/svo.classchange.lua`:

```lua
    svo.sk.resetserversideprios()
    svo.dict = {}
    svo.systemloaded = false; svo_init_system()
```

General defences are stashed and re-applied afterwards so svof does not re-raise
what is already up. The consequence that matters for anything you build:
**`svo.dict` is destroyed and rebuilt on every class change.** Anything installed
into the dict from outside must be re-installable, and anything that must
survive belongs in a table declared `svo.X = svo.X or {}` in `Setup.lua`.

---

## 5. The prompt tick

From `Developer_readme.md` and `Controllers.lua:215-288`:

```
onprompt
 checkblackout, check_promptflags, prompt_stats, calculatestatchanges
 signals.before_prompt_processing
     prompt_stats            (stores new prompt stats)
     sk.acrobatics_pronecheckf
     valid.check_life
     sk.onprompt_beforelifevision_do  (-> svo.aiprompt())
 send_in_the_gnomes
     lifevision.validate                 <- illusion decision, section 9
     signals.after_lifevision_processing
         sk.onprompt_beforeaction_do / prompttrigger
         cnrl.checkwarning
         sp_checksp
     make_gnomes_work                    <- curing commands, section 8
 signals.after_prompt_processing
     custom prompt
     cnrl.dolockwarning
 fancysendall, sk.dosendqueue
 svo.paragraph_length = 0
```

Two things to hold on to. **GMCP is processed before the game text it
accompanies**, so by the time a cure's own line reaches a trigger, the
`Char.Afflictions.Remove` handler has already removed the affliction. That is
why `sk.gmcp_cured` exists, covered in section 14. And `svo.paragraph_length`
resets here, which is what the illusion check counts against.

---

## 6. svo.dict, the actions dictionary

`svo (actions dictionary)/Dictionary_of_actions_(affs-defs-misc).lua`, 15,417
lines, the largest file by an order of magnitude. Everything svof does, whether
curing an affliction, raising a defence, or waiting for a balance, is an action
defined here.

### 6.1 Shape

```lua
svo.loader.dict = function()                              -- line 25
  ...
  if not next(svo.dict) then                              -- line 401
    svo.dict = {                                          -- line 402
      <entry> = { ... },   -- 267 of these
    }                                                     -- closes 10766
    ...class and skillset gated assignments...            -- 155, over 148 names
  end                                                     -- closes 14615
  function svo.basicdef(...)                              -- 14622
  basicdef('satiation', 'satiation')                      -- 157 calls, 14655+
  function svo.dict_setup()                               -- 14942
  svo.dict_setup()                                        -- 15109
  function svo.dict_validate()                            -- 15111
  ...
end                                                       -- 15415
if svo.systemloaded then svo.loader.dict() end            -- 15417
```

Note the asymmetry, because it bites. The 267-entry literal sits behind
`if not next(svo.dict)`, but `basicdef` and `dict_setup` are **outside** it. So
re-running the loader against a populated dict skips the afflictions, rebuilds
all 157 defence entries from scratch, and runs `dict_setup` again anyway.

The comment at line 396 states a design constraint the whole system depends on:

> `dict is to NEVER be iterated over fully by prompt checks; so isadvisable
> functions can typically expect not to check for the common things because
> pre-filtering is done.`

That is why `isadvisable` for a herb cure does not check `bals.herb`. The caller
already did, as section 8 shows.

### 6.2 What is in the dictionary, by kind

Entries reach `svo.dict` from **three** construction sites, and the literal is
only the first of them. Counting the literal alone badly understates the
defences, because almost every defence is built elsewhere.

| site | definitions | distinct names |
|---|---:|---:|
| the `svo.dict = { ... }` literal | 267 | 267 |
| `svo.dict.NAME = { ... }`, class and skillset gated | 155 | 148 |
| `basicdef(...)` calls | 157 | 134 |
| **total** | **579** | **542** |

Classifying every definition, where a defence is a balance carrying
`def = true` and an affliction is an entry with an `aff` sub-table:

| kind | literal | class-gated | basicdef | total |
|---|---:|---:|---:|---:|
| affliction | 179 | 1 | 0 | 180 |
| both affliction and defence | 1 | 0 | 0 | 1 |
| defence | 29 | 136 | 157 | 322 |
| wait or timer action | 39 | 8 | 0 | 47 |
| other action | 15 | 10 | 0 | 25 |
| name map, not an action | 4 | 0 | 0 | 4 |

By distinct name, counting a name as a defence if any of its definitions is
one: **287 defences, 181 afflictions, 47 wait or timer actions, 24 other
actions, 4 name maps.** `insomnia` is the one entry that is both an affliction
and a defence, carrying `def = true` on its `herb` and `misc` balances.

Cross-checked against `Defences.lua`, which holds 396 live `defs_data:set`
calls over 317 distinct names: **every one of the 287 defence entries has a
`defs_data` record**, and 30 records have no dict entry. 28 of those 30 carry
`nodef`, `invisibledef` or `custom_def_type`, so svof recognises them and never
means to raise them. The remaining two, **`bedevil` (Zeal) and `evasion`
(Woodlore), carry none of those flags**: the consumer loop gives each a
`defdefup`/`defkeepup` slot, so a user can add either to defup and
`sk.have_defup_defs` will list it as `bedevil (?)` forever, because no dict
entry exists to raise it. Read from the code, not observed in play.

Names are defined more than once on purpose, inside alternative
`svo.haveskillset` branches: 18 names are passed to `basicdef` twice, and
`bear`, `eagle`, `fitness`, `lyre`, `reflection`, and `vitality` are assigned
twice. Six names are defined at two different sites, and the later site wins at
runtime: `nightsight` in the literal and again by `basicdef`, `lyre` in the
literal and again class-gated, and `barkskin`, `grip`, `hiding`, `resistance`,
and `tentacles` class-gated and again by `basicdef`.

**The 71 actions that are neither afflictions nor defences** are what Change A
must not sweep into a derived list. The 47 waits are the `curing*` family plus
`givewarning`, `gotbalance`, `gothit`, `nomana`, `stolebalance`, and the
`waitingfor*` and `waitingon*` set. The 24 others are `block`, `breath`,
`cloak`, `defcheck`, `diag`, `doparry`, `doprecache`, `dragonarmour`,
`dragonbreath`, `dragonflex`, `dragonform`, `dragonheal`, `fillelm`,
`fillskullcap`, `fillvalerian`, `healhealth`, `healmana`, `lightpipes`, `lyre`,
`meditate`, `metawake`, `mindseye`, `restore`, `rewield`, and `touchtree`, plus
`rage` and `dwinnu` from the class-gated set.

### 6.2b An entry

An entry is a table of **balance sub-tables** plus a few entry-level fields.
`paralysis`, from `Developer_readme.md`, is the canonical example:

```lua
  paralysis = {
    herb = {                        -- the balance this cure spends
      isadvisable = function()      -- should we do this, right now?
        return (affs.paralysis) or false
      end,
      oncompleted = function()      -- the cure worked
        svo.rmaff('paralysis')
        svo.lostbal_herb()
        svo.killaction(svo.dict.checkparalysis.misc)
      end,
      eatcure = {'bloodroot', 'magnesium'},   -- herb, then its mineral pair
      onstart  = function() svo.eat(svo.dict.paralysis.herb) end,
      empty    = function() empty.eat_bloodroot() end,
    },
    aff  = { oncompleted = function() svo.addaffdict(svo.dict.paralysis) end },
    gone = { oncompleted = function() svo.rmaff('paralysis') end },
    onremoved = function() svo.affsp.paralysis = nil svo.donext() end,
  },
```

### 6.3 The balance sub-tables

Counts are entries carrying at least one such sub-table.

| sub-table | entries | what it is |
|---|---:|---|
| `gone` | 189 | the game said the affliction is gone |
| `aff` | 180 | the game said you gained it |
| `waitingfor` | 73 | not a cure, a timed wait, with `customwait` and `ontimeout` |
| `herb` | 68 | eat a herb or its mineral pair |
| `salve` | 45 | apply a salve |
| `physical` | 26 | costs physical balance or equilibrium; `balanceful_act`, `balanceless_act` |
| `misc` | 26 | anything with its own balance: rage, tree, class skills |
| `focus` | 20 | cure by focusing; an alternative route, never the only one |
| `smoke` | 13 | smoke a herb or mineral |
| `sip` | 6 | sip a potion |
| `purgative` | 5 | |
| `happened` | 4 | |
| `moss` | 2 | |
| `map`, `tempmap`, `boosted`, `weakened` | 1 each | special purpose |

Three things about this table are easy to get wrong:

- **`focus` is an alternative, not a second balance an affliction needs.**
  Afflictions like `pacifism` can be cured either by focus or by the normal cure.
  The `focus` block only describes what to do if svof picks focus this tick.
  Every focusable affliction wants one.
- **`eatcure = {'bloodroot', 'magnesium'}` is a herb and mineral pair**, not a
  container and its contents. Achaea has two kinds of eatable and smokable cure,
  herbs and minerals, and the two entries cure the same thing. Elm and cinnabar,
  valerian and realgar, skullcap and malachite.
- **Second entries in `applycure` and `sipcure` lists are dead.** Transmutation
  cures, which is what mineral-based salves and potions were called, no longer
  exist in Achaea. `renewal`, `reconstructive`, `sensory`, `exothermic`,
  `density`, `vitality`, `mentality`, `antigen`, `endothermia`, `hovering`,
  `haste`, and `toxin` are leftovers. Do not treat a missing second name as a
  gap to fill.

### 6.4 The resolution branches

When an action resolves, the action system calls
`act[other_action or 'oncompleted'](arg)` at `Action_system.lua:106`. The branch
name is chosen by whatever recognised the outcome: a trigger, the lifevision
system, or a GMCP handler. Counts are balance sub-tables defining that branch.

| branch | count | fires when |
|---|---:|---|
| `oncompleted` | 656 | the default, the action did what it was for |
| `onstart` | 284 | not a branch: sends the command, `send('rage', ...)` |
| `isadvisable` | 247 | not a branch: the predicate the curing loop asks |
| `empty` | 154 | **the cure fired and cured nothing** |
| `noeffect` | 68 | **the attempt did nothing because you were off that balance** |
| `ontimeout` | 51 | the action's failsafe timer expired |
| `cured`, `general_cure`, `general_cured` | 15 each | levelled afflictions: one level off versus the whole thing gone |
| `fizzled` | 11 | salve fizzled off balance |
| `onclear`, `forced`, `helpless`, `all` | 10 or fewer | narrow cases |

**`empty` and `noeffect` are the two that get misread, and they are not
symmetric.**

`empty` means you ate the bellwort and nothing was cured. That means you do not
have any of the afflictions bellwort cures, so svof reasserts: it strips every
affliction that cure would have handled from its tracking. It also records the
balance loss, because eating spends herb balance whether or not anything was
cured. `Empty_cure_handling.lua` builds these per herb:

```lua
empty['eat_'..herbname] = function()
  svo.lostbal_herb()
  if not affs.madness then svo.rmaff(herbaffs)
  else svo.rmaff(table.n_complement(herbaffs, madness_affs)) end
end
```

Madness makes cures lie, so the affs it can fake are excluded from the sweep.

`noeffect` means you tried to eat and got the "no effect" message because you
were **already off herb balance**. Cure paralysis with bloodroot, then
immediately try bloodroot again for slickness: that is a `noeffect`. It says
nothing about which afflictions you have.

**`svo.lostbal_<balance>()` records that a balance was spent. It does not return
one.** Eating a herb knocks you off herb balance whether or not it cured
anything, and that is what these functions record. `Curing_skeleton.lua:1555`,
`svo.lostbal_rage`, is the shape of all 17:

```lua
svo.lostbal_rage = function()
  if not bals.rage then return end
  bals.rage = false
  svo.startbalancewatch('rage')
  sk.ragetick = sk.ragetick + 1
  local oldragetick = sk.ragetick
  tempTimer(15+svo.getping(), function ()          -- fallback recovery
    if not bals.rage and sk.ragetick == oldragetick then
      bals.rage = true; svo.make_gnomes_work()
      raiseEvent("svo got balance", 'rage')
    end
  end)
  raiseEvent("svo lost balance", 'rage')
end
```

The 17: `tree`, `focus`, `shrugging`, `fitness`, `rage`, `prayer`, `voice`,
`sip`, `herb`, `salve`, `moss`, `purgative`, `smoke`, `dragonheal`, `word`,
`anathema`, `wrathbal`.

### 6.5 Other fields on a balance sub-table

`eatcure` (72), `customwait` (72), `actions` (59), `applycure` (46), `action`
(42), `uncurable` (31), `def` (18), `balanceful_act` and `balanceless_act` (13
each), `smokecure` (12), `notagameaff` (9), `irregular` (8), `sipcure` (7),
`dontbatch` (7).

The flags that change how the rest of the system treats the entry:

- **`def = true`** marks a defence. `dict_setup` auto-creates a `gone` handler so
  lifevision watches it, and the entry joins the matching `svo.dict_*_def`
  shortlist.
- **`uncurable = true`** means serverside can never take this action. It is
  excluded from `sk.getallserversideactions` at `Serverside.lua:456` and dropped
  from prio lists by `sk.splitdefs` at `Serverside.lua:284`. Since the
  serverignore UI is built from that same list at `Alias_functions.lua:712`, an
  `uncurable` action can never be handed to serverside even deliberately.
- **`undeffable`** means serverside cannot raise this defence, so svof must.
- **`dontbatch`** means that in async `check_misc`, once one `dontbatch` action
  has been done, no further `dontbatch` action goes out this tick.
- **`irregular`**, like `uncurable`, is excluded from serverside prio lists.

### 6.6 Copy-paste is the dominant defect shape

The dictionary grew by copy-paste, and that is where its bugs come from. Known
instances, found in one small area: `mindravaged`'s `gone` calling
`rmaff("burning")`, fixed in 850; `flamefisted` carrying `ablaze`'s `pyre`
guard; `icing` and `flamefisted` both at `customwait = 30, -- ??`, both
unverified guesses that want timing in game.

When you read an entry, ask which neighbour it was cloned from and what did not
get updated.

---

## 7. dict_setup, the generator

`Dictionary...lua:14942`. It walks the whole dictionary and fills in what every
entry would otherwise repeat.

It stamps identity onto every balance sub-table:

```lua
if not balancedata.name        then balancedata.name        = action..'_'..balancename end
if not balancedata.balance     then balancedata.balance     = balancename end
if not balancedata.action_name then balancedata.action_name = action end
```

So `svo.dict.bleeding.misc.name` is `"bleeding_misc"`. That name is the key
everything else uses: `svo.actions`, `svo.lifevision.l`, the sync priority list,
and `valid_sync_action`'s `actionname_balance` format.

It fills in default handlers, each only when absent: `herb.noeffect`,
`herb.mickey`, `focus.nomana`, and `offbalance` for focus, salve, herb, and
smoke. It gives every entry a `sw` stopwatch, and every priced balance an
`aspriority` and `spriority` of 0 if it has none.

It rebuilds eight derived shortlists so the curing loop never walks the whole
dictionary: `dict_balanceful`, `dict_balanceless`, `dict_herb`, `dict_misc`,
`dict_misc_def`, `dict_purgative`, `dict_salve_def`, `dict_smoke_def`. Each
holds `{p = svo.dict[action]}`, a reference, so mutating the entry is visible
through the shortlist.

Then it renumbers priorities: anything left at 0 is pushed to the bottom of its
balance and everything above it shifted up.

### 7.1 dict_setup is idempotent by construction, and must stay that way

Every field it installs is either behind `if not X then` or self-guarding, as in
`X = X or 0`. There are no exceptions, verified by scanning the body.

This is not stylistic. `dict_setup` has **five call sites**:

| where | when it fires |
|---|---|
| `Dictionary...lua:15109` | end of `svo.loader.dict()`, so every load and every class change |
| `Priorities.lua:476` | inside `prio.import` |
| `Defences.lua:2590` | Phylactery of Sixth Sense detected |
| `Defences.lua:2702` | lifevision mask detected |
| `Defences.lua:2813` | Shadowcloak detected |

`prio.import('current')` is wired to `systemstart` at `Priorities.lua:491`, which
`svo_init_system` emits after every loader has run. `prio.import` falls back to
the bundled `default_prios` when no saved file exists, at `Priorities.lua:417`,
so it reaches line 476 even on a fresh install.

**So `dict_setup` runs at least twice on every load**, once more per artefact the
character owns, once per `prio import`, and again on any script re-save. Anything
you add to it that replaces rather than fills in will compound.

---

## 8. The curing loop

`svo (curing skeleton, controllers, action system)/Curing_skeleton.lua`

`signals.changecuring` binds `make_gnomes_work` at load to one of two
implementations: `_async` normally, `_sync` under aeon or retardation, and a
no-op while logging in.

Async, in `work_slaves_work` at line 662, asks every balance in turn:

```
check_misc(false, true)   -- amnesia and fear only, first
check_focus, check_salve, check_sip, check_purgative, check_smoke, check_herb
check_misc()              -- the rest
check_moss
check_balanceless_acts
check_balanceful_acts     -- and if it did nothing, sk.balance_controller()
```

Each `check_*` has the same shape, and the pre-filter at the top is the "common
things" the entry conditions are allowed to skip:

```lua
svo.check_herb = function(sync_mode)
  if not bals.herb or svo.usingbal('herb') or affs.sleep
    or affs.stun or affs.unconsciousness or svo.sacid or affs.anorexia
    or (conf.aillusion and conf.waitherbai and sk.checking_herb_ai()) then
      return
  end
  local prios = {}
  local function check (what)
    for i, j in pairs(what) do
      if not (conf.serverside and svo.serverignore[i]) and j.p.herb
        and j.p.herb.isadvisable() and not svo.ignore[i]
        and (sys.canoutr or sk.can_eat_for(j.p.herb)) then
          prios[i] = (not sync_mode) and j.p.herb.aspriority or j.p.herb.spriority
      end
    end
  end
  check(affs)
  if sys.deffing or conf.keepup then check(svo.dict_herb) end
  if not next(prios) then return false end
  if not sync_mode then
    svo.doaction(svo.dict[svo.getHighestKey(prios)].herb) else
    return svo.dict[svo.getHighestKey(prios)].herb end
end
```

So an `isadvisable` is called only for afflictions you currently have, plus the
relevant defence shortlist, and four things outside itself gate it: serverside
ownership, the `svo.ignore` list, item availability, and the balance pre-filter.

**One balance behaves differently and it matters.** `check_misc` in async mode
does **every** advisable misc action in priority order, not just the top one,
because misc actions sit on separate balances:

```lua
    for i = highest, lowest, -1 do
      if set[i] then
        if not svo.dict[set[i]].misc.dontbatch or not dontbatch then
          svo.doaction(svo.dict[set[i]].misc)
          if svo.dict[set[i]].misc.dontbatch then dontbatch = true end
```

Every other `check_*` takes the highest and stops. In sync mode all of them
return a candidate instead of acting, and `make_gnomes_work_sync` picks the
single highest `spriority` across all balances. It also refuses to start
anything while any non-`waitingfor`, non-`gone`, non-`aff` action is in flight.

---

## 9. The action system and lifevision

`Action_system.lua`, 383 lines, read in full, and `Curing_skeleton.lua:356-477`.

**`svo.doaction(act)`** takes a balance sub-table, for example
`svo.dict.healhealth.sip`. It:

1. computes a timeout from `customwait` or `customwaitf`, `sys.wait`, and
   `syncdelay()`, and arms a `tempTimer`;
2. registers the action in `svo.actions` under `act.name`, with a `completed`
   closure that dispatches `act[other_action or 'oncompleted'](arg)`;
3. records it in `bals_in_use[act.balance][act.name]` and
   `actions_performed[act.action_name]`;
4. `pcall`s `act.onstart()`, which is what actually sends the command.

On timeout it increments `sys.lagcount`, calls `ontimeout` if present, and infers
stupidity if a stupidity count is pending.

Queries built on that bookkeeping: `svo.usingbal(balance)`,
`svo.doingaction(name)`, `svo.findbybal(balance)`, `svo.findbybals(list)`,
`svo.checkany(...)`, and `svo.haveorwill(aff)`.

**Lifevision is the illusion filter.** Triggers do not resolve actions directly.
They call `svo.lifevision.add(what, other_action, arg, lineguard)`, which queues
the resolution in an `OrderedMap` and remembers the smallest `lineguard` seen. At
the prompt, `svo.lifevision.validate()` decides in one place whether the whole
paragraph was real:

```lua
  if sys.flawedillusion or (not conf.batch and sys.lineguard
                            and paragraph_length > sys.lineguard) then
      ... it was an illusion: discard the queue ...
  else
      run_through_actions()          -- svo.actionfinished on each, in order
  end
```

Discarding used to lose the balance bookkeeping with it. `actionclear()` frees
`bals_in_use` so `usingbal()` goes false, while `bals.<balance>` was never set
false because that happens in the handler being skipped. svof then believed it
still had the balance and re-sent the cure on the next prompt, fast enough to
outrun GMCP item tracking, failing the same check again. It fed itself. The fix
in this tree records the spend anyway for the balances a cure physically
consumes:

```lua
local consumable_balances = {
  herb = true, salve = true, sip = true,
  smoke = true, moss = true, purgative = true,
}
```

> An illusion can lie about what a cure did; it cannot un-eat the herb.

**One open question of the same shape.** The `sk.stopprocessing` discard in
`run_through_actions` has the same structure as the illusion-branch bug, but
fires under different circumstances. It was deliberately left alone. Decide
whether balance should be spent there too.

---

## 10. The affliction data model

Four tables, and confusing them causes real bugs.

| table | keyed by | value | who reads it |
|---|---|---|---|
| `svo.affs` | svof name | `{p = <dict entry>, sw = <stopwatch>}` | everything internal, `affs.paralysis` in conditions, and the `check(affs)` loops, hence `j.p.herb` |
| `svo.affl` | svof name | `{sw = ..., count = ...}` | the public list; raises `svo got aff` and `svo lost aff` |
| `svo.gaffl` | **game** name | `true` | raw GMCP mirror: bare at level 1, `"name (n)"` above |
| `svo.affsp` | svof name | ad hoc | suspected flags set by triggers before confirmation |

`svo.addaffdict(entry)`, which is the internal `addaff`, populates `affs` and
`affl`, starts the stopwatch, and calls the entry's `onadded`.
`svo.rmaff(name_or_list)` clears both, calls `onremoved`, and accepts a table to
remove many. `svo.updateaffcount(entry)` writes `svo.affl[name].count` and raises
`svo updated aff`.

`svo.affs` and `svo.affl` are **string-keyed maps**. `ipairs` over either
iterates nothing, which is exactly the bug in section 19.

**`svo.rmaff` is quiet by design and that contract is deliberate.** It returns
before `svo.dict` is consulted, and a comment says so: "rmaff can be called on
affs that don't exist, that's valid". `addaff`, `addaffdict`, `killaction`, and
`doaction` all raise on a bad name. Do not change `rmaff`. Add a static check
instead, per section 18.

Defences mirror this: `svo.defc` holds current defences by svof name, and
`svo.gdefc` holds raw GMCP names.

---

## 11. Affliction names: the two vocabularies

This is the largest planned piece of work and the source of a whole class of
silent bug. Section 18 carries the agreed plan.

`svo.dict.sstosvoa` maps the game's GMCP name to svof's internal name. The
dictionary builds the reverse index `svo.dict.svotossa`, and `svotossd` for
defences, from it at load time by a loop at `Dictionary...lua:14886` that skips
`false` values. **Never rebuild those maps elsewhere. Read them.** Skipping the
`false` entries is what makes them the correct gate for "can GMCP confirm or deny
this at all", and the List reconcilers use them exactly that way.

Measured from the checkout, and matching the export's independent count:

| table | entries | string-valued | identity | differing | `false` |
|---|---:|---:|---:|---:|---:|
| `sstosvoa` | 171 | 145 | 100 | 45 | 26 |
| `sstosvod` | 209 | 172 | 121 | 51 | 37 |

**The 45 divergent affliction names are the disease. The reverse index is only a
symptom.** Collapse the names and `sstosvoa` degenerates into "can GMCP report
this", which is the `false` entries, and the reverse tables vanish for free.
Deleting the reverse tables on their own means a linear scan of about 171 entries
per lookup, which is probably fine at List-reconciliation rates but is a real
change, not a free one.

**Four of the 45 are traps, not just noise.** In those four the svof name is
itself a live GMCP key, so keying on the wrong space resolves to a real
neighbouring affliction one severity step away, rather than to nothing:

```
GMCP damagedleftarm   -> svof mangledleftarm    | GMCP mangledleftarm   -> svof mutilatedleftarm
GMCP damagedleftleg   -> svof mangledleftleg    | GMCP mangledleftleg   -> svof mutilatedleftleg
GMCP damagedrightarm  -> svof mangledrightarm   | GMCP mangledrightarm  -> svof mutilatedrightarm
GMCP damagedrightleg  -> svof mangledrightleg   | GMCP mangledrightleg  -> svof mutilatedrightleg
```

A fifth case, GMCP `burning` equals svof `ablaze` while svof `burning` equals
GMCP `flamefisted`, was removed by the rename in 850. The reconciler test fixture
currently uses the limb collision on purpose, so it needs a new fixture when
these are fixed.

**The defence side has 51 divergent names and zero collisions**, measured the
same way. So the defence renames are hygiene, and the affliction renames are
correctness.

**The Striking fist family is an inverted precedent.** The game calls all four
`*fisted`. svof declines that name for three: `airfisted` is `galed`,
`icefisted` is `icing`, `voidfisted` is `voided`, and after 850 `flamefisted` is
`flamefisted`. So the three siblings are counter-examples to "svof matches the
game's name", not precedent for it. The dictionary comment at the `flamefisted`
entry claims the opposite and needs correcting. The rename is still right, but
the justification is collision removal, not precedent.

**Trigger patterns are the ground truth for what a svof name means.** The names
lie; the game text in `src/triggers/` does not. The four Striking fist
afflictions are identifiable only by their attack lines, "blazing fist", "icy
vapour", "hollow blow", and "dancing blow", not by their svof names.

### One affliction lives in about nine places

This is the concrete scope of the single-source goal:

1. the dictionary entry, with `waitingfor`, `aff`, `gone`, and `customwait` for
   timed ones
2. `sstosvoa`, from which `svotossa` derives automatically
3. the `afflist` in `Simple_aff_trigger_functions.lua`
4. the list in `Diag_trigger_functions.lua`
5. the wore-off `afflist` in `Main_trigger_functions.lua`
6. the tree curable list in `Main_trigger_functions.lua`
7. another aff list further down `Main_trigger_functions.lua`
8. the prompt tag in `@affs.lua`
9. its trigger items, with `.lua` script files named after them

**`svo.valid.*` is generated, not written.** `svo.valid.simple<aff>`,
`diag_<aff>`, and `<aff>_woreoff` come from `ipairs` loops over lists 3 to 5. A
trigger script calling `svo.valid.simplefoo()` works only because `'foo'` sits in
the matching list. A list and a trigger script disagreeing gives a nil call at
runtime and nothing at build time.

---

## 12. Defences

A defence lives in **two tables that answer two different questions**, and the
split is deliberate.

| table | question it answers | who needs it |
|---|---|---|
| `svo.dict[name]` | how do I **raise** this defence | only a class that has the skill |
| `svo.defs_data[name]` | what does the game **print** when it goes up, down, or shows on `DEF` | anyone who can hold it at all |

### 12.1 svo.dict, the raising side

**`svo.basicdef(which, command, balanceless, gamename, undeffable)`** at
`Dictionary...lua:14622`, called 157 times over 134 distinct names, since some
names appear in alternative skillset branches. It generates the whole `physical`
block: `def = true`, a standard `isadvisable` covering not already up, on defup
or keepup for the current mode, `balanceful_defs_codepaste` clear, `sys.canoutr`,
not paralysed, not prone and not mid-defence, plus `oncompleted`, `action` and
`onstart`. `gamename` becomes `svo.dict[which].gamename`; `undeffable` becomes
`physical.undeffable`; `balanceless` picks `balanceless_act` over
`balanceful_act`.

`sys.canoutr` is not only about the rift. `Setup.lua:206` sets it false when you
are webbed, bound, transfixed, roped or impaled, **or** when each arm is
crippled, mangled or mutilated. Every generated defence carries it; only 17 of
the 130 hand-written conjunctions do.

**A hand-written entry** when the defence needs real conditions. See `devour` in
`Developer_readme.md`, or `lipread` at `Dictionary...lua:14415`.

287 distinct names carry `def = true` somewhere, across **four** construction
sites, not three:

| site | entry-level definitions |
|---|---:|
| the `svo.dict = { ... }` literal | 30 |
| `svo.dict.NAME = { ... }`, class and skillset gated | 138 |
| `svo.dict.NAME.BALANCE = { ... }` | 4 |
| `basicdef(...)` | 157 |
| **total** | **329** |

The third site is easy to miss: `svo.dict.blind.misc` and `svo.dict.deaf.misc`
are each assigned twice, under Shindo and under Kaido, and each carries
`def = true`. Two of the 138 are not in the dictionary file at all:
`svo.dict.lifevision` and `svo.dict.shroud` are built inside *Defences* when the
Mask of Lifevision or a Shadowcloak is detected.

`def = true` appears 176 times in `src/`; 175 are definitions and one is
`basicdef`'s own template. Fifteen names carry more than one: `lyre` four times,
`blind` and `deaf` three, and `bear`, `deathsight`, `eagle`, `insomnia`,
`lifevision`, `reflection`, `thirdeye` and `vitality` twice. It sits on
`physical` 154 times, `herb` 8, `misc` 7, `purgative` 4, `salve` 2 and `smoke` 1.

### 12.1a The shape of the 175 written-out definitions

Decomposed into top-level conjuncts by `tools/decompose_defs.py`, which reads
the source through `tools/lua_tokens.py`: the file is tokenised, comments are
discarded before any structure is read, and the table nesting is rebuilt from
tokens, so no count depends on spacing, line breaks or quote style. Each
definition lands in exactly one row.

| | definitions |
|---|---:|
| a plain conjunction, every term nameable as a field | 134 |
| a plain conjunction with one term a field cannot name | 20 |
| delegates to `tekura_ability_isadvisable` or `shikudo_ability_isadvisable` | 16 |
| genuinely multi-statement (`block`, `shadowcloak`, `unbowed`, `vitality` x2) | 5 |

**Every one carries an `isadvisable`**, including the 21 on a `herb`, `misc`,
`purgative`, `salve` or `smoke` balance. There is no set of defence entries that
svof only recognises and never raises.

The two shared helpers at `Dictionary...lua:55` and `:75` are byte-identical
apart from `me.path == 'tekura'` against `'shikudo'`, and are the existing
precedent for parameterising a defence condition.

Six factorings of the defup/keepup test are in use and **three of them are the
same truth function**, proved over all 32 states of the five atoms by
`tools/check_basicdef_spec.py`:

| factoring | definitions | against `basicdef`'s own |
|---|---:|---|
| `not defc and ((deffing and defdefup) or (keepup and defkeepup))` | 130 | this is it |
| `not defc` distributed into each arm | | identical |
| plus a redundant third disjunct repeating the second arm | | identical |
| `not defc` split out of one arm, carried separately | | identical |
| keepup arm also requires `not sys.deffing` | 22 | differs in 1 of 32 |
| keepup arm also lowers an unwanted defence | 2 | differs in 3 of 32 |

The single state the `not sys.deffing` variant changes: you are in defup, the
defence is in keepup but not defup, and you do not have it.

### 12.2 defs_data, the recognition side

`defs_data` is a `pl.OrderedMap`, and the order is load-bearing: the
`systemstart` consumer loop appends to `defences.def_types[type]` in iteration
order, and `show_defs` walks that with `ipairs`, so insertion order is the order
`vdefs`, `vdefup` and `vkeepup` print in.

396 live `defs_data:set` calls over 317 distinct names, carrying exactly 20
keys. Seven of them are game text and become tempTriggers at `systemstart`:

| key | trigger kind | calls carrying it |
|---|---|---:|
| `def` | exact match, the `DEF` list line | 303 |
| `defr` | regex, same purpose | 21 |
| `on` | exact match, gained | 307 |
| `onr` | regex, gained | 14 |
| `on_only` | exact match, "you already have it" | 15 |
| `off` | exact match, lost | 233 |
| `offr` | regex, lost | 17 |

Each may be a string or a list of strings. Thirteen more keys are behaviour:
`type` (355), `onenable` (53), `custom_def_type` (49), `nodef` (41),
`specialskip` (29), `invisibledef` (25), `mana` (24), `ondef` (14),
`staysindragon` (13), `stays_on_death` (6), `offline_defence` (5),
`availableindragon` (3), `tooltip` (5).

Always gate a class's block on `svo.haveskillset(...)` so the defence list is
not cluttered with defences the current class cannot raise, **unless** the
defence can be held without the skill, in which case leave the record ungated.

### 12.3 The consumer loop

`Defences.lua:3279`, on `systemstart`. It iterates `defs_data`, not the dict,
and for each record it:

1. creates a tempTrigger per pattern in the seven text keys;
2. defines `svo.defs.got_<name>`. If `svo.dict[name]` exists it finds the
   entry's one non-`gone` balance sub-table and routes through
   `svo.checkaction` and lifevision; otherwise it falls back to
   `defences.got(name)`;
3. defines `lost_<name>` the same way against `svo.dict[name].gone`;
4. defines `def_<name>`, which files the name in `def_def_list` or
   `nodef_list` depending on `nodef`, `custom_def_type` and dragonform;
5. files the name under `defences.def_types[type]` and
   `sk.ignored_defences[type]`;
6. creates a `defdefup`/`defkeepup` slot in every mode, unless `nodef`.

Step 2's balance discovery is
`for kk,vv in pairs(svo.dict[defname]) do if type(vv)=='table' and kk ~= 'gone'
then bal = kk break end`, with the comment "rely on the fact that defs only have
1 item in them". `pairs` order is undefined, so any defence entry with more than
one non-`gone` table picks arbitrarily. Three do: `deathsight` (`herb`,
`physical`), `thirdeye` (`herb`, `misc`) and `insomnia` (`herb`, `misc`, `aff`).
Every `basicdef` entry has exactly one, so the hazard is confined to those three.

### 12.4 How the two tables line up

Every one of the 287 dict defences has a `defs_data` record. 30 records have no
dict entry; 28 carry `nodef`, `invisibledef` or `custom_def_type` and are
recognise-only by design. The other two, **`bedevil` (Zeal) and `evasion`
(Woodlore)**, carry none of those, so each takes a `defdefup` slot that nothing
can fill.

The gating deliberately differs. 81 of 317 `defs_data` names are ungated against
16 of 134 `basicdef` names, and ten names are recognised for everyone but raised
only by some classes: `breakthrough`, `comprehend`, `constitution`, `mindnet`,
`nightsight`, `resistance`, `shroud`, `toughness`, `transcend`, `vanish`.
`nightsight` is the clearest case: anyone can hold it from a tattoo, only Kaido
can command it.

### 12.5 Facts written twice

- **`specialskip` against `isadvisable`.** 19 of the 29 `specialskip` records
  restate a condition the dict entry's `isadvisable` already carries, term for
  term. They cannot simply merge: `isadvisable` false means "not now" and keeps
  defup waiting, `specialskip` true means "never, stop waiting". The comment
  above `sk.have_defup_defs` at `Defences.lua:3828` claims the function checks
  `isadvisable`; it does not, and the comment is stale.
- **The serverside defence name.** `basicdef`'s `gamename` maps svof to
  serverside; `svo.dict.sstosvod` maps serverside to svof. 32 names carry a
  `gamename`, 17 of which also appear in `sstosvod`; they agree today. The other
  15 (`breakthrough`, `cloaking`, `cohesion`, `comprehend`, `extrusion`,
  `fireshroud`, `mentalclarity`, `rupture`, `skysight`, `strata`,
  `susurrating`, `tempest`, `transcend`, `tremorsense`, `vanish`) have a
  `gamename` and no `sstosvod` entry, so svof can send a priority for them and
  cannot read a serverside line naming them.
- **`type` against the enclosing skillset gate.** For 110 of the 117 gated
  `basicdef` names the `defs_data` `type` is the skillset the dict definition
  sits under. `nightsight` differs on purpose. `retaliationstrike` is filed
  `twoarts` in `defs_data` and gated `shindo` in the dict; both are Blademaster
  skillsets, so the gates are equivalent and only the display grouping differs.

### 12.5a Defects in the defence conditions

- **`shield`'s arm guard has never fired.** `Dictionary...lua:10353` reads
  `not (affs.mangledleftarm and affs.mangledlrightarm)`. That second name is
  misspelt, occurs exactly once in the tree against 32 correct uses, and
  `svo.affs` carries only a `__tostring` metamethod, so the read is nil and the
  clause is always true. Correcting the spelling is not the fix: the same
  conjunction already carries `sys.canoutr`, which is false whenever each arm is
  crippled, mangled or mutilated, a superset of the corrected clause. The clause
  is redundant either way and should be deleted. Read from the code, not
  observed in play.
- **`disperse`, `hiding`, `shadowveil` and `waterbubble` return nil, not
  false**, because their `isadvisable` omits the trailing `or false`. Harmless today, since every
  caller consumes the value as a truth value, and the same trap as
  `rage.misc.isadvisable` in section 17.
- **`affinity` checks `not svo.doingaction('waitingformorph')` without
  `not affs.cantmorph`.** The other 29 metamorphosis definitions carry both.
  Whether that is deliberate is a question about the game.
- **Ten definitions carry a redundant third disjunct** in the defup clause,
  `((X or Y)) or Y`.

### 12.6 Dead weight

- `on_free`, `off_free` and `offs` each have a branch in the consumer loop and
  **no record sets them**.
- `defs_data[def].onshow` is read twice in `show_defs` and **never set**. The
  `onshow` in `Alias_functions.lua` belongs to the config table, not this one.
- `tooltip` is set on five records and written by `defences.complete_def`, and
  **never read**.
- `defences.complete_def` itself has no caller in `src/`. It looks like an
  addon-facing API.

### 12.7 What dict_setup already derives for defences

More than it derives for afflictions. `dict_setup` builds `dict_herb`,
`dict_misc_def`, `dict_purgative`, `dict_salve_def` and `dict_smoke_def` from
`balance.<bal>.def`, and auto-creates a `gone` sub-table calling
`defences.lost(action)` for any balance with `def = true` whose entry lacks one.
The `dragonform` signal handler builds `dict_balanceful_def` and
`dict_balanceless_def`, and in dragonform it filters them through
`svo.defs_data[i].type` and `.availableindragon`, which is the dictionary
reading `defs_data`. `svo.dict.waitingfordragonform` reads
`defs_data[def].staysindragon` at `Dictionary...lua:10038`. The dependency runs
both ways.

---

## 13. Priorities

Two numbers per balance sub-table: **`aspriority`** for normal, asynchronous
curing, and **`spriority`** for slow curing under aeon or retardation. Higher
wins.

`src/resources/default_prios` ships the defaults as a sandboxed Lua chunk of
per-balance ordered lists. `prio.import` loads it into a restricted environment
using `setfenv` and `pcall`, applies it, then calls `dict_setup` and
`dict_validate`. `prio.export('current')` runs on the `signals.saveconfig`
pre-emit.

Anything absent from `default_prios` starts at 0, and `dict_setup` assigns it a
low id. `rage` is one such, covered in section 17.

`dict_validate` reports any two actions sharing a priority within a balance.

---

## 14. GMCP

**What exists**, for `Char.Afflictions` and `Char.Defences`: `Add`, `Remove`, and
`List`, all server to client. There is **no `Char.Afflictions.Request`**. Do not
invent one by analogy with `IRE.Time.Request`. A resync is triggered by sending
the game commands `DIAGNOSE` or `DEF`, whose output the game answers with a
`List`.

The full GMCP surface referenced in `src/`:
`Char.Afflictions.{Add,Remove,List}`, `Char.Defences.{Add,Remove,List}`,
`Char.Items.{Add,Remove,Update,List}`, `Char.Name`,
`Char.Status.{class,name,race,xprank}`, `Char.Vitals.{bal,eq,nl,charstats}`,
`IRE.Time.{List,Update}`, and `Room.Info.*`.

Handlers live in `Setup.lua:619-840`, one per signal. Points worth knowing:

- `parseaffname("torntendons (2)")` returns `("torntendons", 2)` via
  `raw:match("^(.-) %((%d+)%)$")`. The old parse took the first digit anywhere in
  the string and assumed a four-character suffix, so it misparsed at level 10 and
  on any name containing a digit.
- `svo.gaffl` keeps a pre-existing inconsistency: bare name at level 1, suffixed
  above it. Both the Add and List handlers preserve it deliberately.
- `sk.gmcp_cured[name]` is set when GMCP reports a cure and cleared on the next
  prompt. It exists because GMCP arrives before the text, so a trigger asking "do
  we still have this?" to distinguish a real cure from an illusion would
  otherwise always read no.
- The List handlers reconcile. Anything svof tracks that the game's list omits is
  removed, but only if it appears in the reverse map, so afflictions GMCP cannot
  see are never touched.

**Known limits of GMCP as a source of truth**, from the repository owner:

- `blackout` can stop GMCP updates reaching the client entirely, so svof's own
  tracking has to survive the gap.
- `latency`, a Pariah affliction, is not a real game affliction and never appears
  in GMCP.
- Achaea adds afflictions and defences over time, so svof must not break on a
  name it does not know.

---

## 15. Serverside

`svo (custom prompt, serverside)/Serverside.lua`. svof mirrors its priorities to
the game's own curing so serverside does the work where it can.

- `svo.serverignore[action]` means svof handles this one instead of serverside.
  Toggle it from `svo.showserverside`, whose list comes from
  `sk.getallserversideactions()`.
- `sk.getallserversideactions` excludes `uncurable` and `undeffable` balances.
- `sk.splitdefs` separates defences from afflictions and drops `uncurable` and
  `irregular` entries from prio lists.
- `sk.getbeforestateprios`, `getafterstateprios`, and `notifypriodiffs` snapshot
  and diff priorities around anything that might renumber them. They read only
  priority numbers through `make_prio_tablef`, so extra fields on a balance table
  are invisible to them.
- `svo.enabledefaultserverside()` un-ignores exactly `impale`, `lovers`, `roped`,
  `transfixed`, `webbed`, and `selfishness`.

Separately, `svo.ignore[action]` means do not cure this at all. Every `check_*`
tests it. `svo ignore <action>` accepts anything present in `svo.dict` at
`Alias_functions.lua:70`, with no further validation.

---

## 16. Contributed-strategy registries

Six tables in `Setup.lua` let a user add when-to-fire rules without editing svof:
`svo.dragonheal`, `svo.restore`, `svo.shrugging`, `svo.tree`, `svo.rage`, and
`svo.fitness`. All are declared `svo.X = svo.X or {}`, so they survive a class
change. All are keyed by strategy name. None has a registration function; you
assign into the table.

`Rage_curing_strats.lua` is the shipped example and carries the instruction:

> if you'd like to add your own strat: add it in another script outside Svo, so
> it stays upon an update.

```lua
svo.rage.any2affs = {
  desc = "Use rage when we've got at least two afflictions and one of them is rage-curable",
  function () return table.size(svo.affl) >= 2 end
}
```

`me.disabledragefunc` toggles each by name, persisted to
`<profile>/svo/config/rage` and listed in `vconfig2` at
`Config_system.lua:1847-1884`. The consumer enumerates the table **at call time**
and runs each under `pcall`, so a strategy added later is picked up without a
reload.

---

## 17. Worked example: how rage interacts with six afflictions

This is the most tangled cross-entry interaction in the dictionary, and a good
test of whether a change is safe.

`svo.dict.rage` at `Dictionary...lua:14129` exists only under `discipline`,
`malignity`, `valour`, or `dominion`. Six afflictions, `inlove`, `justice`,
`generosity`, `pacifism`, `peace`, and `pyre`, carry a clause saying "do not
spend a herb, rage is about to cure this", in **eight** places, because
`pacifism` and `generosity` have both a herb and a focus route:

```lua
return (affs.peace and (not (svo.haveskillset('discipline') or ... or
  svo.haveskillset('dominion')) or not svo.dict.rage.misc.isadvisable())) or false
```

Four things about that clause are not obvious from reading it once:

1. **The first half is a nil guard, not a logic term.** `svo.dict.rage` does not
   exist for other classes, so without the short-circuit `svo.dict.rage.misc`
   would raise.
2. **`rage.misc.isadvisable` has no final `return false`.** It returns `nil` when
   the gate passes but no strategy matches. That is harmless here because
   `not nil` is `true`, but it is a trap for anything comparing to `false`.
3. **The eight copies have drifted.** `generosity.herb` at line 1819 omits
   `dominion`. Since `available_skills` is built from the current class alone
   and each rage skillset belongs to exactly one class (`discipline` runewarden,
   `malignity` infernal, `valour` paladin, `dominion` unnamable), that omission
   affects **every Unnamable, every time rage is advisable**: the herb route
   eats a bellwort while the same character's focus route stands down. Ten
   reachable class-and-rage states, differing in one.
4. **Nothing is suppressed. The affliction is still cured, by rage.** Rage reaches
   the game by its own independent route. `rage.misc` has no `def`, so
   `dict_setup:15012` files it in `svo.dict_misc`, `check_misc:226` walks that,
   `check_misc:218` calls the same `isadvisable`, `check_misc:245` calls
   `svo.doaction`, and `onstart` sends `rage`. Rage carries no `dontbatch` and
   `check_misc` batches, so its low default priority delays it within the tick
   but never skips it. `uncurable = true` means serverside can never take it.

The one way this can strand an affliction: `svo ignore rage` is accepted, after
which `check_misc` skips rage while `isadvisable` still says advisable, so the
six defer to an action that never comes. The invariant for any such deferral is
that **the condition must be false whenever the owning action cannot run.**

The planned fix is one boolean, `rage = true`, on each of the six, with
`dict_setup` deriving the set that rage's own `isadvisable` and `empty` read.
See `claude/svof-single-source-guide.md` Step 6. Two earlier designs, an
external registry applied by wrapping `isadvisable`, were discarded: they needed
`raw_isadvisable` to survive `dict_setup`'s five call sites, and they left the
six names written a fourth time.

---

## 18. Open work, in order

Ordered by what unblocks the most. Sources: the 2026-09-03 export and the
2026-08-23 and 2026-08-30 agreements with the repository owner.

### 18.1 Cut the first package release

Nothing has shipped as a package yet. The in-client updater points at the testing
fork, matching where the README and `doc/index.rst` send people, but neither
location has a release carrying `svof.mpackage`, so the updater is honest and
inert.

Blocking questions, both for the repository owner: reconcile `fork-version-66`
with `in-client-svof`, and decide whether the update repository and the release
job's fork-only gate move back to `svof/svof` together.

### 18.2 The affliction name-space cleanup

The largest planned piece, agreed 2026-08-23. Section 11 carries the topology.

1. **Rename svof afflictions to match their GMCP names**, one batch at a time,
   until `sstosvoa` is all identities plus `false`. Pull request 850,
   `flamefisted`, is the template and covers every place an affliction is
   registered: dictionary entry, `sstosvoa`, four affliction-name lists, prompt
   tag, trigger items and files, and `ITEM_RENAME` in the gate.
2. **The three remaining Striking fists** are the easiest next batch:
   `galed` to `airfisted`, `icing` to `icefisted`, `voided` to `voidfisted`.
   Doing them makes the family internally consistent and removes the
   inverted-precedent confusion.
3. **The four mangled limbs** are the highest risk, because each collision is one
   severity step from a real affliction. The reconciler test fixture uses this
   collision on purpose and will need a replacement.
4. **Then delete `svotossa` and `svotossd`** and the two gates that read them.
5. **Then make `svo.dict` the single source of truth.** This is the long-standing
   goal, and `claude/svof-single-source-guide.md` is the plan for it.

Every rename needs in-game testing, and every rename is structural to
`verify_merged`, so declare it in `ITEM_RENAME` and rename the `.lua` file to
match.

### 18.3 Smaller agreed items

- **Two dead diagnose triggers**, agreed 2026-08-30 as one small pull request off
  `in-client-svof`. `blistered` has a trigger with pattern
  `suffering from horribly blistered skin.` (exactMatch) and an empty `<script/>`;
  `svo.valid.diag_blistered` is defined by the generic loop but nothing calls it,
  so DIAGNOSE never records blistered. The fix is one line. `pyre` has no
  `diag_pyre` trigger at all, and is not among the `svo diag` folder's 149
  children. That one matters more than it looks: nothing in the trigger path
  raises `svo.dict.pyre.count`, only the GMCP path does, so a diag trigger is how
  a non-GMCP player gets pyre registered at all. Combined with the presence floor
  added in 853, a diag-detected pyre immediately stops svof salving ablaze off,
  which is the case players describe. The pattern
  `being consigned to the flame.` (exactMatch) was confirmed by the repository
  owner on 2026-08-30 and can be used as is. Both are structural to
  `verify_merged`, so regenerate the baseline in the same commit.
- **The `asleep` bug**, its own pull request. `sleep` is the dict key; `asleep`
  is not a dict key and is never set anywhere. Confirmed in the checkout:
  `Main_trigger_functions.lua:79` has `if affs.asleep or actions.asleep_aff`, so
  the block cancelling non-`waitingfor` actions on falling asleep has never run,
  while line 73 six lines up uses `affs.sleep` correctly in the same function.
  `Main_trigger_functions.lua:735` has `if affs.asleep then svo.rmaff('asleep')`,
  dead in both halves, so the blackout workaround its comment describes has never
  taken effect. `@affs.lua:10` carries `asleep = "asl"`, an abbreviation for a key
  `svo.affl` can never hold. **This is not a mechanical fix.** Lines 73 to 76 add
  `sleep_aff` just above, so a corrected guard would be true almost every time
  and the kill loop would run for the first time. It wants thought and live
  testing.
- **A static check** over the dictionary for a `gone` or `aff` handler whose
  `rmaff` names something other than its own entry. It would have caught both
  `mindravaged` and `asleep`, and fits the existing `tools/` style. Add the
  check rather than changing `rmaff`, whose quiet contract is deliberate.
- **Comment and record corrections** from the 2026-08-23 review. None change
  behaviour:
  - `tools/test_gmcp_reconciler.lua`'s fixture comment says 46 differing
    `sstosvoa` entries; it is 45 now. Per the repo's own rule about counts
    rotting, drop the figure rather than update it.
  - The dictionary comment at the `flamefisted` entry justifies the rename as
    "the way icefisted/airfisted/voidfisted already do", which is inverted. See
    section 11.
  - `tools/verify_merged.py`'s comment claims `ITEM_RENAME` and
    `check_renamed_callsites.py` are coupled. They are not; that gate never reads
    `ITEM_RENAME`.
  - Same file: "a reordered, missing or duplicated item" overstates. A missing or
    duplicated item changes `len(a)` and routes to `count|`, `gone|`, or `added|`,
    all content and all baseline-able. Only a reorder, or a size-preserving swap,
    reaches the path mismatch.
  - 850's pull request description cites `GROUP_RENAME`, which exists only in an
    uncommitted working tree, so reviewers cannot see it.
  - 850's description and the `d445ace` commit message call dropping the `pyre`
    gate a behaviour change needing live testing. It is not.
    `waitingfor.isadvisable` is never invoked: every call site is a typed curing
    balance, `svo.doaction` reads only `customwait` and `customwaitf`, and every
    generic walk over an entry's balances skips `waitingfor`.
- **`ITEM_RENAME` hygiene**, the three gaps in section 2.
- **The anonymous-handler leak** on same-session reinstall. Nine call sites
  across seven files would need identifiers recorded and cleaned up. Bodies are
  idempotent, so there is no observable effect today.
- **Vestigial duplicate files**: the root `default_prios` and `ndb-help.lua`.
  Only the `src/resources/` copies ship. CI fails if they drift, but retiring the
  root copies is the real fix.
- **Nine item names that do not exist**, recorded in
  `tools/known_unresolved_names.json`. All are absent from the 2018 XML files
  too, so they are pre-existing silent no-ops rather than conversion damage.
  Fixing them is a behaviour change and wants its own commit.
- **Unverified `customwait` guesses**: `flamefisted` and `icing` both carry
  `customwait = 30, -- ??`. Both want timing in game.
- **The `svo.valid.ate1` illusion question** on 848. The new loop may mark herb
  balance spent for a herb GMCP says never left the rift. The mechanism is clear,
  the reachability is not, and it needs a live session.
- **The 25 reference XML files** cannot be retired while `verify_merged.py`
  depends on them.
- **A `DEF`-resync capture** is the missing live coverage for the defence List
  reconciler.

---

## 19. Defects found by reading

Report these as observations, not as confirmed bugs, unless a row says otherwise.

| where | what | state |
|---|---|---|
| five burn conditions | `affs.pyre.count`; `svo.affs[name]` is `{p=..., sw=...}` and has no `count`, which lives at `affs.pyre.p.count`. The read raised out of an unprotected `isadvisable` and aborted `svo.onprompt`. | **Fixed by 853**, still present in the older checkout at lines 4576, 4652, 4697, 4742, 4787 |
| pyre and burn ladder | one rung too permissive | **Fixed by 853** |
| `mindravaged.gone` | called `rmaff("burning")` | **Fixed by 850** |
| `Main_trigger_functions.lua:79, :735`, `@affs.lua:10` | the `asleep` guards, dead since they reference a key that is never set | confirmed, open, see 18.3 |
| 20 salve entries | no `noeffect` branch, while `salve_had_no_effect` resolves through `findbybal('salve')`, whichever salve action is in flight. `dict_setup` defaults `noeffect` for herb only, so these twenty can be that action with no branch to take. `Action_system.lua` logs an error and then calls the nil anyway; `svo.actionfinished` wraps it in `pcall`, so the result is `(e!)` in the client and, the part that matters, the balance correction never happens and svof keeps thinking it has salve balance. The twenty: `calcifiedskull`, `calcifiedtorso`, `heartseed`, `hypothermia`, `laceratedthroat`, the four `mangled*` limbs, `mildconcussion`, `mildtrauma`, the four `mutilated*` limbs, `parestoarms`, `parestolegs`, `seriousconcussion`, `serioustrauma`, `tonguetied`. They are exactly the entries whose `empty` is `svo.dict.<name>.salve.oncompleted()`, so it looks like `empty` was filled in and `noeffect` was not. Read from the code, not observed. | open |
| `generosity.herb:1819` | omits `dominion` from the rage guard. Because only one rage skillset exists at a time, this is every Unnamable whenever rage is advisable, not a corner case: the herb route cures while the entry's own focus route stands down | open |
| `rage.misc.empty:14146` | clears five afflictions but `isadvisable` fires on six; `pyre` triggers rage and is not cleared | open |
| `horror`, `pyre` | spend herb balance twice in `empty`: they call a generated `empty.eat_*`, which already calls `svo.lostbal_herb()`, and then call it again. `lostbal_herb` has no re-entry guard (unlike `lostbal_rage` and `lostbal_focus`), so the second call re-arms the recovery timer and raises `svo lost balance` twice. The four humours look identical but are correct, because `empty.eat_ginger` is hand-written and does not spend the balance | open, and **corrected**: an earlier draft of this table said six entries |
| 18 of 20 focus blocks | carry `action = 'focus'`, so all 18 write the same key into `sys.input_to_actions['focus']` and 17 are overwritten; which one survives depends on `pairs` order. `pacifism` and `unknownmental` carry no `action` at all. `Controllers.lua:908` reads that map when the player types a command themselves, to kill and re-take the action. Whether the arbitrary winner affects which affliction gets cleared is **not traced** | open, unverified |
| `fulminated` | has a live focus block but is missing from `empty.focuscurables` | open |
| DIAGNOSE list | `voyria` appears twice | open |
| `blistered`, `pyre` | dead or absent diagnose triggers | open, agreed as one PR |

---

## 20. Working rules for this repository

1. **Read code in full. Never generalise from a pattern.** Use grep to locate,
   never as the sole basis for a claim about behaviour. Do not delegate reading
   to a subagent that returns only a summary when the point is to understand the
   code.
2. **Do not hardcode counts in prose.** Derive them, print them, or name the
   command that does.
3. **Diff every file a bulk edit touches before committing.**
4. **`src/` is the source.** Never regenerate it from the reference XML files.
5. **Never add AI attribution** to commits, pull requests, or issues.
6. **Keep the three evidence tiers apart**: gates have verified structural
   correctness, two captured fights have verified curing over 54 afflictions, and
   sustained play is unverified.
7. **Anything added to `dict_setup` must be idempotent.** It runs at least twice
   per load and is reachable five ways.
8. **Anything that must survive a class change** goes in a `svo.X = svo.X or {}`
   table in `Setup.lua`, not into `svo.dict`.
9. **Declare every item rename in `ITEM_RENAME`** and rename the `.lua` file too.
10. **Build on Linux before believing a build**, and verify any raw-bytes check
    against the git blob rather than the working tree.
11. **Do not edit files in the svof working copy automatically.** `CLAUDE.md`
    there is the exception.

### Writing conventions

Write reader-facing prose in the Google developer documentation style: second
person, active voice, present tense, sentence case headings, and the serial
comma. This applies to chat replies as well as to documents.

- **No em dashes or en dashes.** This is an explicit standing override.
- **Project terms keep their own spelling.** "defence" and "defences" match
  `Char.Defences` in GMCP and `svo.defences` in the code, so American spelling
  does not apply to them.
- The style governs prose only. It never touches code, identifiers, code
  comments, or commit messages, which follow the surrounding codebase.

---

## 21. Analysis errors made against this codebase

Recorded because each has a reusable cause, not because the individual facts
matter.

| the error | the cause |
|---|---|
| Invented `Char.Afflictions.Request` | generalised `.Request` from `IRE.Time.Request` |
| "27 afflictions get wiped" | missed that `ipairs` over a string-keyed map iterates nothing, so the loop was inert. The landmine is that fixing the `ipairs` activates it |
| Read `lostbal_*` as restoring balance | inferred from the name instead of reading the body |
| Misread `empty` and `noeffect` | guessed from the words; both mean something specific and non-obvious |
| Treated `eatcure = {herb, mineral}` as a container plus contents | assumed a game mechanic instead of asking |
| "Seven entries are missing their alternative cure" | had the direction backwards; the two-item lists are the stale ones |
| "19 of 20 focus blocks check `doingaction`" | matched text inside a commented-out condition; the real answer is 18 |
| "`unless` can be inherited, 17 of 19" | measured by substring presence rather than semantic equivalence; a truth-table check says it fails 5 of 19 |
| `onstart` counts 62, 32, 5 | read off a truncated display; the real totals are 71, 45, 7 |
| "17 entries carry the rage gate" | 6 do; 19 mention `haveskillset` for unrelated reasons |
| Proposed wrapping `isadvisable` inside `dict_setup` with `local original = ...` | assumed one call site; there are five, and two fire on every load |
| "Nothing has been observed in play" | stated a limit of my own checkout as a fact about the project; two captured fights already covered curing |
| "45 class-conditional entries", "306 `defs_data:set` uses" | counted with a regex narrower than the construct; the real figures are 155 assignments and 396 calls. The `defs_data` figure was low because the name group was `\w+` and eleven defence names contain a space (`extra crits`, `ox tattoo`, `grove vigour`) |
| "six entries spend herb balance twice in `empty`" | it is two, `horror` and `pyre`. The other four call `empty.eat_ginger`, which is hand-written and does not spend the balance. I matched the call shape without reading the callee |
| designed a registry and a wrapper for one relationship | generalised nine cross-entry references into a mechanism when six of them share one owner and the other three stay hand-written either way. The user's `rage = true` does the same job with no wrapper and one fewer copy of the names |
| Derived each affliction list from entry shape | proposed, in code, deriving `afflist` from "has an `aff` sub-table" and `generic_cures_data` from "has a `gone` sub-table". All four such inferences miss: 180 against 154, 189 against 111, 180 against 151, 20 against 18. Worse, two of the lists contain names that are not afflictions at all (`healhealth`, `healmana`, `godfeelings`, five fluid levels), so following it would have deleted them silently. The lists are facts the entry must **declare**, not projections of its shape |
| Wrote a plausible sample output instead of running anything | the guide's Step 3 illustrated a checker with invented numbers: it claimed the two tree lists differ in 5 names when they differ in 27, and quoted 152 for a list of 151 distinct names. Writing the checker for real also caught two bugs in my own scanner, a greedy regex that ran past the tree list's closing brace and a `fear` test that read a commented-out condition as live |
| Mapped the `sip` action onto the `purgative` balance | assumed one sipped balance. There are two: all six entries on the `sip` balance call `lostbal_sip`, while `purgative` is its own balance of five entries, only `voyria` of which calls `lostbal_purgative` |
| Defaulted `notwhiledoing` on, under the name `busy` | assumed the `not doingaction(<self>)` conjunct was the common case. It is on 61 of 185 cure conditions, so the default had to be off or it would need switching off on 120 entries |
| "1 of 32 states" for the generosity drift | treated four skillsets as independent booleans. `available_skills` is built from the current class alone and each rage skillset belongs to one class, so 22 of the 32 cannot occur. The real statement is every Unnamable whenever rage is advisable |
| Proposed `focus = true` as entry metadata | `Curing_skeleton.lua` tests `j.p.focus` to mean "does this entry have a focus balance", then calls `j.p.focus.isadvisable()`. The flag would have made that true for an entry with no focus block and indexed a boolean. The fix was to add no field at all: having the block is the flag |
| "15 defences in the dictionary" | three errors stacked. I classified only the 267 literal entries and reported it as the dictionary, when 292 of the 321 defence definitions are built by `basicdef` and the class-gated block, both outside the literal. Then two regex faults moved the literal count in opposite directions: a bare `def = true` substring matched `restoredef = true`, and a line-anchored `^\s+def = true` missed the 14 entries that write `balanceful_act = true, def = true, undeffable = true,` on one line. The real figure is 287 defences by name |
| "286 defences by name", "578 definitions", "154 assignments over 147 names" | the corrected figure was still one short. `^\s*svo\.dict\.(\w+) = \{` required exactly one space on each side of the `=`, and `svo.dict.lipread  = {` writes two. One name, one definition, one assignment missed. The real figures are **287 defences, 579 definitions, 155 assignments over 148 names** |
| "31 `defs_data` records have no dict entry, and all carry `nodef` or `invisibledef`" | 30 records, and two of them, `bedevil` and `evasion`, carry neither. Both therefore take a `defdefup` slot that nothing can ever fill. I sampled the flagged ones and generalised to the set |
| Reported 16 Tekura and Shikudo defences as having no `isadvisable` at all | the extractor matched `isadvisable = function() ... \n end`, and those 16 write the whole function on one line delegating to a shared helper. A newline in a regex is an assumption about formatting, not about code |
| Guessed how many of 32 states two defup factorings differ in | wrote 4 and 12 into the harness as expectations before running it; the answers are 1 and 3. Expected values in a checker are claims like any other and must come from the truth table, not from intuition |
| Built the whole defence analysis on regexes, then reported it | four separate formatting assumptions, each wrong: `svo.dict.NAME = {` with one space and the brace on the same line; exactly two dots after `svo.dict`, which hid the four `svo.dict.blind.misc` / `svo.dict.deaf.misc` assignments; the dictionary file only, which hid `svo.dict.lifevision` and `svo.dict.shroud` in *Defences*; and `isadvisable = function() ... \n end`, which hid 16 one-line delegations. Together they undercounted defence definitions by 6 and misclassified 21 more. The fix was not a better regex: the tools now tokenise, and `tools/check_formatting_hazards.py` asserts each spelling |
| "15 defence entries have no `physical` block, so they are cured rather than raised and out of scope" | they have an `isadvisable` on a `herb`, `misc`, `purgative`, `salve` or `smoke` balance. Not finding a `physical` key is not the same as not finding a raise route, and I reported the first as the second |
| Wrote "8" and "24" into the hazard checker before measuring | the answers are 13 and 16. Same error as the truth-table one above, made again in the same session |

The pattern across all of them: a claim measured by pattern-matching text rather
than by reading the construct, or by reading one instance and assuming the rest.
The countermeasure that worked was writing a script that re-derives each claim
from `src/` and fails loudly.

---

## 22. Re-deriving every number here

**These are not the repo's gates.** Two sets of tools exist and both are reached
as `tools/`:

| set | directory | what it is |
|---|---|---|
| the repo's gates | `<repo>/tools/` | `verify.py`, `check_package.py`, `check_lua_syntax.py` and the rest. They gate the build and run in CI. Section 2 lists them |
| the analysis harnesses | `svof-cowork-export/from-cowork/tools/` | the scripts below. They re-derive the numbers in this document and in the single-source guide. Nothing in svof imports them and none is wired into CI |

Run each from that second directory with the repo root as the argument, for
example `python3 check_rage.py C:\work\svof`.

```
derive_svof_facts.py            # everything structural in sections 2 to 16
check_rage.py                   # section 17, 45 checks
check_defs_data.py              # section 12, defs_data against svo.dict
check_basicdef_spec.py          # section 12.1a, 39 checks
check_formatting_hazards.py     # the spellings a regex gets wrong, 16
decompose_defs.py               # the working behind 12.1a, report only
check_derived_lists.py          # what each list would derive from today
check_guide_claims.py           # the single-source guide's claims, 129
check_alsofocus.py              # focus-block equivalence, truth table
lua_tokens.py, extract_defs.py  # libraries the defence tools read source with
```

If a number here disagrees with what those print, they are right. The full
inventory, including which files are retired, is in
`claude/svof-cowork-export-notes.md`.

---

## Appendix: file map

| file | lines | what lives there |
|---|---:|---|
| `svo (actions dictionary)/Dictionary_of_actions_(affs-defs-misc).lua` | 15,418 | `svo.dict`, `basicdef`, `dict_setup`, `dict_validate`, the serverside name maps |
| `svo (trigger functions)/Main_trigger_functions.lua` | 4,640 | trigger bodies, cure tables, `generic_cures_data` |
| `svo (alias and defence functions)/Defences.lua` | 3,952 | `defs_data`, defence tracking and switching |
| `svo (curing skeleton, controllers, action system)/Curing_skeleton.lua` | 2,521 | `check_*`, `make_gnomes_work`, lifevision, `addaff` and `rmaff`, `lostbal_*`, symptom detectors |
| `svo (install, config, pipes, rift, parry, prios)/Config_system.lua` | 2,289 | `vconfig`, tn and tf |
| `svo (setup, misc, empty, funnies, dor)/Setup.lua` | 2,066 | global tables, `knownskills`, class resources, all GMCP handlers |
| `svo (curing skeleton, controllers, action system)/Controllers.lua` | 1,216 | `onprompt`, GMCP stats, lock tracking, aeon and retardation |
| `svo (alias and defence functions)/Alias_functions.lua` | 1,170 | alias bodies, `showserverside`, the ignore list |
| `svo (custom prompt, serverside)/Serverside.lua` | 915 | serverside mirroring, prio snapshots |
| `svo (setup, misc, empty, funnies, dor)/Miscellaneous_functions.lua` | 808 | helpers, `setignore`, `installationfolder` |
| `svo (install, config, pipes, rift, parry, prios)/Priorities.lua` | 496 | `prio.import` and `prio.export` |
| `svo (curing skeleton, controllers, action system)/Action_system.lua` | 382 | `doaction`, `actionfinished`, `killaction`, `usingbal`, `doingaction` |
| `svo (setup, misc, empty, funnies, dor)/Empty_cure_handling.lua` | 209 | `empty.eat_*`, `focuscurables`, `treecurables`, `madness_affs` |
| `svo (trigger functions)/Simple_aff_trigger_functions.lua` | 191 | `afflist` |
| `svo (core)/svo Utilities/Custom prompt tags/@affs.lua` | 188 | `aff_abbrev`, the short names behind the `@paracelsus_affs_customtag` prompt tag |
| `svo (trigger functions)/Diag_trigger_functions.lua` | 119 | DIAGNOSE parsing |
| `svo (core)/Load & init/svo_init_system.lua` | 100 | loader order |
| `svo (core)/Load & init/svo.classchange.lua` | 49 | class change |
| `svo (core)/svo Utilities/Rage_curing_strats.lua` | 22 | shipped rage strategies |

Adding an affliction currently touches about nine places, listed in section 11.
That is the duplication the single-source work in 18.2 step 5 aims at.
