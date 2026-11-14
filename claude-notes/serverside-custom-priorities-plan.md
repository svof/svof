# Plan: custom serverside priorities

Written 2026-10-31, against `in-client-svof` at `6bd3c5e`. The game facts and
decisions are also in the `achaea-serverside-priorities` memory.

Progress, 2026-11-13:

- Step 0 is captured, step 1 needed no work, and step 2 is PR #915 (branch
  `serverside-custom-priorities`).
- Steps 3 to 8 are draft PR #916 (branch `serverside-custom-mode`, stacked
  on #915). Step 9, defences, is built in that branch's worktree
  (`C:\work\svof-serverprios`) and not committed yet.
- Step 10, the docs, is written on branch `serverside-custom-docs`, pushed
  with no PR. The owner holds every docs change until their tasks and the
  single-source plan are done, and then makes one big docs change, so this
  branch waits for that. Its base is #916 before step 9, so it needs a
  rebase first.
- Step 11, the live test, is owed, and needs asking first.

The code references in "What svof does today" are from the day the plan was
written, and the files have moved on since. "Built differently from the
plan" near the end lists where the code and the plan part ways.

## The problem

svof sends serverside one number per affliction, worked out from its own
priority lists, and the server only has 25 (26 means ignore). Combatants lose
control in three ways:

- **The numbers are squeezed.** `sk.sendpriorityswitch` sends an affliction's
  position in its own balance list and caps it at 25 (`Serverside.lua:69`).
  Defences, ignored entries, and uncurable entries use up positions too, so the
  user's herb list (69 entries, kola first) puts paralysis at 2, and every
  herb affliction from position 25 down lands on 25. The salve list (44
  entries) does the same. Herb has far more than 24 afflictions the server
  cures, so no automatic packing removes the pile. Which afflictions share a
  number is a judgment call.
- **In-game edits never stick.** The before-state starts blank at load
  (`Serverside.lua:36`), so the first sync re-sends every number.
  `vconfig serverside on` sends `PRIORITY RESET` (`Serverside.lua:503`), and a
  class change sends `curing priority reset` (`svo.classchange.lua:36`).
- **The defence numbers are svof's too.** The server keeps up whatever is on
  its defence list, and svof writes that list, numbers included, from its
  own keepup list and positions. Numbers set in game get overwritten the
  same way.

## Game facts (the user, 2026-10-31)

1. A herb cures a random one of the afflictions it can cure, bar rare cases.
   An affliction's number decides when its herb gets eaten, not which
   affliction the herb cures.
2. The server doesn't compare numbers across balances (the user's
   understanding, not tested).
3. Nobody knows how the server breaks a tie at one number. The user guesses
   the first one listed. Nothing in this plan relies on a tie.
4. Stack entries. The command is `curing priority unweavingmind2 6` and the
   confirmation is `You have set the 'unweavingmind(2)' affliction to the 6
   priority.` The list prints `unweavingmind(2)` inline among the names.
   `(2)` means exactly 2 stacks. The plain name is stack 1, and setting it
   doesn't touch stack entries. Every stackable affliction accepts them. A
   stack level the user never set uses the plain entry's number, and the
   list doesn't print it.
5. The game refuses an impossible stack:
   `curing priority unweavingmind9 6` gives `The unweavingmind affliction
   can only have up to 5 stacks.` AFFLICTION SHOW has no stack maximums, so
   this line is the only source.
6. `curing priority list` starts with `Your affliction curing priorities for
   the priority set normal:`, lists `N:  name, name, ...` for 1 to 26, wraps
   at the screen width (continuation lines have no number), and ends with
   `Affs with priority 26 are ignored.` It includes afflictions svof has no
   entry for, such as icebound, grievouswounds, and frostbite, at the game's
   defaults. It doesn't list every affliction: see fact 14.
7. svof cures latched itself on purpose.
8. The server keeps up every defence on its defence list. It has no defup of
   its own, which svof's comment at `Defences.lua:3004` also says.

### From the live run, 2026-11-09

The run sent each command from a test character with no svof installed. The
raw log is `serverprios-step0-2026-11-09.txt` in the local
`svof-live-testing/captures` folder.

9. The confirmation of a plain entry, and of 26, has the stack entry's form:
   `You have set the 'paralysis' affliction to the 3 priority.`
10. A batch prints one confirmation for each entry, in order. A refused entry
    prints its refusal in place, and the game still sets the entries after
    it.
11. The game doesn't refuse a stack number on an affliction that doesn't
    stack. `curing priority paralysis2 5` sets plain paralysis to 5 and
    confirms `'paralysis'`.
12. The game accepts `blind` and `deaf`, which svof sends, and confirms them
    as `'blindness'` and `'deafness'`. A confirmation's name can differ from
    the name sent.
13. The slowcuring list's header is `Your affliction curing priorities for
    the priority set slowcuring:`. A list's header names the set in use.
14. `curing priority reset` resets only the set in use, and clears that set's
    stack entries. The defaults put nothing at 26, with latched at 1 and
    impaled at 2. They don't list blindness or deafness at all, so the list
    can lack an affliction the server knows. A level with nothing on it
    prints as a bare `13:`. With no screen width set, no level wraps.
15. `curing priority defence list` prints `Your defence priorities for curing
    set normal:`, and then one `name : N` line for each defence on the list,
    with the name padded to a column. It has no footer. The run saw 12 and
    20 on it, and didn't probe the highest number.
16. A defence edit confirms `You have set the 'cloak' defence to the 3
    priority.`, one line for each entry of a batch. `curing priority defence
    cloak reset` prints the same line with 0, and takes the defence off the
    list.
17. The server acts at once on a defence put on its list, and a switch of
    curingset raises the defences on that set's list.
18. The list has 11 names svof has no action for: blindness, dazed, deafness,
    diminished, fratricide, frostbite, grievouswounds, icebound,
    internalbleeding, kkractlebrand, and stridulating.

## The user's choices, 2026-10-31

1. **A mode, `vconfig serverprios auto|custom`** (name to settle when
   building). `auto` is today's behavior.
2. **Custom mode owns the whole list**, for both curingsets, normal and
   slowcuring. Switching to custom starts from what the server has, so
   nothing changes until the user edits.
3. **Edits work both ways.** svof records edits made in game from the game's
   confirmation lines and from a parsed `curing priority list`, and sends
   edits made in svof to the game. svof never records its own override sends
   as the user's edits.
4. **Safety overrides stay.** Afflictions svof cures itself, and temporary
   ignores, go to 26 and get the user's number back afterwards.
5. **Tactical switches stay** (autoslick, `pva`, `avs`, `pvd`), as temporary
   changes to the user's numbers.
6. **Keepup and defup stay svof's in both modes.** `vkeep`, `vdefup`,
   `vshow keepup`, `vdefs`, and their toggles work as today, and svof still
   decides which defences are on the server's list. In custom mode, only the
   defence numbers are the user's.
7. **svof recognizes stack entries.** It never widens the user's per-stack
   choices: 26 on stack 1 with `(2)` at 6 is deliberate. svof sets every
   stack entry to 26 only when its reason covers the whole affliction.
8. **`vignore <aff>` covers every stack. `vignore <aff> <count>` toggles one
   stack**, in custom mode only. Anywhere else svof refuses it with a note that
   only serverside can ignore a single stack.
9. **svof's own curing keeps ignoring an affliction at every stack or none.**
   svof-side per-stack ignores and priorities were weighed and put off.
10. **`pva`, `avs`, and `pvd` survive a restart in custom mode**, as they do
    today. svof saves which ones are on and applies them again after login.
11. **At login, when the server's list and the table differ, svof shows the
    differences and asks.**
12. **svof's own list commands edit the server lists when `server` is the
    last word.** The user picks the slow set the same way as for svof's
    lists. Without `server`, the commands change only svof's lists.
13. **No `vupdate prios server`.** The game's `curing priority reset`, a
    switch to auto and back, and `vimportprio <name> server` cover its uses.
14. **A reset in game makes svof read the list again**, then send its
    overrides. The table takes the game's defaults.
15. **Parry stays out.** The server has no parry priorities, and
    `vp nextprio` stays as it is.
16. **Each defence mode has its own defence numbers.** A new mode starts from
    auto's numbers. The slowcuring set gets the same numbers as the normal
    set.
17. **`vp serveraffs` and `vp serverdefs` show the server lists**, and
    `vp serveraffs slowcuring` shows the slow set. There's no per-balance
    view, because the server's list doesn't group by balance. The edit
    commands keep `server` last.

## What svof does today (read in full)

- **The sync.** `sk.updateserversideprios` (`Serverside.lua:113`) diffs a
  before and after snapshot per balance, splits each balance's sorted list
  into afflictions, defences, and two disabled lists (`sk.splitdefs`,
  `Serverside.lua:256`), and sends each changed affliction its position
  (capped at 25) or 26. Positions keep their gaps because `splitdefs` sets
  removed entries to `nil` instead of removing them. Affliction and defence
  sends share this one pass. `sk.priochangecache` skips a send whose number
  svof already sent, but it can't see in-game edits.
- **Who cures what.** `svo.serverignore[action]` true means the server cures
  it, and nil or false means svof does. `sk.shouldignoreserverside`
  (`Serverside.lua:225`) is true when svof cures it, when it's in
  `svo.ignore`, when a defence is off keepup or defup, or when the
  dictionary's `onservereignore` says so. Every curing check skips an
  action the server cures (`Curing_skeleton.lua:178` and the matching line
  in the other nine checks), so svof's internal number for a server-cured
  affliction is only ever used to work out the server's number.
- **Runtime changes that reach the server**:
  - temporary ignores: `Sit.lua` and `Toggle_mediation.lua` (prone),
    `Sleep.lua` (sleep), the lovers and hoisted options
    (`Config_system.lua:1186`, `:1244`), extispicy (the dictionary,
    line 13523), and `vignore` (`Alias_functions.lua:69`)
  - `onservereignore` on afflictions: `blindaff` and `deafaff` while blind
    or deaf are on keepup or defup, and `ablaze` (burning) for fire
    elementals with torch
  - autoslick (`svo_autoslickprio.lua`), which moves asthma to the top of
    the herb list while slickness and asthma are both present and
    paralysis or impatience is above it
  - `pva`, `avs`, and `pvd`, which swap paralysis with asthma, slickness with
    impatience, and paralysis with darkshade in svof's herb list, through
    `svo.prio_swap` (`Controllers.lua:509`)
- **Not affliction numbers, so out of scope:** `shh` (`prio_makefirst` on
  `healhealth` in slow curing) and the health and mana mirror
  (`codepaste.serversideahealthmanaprio` sends `curing priority health` or
  `mana`).
- **The send path.** `svo.sendcuringprio` (`Curing_skeleton.lua:2509`)
  batches entries into one `curing priority a 1 b 2 ...` command per queue.
  The slow queue wraps its command in `curingset switch slowcuring` and,
  when not in slow curing, `curingset switch normal`. The normal queue
  didn't switch when this plan was written, so a normal-set change sent
  while `sys.sync` was true landed in the slowcuring set. #903 fixed that:
  `sendprionow` wraps a normal-queue command in `curingset switch normal`
  and back.
- **svof hides confirmations.** The `vconfig gagserverside` trigger deletes
  every line starting `You have set the` when `gagserverside` is on, which
  is the default. Set switches print `You will now cure using the normal
  set.` and `... the slowcuring set.`, and svof already matches both.
- **`vignore`** is a toggle with the alias regex `^vignore (\w+)$`. Every
  curing check tests `svo.ignore[i]` for any value at all.
- **svof's list commands** and their patterns:
  - `vp` and `vshowprios`: `^(?:vshowprios|vp) (\w+)$`
  - `vset`: `^vset (\w+) (\w+) (\d+)$`, which calls `svo.prio.insert`
  - `vswap`: `^vswap (\w+) (\w+) (\w+)(?: (\w+))?$`, which calls
    `svo.prio_swap`
  - `vswapslow`: `^vswapslow (\w+) (\w+)$`, which takes `action_balance`
    names such as `paralysis_herb`
  - `vexportprio`: `^vexportprio (\w+)(.*)$`
  - `vimportprio`: `^vimportprio(?: (\w+))?$`
  - `vcleargaps` and `vupdate prios`

  `vp nextprio ...` is a separate parry alias that shares the `vp` prefix.
  No dictionary action is called `server`.
- **A reset prints one line.** `curing priority reset` answers only `All
  your curing affliction priorities have been reset to defaults.`, which the
  gag trigger also matches.
- **Counted afflictions** (callers of `svo.updateaffcount`): the four
  humours, the three unweavings, the four fractures (skull, ribs, tendons,
  wrist), bleeding, crescendo, horror, paradox, pressure, and pyre, plus
  `ablaze` once #891 lands. The count lives at `svo.dict[name].count`, set
  from the GMCP level.
- **Defences.** `splitdefs` sends each keepup defence its position, and
  gives every defence the mode marks off `curing priority defence <def>
  reset`. Every mode marks each defence it doesn't use as off
  (`Defences.lua:3158`, `:3526`), so the server's list holds exactly the
  keepup defences. During defup, svof swaps the list to the mode's defup
  defences, and swaps it back on `svo done defup` (`Serverside.lua:761`).
  `vshow keepup` links to `CURING PRIORITY DEFENCE LIST` and says it's the
  same as svof's keepup list.
- **The keepup and defup toggles.** `vshow keepup` and `vshow defup` show a
  grid of toggles, three per row in fixed-width columns, that call
  `defs.keepup` and `defs.defup` (`Defences.lua:3041`, `:3098`). Keepup
  changes raise `svo keepup changed`, which the sync listens to. Defup
  changes raise `svo defup changed`, which nothing listens to, so a change
  during defup reaches the server only at the next sync.
- **Defences svof keeps for itself.** Defences the server can't raise
  (`undeffable`, such as metamorphosis morphs) and ones svof handles itself
  stay with svof. `onservereignore` takes blind and deaf off the server's
  list when a Shindo or Kaido skill raises them, and waterbubble for water
  elementals.
- **Defence modes.** svof saves them once per profile in
  `svo/defup+keepup/`, not per class, and each mode's lists can hold
  defences from every class. svof's defence order is shared by every mode,
  because it lives on the dictionary entries. A class change rebuilds the
  dictionary for the new class, so svof only uses that class's defences,
  and resets the server's affliction and defence lists
  (`svo.classchange.lua:34`).
- **The keepup commands:** `vkeep` (`^vkeep(?:up)? (\w+)(?: (\w+))?$`, a
  defence and then `on` or `off`), `vdefup`, `vshow keepup`
  (`^vshow(k| keepup| keep)$`), and `vdefs <mode>`.

## Design

### The table

`svo/config/serverprios`, loaded and saved like `serverignore`
(`Setup.lua:2333`):

```lua
{
  normal     = { ["paralysis"] = 2, ["unweavingmind(2)"] = 6, ["icebound"] = 1, ... },
  slowcuring = { ... },
  stackignore = { unweavingmind = { [2] = true } },
  toggles    = { pva = true },
  defences   = { combat = { ["cloak"] = 1, ... }, basic = { ... } },
}
```

Entries are keyed by the game's name, plus `(n)` for a stack entry, exactly
as the list prints them. The table keeps afflictions svof has no entry for,
so the whole list survives a reset. svof maps a game name to its own through
`svo.dict.sstosvoa` only when it needs to reason about one: for overrides
and warnings.

The table holds only what the game confirmed, never what svof sent. A
refused send leaves no trace.

### What svof reads from the game

- **The list parser** starts on the header, takes the set name from it, opens
  a level on each `N:` line, appends any other line to the open level (the
  wrap), and commits the whole set only when the footer arrives. A list
  that never finishes changes nothing. Tokens are `name` or `name(n)`.
- **The confirmation recorder** matches `You have set the '<entry>'
  affliction to the <n> priority.` and records it in the active set's table.
  It has to run before the gag trigger deletes the line.
- **The active set** follows the `You will now cure using the ... set.`
  lines. Achaea runs commands in the order sent, so a confirmation inside a
  `curingset switch` wrapper is credited to the right set.
- **The refusal line** clears any pending send for that entry, and svof
  passes the refusal on with context.
- **When svof asks for the list itself**, it hides the output and prints a
  one-line summary instead.
- **The reset line.** In custom mode, svof answers it by sending
  `curing priority list` and then its overrides, in one batch. Achaea runs
  commands in the order sent, so the list shows the game's defaults before
  any override lands, and the table records those defaults. The summary
  names the afflictions svof set back to 26, for example "Priorities reset to
  the game's defaults. svof re-read the list and set impale, lovers,
  selfishness, and latched back to 26." The table takes the defaults instead
  of sending the old numbers back, because the user asked for the reset. A
  reset affects only the set in use, so svof reads only that set, and the
  other set's table stays. Like the confirmation recorder, this has to run
  before the gag trigger deletes the line.

### Overrides

An override is a temporary number on one entry, with a reason. The number
sent is the override when one is active, else the table's. Overrides never
write into the table.

| Reason | Entries | Number |
|---|---|---|
| svof cures it (`serverignore` not true) | plain and every stack entry set | 26 |
| in `svo.ignore` (vignore, sitting, sleeping, meditating, hoisted, lovers, extispicy) | plain and every stack entry set | 26 |
| `vignore <aff> <count>` | that stack entry | 26 |
| `onservereignore` (blindaff, deafaff, ablaze) | plain and every stack entry set | 26 |
| `pva`, `avs`, `pvd` | the two entries | each other's numbers |
| autoslick | asthma, and paralysis or impatience if needed | see next |

A 26 override beats a tactical one. Among tactical overrides, the latest
wins.

**Autoslick in server numbers.** Lower is more important on the server, the
reverse of svof's lists. As today (`svo_autoslickprio.lua`, which moves
asthma above every other entry), asthma goes to the top: server number 1.
Whatever held 1 moves to 2, so the order never rests on a tie. Both are
overrides, so when autoslick ends, asthma and the entry it moved each get
the user's number back from the table (the user, 2026-11-07). The check
compares the server numbers of asthma, paralysis, and impatience instead of
`svo.prio.getnumber`.

**The echo-loop guard.** svof records each override as pending, per set and
entry, with the value it last sent. It records what actually went out, after
`sendcuringprio` (`Curing_skeleton.lua`) drops a repeat within the same
tick. Queueing `latched 26`, then 5, then 26 again sends
`curing priority latched 26 latched 5`, so the pending value for latched is
5, the last one sent, not the 26 queued after it. The guard keys a pending
entry by the name the game confirms, not the name svof sent: svof sends
`blind`, and the game confirms `'blindness'`. A confirmation that
matches the pending value clears it and goes no further. Any other
confirmation is the user's edit. A pending entry that no confirmation
clears within a few seconds is dropped, so a lost confirmation doesn't
leave the guard waiting. When svof reads the list while an override is
active, the table keeps its own value for that entry. Without this, svof
would record autoslick's `asthma 1` as the user's number, and asthma would
stay on top after the restore.

### Stack entries

- svof sends a stack entry as `name<n>` and reads it as `name(n)`.
- The number in force for an affliction at count `c` is the `name(c)` entry
  when set, else the plain entry.
- Whole-affliction 26s cover the plain entry and every stack entry in the
  table, and each gets its number back when the reason ends. Unset levels
  follow the plain entry, so they're covered too.
- svof never widens a 26 the user set on one stack entry.
- svof refuses a stack entry for an affliction it doesn't count, before
  sending anything. The game doesn't refuse one: it sets the plain entry
  instead.

### `vignore <aff> <count>`

- The alias regex becomes `^vignore (\w+)(?: (\d+))?$`. With a count, it
  toggles `stackignore[aff][count]` and the matching override.
- Per-stack ignores never go into `svo.ignore[aff]`. Every curing check
  tests that for any value, so it would become a whole-affliction ignore.
- svof refuses it, giving the reason, for:
  - not in custom mode
  - an affliction svof doesn't count
  - an affliction svof cures itself, since svof's own curing can't tell
    stacks apart
- The plain toggle and the per-stack toggles are separate. While the plain
  one is on, every stack is at 26. When it goes off, any per-stack ignores
  still set take effect again.
- `vshow ignore` lists per-stack ignores next to the plain ones, for
  example `unweavingmind (stack 2)`.

### Warnings

svof echoes each warning once per change, with a clickable fix:

- **Nothing cures it.** The server cures it, it isn't ignored, and every
  entry for it in the table is at 26.
- **svof cures it, but it has a number.** svof sends 26 anyway and says so.
  The table keeps the user's number for when the server cures it again.
- **svof's name isn't in the list.** An affliction in svof's dictionary that
  the server cures maps to no name in the list. That's a `gamename` or
  `sstosvoa` gap, not a new affliction, because the list includes every
  affliction the server knows.

### Defences

- **What's on the list stays svof's.** Keepup and defup decide which
  defences are on the server's list in both modes, exactly as today: svof
  swaps the list to the defup defences during defup, and back to keepup
  afterwards. The toggles in `vshow keepup` and `vshow defup`, and `vkeep`,
  `vdefup`, and `vdefs`, work as they do now.
- **The numbers are the user's in custom mode.** Whenever svof puts a
  defence on the server's list, it uses the user's number for that defence
  in the current mode instead of its own position.
- **One table of numbers per defence mode**, keyed by the game's defence
  names. Every mode's table covers every defence svof knows, so a toggle
  always has a number to use.
- **Where the numbers start.** Switching to custom fills the current mode
  from the server's defence list, and every other mode from auto's order.
  The server's list holds only the defences on keepup, so a defence it
  doesn't list, such as fly when it's off keepup, takes auto's number in
  the current mode too.
  svof's defence order is shared by every mode, so auto's number for a
  defence is the same in each. A custom defence created later gets auto's
  number in every mode.
- **The mode commands:**
  - `vcreate defmode` gives the new mode auto's numbers.
  - `vcopy defmode A TO B` copies A's numbers along with its lists.
  - `vrename defmode` and `vdelete defmode` rename or drop that mode's
    numbers.
- **Switching mode.** `vdefs <mode>` sends the numbers that differ between
  the two modes, along with the keepup changes, batched like any other send.
- **Both curingsets** get the same numbers.
- **Edits in game.** `curing priority defence <def> <n>` goes into the
  current mode's numbers. The confirmation is `You have set the 'cloak'
  defence to the 3 priority.` If the
  defence isn't on the current mode's keepup list, svof records the number
  but takes the defence off at its next sync, because keepup decides what's
  on the list. svof says so, with a link to run `vkeep <def>`.
- **Edits in svof.** `vset cloak defences 3 server` sets cloak's number in
  the current mode, with `defences` where `slowcuring` would go. Plain
  `vset cloak 3 server` can't do it, because the server uses `blindness` and
  `deafness` in both the affliction and the defence list. svof names the
  mode when it confirms, for example "cloak is 3 in combat mode". To edit
  another mode's numbers, switch to it first.
- **Showing them.** `vp serverdefs` shows the current mode's numbers, with
  the mode in the header. In custom mode, the "view serverside keepup" link
  in `vshow keepup` opens `vp serverdefs` instead of sending `CURING
  PRIORITY DEFENCE LIST`. The toggle grid stays as it is: its columns are
  fixed-width, and some entries already use the space after the name.
- **Defup toggles reach the server at once.** The sync starts listening to
  `svo defup changed` while defup runs, in both modes.
- **Unchanged:**
  - Defences svof keeps for itself: `undeffable` defences and ones svof
    handles itself stay off the server's list. The conditional ones (blind
    and deaf with a Shindo or Kaido skill, and waterbubble for water
    elementals) come off it while their condition holds.
  - Class changes: the sync already sends only the current class's
    defences, and now uses the user's numbers for them.
  - `curing defences on` and `off` still follow `conf.keepup`.

### Mode switches and resets

- **Auto to custom.** Read the normal list, then the slowcuring list (inside
  a `curingset switch` wrapper), then the defence list, and commit each.
  The defence list gives the current mode's numbers, and every other mode
  starts from auto's (see Defences).
  - The affliction lists still hold auto's 26s: for each affliction svof
    cures, each one svof ignores for now (such as prone while sitting), and
    each `onservereignore` one. Those aren't the user's numbers, so for
    each entry auto sent 26 for (`sk.splitdefs`' `disabledaffs`), the table
    takes auto's own number for it instead, the place svof's list gives it.
    Without this, restoring one later sends 26 again: run with
    `ignore.prone` set and `serverignore.latched = false`, `sk.splitdefs`
    gives `disabledaffs (sent 26): latched prone`. Then stop the affliction half of the
  sync, switch the defence half to the user's numbers, and apply the
  overrides. The overrides mostly match what auto already sent.
- **In custom:**
  - `updateserversideprios` sends no affliction numbers. It still puts
    defences on and off the server's list, with the user's numbers.
  - `vconfig serverside on` sends no `PRIORITY RESET`, and sends the table
    plus overrides instead.
  - A class change sends only the defence reset, which clears the old
    class's defences. The sync then puts the new class's defences on with
    the user's numbers.
- **At login in custom.** Read the affliction and defence lists once, and
  compare them with what svof expects on the server: the table plus the
  active overrides, saved toggles included. That way an active `pva`, or a
  26 for an affliction svof cures, doesn't show up as a difference. If
  anything else differs, show the differences, with one link to keep the
  server's numbers and one to send svof's.
- **Custom to auto.** Give every per-stack ignore its number back, clear the
  per-stack ignores, then run the full resync `vconfig serverside on` does
  today, which also gives the defences svof's positions again.
  That resync sends `PRIORITY RESET` (`Serverside.lua`) to the set in use
  only, and a reset clears that set's stack entries. So the switch says
  that the stack entries of the set in use are gone, that the other set's
  stay on the server because auto never touches them, and that switching
  back to custom sends them all again from the table.

### Commands for the server lists

svof's own list commands edit the server lists when the last word is
`server`. The user picks the slow set the same way as for svof's lists. The
server has one number per affliction, not one per balance, so the server
forms of `vset` and `vswap` take no balance. `vp` takes a list name
instead, and the defence numbers are covered in the Defences section.

| Normal set | Slowcuring set | What it does |
|---|---|---|
| `vp serveraffs` | `vp serveraffs slowcuring` | Shows the whole set, grouped by number like the game's list |
| `vset paralysis 3 server` | `vset paralysis slowcuring 3 server` | Sets one entry |
| `vswap paralysis asthma server` | `vswapslow paralysis asthma server` | Swaps two entries' numbers |

- **The display** shows stack entries and override marks, such as
  `26 (svof cures it)` and `1 (autoslick)`. The arrows move an entry up or
  down one number. On svof's lists they swap neighbors, but the server
  allows several afflictions on one number.
- **Stack entries** use the game's form: `vset unweavingmind2 6 server`.
- **Edits** go into the table when the game confirms them, like any other.
- **`vexportprio <name> server` and `vimportprio <name> server`** save and
  restore both server affliction sets and every mode's defence numbers, so
  one file holds a whole server setup. Import restores the numbers for the
  modes the user has, and says which modes in the file it skipped.
- **No per-balance view.** The server's list doesn't group by balance, so
  `vp` shows it whole.
- **Without `server`**, the commands change only svof's lists. In custom
  mode they remind the user that `server` at the end edits the server list.
  These commands work on list positions, so letting them reach the server
  would bring the squeeze back, and one `vimportprio` would overwrite the
  whole server list.
- **svof refuses `vcleargaps <balance> server`**: empty numbers on the server
  do no harm, because only the order between afflictions matters.
- **There's no `vupdate prios server`.** See choice 13.
- **In auto mode**, `vp serveraffs` and `vp serverdefs` show the numbers
  auto sends, marked as such. svof refuses server edits and points to
  `vconfig serverprios custom`.
- **Patterns.** `vp serveraffs` and `vp serverdefs` already match `vp`'s
  pattern, because `vp` takes a list name. `vp` widens only by an optional
  second word limited to `slowcuring`, which keeps it clear of
  `vp nextprio ...`, the parry alias. `vset`, `vswapslow`, and `vimportprio`
  widen to accept the server forms. `vswap paralysis asthma server` already
  matches `vswap`'s
  pattern, with `asthma` where the balance goes, so its handler checks for a
  trailing `server` first. No svof action is called `server`, so svof's own
  forms can't be mistaken for it. `vexportprio`'s `(.*)` already takes the
  extra word.
- **The `ss aff` column of `vp`** (`echoserver`, `Controllers.lua:1005`)
  shows the table's number in custom mode instead of the list position.

## Steps

0. **Captures.** Done in a live run on 2026-11-09: see "From the live run"
   in the game facts. Still unknown: the highest defence number, and how the
   server breaks a tie.
1. **Fix the normal-set send path.** Nothing to do: #903 already fixed it.
2. **Parser, recorder, and set tracker, with no behavior change.** Done in
   #915. `sk.serverread` holds what svof read, and
   `tools/test_server_priority_list.lua` tests it on captured lists and
   lines. Not checked in a real Mudlet: that the trigger still runs on a
   line the gag trigger deletes.
3. **Table, storage, the option, and the mode switches**, including the
   gates on the affliction sync, `PRIORITY RESET`, and the class-change
   reset. Done in #916, with the login check (choice 11).
4. **Overrides and the echo-loop guard**, safety reasons first, hooked to
   the events the sync listens on today (`Serverside.lua:754` to `761`).
   Done in #916.
5. **Tactical overrides**: autoslick in server numbers, `pva`, `avs`, `pvd`.
   Done in #916.
6. **Stack entries and `vignore <aff> <count>`.** Done in #916.
7. **Warnings.** Done in #916.
8. **The server forms of the list commands**, and the `ss aff` column.
   Done in #916.
9. **Defences**: the per-mode numbers and the mode command hooks,
   `vset <def> defences <n> server`, `vp serverdefs`, the keepup link, and
   the `svo defup changed` listener. Built, not committed yet.
10. **Docs** for the option, `vp serveraffs` and `vp serverdefs`, the
    `server` forms of the list commands, and the `vignore` count. Written
    on branch `serverside-custom-docs`, held for the owner's one big docs
    change.
11. **Live test** in `muddlertest`, after asking. Owed.

## Built differently from the plan

Decided with the owner while building, 2026-11-09 to 2026-11-13:

- **The game's names.** An affliction's server name is its `gamename`, else
  the name GMCP reports it by (`svo.dict.svotossa`). One with neither is
  svof's own and has no server priority, so no flag is needed: paradox (a
  Depthswalker condition svof tracks as an affliction), hoisted, insomnia,
  and lust (svof's `lovers` action, which the game handles with `CURING
  REJECTION`) are left out this way. sleep goes out as sleeping. A GMCP name
  doesn't prove a priority: 12 afflictions svof cures itself, such as galed
  (airfisted), have GMCP names and aren't on the captured list.
- **The pending-send guard** keeps every number svof sent until the game
  confirms it, and a send nobody confirms stops waiting after 60 seconds.
  Defences have their own pending table, since blindness is both.
- **Tactical overrides** never go into the table. `svo.serverprios.toggles`
  keeps `pva`, `avs`, and `pvd` in the order they went on, and a later swap
  moves what the earlier ones left.
- **`vignore <aff> <count>`** works in custom mode only (choice 8), refuses
  stack 1, and refuses an affliction svof cures itself. A stack entry svof
  creates for an ignore is kept in `svo.serverprios.made` and follows the
  plain entry's number afterwards, because the game can't remove one.
- **Warnings.** "Your number is kept" fires only when the player sets a
  number in game, not for auto's numbers taken at the switch. "Not on the
  game's list" fires once a session, and doesn't say the name is wrong.
- **`vset` server forms.** `vset <name> <number> server` sets a defence or
  an affliction by its name. A name the game's list or svof's names have as
  an affliction is the affliction: blindness, deafness, and retribution are
  both, and the reply says how to set the defence. `defence` or
  `affliction` before the number settles it, and the plurals work too. The
  docs show only the plain forms.
- **Defence numbers** go from 1 to 25, since the game's highest is unknown. A
  defence with no number of the player's in a mode has svof's own order, so
  a new mode starts with none. The defence list has no footer, so its read
  ends at the prompt or the first line that isn't the list's.
- **`vexportprio <name> server`** writes its own small Lua tables to
  `svo/serverprios/<name>`, not through `pl.pretty`.

## Gates and tests

- New and changed items need the baseline regenerated in the same commit
  that causes the difference. That includes the new triggers and the
  widened patterns of `vignore`, `vp`, `vset`, `vswapslow`, and
  `vimportprio`.
- New `.lua` files need their json entries (`check_src_tree.py`).
- The parser and override tests run in plain Lua, extracting the real code
  the way `test_gmcp_reconciler.lua` does, and go into both `build.yml` and
  `gates.sh`.
- `tools/svof_world.lua` can run the real loaders for the override logic.

## Not in this plan

- svof-side per-stack ignores and priorities (put off by the user).
- svof holding its own cures while the server has a more important
  affliction on the same balance. Today svof races the server for the
  balance in both modes. This is its own change, and auto mode would gain
  from it too.
- Auto mode packing. Two quirks are left as they are: positions keep their
  gaps, and slickness is on both the herb and smoke lists but has one server
  number. Custom mode has neither problem.

## Open questions

None.
