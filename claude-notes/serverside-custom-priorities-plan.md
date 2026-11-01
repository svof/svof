# Plan: custom serverside priorities

Written 2026-10-31, against `in-client-svof` at `6bd3c5e`. No branch yet. The
game facts and decisions are also in the `achaea-serverside-priorities`
memory.

## The problem

svof sends serverside one number per affliction, worked out from its own
priority lists, and the server only has 25 (26 means ignore). Combatants lose
control twice:

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
  `vconfig serverside on` sends `PRIORITY RESET` (`Serverside.lua:496`), and a
  class change sends `curing priority reset` (`svo.classchange.lua:36`).

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
5. The game refuses an impossible stack: `curing priority unweavingmind9 6` gives
   `The unweavingmind affliction can only have up to 5 stacks.` AFFLICTION
   SHOW has no stack maximums, so this line is the only source.
6. `curing priority list` starts with `Your affliction curing priorities for
   the priority set normal:`, lists `N:  name, name, ...` for 1 to 26, wraps
   at the screen width (continuation lines have no number), and ends with
   `Affs with priority 26 are ignored.` It lists every affliction the server
   knows, including the ones svof has no entry for (icebound, grievouswounds,
   frostbite) at the game's defaults.
7. svof cures latched itself on purpose.

## The user's choices, 2026-10-31

1. **A mode, `vconfig serverprios auto|custom`** (name to settle when
   building). `auto` is today's behavior.
2. **Custom mode owns the whole list**, for both curingsets, normal and
   slowcuring. Switching to custom starts from what the server has, so
   nothing changes until the user edits.
3. **Edits work both ways.** svof records edits made in game from the game's
   confirmation lines and from a parsed `curing priority list`. Edits made in
   svof are sent to the game. svof never records its own override sends as
   the user's edits.
4. **Safety overrides stay.** Afflictions svof cures itself, and temporary
   ignores, go to 26 and get the user's number back afterwards.
5. **Tactical switches stay** (autoslick, `pva`, `avs`, `pvd`), as temporary
   changes to the user's numbers.
6. **Defences stay svof-managed** in both modes.
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
    lists.
    Without `server`, the commands change only svof's lists.
13. **No `vupdate prios server`.** The game's `curing priority reset`, a
    switch to auto and back, and `vimportprio <name> server` cover its uses.
14. **A reset in game makes svof read the list again**, then send its
    overrides. The table takes the game's defaults.
15. **Parry stays out.** The server has no parry priorities, and
    `vp nextprio` stays as it is.

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
    line 13294), and `vignore` (`Alias_functions.lua:69`)
  - `onservereignore` on afflictions: `blindaff` and `deafaff` while blind
    or deaf are on keepup or defup, and `ablaze` (burning) for fire
    elementals with torch
  - autoslick (`svo_autoslickprio.lua`), which moves asthma to the top of
    the herb list while slickness and asthma are both present and
    paralysis or impatience is above it
  - `pva`, `avs`, and `pvd`, which swap paralysis with asthma, slickness with
    impatience, and paralysis with darkshade in svof's herb list, through
    `svo.prio_swap` (`Controllers.lua:486`)
- **Not affliction numbers, so out of scope:** `shh` (`prio_makefirst` on
  `healhealth` in slow curing) and the health and mana mirror
  (`codepaste.serversideahealthmanaprio` sends `curing priority health` or
  `mana`).
- **The send path.** `svo.sendcuringprio` (`Curing_skeleton.lua:2453`)
  batches entries into one `curing priority a 1 b 2 ...` command per queue.
  The slow queue wraps its command in `curingset switch slowcuring` and,
  when not in slow curing, `curingset switch normal`. **The normal queue
  never switches**, so a normal-set change sent while `sys.sync` is true
  lands in the slowcuring set. Pre-existing, found while reading this, not
  checked live.
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

## Design

### The table

`svo/config/serverprios`, loaded and saved like `serverignore`
(`Setup.lua:2121`):

```lua
{
  normal     = { ["paralysis"] = 2, ["unweavingmind(2)"] = 6, ["icebound"] = 1, ... },
  slowcuring = { ... },
  stackignore = { unweavingmind = { [2] = true } },
  toggles    = { pva = true },
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
  of sending the old numbers back, because the user asked for the reset. If
  step 0 shows a reset affects only the active set, svof reads only that
  set. Like the confirmation recorder, this has to run before the gag
  trigger deletes the line.

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
reverse of svof's lists. The check compares the server numbers of asthma,
paralysis, and impatience instead of `svo.prio.getnumber`. To move asthma
above both, it gets one less than the lower of the two numbers. When that
lower number is already 1, asthma gets 1 and whichever of the two is at 1
moves to 2, so the order never rests on a tie.

**The echo-loop guard.** svof records every override send as pending, per
set and entry. A confirmation that matches a pending send clears it and
goes no further. Any other confirmation is the user's edit. When the list is
read while an override is active, the table keeps its own value for that
entry. Without this, autoslick's `asthma 1` would be recorded as the user's
number, and asthma would stay on top after the restore.

### Stack entries

- svof sends a stack entry as `name<n>` and reads it as `name(n)`.
- The number in force for an affliction at count `c` is the `name(c)` entry
  when set, else the plain entry.
- Whole-affliction 26s cover the plain entry and every stack entry in the
  table, and each gets its number back when the reason ends. Unset levels
  follow the plain entry, so they're covered too.
- svof never widens a 26 the user set on one stack entry.

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

### Mode switches and resets

- **Auto to custom.** Read the normal list, then the slowcuring list (inside
  a `curingset switch` wrapper), commit each, then stop the affliction half
  of the sync and apply the overrides. The overrides mostly match what auto
  already sent.
- **In custom:**
  - `updateserversideprios` keeps sending defences and sends no affliction
    numbers.
  - `vconfig serverside on` sends no `PRIORITY RESET`, and sends the table
    plus overrides instead.
  - A class change sends only the defence reset, since the comment there
    is about class defences.
- **At login in custom.** Read both lists once and compare them with what
  svof expects on the server: the table plus the active overrides, saved
  toggles included. An active `pva` or a 26 for an affliction svof cures is
  then not reported as a difference. If anything else differs, show the
  differences, with one link to keep the server's numbers and one to send
  svof's.
- **Custom to auto.** Give every per-stack ignore its number back, clear the
  per-stack ignores, then run the full resync `vconfig serverside on` does
  today. Say that any stack entries the user set stay on the server, since
  auto never touches them.

### Commands for the server lists

svof's own list commands edit the server lists when the last word is
`server`. The user picks the slow set the same way as for svof's lists. The server
has one number per affliction, not one per balance, so the server forms of
`vset` and `vswap` take no balance.

| Normal set | Slowcuring set | What it does |
|---|---|---|
| `vp server` | `vp slowcuring server` | Shows the whole set, grouped by number like the game's list |
| `vp herb server` | `vp slowcuring herb server` | Shows only the afflictions one balance cures, in server order |
| `vset paralysis 3 server` | `vset paralysis slowcuring 3 server` | Sets one entry |
| `vswap paralysis asthma server` | `vswapslow paralysis asthma server` | Swaps two entries' numbers |

- **The display** shows stack entries and override marks, such as
  `26 (svof cures it)` and `1 (autoslick)`. The arrows move an entry up or
  down one number. On svof's lists they swap neighbors, but the server
  allows several afflictions on one number.
- **Stack entries** use the game's form: `vset unweavingmind2 6 server`.
- **Edits** go into the table when the game confirms them, like any other.
- **`vexportprio <name> server` and `vimportprio <name> server`** save and
  restore both server sets.
- **Without `server`**, the commands change only svof's lists. In custom
  mode they remind the user that `server` at the end edits the server list.
  These commands work on list positions, so letting them reach the server
  would bring the squeeze back, and one `vimportprio` would overwrite the
  whole server list.
- **svof refuses `vcleargaps <balance> server`**: empty numbers on the server
  do no harm, because only the order between afflictions matters.
- **There's no `vupdate prios server`.** See choice 13.
- **In auto mode**, `vp server` shows the numbers auto sends, marked as
  such. svof refuses server edits and points to `vconfig serverprios
  custom`.
- **Patterns.** `vp`, `vset`, `vswapslow`, and `vimportprio` widen to accept
  the server forms. Widening `vp` must not catch `vp nextprio ...`, the
  parry alias. `vswap paralysis asthma server` already matches `vswap`'s
  pattern, with `asthma` where the balance goes, so its handler checks for a
  trailing `server` first. No svof action is called `server`, so svof's own
  forms can't be mistaken for it. `vexportprio`'s `(.*)` already takes the
  extra word.
- **The `ss aff` column of `vp`** (`echoserver`, `Controllers.lua:982`)
  shows the table's number in custom mode instead of the list position.

## Steps

0. **Captures still owed.** These need a live game, so ask before each run:
   - the confirmation for a plain entry, and for 26
   - whether a batched `curing priority a 1 b 2` prints one confirmation per
     entry, and what happens to the rest of a batch when one entry is
     refused
   - the reply to a stack on an affliction that doesn't stack, such as
     `curing priority paralysis2 5`
   - whether `curing priority reset` and `PRIORITY RESET` clear stack
     entries, and whether they reset only the active set
   - the slowcuring list's header
1. **Fix the normal-set send path** (its own PR, off `in-client-svof`). Wrap
   normal-queue sends in `curingset switch normal` and back while
   `sys.sync` is true. Check live first that the bug happens.
2. **Parser, recorder, and set tracker, with no behavior change.** Test them
   in plain Lua with the user's two pasted lists as fixtures. Map every name
   through `sstosvoa` and list the ones that don't map.
3. **Table, storage, the option, and the mode switches**, including the
   gates on the affliction sync, `PRIORITY RESET`, and the class-change
   reset.
4. **Overrides and the echo-loop guard**, safety reasons first, hooked to
   the events the sync listens on today (`Serverside.lua:747` to `754`).
5. **Tactical overrides**: autoslick in server numbers, `pva`, `avs`, `pvd`.
6. **Stack entries and `vignore <aff> <count>`.**
7. **Warnings.**
8. **The server forms of the list commands**, and the `ss aff` column.
9. **Docs** for the option, the `server` forms of the list commands, and
   the `vignore` count.
10. **Live test** in `muddlertest`, after asking.

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
- Custom defence priorities.
- Auto mode packing. Two quirks are left as they are: positions keep their
  gaps, and slickness is on both the herb and smoke lists but has one server
  number. Custom mode has neither problem.

## Open questions

None. The last one, which number an unset stack level uses, is answered in
game fact 4.
