# Custom defences: live test on muddlertest, 2026-10-18

Build tested: `defences-single-source` at `749d309` (svof 66), installed into
the `muddlertest` profile (Achaea, Magi) in Mudlet 5.0.1. Seven sessions, each
logged in with the profile's saved login and quit with QQ. svof stayed paused
except in short defup trials, in a defence mode of its own (`probe865`).
Afterwards svof was uninstalled and the profile's `svo/` folder and name
database were restored from a checksummed backup (30 of 30 files match).

Test definitions used: `arcaneshield` (from the game, every class),
`potentiate` (from the game, a profession's, under a typed skillset
`testing`), `moontest` (GMCP `moontattoo`), `probealpha` and `probebeta`
(fake, commands `ql` and `score`), `acrobatics` (a copy of the Bard's),
`importok` (from an imported file).

## Problems found

1. **A session with `vconfig customdefinitions off` loses your definitions'
   priorities.** svof saves priorities as it quits, and with definitions off
   they aren't in the list, so the save has no entry for them. When they come
   back they start at the bottom: probealpha was 176 before, 4 after. Changes
   to svof's own keep their order. Either keep the saved entries of actions
   svof doesn't have this session, or say so when turning it off.

2. **Under lag, a late DEFENCE SHOW reply goes into the wrong definition.**
   The game lagged 60 to 90 seconds in session A. svof's fetch for
   arcaneshield timed out, and its reply arrived during the fetch for
   moontest, which took arcaneshield's lines. svof takes the next reply
   whatever defence it names. A reply whose keyword doesn't match what was
   asked could be dropped (the game's own spelling still needs allowing for,
   as in "Tremor sense (tremorsense)"). In the same lag, the rest of a timed
   out DEFENCE LIST arrived later and showed on screen, ungagged.

3. **`vcustomdef game` lists defences svof has for other classes as ones it
   doesn't know.** skysight is listed, and clicking it rightly offers to copy
   the Air Elemental's. The list could show those apart, as ones to copy.

4. **A defence under "Svof knows these, but leaves them alone" may not be
   definable as the game describes it.** moontattoo's DEF line is one svof's
   own moon tattoo already watches, so the definition is refused as a clash
   (correctly). With `def none` it installs, and GMCP marks it up at login.
   The list could say so.

5. **svof's efreeti is out of date.** The game now prints, on summoning,
   "You channel Fire and calescence consumes your surroundings ..." and, with
   one out already, "You have already called up a fiery efreeti." Neither is
   one of svof's lines, so on defup svof re-sent the summon every 0.7 seconds
   (5 times in 6 seconds). With your command and those two lines in a change,
   svof sent it once, saw efreeti up and finished the defup. This wants fixing
   in svof's dictionary.

6. **waterweird's command can't be changed**, as designed: its action is
   written by hand and also needs the water channel. Its command, `cast
   waterweird at me`, is probably out of date too; not raised live, as it
   needs the channel open.

## What works

**Hiding.** `vshow hidelist` with clickable names and the command line forms;
`vshow hide` and `unhide` for a defence, a skillset, another class's skillset
(`tekura`, shown as "Tekura (Monk)" in `vshow hidelist all`) and another
class's defence (acrobatics, hidden in both its skillsets). Hiding takes a
defence off defup and keepup in every mode, the undo link puts it all back,
and showing it again doesn't. `vconfig showhiddendefs` lists hidden ones;
`vshow` counts them; `svo.ignoreskill` still works; an unknown name is
explained. Hidden state survives a relaunch, and a hidden definition is left
out of `vshow defup`.

**Defining from the game.** DEFENCE LIST read whole (279 defences, 68 unknown
to svof) when the game isn't lagging. DEFENCE SHOW fills a definition's gain,
loss and DEF lines and GMCP name; "Profession: No" makes it every class's and
"Yes" asks which class, with a link for each. A typed skillset gets its own
group after the class's. Installed definitions take their GMCP name, are left
to serverside once serverside is on, and drop out of the game list. An unknown
GMCP name is refused. GMCP marks a definition up at login (moontest).

**Changing svof's own.** efreeti: command `elemental summon efreeti`, skillset
Artificing, two new gain lines; shown with `+` and Svof's own beside each
change; install asks first; raised live. waterweird moved to Artificing.
nightsight: command, skillset, class, unknown GMCP name and a bad pattern each
refused with the reason; loss line, gain pattern and `def none` installed,
then reset. treewatch: command and gain pattern raised and seen up live, then
reset. A change for another class (Monk's mindcloak) is kept, not used.

**Gain lines.** A definition's line and a change's pattern mark the defence
up when they arrive in the reply to its own command, typed or sent by svof. A
gain line with no command before it doesn't count (svof's protection against
illusions).

**Copies.** acrobatics copied from the Bard with svof's command and GMCP name;
accursedresolve refused with its reason.

**Clashes.** A shared gain line, svof's own GMCP name, a command svof takes for
another action, and a pattern matching another defence's line are all
refused. A real one turned up too: arcaneshield was refused while moontest
held arcaneshield's lines from the lag.

**Priorities.** Definitions appear in `vp physical` with `*` and the key; a new
one goes in at the bottom and the others' numbers shift up by one, order
kept. `vset`, `vswap`, `vexportprio` and `vimportprio` work on them. Defup
raises the higher priority first, and the other one first after `vswap`
(live, both ways). Priorities survive a relaunch (except item 1).

**Export and import.** Export to the default and a named file, with
definitions and changes. Importing a made file left out a definition with a
GMCP name the game doesn't have, installed the good one, added and used a
change to svof's own, and kept another class's. Importing again says what's
there already. Deleting a definition and resetting a change, then importing
the export, brings both back, the change with its new lines. A missing file
and a broken one are explained.

**`vconfig customdefinitions`.** Off: no definitions or changes in play after
a relaunch, saved files kept, the menu says it's off and the changes aren't in
use. On again: all back.

**Cleanup through svof's commands.** Every delete, reset, the other class's
change, unhide and the test mode's removal worked; the menu ended empty.

## Checks by session

| Session | Checks | Passed | Failures |
|---|---|---|---|
| A, everything | 136 | 112 | 13 from the game's lag, 6 wrong expectations of mine, 5 from my test timing |
| A2, redone | 45 | 30 | the stale moontest from A (clash), my timing, the efreeti lines (item 5) |
| A3 | 32 | 30 | my timing |
| B, relaunch | 34 | 32 | my test's feed looped |
| C, definitions off | 20 | 20 | |
| D, back on, cleanup | 33 | 30 | item 1 |

## Cost in the game

Session A2's defup trials kept blind and deaf up in the test mode, which ate 1
bayberry and 1 hawthorn. efreeti was summoned once. Otherwise only `ql`,
`score`, `look`, `def`, DEFENCE LIST and DEFENCE SHOW were sent.

## A correction

Earlier I said the profile's `vshow server` had blind and blindaff left to
svof. It's the other way round: `serverignore[name] = true` means serverside
handles it (`Serverside.lua:228`). The earlier fight over blindness came from
svof's serverside being off while the game's own curing was on, and my turning
keepup off.
