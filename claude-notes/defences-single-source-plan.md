# Defences: the single-source plan

Written 2026-10-08 against the stack tip `4f4c017` (#863, `action-system-live-gnome`).

## Progress

Work happens on the branch `defences-single-source` in the worktree
`C:\work\svof-defs`, branched from `origin/action-system-live-gnome`
(`4f4c017`). Pushed to the user's fork only (`fork`, TheLastDarkthorne/svof,
2026-10-10, at `1bd38ce`) as a backup, at the user's request; not to
svof/svof, and no PR: the stack is still with the repo owner.

| step | state | commits |
|---|---|---|
| D0.1 `tools/test_defences.lua` on `tools/svof_world.lua` (gate 1.94) | done | `2299217` |
| D0.2 `svo.defs` call sites in `check_valid_callsites.py` (gate 1.22) | done | `a7808cc` |
| D0.3 `tools/check_defences.py` (gate 1.95) | done | `3132baa` |
| D1 typos: defects 1, 2, 4, 5, 6, 7, 8 | done | `b7909c1` `cba0bd1` `12ec97f` `9d32824` `11f31e9` `31c92af` `c4f2bb3` |
| D1 defect 12 (mindseye precedence, no game question) | done | `44d23cb` |
| new defect 25: frost and temperance never lost themselves | done | `ec47d89` |
| D1 defects 3, 9, 10, 11, 13, 14, 15 | waiting on game questions | |
| D2.1, the part that changes play: caloric and frost send their serverside names, insulation and temperance | done | `d2cecba` |
| D2.1, the rest: GMCP names onto records, `sstosvod` derived | folded into D5: structural only, now one namespace is confirmed | |
| new defect 26: `dict_setup` added `gone` while `pairs()` walked the entry | done | `5238805` |
| the three artefact defences checked for every class and through a class change | done | `9537ea2` |
| new defect 27: `vconfig havemindnet on` registered lifevision | done | `39078c1` |
| D3.1 `confirm`, `unconfirm`, `waits`, `ongot`/`onlost` hooks | done | `0f22c70` |
| D3.1 six consequences onto records (frost, temperance, mindseye, astralform, viridian, block) | done | `05111f1` |
| D3.2 GMCP Add, Remove and List call them | done | `f77f37f` |
| D3.3 `process_defs` leftovers call `confirm` | done | `85a5bf4` |
| D3.4 text `got_` claims whichever action is in flight | done | `0bca96d` |
| D3.5 remake generated handlers each systemstart | done | `907d642` |
| D4 losses: a line saying a defence is gone is dropped while GMCP reports it | done | `90564b1` |
| D4 gains: a gain line GMCP does not back is dropped, svof's command kept in flight | done | `edb0cd6` |
| the phylactery found with one space or two after its "a" | done | `e495281` |
| D2.2 (part): `tempest`, `susurrating` mapped, from the login log | done | `6e9806b` |
| D6.1 `defences.wire` | done | `d83ceca` |
| D6.2 `defences.register`; mindnet, lifevision, shroud on it | done | `dea118b` |
| D6.3 definitions saved under `svo/custom/defs`, registered every systemstart, `vconfig customdefinitions` | done | `5d67e0a` |
| D7 `vconfig customdef` (with `defences.unregister`, docs) | done | `dec3850` |
| D7: a definition fills itself from the game's `DEFENCE SHOW` (owner, 2026-10-09: `DEFENCES LIST` lists every defence GMCP reports; `DEFENCE SHOW <name>` gives `Defence: Name (gmcpname)`, `DefMsg`, `EnactMsg`, `FadeMsg`, `Profession`, `Strippable`) | done | `7221105` |
| D7: `vconfig customdef game` compares with `DEFENCE LIST` (paged with MORE); Profession No means every class, Yes asks which (owner, 2026-10-09); "There is no such defence." ends a fetch; the list of definitions links each, and vconfig2 links to it | done | `00c14bf` |
| D7: the alias is `vcustomdef`, and `vconfig customdef` is gone (user, 2026-10-10: easier to type) | done | `eb220b0` |
| new defect 28: hide choices for a class's skillsets forgotten on a class change and back; `vshow hidelist` listed a defence under another class's group (2018) | done | `56db41c` |
| defence groups in the class's order (`defences.group_order`), not `pairs()` | done | `39daea4` |
| D7: a class definition goes under one of its class's skillsets (user, 2026-10-10), or a typed one where svof's list is out of date; hidden state kept on reinstall | done | `3dd0229` |
| D7: serverside raises a definition with a GMCP name while serverside is on, svof otherwise (user, 2026-10-10); the `serverside` field is gone; delete or a new GMCP name tells the server; `notifypriodiffs` skips a removed action | done | `b8dbf76` |
| hiding takes a defence off defup and keepup in every mode, with undo (user, 2026-10-10); `vconfig showhiddendefs`; the general group's hide honoured in the lists (2018 no-op) | done | `f5d4c57` |
| changing svof's own defences (user, 2026-10-10: allowed, with a warning, minding logic-heavy ones): `vcustomdef <svof's name>` replaces exact lines, GMCP name, and the command where `basicdef` made the entry (`sendsaction`); a change replaces svof's lines (my recommendation; the user's go-ahead was "do both marks"); saved in `svo/custom/edits` by class or `all`; `was` says when an update changed it; first install confirms; reset; `wire_triggers` split out of `wire`; also fixes `vcustomdef` erroring with `customdefinitions` off at load | done | `10bdf55` |
| marks: `*` defined, `+` changed, in vshow defup/keepup, current and additional defences, both priority lists, vshow server, vshow hidelist, with a key and link hints (user, 2026-10-10: "do both marks") | done | `650525c` |
| DEF line and GMCP name (user, 2026-10-10): a missing DEF line warns, not refuses (some defences DEF doesn't list, such as bloodiedknife); `def none` sets `invisibledef` on a definition or a change; only a GMCP name the game confirms (DEFENCE SHOW, DEFENCE LIST, GMCP) is taken, otherwise refused with "check it or use none"; import checks against DEFENCE LIST | done | `1bd38ce` |
| outdated classes: which classes, and what changed (DEFENCE SHOW captures), to fix svof's own | asked the user | |
| DEFENCE LIST ends at the game's "There is no more, friend." whisper (user's capture) | done | `a70c841` |
| cross-class clash: at load, offer to make the definition a change to svof's own, or delete it (user, 2026-10-10); vshow links vcustomdef | done | `cc5dee6` |
| copies and clashes (user, 2026-10-10: refuse a name svof has in another class, offer svof's own instead, for artefacts like mindnet and shroud; "be very careful about conflicts"; artefact versions so far share the class version's GMCP name): `tools/defence_catalog.lua` writes `src/resources/defence_catalog.lua` (239 defences, 290 class versions; CI gate 1.96); `vcustomdef <name> copy` copies only plain send-and-track versions; `defences.clash` refuses a shared line, GMCP name or command on install and at every load; copy update notices | done | `5113cd2` |
| serverside adoption (user, 2026-10-11): `defences.register` maps a definition's, copy's or item defence's command into `sys.input_to_actions` (lower case, never over another action's), `unregister` takes it out | done | `825bd8f` |
| patterns (user, 2026-10-11): `gotpattern`, `lostpattern`, `defpattern` into a definition's `onr`/`offr`/`defr`, next to exact lines; rex must read them; clash checks patterns against other lines, other patterns against lines, and against the definition's own lines of another kind (pattern against pattern can't be checked); copies take svof's patterns as their own | done | `37698fb` |
| change patterns (user, 2026-10-11): `onr`/`offr`/`defr` are change fields, shown, edited, saved with `was`, reset and update-noticed like lines; clash and import checks | done | `ad0d1fa` |
| D2.3, D5 | not started | |
| `customaff` | waits on the affliction groundwork (main plan phases 1 to 3) | |

D3 changed the design in three places, all measured:

- `ongot`/`onlost` run from `defences.got`/`lost` themselves, on the
  change only, last and under pcall, so a consequence runs on every path,
  not only from `confirm`.
- `confirm` leaves blind and deaf to the prompt flags when nothing of
  svof's is in flight (`defences.prompt_decides`), rather than a third
  copy of the defence-or-affliction rule.
- `confirm` drops a claim a line already filed for the action it
  finishes, so the prompt does not finish it twice.

**Answers from the owner, 2026-10-09:**

- Game question 2b: the serverside name for caloric is insulation, the
  same as GMCP's. svof did not convert it: the real code sent "curing
  priority defence caloric 5". Of the 13 defences svof names differently
  from GMCP, only caloric and frost are ever sent; the other 11 are
  undeffable, which serverside skips. Fixed in `d2cecba`.
- The fire elemental class string is how GMCP sends it, like the air,
  water and earth ones ("fire Elemental Lord"). Not a defect.
- The game does not allow `[Curing]:` lines to be illusioned. So the gain
  gate lets a line through when the server's own command raised the
  defence (below).
- Anyone can buy the phylactery, a lifevision mask or a Shadowcloak, so
  the three item defences must work for every class. Checked in
  `9537ea2`: all 26 classes register all three, GMCP sets each, and a
  class change and back keeps them with the same live triggers (on the
  stack tip their triggers piled up, shroud's 5, 10, 15).

**The gain gate as built.** A claim that would raise a defence GMCP does
not list is dropped at the prompt; svof's own command stays in flight,
so GMCP's Add finishes it through `confirm` with its balance and puff,
or the outcome line does, or it times out. A claim the line made up is
cleared. Still counted: a command the server sent (`svo.curingcommand`
marks it `served`), a delayed defence's raise, blind and deaf, a GMCP
name the game has not sent this session (so a wrong mapping cannot
loop), and a second refusal of a separate command on a later prompt
within 30 seconds (the #858 loop breaker).

**Still open on the item defences:** a Serpent's GMCP `shroud` maps to
its own cloaking (`sstosvod.shroud`), so a Serpent with a Shadowcloak
has svof's shroud set only by its text line. Are the conjured cloak and
the Shadowcloak the same game defence?

What running the real code changed in this plan (all measured with
`tools/svof_world.lua`, which loads the 22 real loaders through
`svo_init_system` for any class):

- Every count in "Two tables" and the main finding reproduced exactly.
- **blind's GMCP gain is dropped whatever anti-illusion says**: its
  handler uses `checkany`, which never makes an action up. The other five
  are dropped only with anti-illusion on.
- **A GMCP rebounding alone never sets the defence**: it starts the wait,
  and only the aura's text line finishes it; without that line the wait
  times out as lag.
- **`apply caloric` is claimed by three actions** (caloric, frozen,
  shivering), and which one serverside adopts changes from run to run
  (defect 23). Pairs order differs between runs on Lua 5.4+.
- The Spirit channel has three dead handlers, not one: `got_spirit`,
  `got_boundspirit`, `got_fortifiedspirit` (the last two in inline json).
- New defect 21: susurrating's gain line ends in a space.
- Defect 3 is not a typo. Making the clumsy-transition line live would
  lose the new form too; what the game prints then is game question 12.
- Defect 15 is not safe to fix as written: losing every defence at
  relogin would also drop offline and stays-on-death defences, which
  `reset.defs` keeps on purpose. Game question 14.

This plan covers the defence half of making `svo.dict` the source of truth. It
replaces the defence steps of `single-source-implementation-plan.md` (2.4, 2.6,
3.1, 3.2, the defence half of 3.5, and `customdef` in Phase 4) and corrects
three of them. It also designs the queued "defences" PR from the GMCP-first
direction (`svof-gmcp-first-direction` memory), because both need the same
change underneath: separating "the game says you have it" from "svof's command
finished".

## How the claims here were checked

I read `Defences.lua` (3,952 lines) and the dictionary's defence half (lines
9,309 to 15,533) in full, plus every other file that reads or writes defence
state: `Setup.lua` (GMCP handlers, morph and stance tracking), `Curing_skeleton.lua`
(the balance checks, `fix_affs_and_defs`, the morph helpers), `Controllers.lua`
(prompt flags, priority display), `Action_system.lua`, `Serverside.lua`,
`Main_trigger_functions.lua` (the hand-written `svo.defs.*` handlers and
`defstrip`), `svo.classchange.lua`, `Alias_functions.lua` (`reset.defs`), the
14 defence aliases, and the 143 trigger items that call defence functions
(dumped with their patterns by a scratch script).

Three kinds of claim, kept apart:

- **Measured**: a count from a tool run today. `check_defs_data.py` and
  `check_basicdef_spec.py` (Cowork export) both run clean on this tip; 39 of 39
  claims pass.
- **Read**: a code path I traced line by line but have not run. Phase D0's
  harness has to confirm each one before anything changes.
- **Game**: a question only the repo owner or the game can answer.

---

## How defences work today

### Two tables, joined by name

| table | built in | answers | gated on |
|---|---|---|---|
| `svo.defs_data` | `Defences.lua`, loader `defences` (subsystem 16) | what the game prints: gain, loss and `DEF` lines, plus display and dragon flags | what you can *have* (78 of 317 names exist whatever the class) |
| `svo.dict[name]` | the dictionary, loader `dict` (subsystem 4) | how svof raises it: balance, `isadvisable`, `onstart`, `oncompleted` | what you can *raise* (16 of 134 `basicdef` names ungated) |

The 78 is measured by running the real data block under Lua twice, with every
skillset off and with every skillset on, and counting the names present both
times (scratch `defs/gating.lua`).

Measured: 317 record names from 396 `defs_data:set` calls (48 names are set
more than once under class gates), about 1,334 game-text patterns, 287 defences
with a dictionary entry (30 in the literal, 130 assigned, 134 from 157
`basicdef` calls). Every dictionary defence has a record. 30 records have no
entry: 28 are recognise-only on purpose (`nodef`, `invisibledef` or
`custom_def_type`), and `bedevil` and `evasion` are not.

The guide's argument for keeping the two tables apart holds, with a better
example than its own: `toughness` is recognised for everyone, as an additional
defence on `DEF`, and raised only by Shindo and Kaido, so one table would force
one gate on both halves. **This plan keeps the two halves and removes
everything that is written twice between them.**

### Four ways defence state changes

1. **Text lines.** A `systemstart` handler (`Defences.lua:3279`) walks
   `defs_data` and makes a temp trigger per pattern. Each calls a generated
   `svo.defs.got_<name>`, `lost_<name>`, `def_<name>` or `gotonly_<name>`.
   `got_` claims the entry's action through `checkaction` and files it with
   lifevision; `lost_` claims the `gone` action. 143 static trigger items call
   defence handlers too: strip lines call the generated ones, and the rest call
   hand-written handlers in `Main_trigger_functions.lua` for the defences that
   take more than one line (sileris, speed, dragonform, mace, viridian, blind
   and deaf by skill) or share their line with a cure (`gotherb_*`).
2. **GMCP.** `Char.Defences.Add`, `Remove` and `List` (`Setup.lua:1044-1096`)
   translate the game name through `svo.dict.sstosvod` and call
   `svo.defs.got_<name>(true)` or `lost_<name>()`.
3. **`DEF`.** `defcheck` sends it, each listed line calls `def_<name>`, and
   `svo.process_defs()` reconciles at the prompt.
4. **Prompt flags.** `check_promptflags` (`Controllers.lua:136`) sets and clears
   blind, deaf, kola, cloak and the `@` defences from the prompt itself.

### Where one defence's facts live

| place | what it holds | how many defences |
|---|---|---|
| `defs_data` record | lines, skillset `type`, flags | 317 |
| dictionary entry | how to raise it | 287 |
| `svo.dict.sstosvod` | GMCP name to svof name | 172 strings, 37 `false` |
| entry `gamename` | svof name to serverside name, read by `Serverside.lua:79,108` | 60: 29 hand-written entries and 32 `basicdef` calls, `grip` in both; 14 have no `sstosvod` entry |
| `svo.valid.defstrip` table | the game's display name in strip lines | 17, plus 10 behind class gates |
| `onenable`, `specialskip` and `isadvisable` of every member | mutually exclusive groups: stances, forms, morphs, the breath, meditate, dilation, lyre and flame web | 53 records carry an `onenable` |
| a `waitingfor` entry, hand-written `svo.defs.*` handlers and static triggers | defences that arrive some seconds after the command | 10, plus 2 cooldowns |
| `check_promptflags`, `fix_affs_and_defs`, `Custom_prompt.lua` | the prompt letter, and the affliction twin of blind, deaf and torch | 5 and 3 |

A typical class defence touches three or four of these. Names are the worst
case: one defence can be spelled four ways (record key, GMCP name, serverside
name, strip-line display name) in four tables.

---

## What the earlier documents get wrong

1. **`defs_data` is rebuilt on every init.** The main plan's 3.5 and the
   `svof-runtime-registration-machinery` memory say it is not cleared on a
   class change. It is: `Defences.lua:57` assigns `svo.defs_data =
   svo.pl.OrderedMap {}` inside the loader, and `svo.classchange` re-runs every
   loader. Runtime registrations survive only because `enablemindnet` and its
   two siblings re-run from `systemstart`. What persists is `svo.defs`, the
   handler table (`Setup.lua:116`, `svo.defs or {}`), which causes defect 16.
2. **The balance pick (guide 7e) is the wrong kind of fix.** "Prefer
   `physical`" keeps picking one balance for three callers that need
   different things. The GMCP and `DEF` callers need no balance at all (D3),
   and a text gain line should claim whichever of the defence's actions is in
   flight (D3.4). It also misses two cases: Shindo and Kaido give `blind` and
   `deaf` a second balance (`misc`), so five entries have more than one, not
   three.
3. **The GMCP path is not a thin translation.** Neither document noticed that
   a GMCP gain runs the raising action's `oncompleted`. That is the main
   finding of this pass, below.
4. **14 serverside names lack a GMCP mapping, not 15.** The guide's list (and
   `check_defs_data.py`) includes `cloaking`, which the class-dependent
   assignment after the literal (dictionary line 10885) maps. Both tools read
   the literal only, the same spelling trap the reference-docs memory
   describes. Counting hand-written entries as well, 60 defences carry a
   `gamename`, not 32.
5. **Six of the guide's ten "recognised for everyone, raised by some" are
   not.** Running the real block shows `breakthrough`, `comprehend`,
   `transcend` and `vanish` exist only with Psionics (their gate is written
   ` if svo.haveskillset('psionics')`, with a leading space the tool's parser
   misses), and `mindnet` and `shroud` exist without their skillsets only once
   `enablemindnet` or `enableshroud` registers them at runtime. The four real
   ones are `constitution`, `resistance`, `toughness` and `nightsight`, and
   `nightsight` is a different case again: the dictionary literal has an
   ungated `nightsight` entry (line 10428), so every class has a raising
   action for it, and Kaido's `basicdef` replaces it.

---

## The main finding: GMCP and `DEF` run svof's own command bookkeeping

Read, not run. `got_<name>(true)` is the generated handler with `force` set.
It force-adds the entry's action and calls `svo.actionfinished` at once, which
runs `oncompleted` with no argument. `oncompleted` is written for one
situation: svof sent the command and the game took it. So when the game
reports a defence svof did not just raise (at login, after a reload, raised
by another player, or by serverside), svof does the bookkeeping for a command
it never sent:

| defence (GMCP name) | what a GMCP gain does today |
|---|---|
| rebounding | restarts the 9 s rebounding wait (leaking the running timer), uses a skullcap puff, inserts "(N skullcap left)" into whatever line is current, and marks smoke balance spent |
| sileris (`fangbarrier`) | starts the 10 s sileris wait. With no hardening line to end it (at login), the timeout marks sileris `'unsure'` and warns "we might've been tricked" if it is on keepup, or leaves it unset if not, and counts a lag tick |
| caloric (`insulation`), mass (`density`) | marks salve balance spent |
| the five Zeal blessings | mark prayer balance spent |
| lay, tune, aria | mark voice balance spent |
| lyre (`prismatic`) | pauses svof when lyre mode is on |
| mindseye | marks you deaf (an `and`/`or` precedence slip, defect 12) |
| shield | turns shield keepup off when `oldts` is on |

Rebounding and sileris hit this even when svof raised them. Their GMCP gain
comes with the delayed arrival, after svof's smoke or apply action has
finished, so the force path finds nothing in flight and makes the action up
again. The old wait's timer is never killed: when it fires it counts a lag
tick, and if the new wait has not finished yet it deletes the new wait's
record. With serverside on, every defence the server raises takes this path:
the gain arrives before svof adopts the server's command, so the force path
makes the action up, and the adopted action then records the same work again
(see "When serverside raises the defence" below).

Six GMCP-mapped defences have hand-written `got_` handlers that ignore
`force`: blind, block, deaf, dragonbreath, speed and viridian. With
anti-illusion on (the default, `Setup.lua:1307`), each claims only an action
already in flight, so a GMCP gain of any of them is dropped unless svof was
raising it. With it off, `checkaction` makes the action up and the gain goes
through lifevision as a text claim would, except blind's, whose handler uses
`checkany` and is dropped either way (measured). `got_block(true)` also
passes `true` as the blocking direction.

`process_defs` has the same shape. For a defence `DEF` lists that svof did not
know about, it picks a balance with `pairs` and calls `oncompleted(true)`. A
`DEF` listing rebounding spends smoke balance, uses a puff and starts the
wait; a listing of blind (herb route) spends herb balance.

GMCP losses go the other way: `lost_<name>()` files the `gone` claim with
lifevision, so an illusion verdict on the paragraph discards a real GMCP loss.

This is why the GMCP-first defences PR cannot be a gate bolted onto lifevision
the way #858 was for afflictions. The paths have to be separated first.

---

## The target

### What a defence looks like at the end

Two halves, one name, nothing repeated between them:

```lua
-- Defences.lua: what the game prints, and the one game name
defs_data:set('chargeshield', {
  type     = 'elementalism',
  gamename = 'chargeshield',          -- GMCP and serverside; sstosvod is derived
  def      = "You are surrounded by a non-conducting chargeshield.",
  on       = {"You already have a chargeshield active.",
              "You call upon the powers of air and earth to weave a non-conducting energy shield around you."},
})

-- the dictionary: how to raise it (guide Step 8)
basicdef('chargeshield', {
  command  = "cast chargeshield at me",
  requires = {'air'},
})
```

Derived at `systemstart`, when both halves exist: `sstosvod`, `svotossd`,
the serverside name `Serverside.lua` reads, the `defstrip` map, and the
`onenable` and `specialskip` of every group member. These are already
derived there today: `def_types`, `sk.ignored_defences`, the defup and keepup
slots, the temp triggers and the handlers.

Three new declarations, each replacing a fact written many times:

- **`gamename` on the record**, not the entry. The record is the half every
  GMCP-reported defence has; 28 of them have no entry. The 45 defences that
  carry a `gamename` and also appear in `sstosvod` agree in all 45 (measured),
  so the GMCP name and the serverside name are one namespace as far as svof
  has ever used them.
- **`delayed = '<wait entry>'`** on a raising spec, for the 10 defences that
  arrive later. The constructor writes the `waitingfor` entry and records
  `defences.waits[name]`, which `confirm` and the GMCP gate read.
- **Exclusive groups**, declared once: `defences.incompatible(def, {...})`.
  `onenable`, `specialskip` and the `not defc.X` terms in `isadvisable` are
  generated from them. The relation is directed, because today's lists are not
  symmetric (see game question 7).

### Bookkeeping versus consequence

Every `oncompleted` and `gone` body splits into two kinds of statement, and
the split decides where each one lives:

- **Bookkeeping of svof's own command** (spending a balance, a pipe puff,
  starting a wait, pausing for a command, toggling keepup): stays in the
  action, and runs only when svof's action is really in flight.
- **Consequence of the state** (another defence comes or goes with it, an
  affliction is reclassified, a cooldown starts): moves to `ongot` or `onlost`
  on the record, and runs on every path, text, GMCP or `DEF`.

This is the defence twin of #858's `onadded`/`onremoved` work for afflictions.
Read so far, only a handful are consequences of a gain: `frost` and
`temperance` give each other for Metamorphs, and `mindseye` reclassifies blind
and deaf. Losses keep running the whole `gone` body, which is where most
consequences already are (dragonform takes breath and armour, vitality starts
its cooldown, lyre unpauses). The classification has to be done entry by
entry in D3.1, and its list goes in the commit message.

### Two functions in place of `got(true)` and `oncompleted(true)`

```lua
defences.confirm(name)    -- the game says you have it
defences.unconfirm(name)  -- the game says you don't
```

`confirm`: if svof is raising the defence (its wait, or one of its raising
actions, is in flight), finish that action now, outside lifevision, with the
`oncompleted(true)` convention `process_defs` already uses. Otherwise set the
defence with `defences.got` and run its `ongot`. For blind, deaf and torch,
route to the affliction twin by the rule `fix_affs_and_defs` already applies.
It never runs bookkeeping for a command svof did not send.

`unconfirm`: run the `gone` action's `oncompleted` directly, outside
lifevision, or `defences.lost` when there is no `gone`.

Callers: the three GMCP handlers, the leftover branch of `process_defs`, and
optionally `check_promptflags`. Text lines keep their lifevision claims.

### When serverside raises the defence

With serverside on, the server sends the raising command, not svof. svof
still sees it as its own action, read from the code:

1. Enabling serverside sends `curing reporting on` (`Config_system.lua:2078`),
   so the game prints each command it runs, such as `[Curing]: TOUCH CLOAK`.
2. The *Running a curing command* trigger passes that to `svo.curingcommand`
   (`Controllers.lua:1199`), which calls `cnrl.processusercommand` with
   `now` set.
3. If the lowered command is in `sys.input_to_actions`, svof starts that
   action with `doaction` while `send` is stubbed out. The action is in
   flight exactly as if svof had sent the command. `sys.input_to_actions` is
   built at `systemstart` from every entry's `eatcure`, `sipcure`,
   `smokecure`, `action` and `actions`.

**What the owner's login log shows (2026-10-08, serverside on).** The game
prints a `[Curing]:` line for every defence command, in letters and spaces
only: `OUTR KOLA`, `EAT KOLA`, `SIP FROST`, `INSOMNIA`, `APPLY SILERIS`,
`APPLY CALORIC`, `LIGHT PIPES`, `SMOKE SKULLCAP`, `TOUCH MINDSEYE`, `TOUCH
CLOAK`, `DEATHSIGHT`, `HYPERSIGHT ON`, `NIGHTSIGHT`. So the regex matches all
of them, and smoking names the herb, not a pipe.

**The GMCP gain arrives before the `[Curing]:` line.** In the paragraph where
the server raised nine defences, all nine `Char.Defences.Add` echoes come
first, then every `[Curing]:` line and its text. A single raise (cloak) shows
the same order. So when the gain arrives, the server's command has not been
adopted yet, and nothing is in flight. The path is:

1. GMCP gain: `confirm` finds nothing in flight and sets the defence, with no
   bookkeeping. Today the force path makes the action up and runs its
   bookkeeping here.
2. `[Curing]:` line: svof adopts the server's command as an in-flight action.
3. The game's text line claims that action, and at the prompt its
   `oncompleted` runs once: the balance and the puff are recorded there.

The bookkeeping is still recorded once, through the text path. Today it is
recorded twice for the salve and smoke defences: caloric spends salve balance
at the GMCP gain and again at the prompt.

Delayed defences go the other way round, because the gain comes seconds after
the command. For rebounding, the smoke line finishes the adopted smoke action
(one puff, smoke balance, the wait starts), and the GMCP gain at the aura
finishes the wait. Today that gain makes a second smoke action up instead.
**The log shows it:** "(0 malachite left)" is inserted twice, once on the
line before the prompt that finished the smoke, and again on the line just
before "Gained def rebounding" 9 seconds later. That is `sk.skullcap_smokepuff`
running twice for one smoke, along with a second smoke-balance loss nothing
in the game will undo, so svof waits out `ai_resetsmokebal`.

The gap is a server command svof does not adopt. Then the text line finds
nothing to claim, and only GMCP records the defence. That happens when:

- the command is not a key of `sys.input_to_actions`, because the server
  words it differently from svof. **Seen in the log:** the server sends
  `NIGHTSIGHT`, and svof's action is `nightsight on`, so nightsight is never
  adopted. Nightsight has no bookkeeping, so only GMCP sets it, today and
  with `confirm`. The fix is one more entry in its `actions` list;
- the key is shared. Several entries eat the same herb, and the map keeps
  whichever `pairs` visited last, so `eat kelp` can adopt the wrong action.

A balance the server spends on an unadopted command goes unrecorded with
`confirm`, where today the GMCP gain records it by accident. It matters only
for actions svof still does itself under serverside (`vshow server`), and the
game's refusal corrects svof through the `offbalance` handlers. D0.1 gets a
case for each order: gain before adoption, and adoption before a delayed gain.

---

## Phases

Each phase lands alone and reverts alone. Every commit regenerates
`tools/verify_baseline.json` when it changes script text, and none adds a
top-level item, so a structural finding means something went wrong.

### D0. Pin today's behaviour (tools only)

| step | what | gate |
|---|---|---|
| D0.1 | `tools/test_defences.lua`, in the extract-the-real-block style of `test_gmcp_reconciler.lua`: loads the real `defs_data` block under each class's skillsets, the real `systemstart` generator, the three GMCP handlers, `process_defs`, and the dictionary entries it exercises. Pins today's behaviour, including the defects above as explicit "today" expectations, so the commit that fixes one has to flip its expectation | 1.94 |
| D0.2 | Extend `check_valid_callsites.py` to the `svo.defs.*` family: hand-written definitions plus the generated names (`got_`, `lost_`, `def_`, `gotonly_` for every record, `def<type>start` for every `custom_def_type`). Today it checks `svo.valid.*` only, so a mistyped defence handler is invisible to every gate. Records the three known dead calls | 1.22 |
| D0.3 | `tools/check_defences.py`: a regex anchor or `\w` in an exact-match key (`on`, `off`, `def`, `on_only`), positional values in a record table, unbalanced quotes in a regex, every entry with a record, every record without an entry flagged `nodef`, `invisibledef` or `custom_def_type` (`bedevil` and `evasion` baselined) | 1.95 |

Each gate is proved by breaking it on purpose, the way 1.1 and 1.2 were.

### D1. Fix what would otherwise be copied into specs

One commit each. The first group is typos with no judgement in them; the
second changes behaviour and needs the owner's yes first.

**Typos:** defects 1 to 8 in the table below.

**Owner's call first:** defects 9 to 15. Game questions 5, 6 and 8 to 10
decide them.

### D2. One name per defence

| step | what | changes play |
|---|---|---|
| D2.1 | `gamename` on records; derive `sstosvod`, `svotossd` and the serverside name at `systemstart`; delete the hand-written `sstosvod` and the entries' `gamename`. Proved by a per-class test: the derived map equals today's string-valued `sstosvod` restricted to that class's records. The 37 `false` entries, which no code distinguishes from a missing key, become a documented list the checker reads | no |
| D2.2 | the 14 serverside names with no GMCP mapping, and `fury` (mapped to `false` though four classes raise it). svof starts reading GMCP for them | yes, game questions 2 and 3 |
| D2.3 | strip-line display names onto records as `strip = {...}`; `defstrip` derives its map | no, except `demon armour`, which starts working |

The subterfuge `shroud` special case (`sstosvod.shroud` set to `cloaking` or
`shroud` by class, dictionary line 10884) disappears: each class's record
carries its own `gamename`.

**Defences keep their svof names.** The affliction backlog renames svof
afflictions to GMCP names. Defence names are typed by players (`vkeep`,
`vdefup`), saved in `defup+keepup/`, and printed in every list, so a rename
breaks saved configuration and habits for no curing gain. `gamename` is the
whole cost of keeping them. Decision B below.

### D3. Separate the game's word from svof's command

| step | what | changes play |
|---|---|---|
| D3.1 | `defences.confirm`, `defences.unconfirm`, `defences.waits` (written by hand for the 10, derived in D5.2), dual routing, `ongot`/`onlost` on the records that need them | no, nothing calls them yet |
| D3.2 | the GMCP handlers call them | yes: fixes the side effects and the six dropped gains |
| D3.3 | `process_defs`'s leftover branch calls `confirm` | yes: a `DEF` listing stops spending balances |
| D3.4 | the generated text `got_` claims whichever of the defence's actions is in flight (`svo.checkany` over its raising balances and its wait), the way `gotherborskill_insomnia` already does. Removes the last two `pairs` picks | no, except the 5 multi-balance entries, which stop depending on `pairs` order |
| D3.5 | rebuild every generated handler on each `systemstart`, keeping a set of the names it generated so it never overwrites a hand-written one. Fixes defect 16 | only after a class change |

### D4. GMCP has the final word on defences

The queued "defences" PR. The design mirrors #858, on top of D3:

- `svo.gmcp_defs_live()`: a `Char.Defences.List` has arrived since login, and
  you are not in blackout. `svo.gmcp_def_reports(name)` reads `svo.gdefc`
  through the derived name.
- **Losses.** In `run_through_actions`, a `gone` claim for a defence GMCP
  still reports is dropped, with "Kept <def>: GMCP still reports it." under
  `gmcpdefechoes`.
- **Gains.** A claim that would set a defence GMCP does not report is dropped,
  unless it starts a `delayed` defence's wait. The GMCP `Add` arrives before
  the event's text (measured from the owner's rat logs for afflictions), and
  `confirm` has already finished svof's action, so a real gain line usually
  finds nothing left to claim. What the gate catches is an illusion of a gain
  line while svof is waiting.
- **Defences GMCP does not report** (stances, forms, morphs: `twoartsstance`,
  `tekurastance`, `shikudoform`, `morph` are all `false`) stay with the text
  and with `Char.Vitals`, as today.
- **Blackout.** `Char.Defences` stops too (owner, 2026-09-26). The text
  decides during blackout. After it, `gdefc` entries are marked unconfirmed
  until the next `List`, or an `Add` or `Remove` for that name, the way
  `sk.gmcp_unconfirmed` works for afflictions. Whether svof can ask for a List
  is game question 1.
- **Prompt flags** stay authoritative for their five, alongside GMCP.
- **Instructions set GMCP aside**, as on #858: `defences.got` and `lost` are
  used by players' scripts and stay direct.
- Docs go in the GMCP-first documentation pass already agreed.

### D5. Defences as data

The guide's Step 8, plus two constructors it does not have.

| step | what |
|---|---|
| D5.1 | `basicdef(name, spec)`, keeping the positional form; convert the 157 calls, byte-identical generated code |
| D5.2 | `delayed` writes the 10 wait entries and derives `defences.waits` |
| D5.3 | `incompatible` generates `onenable`, `specialskip` and the `isadvisable` excludes; a test checks every generated list against today's, pair by pair |
| D5.4 | convert the 175 written-out definitions by skillset, each batch proved by truth table (`check_basicdef_spec.py` is the template) |
| D5.5 | guide 7a (dead keys), the 7d comment, and 7b (`bedevil`, `evasion`, game question 4) |

The three defects the guide lists (shield's arm guard, four nil returns, ten
redundant disjuncts) are fixed by construction in D5.4.

### D6. The registration API

| step | what |
|---|---|
| D6.1 | `defences.wire(name, record)`, the body of the `systemstart` loop for one record, recording every trigger in `svo.defencetemptriggers` |
| D6.2 | `svo.register_defence(name, spec)` takes both halves in one spec; `enablemindnet`, `enablelifevision` and `enableshroud` are rewritten on it, which fixes their untracked and duplicated triggers, the always-false inventory guard, the double space in the phylactery name, and shroud's third line (all in the architecture map's defect list) |
| D6.3 | user definitions saved under `<profile>/svo/custom/defs` and re-registered on every `systemstart`, since `defs_data` and `svo.dict` are both rebuilt |

### D7. `vconfig customdef`

Unchanged from the main plan's Phase 4, built on D6.2, sharing its surface and
its line capture with `customaff`.

**The user's choices, 2026-10-09** (the command surface itself was settled by
the repo owner on 2026-09-22):

1. **Class.** Each definition says which class the defence belongs to, and
   the player can set it; when it is not set, the class they are in when
   they define it. (The option as offered also let a definition apply to
   every class, for an item defence.)
2. **Name clash.** A definition using a name svof already has for that class
   is refused, and svof's own defence is shown instead.
3. **GMCP name.** The player types it, as a field like the others. A wrong
   one cannot loop: the gain gate never refuses a name GMCP has not sent.
4. **Order.** `customdef` first; `customaff` reuses its surface once the
   affliction groundwork (the main plan's phases 1 to 3) is in.

### D8. Optional: put each skillset's two halves together

Once both halves are spec-shaped, each skillset's records and entries could
move into one place, file by file. That is 2,500 lines of game text moved
with nothing in play to gain, so it waits for the owner to want it.

---

## How this meets the affliction half

- **One registration shape.** `svo.register_affliction` and
  `svo.register_defence` take a spec, validate it, place it, re-run
  `dict_setup` inside a priority snapshot, and wire its lines.
- **One GMCP model.** For afflictions GMCP adds through `addaffdict` and
  consequences move to `onadded`/`onremoved`; for defences GMCP goes through
  `confirm`/`unconfirm` and consequences move to `ongot`/`onlost`. Both keep
  text claims for blackout and for what GMCP cannot report.
- **Shared gates.** `check_dict_fields.py` must learn any new flat field put
  on an entry (`delayed` is a string, so a field, not a balance). The `ongot`
  and `onlost` hooks live on records, which `dict_setup` never walks.
- **One dual case to keep straight.** blindness, deafness and insomnia arrive
  on both GMCP feeds. svof reads the defence feed only (`sstosvoa` maps all
  three to `false`); D3's dual routing keeps it that way.

## Where it fits in the queue

1. Stack 856 merges (after the play test).
2. The paragraph-copy lookback fix, as agreed. D0 and the typo half of D1 touch
   different files and can go alongside it.
3. D2.1 and D3, then D4: the defences PR. D2.1 first, so the GMCP code reads
   the derived names from its first commit.
4. D5 and D6, then D7 with `customaff`.

---

## Pre-existing defects found

"Map" means the architecture map already records it, and "memory" the
`svof-gmcp-first-direction` memory; the other 10 are new in this pass. All are
in the 2018 reference xmls.

| # | defect | where | effect | phase |
|---|---|---|---|---|
| 1 | `rest.off` carries a stray second string | `Defences.lua:1027` | "You rise from your rest..." never counts (map) | D1 |
| 2 | Kaido `boosting.onenable` sets `heartsfury` | `Defences.lua:1697` | enabling boosting adds heartsfury, not regeneration (map) | D1 |
| 3 | Shikudo forms put a regex in `off`, an exact-match key | `Defences.lua:1787-1822` | the "clumsily transition" line never clears the old form | D1 |
| 4 | Skirmishing `spinning.off` holds a regex | `Defences.lua:2135` | the loss line never matches | D1 |
| 5 | `croonmirror.offr` starts with a stray `"` | `Defences.lua:2511` | the loss line never matches | D1 |
| 6 | `fortifiedair` tests `defc.fortifiedwaterand` | dictionary 12692 | fortifying air last never grants `fortifyall` (map) | D1 |
| 7 | `bonding.gone` nested inside `physical` | dictionary 11565 | harmless, the default `gone` hides it (map) | D1 |
| 8 | `defstrip` maps "demon armour" to `demonarmour` | `Main_trigger_functions.lua:1079` | the record is `armour`, so the strip is dropped | D1 or D2.3 |
| 9 | `aria` applies `svo.dict.aria.salve`, which does not exist | dictionary 12402 | while deaf, every aria attempt raises and nothing is sung (map) | D1, game 5 |
| 10 | `drunkensailor` and `heartsfury` `isadvisable` precedence | dictionary 12327, 12341 | during defup the conflict, paralysis and doing checks are skipped | D1, game 6 |
| 11 | `lipread.specialskip` reads an undefined global `mindseye` | `Defences.lua:752` | defup finishes without waiting for lipread (map) | D1 |
| 12 | `mindseye.oncompleted` precedence | dictionary 10370, 10379 | marks you deaf, and blind with keepup, until the next prompt's flags. Likely seen in the owner's login log: the prompt after `TOUCH MINDSEYE` shows `db` before either was gained, and the next prompt drops them | D1 |
| 13 | `svo.defs.curedblind`, `cureddeaf` never defined | 3 active triggers | each raises on its line (map) | D1, game 8 |
| 14 | `svo.defs.got_spirit` never defined | Spirit channel trigger | raises; Spirit was Healing's (map) | D1, game 9 |
| 15 | the `relogin` handler collects `defc`, not the name | `Defences.lua:3239` | clears nothing, masked by `reset.defs` (map) | D1 |
| 16 | generated `got_`/`lost_` are made only when absent, and `svo.defs` survives a class change | `Defences.lua:3370,3425` | after a class change a stale `lost_X` can index a dictionary entry that no longer exists, and raise | D3.5 |
| 17 | GMCP gains run svof's command bookkeeping; six are dropped | `Setup.lua:1044-1096` | see the main finding | D3.2 |
| 18 | `DEF` leftovers run `oncompleted(true)` on a `pairs`-picked balance | `Defences.lua:3628` | balances spent, waits started | D3.3 |
| 19 | GMCP losses go through lifevision | `Defences.lua:3426-3431` | an illusion verdict discards a real loss (memory) | D4 |
| 20 | `dict_setup` stamps `name` and `sw` onto `sstosvoa` and `sstosvod` | dictionary 15110, 15178 | harmless today; goes when D2.1 removes the table | D2.1 |
| 21 | susurrating's gain line `"Susurrations already surround you. "` ends in a space | `Defences.lua:2401` | unless the game sends the space, the exact match never fires | D1, game 13 |
| 22 | `bedevil` and `evasion` have records, no entry and no recognise-only flag (guide 7b) | `Defences.lua` | shown as raisable in defup lists | D5.5, game 4 |
| 23 | a serverside command several actions share is adopted by whichever `pairs` visits last | dictionary 15483 | `APPLY CALORIC` can adopt shivering's cure | D3 or D5 |
| 24 | the server's `NIGHTSIGHT` is not a command svof adopts | nightsight's `action` | GMCP alone records it | D5 |
| 26 | `dict_setup` added a defence's `gone` while `pairs()` walked the entry | dictionary, `dict_setup` | undefined; on Lua 5.4 and later a balance could be left nameless until the prio import ran `dict_setup` again. Lua 5.1 skipped none | fixed `5238805` |
| 27 | `vconfig havemindnet on` called `enablelifevision` | `Config_system.lua:129` | owning the phylactery registered lifevision until svof next loaded | fixed `39078c1` |

The constitution line "determined to svo.assert your superior constitution" is
in the 2018 xml too: an old namespacing pass rewrote game text. It is game
text, so it wants the owner's confirmation of the real wording before an edit.

---

## Questions for the owner

### Game questions

1. Does `DEF` bring a `Char.Defences.List`, the way DIAGNOSE brings an
   affliction List? It decides how svof resyncs defences after blackout.
2. Does GMCP use the same names as the serverside names svof sends for these
   12: `psibreakthrough`, `psicomprehend`, `psitranscend`, `psivanish`,
   `cohesion`, `extrusion`, `fireshroud`, `mentalclarity`, `rupturesight`,
   `skysight`, `strata`, `tremorsense`? The owner's login log confirms the
   other two: GMCP sent `tempest` and `susurrating`, which svof echoed and
   could not map.
3. Does GMCP report `fury`? `sstosvod` maps it to `false`.
4. Can `bedevil` (Zeal) and `evasion` (Woodlore) be raised by a command?
5. What should aria do when you are deaf? The entry lists an epidermal cure and
   no salve route exists.
6. Should paralysis, a doing action or the other stance stop `drunkensailor`
   and `heartsfury` during defup, as they do during keepup?
7. Are these asymmetries real game rules: general lyre does not clear flame;
   Metamorph and Groves lyre do not clear dilation; the basilisk and wyvern
   lists do not clear flame while every other morph's does; flame clears
   every morph except basilisk and wyvern?
8. "Blessed sight returns to you." and "The sounds of the world gradually
   return to you." call handlers that never existed. Should they mark blind
   and deaf lost?
9. The Spirit channel was Healing's. Remove its trigger and the `not
   defc.spirit` terms?
10. The constitution gain line: is it "determined to assert your superior
    constitution"?
11. ~~With serverside on, does the game print a `[Curing]:` line for every
    defence command it sends, and in what form?~~ Answered by the owner's login
    log, 2026-10-08: yes, letters and spaces, `SMOKE SKULLCAP`, `EAT KOLA`. See
    "When serverside raises the defence".
12. Shikudo: after "You clumsily transition from the form of X into the
    form of Y.", does the game print Y's gain line too, or is that line the
    whole transition? It decides whether defect 3's fix loses every form or
    sets Y.
13. Is the line "Susurrations already surround you." sent with a trailing
    space (defect 21)?
14. After QQ and logging back in, which defences does Achaea keep? svof's
    relogin handler means to lose all but dragonform, but `reset.defs` keeps
    the stays-on-death ones and `offline_defence` ones are saved to survive
    a reload (defect 15).
15. Lipread: does it need mindseye, or does mindseye make it unnecessary?
    `lipread.specialskip` reads `not mindseye`, a global that never exists,
    so the intent cannot be read from the code (defect 11).

### Decisions

- **A.** Keep two halves joined by name (recommended), or merge recognition
  into the dictionary entry.
- **B.** Keep svof's defence names and carry `gamename` (recommended), or
  rename defences to GMCP names like the affliction backlog.
- **C.** Start D0 and the typo half of D1 alongside the paragraph fix, or
  after it.

---

## What no gate can see

- Whether `confirm` finishes the right action in play. D0's harness proves the
  code paths; the timing of GMCP against text needs a capture with real
  defence traffic, which `svof-live-testing/captures` does not have (six
  defence names in two fights).
- Whether a converted definition behaves the same in a fight. The truth tables
  prove the condition, not the action system.
- Serverside curing raising defences. No capture has it.
- The still-open `DEF` resync capture gap from `CLAUDE.md`.
