# Implementation plan: `svo.dict` as the single source, and a user-facing way to add to it

Written 2026-09-22 against `fork-version-66` at `82e7f14`, `mfile` version 66.

This plan covers two things the request joins together:

1. The eight steps in `reference/svof-single-source-guide.md`, which collapse the
   eleven registration points an affliction needs today down to the entry
   itself.
2. A surface that lets a player, not only a coder, add an affliction or a
   defence: `vconfig customaff` and `vconfig customdef`, and the Mudlet calls
   that make them workable.

The second is not in the guide. It is the reason the plan below reorders the
guide's priorities, and that reordering is the main thing this document adds.

**2026-10-08: the defence steps here (2.4, 2.6, 3.1, 3.2, the defence half of
3.5, and `customdef` in Phase 4) are replaced by `defences-single-source-plan.md`.**
It corrects 3.5 (`defs_data` is rebuilt on every init) and 2.6's 7e, and adds
the `confirm`/`unconfirm` change the GMCP-first defences PR needs.

## What I read and what I checked

I read the guide in full, the three claude-notes reference documents' relevant
sections, and these files in the tree: the dictionary and its `dict_setup` and
`basicdef`, `Defences.lua`, `Empty_cure_handling.lua`,
`Simple_aff_trigger_functions.lua`, `Diag_trigger_functions.lua`, the cure maps
in `Main_trigger_functions.lua`, `@affs.lua`, `Config_system.lua`,
`Alias_functions.lua`, `svo_init_system.lua`, `svo.classchange.lua`, `Rift.lua`,
`default_prios`, and `tools/verify_merged.py`.

I ran two of the harnesses in `C:\work\svof-cowork-export\from-cowork\tools\`
against this checkout:

- `check_derived_lists.py` reproduces its published output exactly, including
  the `bloodroot` redefinition note and all four drifts.
- `check_basicdef_spec.py`: 39 claims checked, 39 passed, 0 failed.
- `check_guide_claims.py`: 129 claims checked, 123 passed, 6 failed, matching
  what `TASKS.md` already records.

Numbers below that I measured myself are marked as such. Everything else is
either from a harness run above or is a file and line reference you can open.

---

## The reframe: the guide's optional half is load-bearing here

The guide splits its work in two and is explicit that the split matters:

> **Change A puts the facts on the entry and builds the lists from them.** ...
> **Change B generates the repetitive entries.** ... Keep them apart. Change A
> is the point; Change B is a convenience some entries take and others do not.

For the goal the guide states, reducing eleven coder edits to two, that is
right. For the goal in this request, a user-facing way to add an affliction, it
is wrong, and the reason is worth stating plainly.

`basicaff(name, spec)` and `basicdef(name, spec)` do one thing that matters more
than saving typing: **they turn a dictionary entry into data.** Today an entry
is a Lua literal full of closures, and the only way to produce one is to write
Lua. Once the entry is built by a constructor from a flat spec table, that spec
can come from three places instead of one:

| source | who writes it |
|---|---|
| a literal in the dictionary | a contributor |
| a saved table under `<profile>/svo/custom/` | a player, through an alias |
| a form | a player, through a panel |

Without the constructors, a `vconfig customaff` alias would have to generate
Lua source text and load it. That is a different and much worse problem: no
validation, no way to report a useful error, and arbitrary code from a shared
file. With them, `svo.register_affliction(name, spec)` is a call with a table
argument, and every spec field can be checked before anything is installed.

**So Steps 5 and 8 move from optional to required, and they sit on the critical
path.** Steps 1 to 4 still come first, still deliver the coder-facing benefit on
their own, and are still worth landing alone if the rest stalls.

---

## Five things already in the tree that the guide does not use

Each of these shortens the work below. All are current as of `82e7f14`.

### 1. `defences.enablemindnet()` is a working runtime defence registration

`src/scripts/svo (alias and defence functions)/Defences.lua:2540-2601`. For one
hardcoded name it does the whole job:

- `defs_data:set('mindnet', {...})` with the `on`, `off` and `def` lines
- `svo.basicdef('mindnet', "mindnet on")`
- a `defdefup` and `defkeepup` slot in every mode
- `sk.ignored_defences.general.t.mindnet` and `sk.ignored_defences_map`
- appends to `defences.def_types['general']`
- creates the recognition triggers from the lines it just set
- defines `defs.got_mindnet`, `defs.lost_mindnet` and `defs.def_mindnet`
- takes a priority snapshot, runs `svo.dict_setup()` and `svo.dict_validate()`,
  then reports the diffs
- emits `signals.dragonform`

That is the complete body of `svo.register_defence(name, spec, lines)`, written
out once. Generalising it is refactoring, not new design, and rewriting
`enablemindnet` to call the general version is the test that the generalisation
is faithful.

### 2. Every defence recognition trigger is already built at runtime, from data

`Defences.lua:3279` connects an anonymous function to `signals.systemstart` that
walks `defs_data` and creates a `tempExactMatchTrigger` or `tempRegexTrigger`
for each of `on`, `onr`, `on_only`, `on_free`, `off`, `offr`, `offs`,
`off_free`, `def` and `defr`, collecting the ids in `svo.defencetemptriggers` so
`svo.classchange` can kill them (`svo.classchange.lua:27-30`).

A player supplying game lines for a defence therefore needs **no new trigger
mechanism**, only a second source feeding the same loop. The one obstacle is
that the loop is anonymous, so it cannot be called for a single new entry.
Extracting its body into a named `defences.wire_defence(name, data)` is the
first commit of Phase 3.

### 3. `svo.afflist()` already derives from the dictionary, and the opt-out flag exists

`Alias_functions.lua:1037-1044` selects entries with
`v.aff and not v.aff.notagameaff`. Nine entries carry `notagameaff` (measured:
`grep -c` in the dictionary). The new fields should extend that convention
rather than start a parallel one, and the guide's proposed opt-outs
(`gmcp = false`, `focusempty = false`) should be named to match it.

### 4. The config system already supports runtime options and a menu callback

`svo.config.setoption(name, data)` at `Config_system.lua:2137` adds a `vconfig`
option at runtime, and `svo.config.set` handles a `type = 'custom'` whose
`onmenu` callback runs when the option is typed with no value
(`Config_system.lua:2236-2249`). `doc/index.rst:94` already tells users they can
add and delete `vconfig` options. Phase 4 needs no new config machinery.

### 5. `rift.herb_conversions` is the guide's `EAT_ALT`, already written

`Rift.lua:242-261` holds all 20 herb-to-mineral pairs, identical to the table
the guide proposes adding. Do not add a second copy. See the load-order
correction below for why this is not quite free.

---

## Four corrections to the guide

### A. The pairing table cannot be read where the guide puts it

`svo_init_system` (`svo_init_system.lua:14-38`) loads subsystems in an explicit
order. `dict` is fourth and `rift` is ninth, so `rift.herb_conversions` is still
empty when the dictionary literal runs and `basicaff` builds its cure lists.

Three ways out, in order of preference:

1. **Move the table earlier.** Put it in `setup` or `misc`, both of which load
   before `dict`, and have `Rift.lua` read it from there. Smallest change, one
   definition, no gate needed.
2. **Resolve lazily.** Have `basicaff` build `eatcure` inside a closure that
   reads the pairing on first use. Works, but it moves a load-time constant into
   the curing hot path for no gain.
3. **Keep two copies and gate them.** A check in `tools/` asserting the two
   agree. Cheapest to write and the worst outcome: it institutionalises the
   duplication this whole plan exists to remove.

Smoked cures need their own table regardless. `skullcap` pairs with `azurite`
eaten and `malachite` smoked, which the guide records correctly.

### B. `prio` is not a scalar field, and it is already automatic

`default_prios` is sectioned by balance, not flat. Measured section sizes:

| section | entries |
|---|---:|
| slowcuring | 211 |
| herb | 54 |
| physical | 49 |
| salve | 41 |
| misc | 26 |
| focus | 19 |
| smoke | 9 |
| sip | 6 |
| purgative | 5 |
| moss | 2 |

An affliction curable on two balances has two positions plus a `slowcuring`
position, so a single `prio = 233` on the entry cannot express it.

More usefully: `dict_setup` already allocates a slot to any action whose
`aspriority` or `spriority` is 0, shifting the rest up to make room
(`Dictionary_of_actions_(affs-defs-misc).lua:14997-15025`). **A new affliction
works today without touching `default_prios` at all.** Drop `prio` from the
field list, and say in the readme that priorities are the one registration point
that has always been automatic.

That takes the guide's eleven places down to ten before any work starts.

### C. The diag loop is two loops

`Diag_trigger_functions.lua:91` iterates 151 plain names. A second loop at
`:108` iterates 10 counted afflictions (`cholerichumour`, `melancholichumour`,
`phlegmatichumour`, `sanguinehumour`, `bleeding`, `skullfractures`,
`crackedribs`, `wristfractures`, `torntendons`, `pressure`) whose generated
handler takes a `howmuch` argument and stores a number rather than `true`.

Step 4.2 has to derive both. The entry already carries `count`, so the split
follows from the entry and needs no second field: `diag = true` plus
`entry.count` picks the counted loop.

### D. Step 3's script is already written

`check_derived_lists.py` exists in `C:\work\svof-cowork-export\from-cowork\tools\`
and, run against this checkout, reproduces its published output exactly. Step 3
is "port it into `tools/`, give it a baseline, add it to `build.yml`", which is
a smaller job than the guide implies and can land before anything else.

---

## How this interacts with the gates

Worth settling up front, because it changes what each commit has to do.

- **Phases 1 and 2 produce content differences only.** Editing a script body,
  deleting a list, converting an entry to a constructor call: all of these
  change script text inside an item that already exists, which is exactly what
  `tools/verify_baseline.json` is for. Regenerate the baseline in the same
  commit that causes the difference, as `CLAUDE.md` requires.
- **No item is renamed, added or moved in Phases 1 to 3**, so any *structural*
  finding means something went wrong. Stop and do not rebaseline.
- **Phase 4 adds aliases, and that is still baselineable.** I checked
  `verify_merged.py:308-349`: a new item inside an existing tree routes to the
  `count|` and `added|` content entries, and `added|` digests the whole
  descriptor rather than just the path. Only a new *top-level* item is
  structural (`:360`). New aliases go under the existing `svo` alias folder, so
  they baseline. They must also be declared in the sibling `aliases.json`, or
  `check_src_tree.py` flags the orphan.
- **`check_renamed_callsites.py` still matters** in Phase 4, since new aliases
  and any renamed item names are silent no-ops in Mudlet when they do not
  resolve.
- **Any new check that reads raw file bytes needs the CRLF treatment** before it
  can be trusted, per the two failures `CLAUDE.md` records. That applies to the
  ported `check_derived_lists.py`.

---

## Phase 0. Prerequisites that are not mine to skip

| item | state |
|---|---|
| Steps 1 to 3 of the affliction name-space backlog, the renames | **optional, not a prerequisite (user, 2026-10-23)**; first batch merged as #850 |
| `fork-version-66` and `in-client-svof` each carry one commit the other does not | `CLAUDE.md` "Still open", first item, gates shipping anything |
| Transmutation cure cleanup | agreed 2026-09-21, deferred to its own work |

**2026-10-23: the renames no longer come first.** The user's view: as long as
svof maps each name to the game's GMCP name, the two vocabularies don't stand in
the plan's way. Checked: `sstosvoa`/`sstosvod` map them, the reverse tables are
derived at load and can't drift, and `vcustomaff`/`vcustomdef` already check
both name spaces. Nothing in Phases 1 to 3 needs an entry to carry its GMCP
name. A rename is still *structural* to `verify_merged` while the work here is
a baselineable content difference, so if renames are done, keep them in their
own commits; after Phase 1 each touches fewer places. What they would still buy
is one name per affliction, for readers and trigger writers: tidiness. vadi2
agreed the backlog on 2026-08-23; dropping it entirely is worth telling him.

The original reasoning, kept for the record: the guide put the renames first
because each one touches the same registration points this work collapses, and
keeping structural and content changes apart keeps each commit's failure mode
legible.

The transmutation cleanup is not a blocker. `basicaff` must simply never derive
a second salve or elixir name, which the guide's helper already gets right.

---

## Phase 1. Make the dictionary the source

The guide's Steps 3, 1, 2 and 4, reordered so the checker lands first. This
phase delivers the coder-facing benefit on its own and is worth landing even if
nothing after it does.

### 1.1 Port the checker into `tools/` -- DONE 2026-09-22

`tools/check_derived_lists.py`, with `tools/derived_lists_baseline.json` holding
37 accepted differences, wired into `build.yml` as gate 1.9.

Three things changed from the script in the Cowork export:

- **`--baseline` and `--write-baseline`**, matching `verify_merged.py`'s
  interface and payload shape, so it fails on anything new and on any change to
  a difference already accepted.
- **The second diag loop.** `Diag_trigger_functions.lua:108` covers 10 counted
  afflictions and the original read only the first loop, so a derivation built
  from that reading would have dropped them. `aff_diag` now compares against
  both. That also surfaced `bleeding`, which is in both loops, so
  `svo.valid.diag_bleeding` is defined twice and the later handler wins.
- **Floors under every literal.** A reformat that breaks one pattern made it
  read zero names, and zero derived against zero declared is a clean run that
  has checked nothing.

Proved by breaking it, five ways, each restored afterwards:

| sabotage | result |
|---|---|
| a new drift: `itching` added to `empty.eat_kelp` | FAIL, unexpected difference |
| a resolved drift: `parasite` added to `empty.eat_kelp` | FAIL, baselined difference no longer present |
| `fear`'s disabled focus block made live | FAIL, a known difference changed |
| a literal reformatted so its pattern stops matching | FAIL, floor |
| `tree = true` declared on an entry not in the tree list | FAIL, unexpected difference |

Line-ending independence verified against the raw git blobs rather than the
working tree, per the rule in *How this interacts with the gates*: 20,603 CR
bytes across the five source files on this Windows checkout, 0 in the blobs, and
the baseline recorded here passes unchanged against the LF tree with identical
digests.

### 1.2 Field-versus-balance collision gate -- DONE 2026-09-22

`tools/check_dict_fields.py`, wired into `build.yml` as gate 1.8. It runs before
gate 1.9 because it is the one that guards the work about to start.

It checks both directions, because `dict_setup` decides what a top-level key
means by its **type**, not its name:

- **A scalar named like a balance.** `Curing_skeleton.lua:332` reads
  `j.p.focus and ... j.p.focus.isadvisable()`, so `focus = true` on an entry
  makes the guard pass and the next term index a boolean.
- **A table named like anything else.** `dict_setup` stamps every table with a
  name, a balance and priorities, so it becomes a balance the curing loop can be
  asked to prioritise. This has already bitten: `dict_setup` empties
  `svo.dict.lovers.map` by hand at the end, under the comment "we don't want
  stuff in svo.dict.lovers.map!".

Both name lists are pinned in the script rather than discovered, so a new key of
either kind fails until somebody writes it down. Measured on this checkout: 267
entries, 17 balances, 17 flat fields, no collisions.

**The first version of this gate passed the `focus = true` sabotage**, which is
why it is worth saying that it was tested. It flattened each entry and then
filtered out any key that appeared as a balance somewhere, which removes exactly
the case it exists to catch. The fix marks a table value with a sentinel so
`herb = {` can be told apart from `count = 3`, and the fixed version reports the
same 17 and 17 on a clean tree. Five sabotage tests now fail correctly,
including a function-valued field containing a table literal, which must read as
a scalar and does.

### 1.3 Add the fields, one batch per commit

Order by how much judgement each needs, least first. Each commit rebaselines
`verify_merged.py`.

| order | field | source to transcribe from | judgement |
|---|---|---|---|
| 1 | `abbrev` | `@affs.lua`, 152 entries | none |
| ~~2~~ | ~~`simpletrigger`~~ | superseded by 1.5a - the simple family is generated from the entry's own shape | |
| ~~3~~ | ~~`diag`~~ | superseded by 1.5a - the trigger names the affliction | |
| ~~4~~ | ~~`generic`~~ | superseded by 1.5a | |
| 5 | `gmcp = false` | the 26 `false` entries in `sstosvoa` | none |
| 6 | `tree` | two lists disagreeing in 27 names | **all of it** |

Four of the six are gone. 1.5a landed instead, and between the three inversions
and the `simple` derivation there is nothing left for `simpletrigger`, `diag`
or `generic` to record - each would state a fact now read off the entry's own
shape, or off the trigger that names the affliction. What remains of batch 6 is
below.

Batch 6 is the largest piece of judgement in the whole plan. The 27 disagreeing
names are worked through under *The two tree lists, resolved* near the end of
this document: 7 are settled, 6 are proposed, and 14 remain game questions. It
also turned up two live nil-call defects that are independent of this work.

`check_derived_lists.py` prints 25, not 27, and that is a different pairing
rather than a number that moved. The inversion removed the 85-name `tree` list,
so the gate compares the names the `tree_cured` triggers pass - 63 of them,
which is the "somebody saw the game print this" evidence - against
`treecurables`. The 27 above is the old list-against-list count, and the groups
below are built on all three signals, so they still say what to do.

`gamename` already exists on entries and is reused, not added.

### 1.4 Build the derived tables in `dict_setup`

The guide's Step 2 code, with two changes: no `prio`, and the diag derivation
splits on `count`. **Sort everything**, for the reason the guide gives and this
repo has already been bitten by once in muddler's directory read order.

Nothing consumes the results yet, so this commit cannot change behaviour.

### 1.5 Switch the consumers, one per commit

Easiest to prove first. Each commit is gated on a green `check_derived_lists.py`
for that list.

1. `afflist` in *Simple aff trigger functions*
2. both diag loops
3. `generic_cures_data`
4. the `tree` list and `treecurables`
5. both herb maps, which is the one that does more than delete a list: the map
   in *Empty cure handling* is the **definition** of the empty handlers, so
   switching it makes the drift impossible rather than merely visible
6. `aff_abbrev` in *@affs*
7. `sstosvoa`

### 1.5a A better answer for four of the seven consumers

**Found 2026-09-22, after the diag triggers turned out to be broken in both
directions. This supersedes part of 1.5 and is the larger simplification.**

1.5 as written replaces a hardcoded list with a derived one. For four of the
seven consumers there need not be a list at all, because **the trigger already
holds the fact and the list is a stale copy of it**.

Measured with `check_valid_callsites.py`'s own resolver:

| family | names the list generates | names a trigger calls | unresolved |
|---|---:|---:|---|
| `simple` | 159 | 116 | `simpleconcussion`, `simplecheckwrithes` |
| `diag_` | 160 | 146 | `diag_calcifiedtorso`, `diag_calcifiedskull`, `diag_latched` |
| `generic_` | 112 | 66 | none |
| `tree_cured_` | 92 | 65 | `tree_cured_latched` |

For `diag_` I checked exhaustively: 16 listed names are called from nowhere at
all, and 3 called names are not listed. The list is wrong in both directions.
It cannot be the source of truth for "does this show in DIAGNOSE", because the
thing that actually knows is the trigger, which carries the game's exact line.

**Invert `diag_`, `generic_` and `tree_cured_`.** Each handler body is a pure
function of the affliction name, so 364 generated closures become three
functions and the trigger passes its own name:

```lua
-- instead of svo.valid.diag_calcifiedskull()
svo.valid.diag('calcifiedskull')
svo.valid.diag('crackedribs', matches[2])   -- counted: the split follows
                                            -- from whether a capture is passed
```

with a guard the per-name version cannot have:

```lua
  if not svo.dict[name] then
    svo.errorf("a diag trigger names %q, which is not an affliction", name)
    return
  end
```

That turns a typo from a silent nil call into a message naming the typo. All
three are internal: nothing in `doc/` or `Developer_readme.md` mentions them.

**`simple` must keep its per-name functions.** `doc/index.rst:1684` documents
`svo.valid.simple<affliction>()` as the way users write their own bashing
triggers, so removing them breaks user scripts. It can still lose its list:
every name in `afflist` has an `aff` block (measured: `afflist - has_aff` is
empty), so generating one per entry-with-an-`aff`-block loses nothing, adds 25
more, and makes the documented API work for any affliction that has one. That
is better public API, not worse.

**Landed 2026-09-23.** 17 of the 25 gained, not all of them: eight are the
anti-illusion probes, excluded by name in `no_simple_handler`, because
`checkslows` and `checkwrithes` take the symptom's real affliction name and
index `svo.affsp` with it, so a bare call raises rather than doing nothing.
`simplecheckwrithes` therefore stays a recorded dead call, which is what the
two bashing triggers calling it already got. The `afflist - has_aff is empty`
measurement above held up under a second, independent parser; an indentation-
based re-measurement disagreed and was wrong, because the dictionary literal
indents some entries two spaces and some four.

**`herb_cured_`, `smoke_cured_`, `focus_cured_` and `salve_cured_` cannot be
inverted.** Their handlers cross-check against sibling cures with
`svo.checkany`, so the grouping is real information rather than duplication.
Those are what Step 2's `cures_by_item` derivation is for.

**The tree family has a second question behind it, settled 2026-09-22.** The
repo owner asked whether GMCP should own tree cures instead of triggers, and
whether that should come before the inversion. Measured: **84 of the 86
tree-cure triggers name an affliction GMCP already reports**; only `bleeding`
and `earworm` are absent from `sstosvoa`. So for affliction removal alone the
triggers are redundant 84 times out of 86.

They are not redundant, for two reasons.

- **They carry a second job GMCP does not do.** `tree_cured_X` does not remove
  the affliction; it reports that the *touchtree action* completed, with the
  affliction as its argument, and `touchtree.misc.oncompleted(aff)` then does
  the removal plus `svo.lostbal_tree()`, the burn-ladder step, the four
  fracture counts, the shivering-to-frozen heuristic, and illusion detection
  through lifevision. The GMCP removal path (`Setup.lua:700-720`) sets
  `sk.gmcp_cured`, calls `svo.rmaff`, resets the count and emits
  `changecuring`. Nothing there closes the touchtree action, so
  `svo.doingaction('touchtree')` would stay true and tree balance would never
  be marked spent.
- **GMCP stops during blackout.** The repo owner confirmed that the `blackout`
  affliction stops `Char.Afflictions` entirely, and `Controllers.lua:572`
  already defaults eight vitals fields "due to gmcp values being nil in
  blackout". The codebase has always known this: both the dictionary's header
  comment and `Developer_readme.md:146` describe `generic_cures_data` as
  covering "passive cures or cures that happen in blackout". The text triggers
  are the blackout fallback by design.

**So the triggers stay, and the inversion goes first.** The 86 edits are
durable rather than throwaway; the GMCP work needs exactly one place to decide
"GMCP already told us, so only close the action" against "GMCP is silent,
remove it too", which is what the inversion creates; and the two have opposite
failure modes. The inversion is a refactor the gates can prove. Making GMCP
primary changes how svof learns a cure happened, which no gate here can see and
which wants play testing - see the open DEF-resync capture gap in the
`svof-curing-live-behaviour` memory. Landing them together would make a curing
regression look like refactor noise.

**`simple` derives from the dictionary, and the codebase already agrees what
the predicate is.** `svo.vaff` gates on `svo.dict[aff] and svo.dict[aff].aff`
(`Alias_functions.lua:1126`) - exactly the set `simple` would be generated
from. Today `vaff` accepts 180 names while `simple` exists for 162, so
deriving makes the two agree by construction instead of by coincidence. Load
order allows it: `dict` is subsystem 4 and `valid_simple` is 11, so the
dictionary is fully populated when the loader runs, and a class change rebuilds
both.

The 162 today break down as 155 from a hardcoded `afflist`, 1 conditional
(`cantmorph`), 4 from a second hardcoded list with a counted body, and **12
written out individually with bodies that are not functions of the name** -
`age`, `blackout`, `bleeding`, `hoisted`, `lovers`, `prone`, `unknownany`, the
three `unknowncrippled*`, `unknownmental`, `webbed`. Those 12 are why `simple`
cannot be inverted the way `diag` was, and they need no special handling when
deriving: a later `svo.valid.simpleX = function() ... end` simply overwrites
the generated one.

### Why this is a prerequisite for Phase 3, not a tidy-up

Raised by the repo owner 2026-09-22. A user-registered affliction needs these
handler families too, and how much work that is depends entirely on whether
the family is a name-taking function or a per-name generated one.

| family | what a runtime-registered affliction needs |
|---|---|
| `diag` | **nothing** - done in `83c0353`; the function looks the name up at call time and its guard passes for any entry with an `aff` block |
| `generic_` | nothing - done in `e893d08` |
| `tree_cured_` | nothing - done in `e893d08` |
| `simple` | one re-run of `svo.loader.valid_simple()` after the entry exists, because the per-name functions are API and are generated from the dictionary |

So inverting turns "wire up four families per custom affliction" into "one",
and that one is a single line in `svo.register_affliction`. Without it, Phase 3
has to reach into four hardcoded lists at runtime and regenerate four closures,
which is the same problem `basicaff` exists to avoid one level down.

All four landed, so that line is now `svo.loader.valid_simple()`, called after
`svo.dict_setup()` the way `Defences.lua` already does when it registers a
defence at runtime. The loader defines rather than accumulates, so re-running
it is safe.

This is the same argument as the reframe at the top of this document. A
constructor turns an entry into data; a name-taking handler turns a trigger
family into data. Both are what make runtime registration cheap rather than
special.

Cost, stated plainly: ~277 trigger scripts change by one line each. That is a
scripted bulk edit, which this repo has been damaged by three times, so it
wants diffing file by file and a `verify_merged` run that shows only script
text moving. The baseline jumps by roughly that many entries.

### 1.6 Resolve the four drifts, one commit each

The checker prints them today, with no refactor needed:

| drift | decision needed |
|---|---|
| `parasite` cured by kelp in the dictionary, absent from `empty.eat_kelp` | probably a missed edit |
| `pyramides` likewise for bloodroot | probably a missed edit |
| `waterbubble` likewise for pear | it is a defence, so probably correct to exclude |
| `fulminated` has a live focus block and is missing from `focuscurables` | the guide reads this as a bug |

Each needs a stated reason in its commit message, because after Phase 1 the
distinction between a deliberate exception and a missed edit is the only thing
the code cannot tell you.

**At the end of Phase 1, adding an affliction is two coder steps: write the
entry, add the triggers.**

---

## Phase 2. Make an entry constructible from data

The guide's Steps 5, 8, 6 and 7. This is where the readability gain is largest
and where the user-facing surface becomes possible at all.

### 2.1 `svo.basicaff(name, spec)`

The guide's helper, with the corrections above: no `prio`, the pairing table
sourced from one place, the `empty` placement quirk reproduced exactly rather
than tidied. Install the `noeffect` default for `salve`, `smoke`, `sip` and
`purgative` as well as `herb`, which closes the 20-salve gap the guide records
under *Related findings* as a side effect.

### 2.2 The equivalence harness, before any conversion

The build gates compare script text, so they will flag every conversion and tell
you nothing useful. The proof has to be behavioural, and the guide's method is
right: keep the old entry under a scratch name and compare both tables over
every combination of the afflictions their conditions mention.

Write it as `tools/test_basicaff_equivalence.lua`, in the same extract-the-real-block
style as `tools/test_gmcp_reconciler.lua`, so the code under test is a substring
of the shipped file and cannot drift. Run it in CI under the same Lua 5.1.5 the
syntax gate uses, and branch on `setfenv` the way the existing tests do.

Then break it on purpose, drop one name from one `unless` list, and confirm the
expected states fail. A test nobody has made fail is not evidence.

### 2.3 Convert the afflictions, in batches by shape

The 27 entries shaped `{aff, gone, herb}` first. Smoke entries come out
shortest: 11 of the 13 fit exactly, and `deadening` goes from 28 lines to 4.

Leave the burn ladder hand-written. It is one state machine across five entries
and Change A does not care: it gains the fields and joins every derived list
like anything else.

### 2.4 `basicdef(name, spec)`

`check_basicdef_spec.py` passes 39 of 39 on this checkout and settles the shape:
21 fields cover all 134 field-only definitions, and 327 of the 329 defence
definitions become one call.

Follow the guide's eight-step order. Step 2 of it is the one that proves the
helper: converting the 157 existing positional calls must produce
byte-identical generated code, and if it does not, the helper is wrong.

Three defects must not carry over, all confirmed by that harness:

- `shield`'s arm guard misspells `mangledrightarm`, so it has never fired.
  Delete the clause rather than correcting the spelling: the same conjunction
  already carries `sys.canoutr`, which the corrected clause is a strict subset
  of.
- `disperse`, `hiding`, `shadowveil` and `waterbubble` return nil rather than
  false. Fixed by construction.
- Ten definitions carry a redundant third disjunct in the defup clause. Also
  fixed by construction.

The one field that is a real preference and not a normalisation:
`defupfirst`, whose keepup arm also requires `not sys.deffing`, differs in 1
state of 32. Keep it as a field.

### 2.5 `rage = true`

**The only step in this plan that changes what svof does in play.** Its own
commit, with the three changes named in the message, because no gate can see any
of them:

1. `generosity.herb` gains `dominion`, which affects every Unnamable every time
   rage is advisable.
2. Rage's `empty` starts clearing `pyre`, which it omits today while
   `isadvisable` fires on it.
3. Clearing a counted affliction resets its count, which also fixes
   `empty.eat_bellwort`.

The repo owner decided on 2026-09-22 that generosity should follow the same
pattern as the other rage cures, so change 1 is intended. Its scope is still
worth stating in the commit message: `available_skills` is built from the
current class alone and `dominion` belongs to Unnamable, so this affects every
Unnamable every time rage is advisable.

### 2.6 The defence tidy-ups

Independent of everything else and of each other.

- **7a and the 7d comment fix are safe today** and can land any time. 7a
  deletes dead weight in four groups, each verified by grep over `Defences.lua`:
  `on_free`, `off_free` and `offs` have a branch in the trigger loop and no
  record sets any of them; `onshow` is neither set nor read on a `defs_data`
  record; `tooltip` is set on 7 records and read nowhere; and
  `defences.complete_def` (`:2880`) has no caller in `src/`. Keep the last one
  with a comment if an addon uses it.
- **7c fits Phase 1's shape**: state the serverside name once on the entry and
  derive `sstosvod` and `svotossd`, the way 1.4 derives `sstosvoa`. Join it to
  1.4 rather than treating it separately.
- **7e fixes real nondeterminism.** Three entries have more than one non-`gone`
  sub-table (`deathsight`, `thirdeye`, `insomnia`), and three sites pick one
  with `pairs`, whose order is undefined. Prefer `physical`, else the single
  candidate, and warn when there is more than one.
- **7b needs a game question**: whether `bedevil` and `evasion` can be raised at
  all. Until answered they hand every user a defup slot nothing can fill.
- **7d itself stays**: `specialskip` means "never, stop waiting" and
  `isadvisable` means "not now". Merging them would move the duplicate one line
  closer without removing it.

---

## Phase 3. The registration API

New work, and the bridge between the refactor and the user surface. Six commits.

### 3.1 Extract `defences.wire_defence(name, data)`

Lift the body of the anonymous `signals.systemstart` handler at
`Defences.lua:3294-3400` into a named function, called once per entry from the
same loop. No behaviour change, one content difference to baseline.

### 3.2 `svo.register_defence(name, spec, lines)`

`basicdef(name, spec)` plus `defs_data:set(name, lines)` plus `wire_defence`
plus the defup, keepup, `ignored_defences` and `def_types` slots, all inside the
priority snapshot that `enablemindnet` already takes.

Then rewrite `enablemindnet` to call it. That is the test.

### 3.3 `svo.aff_lines` and its wiring loop

The affliction side has no equivalent of `defs_data`: recognition lives in static
trigger items, 2,420 trigger scripts across the tree (measured:
`find src/triggers -name '*.lua' | wc -l`). So this is the one genuinely new
mechanism.

Add `svo.aff_lines`, keyed by affliction name, with the same recognition keys
`defs_data` uses (`on`, `onr` for gaining, `off`, `offr` for losing). Connect a
`signals.systemstart` loop that creates the matching temp triggers pointing at
`svo.valid['simple'..name]` and the gone handler, collecting ids the way
`svo.defencetemptriggers` does so a class change kills them.

Shipped afflictions keep their static triggers. `svo.aff_lines` exists for
runtime additions only, so the new loop does nothing at all unless a user has
defined something, which keeps the blast radius on shipped behaviour at zero.

### 3.4 `svo.register_affliction(name, spec, lines)`

`basicaff(name, spec)`, place the result in `svo.dict`, populate
`svo.aff_lines[name]`, re-run `dict_setup` inside a priority snapshot.

It must also give the new affliction its handler families. How much that costs
depends on 1.5a having landed first: with `diag`, `generic_` and `tree_cured_`
inverted they need nothing at all, because those functions take the name and
look it up at call time. Only `simple` needs a per-name function generated,
since `doc/index.rst:1684` documents it as API, and that is one call to the
generator extracted from the loop. Without 1.5a this step has to reach into
four hardcoded lists and rebuild four closures.

### 3.5 Persistence and reload

`svo.classchange` sets `svo.dict = {}` and re-runs the whole loader
(`svo.classchange.lua:37-38`), so custom entries vanish on a class change and
must be re-registered. `defs_data` is *not* cleared, so registering into it is
already idempotent; `svo.dict` is, so it is not. Handle both.

Save to `<profile>/svo/custom/affs` and `<profile>/svo/custom/defs` with
`svo.tablesave`, matching every other svof user file. Note that user data under
`<profile>/svo/` is untouched by package updates, which is the property that
makes a user's definitions survive an svof upgrade.

Re-register on `signals.systemstart`, after the dictionary has rebuilt.

### 3.6 Failure containment

A user definition that raises must not stop svof loading. Three requirements:

- Wrap each registration in `pcall`. On failure report the name and the error
  with `svo.errorf`, skip that one definition, and carry on.
- Validate the spec before installing anything: every field known, no field name
  colliding with a balance name, every referenced cure item real, the affliction
  name not already taken.
- Provide an escape. A user who has broken their own curing needs to start
  without their definitions, so `vconfig customdefinitions no` must be reachable
  and must persist
  across a restart.

---

## Phase 4. The user surface

Built in svof's own idiom. `vconfig`, `vshow defup` and `svo.afflist` are all
clickable echo flows using `echoLink`, `insertLink`, `printCmdLine` and `cecho`,
and the new surface should look like them rather than introduce a second style.

### 4.1 `vconfig customaff` and `vconfig customdef`

**Decided by the repo owner on 2026-09-22**, along with the decision that this
belongs in svof itself and not in an addon.

`vaff` and `vrmaff` already mean "add or remove an affliction *instance*"
(`Alias_functions.lua:1125,1147`), so the surface hangs off `vconfig` rather
than a new `v` verb. The existing alias regex,
`^vconfig[_ ]([^ ]+)(?: (.+))?$`, already parses it: `matches[2]` is
`customaff`, `matches[3]` is the whole rest of the line.

| command | what it does |
|---|---|
| `vconfig customaff` | list every affliction you have defined, with edit and delete links |
| `vconfig customaff <name>` | start or resume defining one, showing the spec so far |
| `vconfig customaff <name> <field> <value>` | set one spec field |
| `vconfig customaff <name> line got` | capture a game line as the "gained" pattern |
| `vconfig customaff <name> line cured` | capture the "cured" pattern |
| `vconfig customaff <name> test` | build the entry, report what it would do, install nothing |
| `vconfig customaff <name> install` | register it and save it |
| `vconfig customaff <name> delete` | remove it |
| `vconfig customaff export [file]` | write all definitions to a shareable file |
| `vconfig customaff import <file>` | read one back |

`vconfig customdef` is the same surface for defences.

Each field set echoes back the whole spec with the unset fields shown as
`echoLink` prompts, exactly the way `vconfig` shows an unset option. That is
what makes it discoverable without a manual.

**One plumbing change is required first.** `svo.config.set`'s custom branch
calls `onset()` with no arguments (`Config_system.lua:2244`), so everything
after the option name is dropped today. Pass `option` through **in the custom
branch only**:

```lua
      if svo.config_dict[what].onset then
        svo.config_dict[what].onset(option)   -- was onset()
        raiseevent(what)
      end
```

Safe as written: all four existing `type = 'custom'` options (`cadmusaffs`,
`treefunc`, `restorefunc`, `dragonhealfunc`) are menu-only and define no
`onset`, so nothing reads the new argument. Leave the `string` and `number`
branches alone, because their `onset` handlers read `conf[what]` rather than a
parameter.

No new alias item is needed, which also means Phase 4 adds nothing structural to
the package and nothing to any `aliases.json`.

### 4.2 Capture the pattern from the screen

This is the single highest-value piece of the surface, because writing a pattern
is the one step a non-coder cannot do and the one step that silently produces a
definition that never fires.

Mudlet gives exactly what is needed, and both calls are far below svof's floor
of 3.20 (`svo_init_system.lua:68`):

- `getLastLineNumber()` returns the latest line's number in the main window.
- `getLines(from, to)` returns those lines as a table.

So `vconfig customaff <name> line got` shows the last 10 lines as a numbered, clickable
list, and clicking one stores it as an exact-match pattern. The player never
types a pattern and never sees the word regex. Offer a regex field as well for
anybody who wants one, but do not make it the path.

Store the choice the same way `defs_data` already does, so `wire_defence` and
the affliction loop need no new cases: `on` for an exact match, `onr` for a
regex.

### 4.3 Registering the two options

Both are `type = 'custom'`, added with `svo.config.setoption`:

```lua
svo.config.setoption('customaff', {
  type   = 'custom',
  onmenu = function () svo.custom.menu('aff') end,
  onset  = function (rest) svo.custom.command('aff', rest) end,
})
svo.config.setoption('customdef', {
  type   = 'custom',
  onmenu = function () svo.custom.menu('def') end,
  onset  = function (rest) svo.custom.command('def', rest) end,
})
```

A `type = 'custom'` option is **not** rendered by the generic `vconfig2` loop,
which only handles options that behave as booleans
(`Alias_functions.lua:269-287`). `treefunc` is the precedent: it is reached from
an `echoLink("view scenarios", "svo.config.set'treefunc'")` placed inside
another option's display (`Config_system.lua:303`). Do the same, with a "view
custom definitions" link in the `vconfig2` output.

A separate plain boolean, `customdefinitions`, carries the on-off switch, so a
player whose own definition has broken their curing can start without it. That
one does render in the generic loop.

### 4.4 A Geyser panel is a separate, later piece

`createTextEdit` and `getTextEditText` would let a player paste several game
lines at once, and `setLabelClickCallback` gives real buttons. Both are worth
having. Two reasons to keep them out of this work:

- The text edit family needs Mudlet 4.21 or later and svof's floor is 3.20, so
  the panel would have to be gated on `not mudletOlderThan(4,21)` with the echo
  flow as the fallback everybody gets. That means building the echo flow anyway.
- svof has one Geyser panel today (`svo.riftlabel`) plus the update prompt, so a
  panel is a new surface to maintain, not an extension of an existing one.

Build the echo flow first. Revisit the panel once somebody has actually used the
aliases and said what is awkward.

---

## Phase 5. Documentation

Three places, all of which currently state the eleven-step recipe:

- `Developer_readme.md:141-152`, "How to add a new affliction", becomes two
  steps. The defence recipe at `:194` keeps its two but gains the spec form.
- `Dictionary_of_actions_(affs-defs-misc).lua:13-21`, the file's own eight-line
  comment header, repeats the same recipe and must change with it.
- `doc/index.rst` gains a `vconfig customaff` and `vconfig customdef` section.

---

## What no gate can see

Stated plainly, because most of the risk in this plan is here.

- **Whether a converted entry behaves the same in play.** The truth-table
  harness proves the condition. It proves nothing about the action system, the
  curing loop, or timing.
- **Whether the three Step 6 behaviour changes are right.** Two are questions
  about the game, not about the code.
- **Whether a user-defined affliction actually cures.** That needs the live
  testing rig at `C:\work\svof-live-testing`, extended with a curing case. The
  existing 49 checks cover install, load and update, not curing.
- **The 27-name `tree` decision.** Every one is a question about the game.
- **The still-open live-testing gap** from `CLAUDE.md`: a capture with real
  `DEF` resyncs. Nothing here closes it.

---

## Order of work

| phase | step | touches | reversible alone | changes play |
|---|---|---|---|---|
| 0 | branch reconciliation (renames optional since 2026-10-23) | prerequisite | n/a | no |
| 1 | 1.1 port the checker | `tools/`, CI | **DONE 2026-09-22** | no |
| 1 | 1.2 collision gate | `tools/`, CI | **DONE 2026-09-22** | no |
| 1 | 1.3 add the fields, 6 commits | dictionary | yes, per commit | no |
| 1 | 1.4 derive in `dict_setup` (+ 7c) | dictionary | yes | no |
| 1 | 1.5 switch 7 consumers | 5 files | yes, per commit | no |
| 1 | 1.6 resolve 4 drifts | dictionary, empty handling | yes, per commit | **yes, small** |
| 2 | 2.1 `basicaff` | dictionary | yes | no |
| 2 | 2.2 equivalence harness | `tools/`, CI | yes | no |
| 2 | 2.3 convert afflictions | dictionary | yes, per batch | no |
| 2 | 2.4 `basicdef(name, spec)` | dictionary, Defences | yes, per batch | no |
| 2 | 2.5 `rage = true` | dictionary | yes | **yes** |
| 2 | 2.6 7a, 7d comment, 7e | Defences | yes, per part | 7e only |
| 3 | 3.1 to 3.6 registration API | Defences, dictionary, new file | yes, per commit | no |
| 4 | 4.1 to 4.3 the surface | aliases, config, new file | yes, per commit | no |
| 5 | docs | readme, dictionary header, rst | yes | no |

**Phase 1 alone delivers the coder-facing benefit.** Phases 2 and 3 are what the
user-facing surface needs. Phase 4 is the surface.

---

## Decisions taken 2026-09-22

The repo owner settled all four open questions.

1. **Phase 4 goes in svof itself, not in an addon.** It is system functionality.
2. **Generosity follows the other rage cures.** So `generosity.herb` gains
   `dominion` and collapses to `rage = true` like the rest of Step 2.5. Its
   behaviour change is intended, not a side effect to flag.
3. **The surface is `vconfig customaff` and `vconfig customdef`**, which needs
   the one-line `onset(option)` change in 4.1.
4. **The tree lists** are settled in part. See the section below.

## The two tree lists, resolved

The guide treats the `tree` list and `empty.treecurables` as one fact written
twice. They are not. They do different jobs, which is why "trust the longer
list" does not decide this.

| list | size | what it drives |
|---|---:|---|
| `tree` in *Main trigger functions* (`:2891`) | 85 | creates `valid.tree_cured_X`, called by a trigger on the game line saying tree cured it. **Recognition** |
| `empty.treecurables` (`Empty_cure_handling.lua:74`) | 80 | `empty.tree()` clears all of these when tree cures nothing, and `svo.gettreeableaffs()` feeds `svo.tree.any2affs`/`any3affs`, the shrugging pair, and `ninkharsag.gone.hiddencures`. **When to tree, and self-correction** |

A third signal was thought to decide most cases better than either list:
whether a trigger on a real game line exists, since somebody had to see the
game print it.

**That third signal is worthless, and so is the 86-name list. Established
2026-09-23, after the repo owner rejected two names it had put in.**

- **A trigger in the *Tree cures* folder proves nothing about tree.** 67 of its
  76 patterns have a twin in *General cures* on the identical pattern. The
  pairing is svof's normal structure for a cure line, not evidence. The tree
  copy calls `svo.valid.tree_cured(name)`, which is a no-op unless a touchtree
  action happens to be in flight, so wiring a line to both paths costs nothing
  and tells you nothing. All the trigger proves is that the *line* is real.
- **The 86-name `tree` list claimed eight afflictions tree does not cure**:
  `bound`, `prone`, `flamefisted`, `galed`, `icing`, `voided`, `bleeding` and
  `tension`. A list wrong about eight names is not evidence for the others.

What is left is owner or in-game confirmation, and nothing else. The standard
now: **do not make the system believe it can cure something until it is
proven.** Getting this wrong is asymmetric - `empty.tree()` removes every
`treecurables` name you currently have, so a wrong entry makes svof forget an
affliction you still hold.

### Two live defects found on the way

`svo.valid.tree_cured_paralysis()` and `svo.valid.tree_cured_latched()` are
called by active triggers and **no code anywhere creates either handler**.
`svo.valid` is a plain table with no metatable (`Setup.lua:130`), so both raise.
The four fractures avoid this only because of their own handler loop at
`Main_trigger_functions.lua:4474`.

The lines are `Your muscles unlock; you are no longer paralysed.` and
`Warmth floods back into your limbs, and you feel suddenly vital.` Both are also
matched by working triggers in *General cures*, so curing still happens and the
error goes to the Mudlet error console.

**Pre-existing, not conversion damage.** The 2018 reference xml carries the
identical 85-name list without either name, and the same two triggers. Same
family as `tools/known_unresolved_names.json`, except that file records item
names that do not resolve and this is a Lua function that does not exist.

### Group 1: was never mechanical -- withdrawn 2026-09-23

Seven names were grouped here as settled because each has a trigger on a real
game line, read as evidence that tree cures them: `bleeding`, `crackedribs`,
`paralysis`, `skullfractures`, `tension`, `torntendons`, `wristfractures`.

**The premise was wrong**, for the reason above: a Tree cures trigger is the
normal twin of a General cures one and says nothing about tree. `bleeding` is
the clearest demonstration. Its line is "Your bleeding slows as your blood
clots", which is the clotting line, and clotting is what cures bleeding. The
repo owner rejected both `bleeding` and `tension` on 2026-09-23 and they were
taken back out.

`paralysis` and the four fractures are in `treecurables` and were there in the
2018 code, so nothing about them changed either way. Their tree lines pair with
General cures ones exactly like `bleeding`'s does, so the same doubt applies and
neither this work nor anything before it has ever proved them. Left alone rather
than acted on in either direction.

`paralysis` landed in `1cc6ce3` for a different and still-valid reason: its
handler did not exist, so an active trigger was raising into the error console
on a line the game really prints.

`latched` was the harder one and is now resolved except for one doubt. Its dict
entry used to carry the comment "not sure how this is cured yet exactly" and all
five of its handlers were missing. `751f706` and `648d73c` wired the mechanic
the owner supplied - gaining it costs elixir balance, SIP HEALTH clears it - and
the inversions resolved the rest.

**The open doubt: `latched` is in `treecurables` on the owner's answer that an
empty cure is empty regardless, but its confirmed cure is SIP HEALTH.** If tree
does not cure it, clearing it on an empty tree makes svof forget a latch it
still has, and the next health sip then tries to heal instead of clearing the
latch. It is also not in the old 86-name list; its only tree evidence is a Tree
cures trigger, which the section above establishes means nothing. Worth a second
look.

### Group 2: timed afflictions -- answered 2026-09-23, none of them

The original six were wrong in two ways, both found when the repo owner asked
what "timed" meant.

**Only four are timed.** `flamefisted`, `galed`, `icing` and `voided` have a
`waitingfor` balance whose `isadvisable` returns false and a `customwait` of
30, 10, 30 and 20 seconds. svof never attempts a cure for these; it starts a
timer and clears the affliction when the timer runs out. `bound` and `prone`
are not timed at all - both have a `misc` balance with a real action, `writhe`
and `stand`/`recover footing`, so svof actively cures them.

**Five of the six are already out of both lists**, and nothing has to be
removed. They were in the 85-name recognition list and had no trigger, so the
inversion dropped them when the list went. None of the six was ever in
`treecurables`.

**`voided` was the only one left open, and the answer is no.** It is the only
one of the six with a tree-cure trigger, on the exact line "The empty grasp of
the void retreats, and you breathe more easily." The owner's reading: a timed
affliction that was never wired into anything tree-related is not cured by tree,
and `voided` being in the 86-name list was probably a mistake. It stays out of
`treecurables`, so its behaviour is unchanged. Its Tree cures trigger is still
there and, for the reason established above, still means nothing.

### Group 3: answered 2026-09-23

The repo owner confirmed tree cures all 14. Six of them - `disrupt`,
`fulminated`, `unknownany`, `unknownmental`, `unknowncrippledarm`,
`unknowncrippledleg` - were already in `treecurables` and needed nothing. The
other eight were added: `flushings`, `mycalium`, `pyramides`, `rebbies`,
`sandfever`, `laceratedthroat`, `mildconcussion`, `slashedthroat`. None has a
known game line, so they are in the empty-cure list only and svof still does
not recognise a tree curing them when it happens.

`latched` went in at the same time, on the owner's answer that an empty cure is
empty regardless and it should behave like every other treecurable. The doubt
about it is under group 1 above.

Group 1's `bleeding` and `tension` went in with them and came straight back out
when the owner rejected both. `treecurables` is 89 names, up from 80.

One thing to keep in view: `empty.dragonheal` and `empty.shrugging` are the
same function as `empty.tree`, so all eleven now also clear on an empty
dragonheal or an empty shrug. That sharing predates this and the comment above
the list now says so, but whether shrugging really cures the same set is not
something this repo has ever checked.

The 14 that were open, and what each was:

| names | situation |
|---|---|
| `flushings`, `mycalium`, `pyramides`, `rebbies`, `sandfever` | ordinary herb cures, in the tree list, no trigger |
| `laceratedthroat`, `mildconcussion`, `slashedthroat` | salve cures, same situation |
| `disrupt`, `fulminated` | in `treecurables` only |
| `unknownany`, `unknownmental`, `unknowncrippledarm`, `unknowncrippledleg` | the unknowns, in `treecurables` only, and arguably right there since clearing an unknown on an empty tree is the point |

Separately, 15 names sit in **both** lists with no trigger at all: `blackout`,
`crescendo`, `degenerate`, `depression`, `deteriorate`, `dissonance`, `earworm`,
`horror`, `itching`, `madness`, `parasite`, `pyre`, `retribution`,
`shadowmadness`, `timeloop`. Either the lines were never added or tree does not
cure them. Lower stakes, since being in both is at least self-consistent.

### What batch 6 became

Not a field. The inversion left only one consumer - `empty.treecurables` -
because recognition now lives in the triggers, and a `tree = true` field
derived into a single consumer is just that consumer with an extra step. So
batch 6 reduced to getting `treecurables` right, which groups 1 and 3 and
`latched` did on 2026-09-23. `voided` is the only name still open.

What a `tree = true` field would still buy is the reverse direction: an entry
declaring it and having no trigger would be a visible gap rather than a silent
one. Twenty-nine names are in that state today. Worth revisiting if the
game lines for them ever turn up.

---

1.1 and 1.2 landed on 2026-09-22. Both are `tools/` and CI only, neither
touches anything muddler reads, so `verify_merged.py` and `check_package.py`
cannot move. The rest of Phase 1 no longer waits on the renames (2026-10-23,
see Phase 0); it is on hold by the user's choice since 2026-10-17.

The two nil-call defects are independent of everything here and can go in their
own small commit whenever wanted.
