# Task list

Last updated 2026-10-20: moving vcustomdef into a script of its own, after
#866 merges. Before that, 2026-10-18: efreeti and waterweird added for the batch of outdated
class defences. Before that, 2026-10-08: the defence half of the single-source work planned in
`defences-single-source-plan.md`, item below. Before that, 2026-10-05: the
paragraph-copy fix for the lookbacks agreed and
queued after the stack merge. Before that, 2026-10-04: the in-flight note below rewritten for #861 and
the review fixes, then for #861's tension, pear and hellsight commits and for #862 and #863. Before that, 2026-10-02: #859 and #860 added to stack 856. Before that, 2026-09-25: the burning item added and then ordered (entry keeps
the name `ablaze`), the Bard earworm and crescendo triggers landed on #855 as
`17e407c` and `3eccccc`, with the `verify_merged` pairing fix `7aeae73`
between them (detail in the `svof-earworm-wiring` memory), and two fixes landed on
`gmcp-gated-empty-cures` (#855) as `a73e7e5` and `43e3ef6`. Before that,
2026-09-23, against `fork-version-66` at `a4f3e11`, `mfile` version 66; that
pass's results are in `verification-2026-09-21.md` in this folder. Commit
hashes from before 2026-09-24 are pre-rebase and differ from the ones on the
branches now.

## How to use this file

Read it at the start of a session. Update it when something lands, changes
status, or turns out to be wrong, and update the memory store in the same pass.
See `README.md` in this folder for how the two divide.

Each item says where it came from and how far it has been verified. Keep those
apart: **agreed** means the repo owner decided it, **proposed** means I am
suggesting it and nobody has said yes, and **found** means it came out of
reading or a harness and has not been discussed.

In flight (2026-10-04): GitHub stack 856, all unmerged and all green on Linux
CI at their current tips: #854 > #855 > #857 > #858 > #859 > #860 > #861 > #862 > #863.
#858 (`gmcp-first`) is GMCP first for afflictions, with the recklessness,
blackout and hidden-affliction fixes on top (`svof-gmcp-first-direction`,
`svof-hidden-aff-refusal-loop`). #859 fixes two pre-existing phantom `?`
counts (`svof-phantom-unknowns`), #860 stops empty tree touches
(`svof-tree-wasted-touches`). #857 to #860 took the 2026-10-04 review fixes.
#861 is plan step 1.6: seven afflictions missing from their empty-cure lists
(pyramides, parasite, the three unweavings, tension) and two false drifts in
`check_derived_lists`, plus no balance for a pear that cures nothing
(`svof-pressure-pear-balances`) and hellsight's cure line grouped with
valerian. #862 records blistered and pyre on DIAGNOSE
(`svof-dead-diag-triggers`) and keeps a doubled tree touch's cure
(`svof-doubled-commands-and-debug-echo`). #863 stops Action_system using
stale copies: the gnome (svof denied its own cures in aeon), the logger, and
actions_performed across a reset. Test build from the tip (`81dd764`):
`C:\work\svof-test-builds\svof-66-stack-81dd764.mpackage`. Merge with
`gh stack merge 856 --squash` once the drafts are marked ready. Queued after
the merge, as its own PR from `in-client-svof`: searching a saved copy of the
paragraph instead of Mudlet's buffer (agreed 2026-10-05, below). Defences
follow #858 as their own PR; I proposed doing the paragraph fix before them,
which nobody has confirmed. The defences PR is designed in
`defences-single-source-plan.md` (D2.1, D3, D4), because a GMCP defence gain
runs svof's own command bookkeeping today and has to be separated first.

---

## Deferred by the repo owner

### Bring svof's own class defences up to date with the game, as one batch
**Status: the user's call, 2026-10-18: efreeti and waterweird go in the batch
that updates the existing classes' defences (the "outdated classes" row of
`defences-single-source-plan.md`). Nothing changed in the code yet.**

Found in the 2026-10-18 live test (`customdef-live-test-2026-10-18.md`, items
5 and 6). Game facts so far:

- **efreeti (Magi).** The user: the command is `elemental summon efreeti`, in
  Artificing. svof sends `cast efreeti` under Elementalism. Seen live: the
  summon prints one long line (below); with one out already, `You have already
  called up a fiery efreeti.` Neither is svof's, so on defup svof re-sends the
  summon every 0.7 s. Not seen live, to check in game: the loss line `The
  efreeti begins to spin faster and faster, and suddenly disappears in a blaze
  of flame.` and the pattern `^A fiery efreeti, your loyal companion, has been
  slain by`. The user wants the old gain lines (`You rub your hands together
  briskly, ...` and `You are unable to summon more than one efreeti.`) kept
  beside the new ones.

  The summon line, 706 characters, rebuilt from the live capture (Mudlet
  wrapped it over eight screen lines; triggers see it whole):

  > You channel Fire and calescence consumes your surroundings as you reach for both here and yet elsewhere, clad now in black armour. Aldar armour, chaining you. Binding you. But to summon Fire you must claim it with might, and so you bestride the Burning Plains. Lava bubbles and roils about you in the unceasing churn, and in a roar calling to battle a blade of brilliantine fire clashes with your own. Back and forth you surge across the trails of magma, until with a shout of triumph your blade slides home in your foe's chest. You step forwards, the lust for fire and fury raging rampant in your claiming of the pact. With both hands you take up the body of the efreeti, and render it unto the corporeal.
- **waterweird (Magi)**, maybe changed the same way (`elemental summon
  waterweird`, Artificing), not confirmed. svof sends `cast waterweird at me`
  under Elementalism, waits for the Water channel, and watches for `You summon
  a water weird to assist you in water crossings.` and `You do not have the
  power to summon more than one water weird.` Its action is written by hand,
  so a player's change can't replace the command. Needed from the game: the
  command, the summon line, the line for one already out, and whether it still
  needs the Water channel.
- **Hide choices across a move (found, not discussed).** Moving a defence to
  another skillset loses a hide choice made for it alone: the flag stays under
  the old group in `svo/defup+keepup/ignored_defences`, unused, and a hidden
  old group no longer covers it. The batch could carry a defence's own flag to
  its new group as svof loads.

### Search a saved copy of the paragraph, not Mudlet's buffer
**Status: agreed 2026-10-05. Queued as its own PR from `in-client-svof`, after
stack 856 merges.** Detail and evidence in the
`svof-warning-suffix-breaks-lookbacks` memory.

**Why.** `svo.find_until_last_paragraph` and `count_until_last_paragraph` read
the paragraph back with `getLines`, which returns Mudlet's buffer as it is now:
svof's own warning suffix ("(breathrain inc)") and anything else that decorates
a line, and each long line cut into pieces at the profile's "Wrap lines at"
(80 on Achaea3_inclient). Exact and cross-cut substring lookbacks miss. That
caused the 2026-09-26 false sensitivity. Live-tested 2026-10-05 in Mudlet
5.0.0 with svof installed: triggers see whole lines, the lookbacks don't, and
the real `checkdeaf` adds sensitivity while the warning shows.

**The fix, as agreed.** Save Mudlet's `line` as each line arrives, in the Prompt
trigger's Lua condition that already counts `svo.paragraph_length`, with the
buffer line it arrived on. Clear it where `paragraph_length` is reset at the
prompt (`Controllers.lua`). The two functions search the saved copy and skip
entries at or past `getLastLineNumber('main')`, the cut `getLines` makes today,
so a trigger still never sees its own line (hypochondria's duplicate check
depends on that) and the prompt sees the whole paragraph. All 99 call sites
stay as they are.

**Review before the PR, site by site.** Searches that silently failed start
working: long lines at wrap 80 (the two Striking exact calls, substrings across
a cut). The window becomes game lines only: the previous prompt, svof's own
echoes and other scripts' echoes drop out (the Swashbuckling 'you' and 'jabs'
checks can match svof's echoes today). Gagged lines become visible: 24 files
call `deleteLine`.

**Same class, separate commits in the same PR.** Eight readers of the line
before the current one (`getLines(getLineNumber()-1, getLineNumber())`, for
example Tekura limb damage), three position checks against
`lastpromptnumber` (`check_dragonform`, `subterfuge_hallucinations`,
`subterfuge_confusion`), and the limb-break check that joins wrapped pieces
without a separator. `sk.getuntilprompt` stays: it deletes the buffer lines it
reads.

**Verification.** A new gate test running the real hook, reset and lookups over
a buffer stand-in taken from Mudlet's source (suffix and prefix warnings, wrap
80 and 100, the current-line cut, prompt-time and outside-trigger calls), with
controls that put `getLines` back. Then rerun
`C:\work\svof-live-testing\tools\make_wrap_test.py` through
`run_curing_sim.sh` against the new build: at wrap 80 with the warning on,
every lookback should find its line and `checkdeaf` should add nothing. Its
expectations encode today's behaviour, so flip them for the fixed build.

**Found alongside, not part of it:** the blademaster slash `pattern` lookback
never matches, because `\w` in a Lua 5.1 string is just `w`.

### Transmutation cure cleanup
**Status: agreed 2026-09-21, deferred to its own piece of work later.**

Remove the dead transmutation cure names. All transmutation cures are gone from
Achaea, so every right-hand name in `rift.vial_conversions` is dead, including
`hovering`.

Three sites: the second entries in the dictionary's `applycure` and `sipcure`
lists, `rift.vial_conversions` in full, and the `['density'] = 'mass'` row in
`svo.valid.defstrip`, which needs the owner's call on whether the game still
sends that wording.

Entry by entry, never a find-and-replace: six of the twelve names live elsewhere
as live game names or as ordinary English inside quoted Achaea lines that
defence recognition depends on.

Full detail in the `svof-transmutation-cure-cleanup` memory.

### Burning is one counted affliction now
**Status: agreed 2026-09-25, the repo owner's direction. Not started.**

Achaea replaced the burn ladder with a single counted affliction, `burning`, to
simplify it. svof still models the old ladder as five separate afflictions,
`ablaze`, `severeburn`, `extremeburn`, `charredburn` and `meltingburn`, walked
by `sk.burns`, `sk.next_burn`, `sk.current_burn`, `sk.previous_burn` and
`codepaste.remove_burns` (dictionary lines 356 to 410 at `43e3ef6`). The owner's
point: this does not break curing, because svof still follows the escalation
through its triggers. The four `Poisons + Generic lines` rung triggers call
`simple<rung>()`, and `svo diag` has a child per rung.

**The work:** remove the escalation and the four extra burn afflictions,
keeping one entry with a `count`. Afflictions that relate to burning change
with it, **pyre first**. `codepaste.pyre_holds` decides whether a salve is
wasted by comparing the pyre level with a burn's index in `sk.burns`, and
`tools/test_pyre_ladder.lua` (gate 1.7) tests exactly that ladder, so both have
to be rewritten against a count rather than a rung.

**The entry keeps its internal name, `ablaze`.** The repo owner's call,
2026-09-25: renaming it to `burning` would add work across the prio files, the
prompt abbreviation, the trigger items and `ITEM_RENAME`, for no behaviour
change. `sstosvoa` keeps `burning = 'ablaze'`. So this is not a name-space
rename and does not wait on the Striking fists. The name-space backlog's step 4,
deleting `svotossa`, will still find `burning = 'ablaze'` as a divergent pair,
which is a question for that step rather than a blocker here.

**Order, agreed 2026-09-25:**

1. After #854 and #855 land and the 66 play-test results are back. This
   rewrites code the stack just changed (`generic_burn` restored in `a73e7e5`,
   `tree_cured('burn')` from the inversion, the dictionary), so it cannot
   branch off `in-client-svof` before then without conflicting with the whole
   stack. It should also not stack a new curing behaviour on an untested build.
2. After the game questions below are answered. Until then it cannot be
   designed.
3. The `diag_pyre` trigger can land first, as part of the dead diag triggers
   PR. It does not touch the ladder, and it gives the pyre rework a way to see
   pyre without GMCP.

It changes two other items: items 1 and 2 of *Four fixes to
`check_guide_claims.py`* wait for it, and the burn-rule bullet of *Carry the
document corrections back to Cowork* is superseded by it. The transmutation
cleanup does not interact: every burn entry's `applycure` is `{'mending'}`
only.

**Found while scoping it, 2026-09-25, not yet designed:**

- GMCP already uses the new name. `sstosvoa` maps `burning = 'ablaze'`, so the
  game's counted affliction is read as svof's bottom rung today.
- `burning` is free as a svof name. svof used to call Striking's blazing fist
  `burning`; it has been `flamefisted` since the conversion (`ITEM_RENAME` in
  `tools/verify_merged.py` records the three renamed items). Not used: the
  entry stays `ablaze`, see above.
- Everything else that knows the ladder, found by name, each to be read in full
  before changing: `empty.apply_mending` (removes all five);
  `valid.generic_burn` and `ablaze.gone.generic_reducelevel` (one rung down,
  restored in `a73e7e5` for now); `svo.valid.tree_cured('burn')` and
  `('all burns')`, which `touchtree.misc.oncompleted` branches on;
  `valid.cured_burns_health`; the rung abbreviations in `@affs.lua`; the rungs
  in both copies of `default_prios`; the `svo diag` child and the
  `Poisons + Generic lines` trigger for each rung; and the verify baseline,
  which will move for every one of those files.
- Questions for the game before starting: whether GMCP sends the count as
  `burning (n)` like the other levelled afflictions; what cures it and by how
  much per application; what pyre does to it now; and whether the Magi
  burncounter addon, which tracks burn levels on a target, needs the same
  change.

Detail in the `svof-burning-counted` memory.

### Curing fixes from the 2026-09-26 fight log
**Status: DONE 2026-09-26 on #855, after the focus toggles: scalded in
`4d4b9f2`, the no-effect balance in `ff2ba5a`, fulminated's focus block in
`f4f67fc` and its cure line in `470cb42`. Awaiting in-game confirmation.
Open from it: scalded's diag trigger still matches "suffering from a scalded
throat.", which may be as stale as the old throat cure line.** Found in his first fight on the `99e354b` test build. Full
analysis in the `svof-cure-mismatch-loops` memory.

The GMCP empty-cure gate is correct, but it removed an accidental loop
breaker: a dictionary cure the game no longer honours used to cost one wasted
cure before svof forgot the affliction, and now it repeats every balance until
the affliction ends. Fix the stale cures, not the gate.

1. **scalded is time-cured, 20 seconds (owner).** Nothing heals it. Remove
   the salve cure from all five sites: the dictionary's salve block, the list
   in `empty.apply_epidermal_head`, the `epidermal` regeneration list in
   `Main_trigger_functions.lua`, `scalded_salve` in both `default_prios`
   copies, and the `General/svo cure scalded` trigger. Give it a `waitingfor`
   with `customwait = 20`, the `blistered` shape, and a trigger for `The
   terrible burning of your skin fades.` Keep the gain (`Artificing/Scald`)
   and diag triggers. Check what a user's saved prios do with a
   `scalded_salve` that no longer exists.
2. **The epidermal no-effect handlers skip `svo.lostbal_salve()`.**
   stuttering, slashedthroat, blindaff, deafaff (head) and itching (body);
   anorexia and the mending entries already call it. The game does take
   salve balance on the no-effect line, so svof applies twice. One line each.
3. **fulminated is not focusable (owner).** Its `focus` block is **removed in
   `f4f67fc`** along with the simple toggle below; `remove_focusable()` was
   read and stays (unknownmental bookkeeping, not a focus cure). Still open:
   a trigger for the plumbum cure line, `You are no longer suffering from
   the ravages of fulminous energy.`, which today reads as an empty eat and
   in blackout would never clear fulminated.

### Focus while fulminated: a vconfig option
**Status: the simple version LANDED 2026-09-26 as `f4f67fc` on #855, at the
owner's request: `vconfig focuswithfulminated`, on or off, off by default,
checked in `svo.check_focus`, synced to the game's own switch in serverside
mode. `2677bd4` adds the same for guilt, `vconfig focuswithguilt`, since
focusing with guilt gives a mental affliction. Still to confirm in game: the serverside spelling, `curing focus
withfulminated` / `withoutfulminated`.**

**Suggestion for later (owner, 2026-09-26): improve it with the richer
scenarios below.** Everything from here down is that design, not yet
settled.

**The mechanic (owner):** with fulminated, focusing for any other mental
affliction strikes you with paralysis. The point is to make the player choose
between focusing and taking paralysis, or not focusing. Seen in the same log:
`stupidity_focus` and `dizziness_focus` each followed by "As you exert your
mental faculties, your body begins to twitch uncontrollably and muscles lock."
The game's own serverside option: `CURING FOCUS WITH|WITHOUTFULMINATED`. A
skilled combatant's advice: the best time to focus with fulminated is when
you already have paralysis, because getting it again does nothing.

**The owner's four scenarios for the option:**

1. never focus while fulminated, back to normal once it is cured
2. focus only when fulminated and paralysis are both held (risky)
3. focus while fulminated only when a user-set number of focusable
   afflictions need curing
4. focus normally

**Template already in svof: cadmus.** `conf.focuswithcadmus` (boolean) plus
`conf.cadmusaffs` / `me.cadmusaffs` (a user-picked set of afflictions worth
focusing for despite cadmus). `svo.check_focus` in `Curing_skeleton.lua`
applies both, and `sk.canfocus()` / `sk.togglefocusserver()` in
`Serverside.lua` send `focus on` / `focus off` to the server as state
changes. Fulminated fits the same three places, and the server side would
send `curing focus withfulminated` / `withoutfulminated`.

**Open design questions:**

- scenario 3 as a count, as the owner put it, or as a cadmus-style list of
  afflictions worth it, or both
- scenario 2 needs the focus to go before the bloodroot that cures the
  paralysis, or the window closes; check how focus and herb priorities
  interleave
- scenarios 2 and 3 change with state, so in serverside mode svof has to
  keep flipping the server's setting; check that `togglefocusserver`'s cache
  pattern holds for a second condition
- whether this wants one setting with four values or separate toggles, and
  how it reads in `vconfig`

### Document GMCP first for script writers
**Status: agreed 2026-09-27, deferred by the owner to the docs pass once the
GMCP-first work (branch `gmcp-first`, stacked on #857) is finished,
defences included.**

What `doc/index.rst` has to say, and where:

- **"Adding your own triggers"** (around line 1684): `svo.valid.proper_<aff>()`
  and `svo.valid.simple<aff>()` now file a claim that GMCP judges like svof's
  own trigger lines. Outside blackout, a claim for an affliction GMCP could
  report but doesn't is dropped. In blackout, and after it until the next
  diagnose's List, GMCP is not consulted and these work exactly as before, so
  scripts reacting to blackout's hint lines need no change.
- **"Adding/removing afflictions directly"** (around line 1703):
  `svo.addaff` / `svo.removeaff` / `svo.removeafflevel` bypass GMCP as well as
  anti-illusion. This is the tool for making svof believe an affliction
  regardless of what GMCP says (the owner's example: a skilled combatant whose
  trigger knows better, such as lines blackout hides or blurs). Say plainly
  that outside blackout, GMCP not reporting an affliction means the game's own
  list says you don't have it; the real exception is hidden afflictions, the
  hint-line kind.
- **The `vaff` / `vrmaff` / `vreset` entries** (around line 1943): typed, they
  act as before. `vaff` inside a trigger files a claim, as the docs already
  imply by pointing triggers at `svo.valid.*`.
- **`gmcpaffechoes`**: the four new echoes, one per way GMCP overrules text.

Style: the `google-doc-style` skill applies to docs.

---

## Open, not yet raised with the owner

### Move vcustomdef out of `Defences.lua` into a script of its own
**Status: the user's suggestion, 2026-10-20, checked the same day as
feasible. Waits for #866 to merge.**

`vcustomaff` has its own script, `Custom afflictions`, since 2026-10-20
(branch `custom-afflictions`). The user would like `vcustomdef` to have one
too, as "Custom defences", so both custom definition surfaces live apart
from the code they extend. `Defences.lua` is 3,952 lines on `in-client-svof`
and about 7,300 with #866, most of the growth `vcustomdef`.

What a move involves, checked against `3daf75b`:

- **The block is one piece.** It runs from `defences.custom_load` to the
  changes' import, about lines 3757 to 6450. It uses only the loader's
  aliases of `svo.*` tables (`defs_data`, `conf`, `sk` and the like), which a
  new loader declares the same way.
- **The hide lists after it use 15 of its local helpers**, such as
  `custom_link`, `line_list`, `whose` and `class_names`. Either they become
  fields of a shared table, or the hide-list code moves with them.
- **Order.** The new loader goes straight after `defences` in
  `svo_init_system`, before `prio`. The definitions register in a systemstart
  handler, and `prio.import('current')` runs in `prio`'s, so moving it any
  later changes which saved priorities a definition gets.
- **The gate.** A new top-level script is structural in `verify_merged`
  unless it's listed in `TOP_LEVEL_ADDED`, which `custom-afflictions` adds
  for `Custom afflictions`. `Custom defences` gets a second entry.
- **`tools/svof_world.lua`** lists the loaders, and `test_defences.lua` and
  `defence_catalog.lua` run through it, so it needs the new loader too.

- **What else moves with it** (the user, 2026-10-20): `svo.gamereader`, the
  SHOW and LIST readers `vcustomdef` and `vcustomaff` share, and
  `defences.ui`, the screen helpers `Custom afflictions` uses. Both live in
  `Defences.lua` on `custom-afflictions` and say in their comments that
  they move.

Why after #866 rather than in it: #866 is up for review, and moving 2,700
lines inside it would bury the review. On its own, a move is easy to check
with `git diff --color-moved`, and #867 and `custom-afflictions` would not
need rebasing over it mid-review. `custom-afflictions` shares some of these
helpers for `vcustomaff` (plan step 4), so whichever lands second takes the
shared table the other made.

### Defences: the single-source plan
**Status: written 2026-10-08 against `4f4c017`. Proposed; 11 game questions
and 3 decisions for the owner at its end. Not started.**

`defences-single-source-plan.md` in this folder. It replaces the defence steps
of the main plan (2.4, 2.6, 3.1, 3.2, the defence half of 3.5, `customdef`) and
designs the queued GMCP-first defences PR. The things to carry into a session
that does not read it:

- **A GMCP defence gain runs the raising action's `oncompleted`** (the
  generated `got_<name>(true)` force-adds and finishes it). Read, not run:
  rebounding restarts its wait, uses a skullcap puff and spends smoke balance;
  sileris starts a wait that ends in `'unsure'` at login; caloric and mass spend
  salve balance; six hand-written handlers (blind, block, deaf, dragonbreath,
  speed, viridian) drop the gain unless svof was raising it. `process_defs` has
  the same shape for `DEF` leftovers.
- **The fix is `defences.confirm`/`unconfirm`**: finish svof's in-flight action
  if there is one, otherwise just set the defence. Bookkeeping stays in actions;
  consequences move to `ongot`/`onlost` on records.
- **`defs_data` is rebuilt on every init** (`Defences.lua:57`); the main plan's
  3.5 said otherwise. `svo.defs`, the handler table, is what persists.
- `gamename` goes on the record and `sstosvod` is derived; defences keep svof's
  names (Decision B). 14 serverside names lack a GMCP mapping, not 15
  (`cloaking` is mapped after the literal).
- 20 pre-existing defects in a table, 10 of them new in this pass.

Order: after stack 856 merges, D0 (gates, `test_defences.lua`) and the typo
fixes can go alongside the paragraph fix; D2.1, D3 and D4 are the defences PR.

### Pipe puff counts drift, worst under serverside
**Status: found 2026-10-08 from the owner's login log ("(0 malachite left)"
on a smoke that worked); the owner called it a bug. Causes read, not run. Not
started.**

svof's puff count for a pipe is wrong in four ways, all in the 2018 code:

1. A server-raised rebounding takes two puffs off the count: one when the
   smoke line finishes the adopted smoke action, one when the GMCP gain remakes
   it 9 seconds later. Seen in the log. This is defence-plan defect 17 and goes
   with D3.
2. Every skullcap smoke is charged to pipe 1 (`sk.skullcap_smokepuff`,
   `Curing_skeleton.lua:2139`, decrements `pipes.skullcap.puffs` only), and the
   "(N herb left)" label shows pipe 1's contents. svof's own smokes name pipe
   1's id, so they are right; the server's `SMOKE SKULLCAP` lets the game pick
   the pipe, and svof does not read the herb from "You take a long drag of
   skullcap off your pipe." The same holds for elm and valerian.
3. With serverside on, svof never refills or relights (`fillskullcap` and
   `lightpipes` both require `not conf.serverside`), and a fill line counts only
   while svof's own fill action is in flight (`svo.valid.fillskullcap`, unforced
   `checkaction`). A server or manual refill is never seen. Only a `PIPELIST`
   the player types resets the counts (`svo.pipestart`, then `svo.parseplist`);
   nothing in svof sends one.
4. `sk.asyncfill` and `sk.syncfill` (`Rift.lua`) set `pipes[orig].filledwith`
   even when filling pipe 2, so refilling the second pipe relabels the first.

Effect: under serverside the count only goes down, and at 0
`codepaste.smoke_skullcap_pipe()` says no, so svof will not smoke for
rebounding itself if serverside is turned off or rebounding is moved to svof
in `vshow server`. Questions for the owner: does the server refill pipes on its
own, and what does `PIPELIST` show (which pipe holds skullcap and which
malachite)? Fix ideas, none agreed: charge the pipe whose contents match the
herb in the smoke line; count a fill line that names a tracked pipe's herb;
send `PIPELIST` at login under serverside.

### The single-source implementation plan
**Status: written 2026-09-22, four questions answered by the owner the same
day. Not yet started.**

`single-source-implementation-plan.md` in this folder turns
`reference/svof-single-source-guide.md` into phased work, and adds the
user-facing half the guide does not cover: `vconfig customaff` and
`vconfig customdef`, so a player can add an affliction or a defence without
writing Lua.

The one thing to carry into a session that does not read it: the guide calls
Change B, `basicaff` and `basicdef(name, spec)`, an optional convenience. For a
user-facing surface it is load-bearing, because a constructor is what turns an
entry into data a saved table can carry. Steps 5 and 8 move onto the critical
path.

**Phase 1.1, 1.2 and the tree nil calls landed 2026-09-22**, in three commits
on `fork-version-66`: `c22dd51`, `796e553` and `1cc6ce3`. The third fixes
`tree_cured_paralysis` and the `simpletinderskin` typo, and adds
`tools/check_valid_callsites.py` as gate 1.22 with
`tools/known_unresolved_valid.json` recording the pre-existing dead calls.
`latched` was then fixed in `751f706` once the owner supplied the mechanic - it
holds elixir balance and SIP HEALTH clears it. Both baselines moved in the same
commit that caused them; the counts live in the baseline files and the gates
print them, which is why they are not repeated here.

**The remaining dead calls, gauged 2026-09-23, and the Healing seven removed
the same day.** See *The dead `svo.valid` calls* below.

**Phase 1.1 and 1.2 detail**: `tools/check_derived_lists.py` with
`tools/derived_lists_baseline.json`, and
`tools/check_dict_fields.py`. Both are wired into `build.yml` as gates 1.9 and
1.8, both are proved by sabotage, and both are verified line-ending independent
against the raw git blobs. Neither touches anything muddler reads. Everything
else in Phase 1 waits on the renames in the name-space backlog.

**Still open from the tree work, 2026-09-23: six names want in-game
confirmation.** The 14 game questions and the timed afflictions are answered -
tree cures all 14, and none of the timed ones including `voided`. What is left
is that two signals turned out not to be evidence at all, so some names already
in `empty.treecurables` rest on nothing: `paralysis` and the four fractures,
there since 2018, and `latched`, added on 2026-09-23. The owner's call was to
keep them rather than remove them on suspicion, and confirm in game later.
**Remind him.** Detail in the plan under "The two tree lists, resolved" and in
the `svof-tree-list-split` memory.

All four open questions are settled and recorded at the end of the plan: the
user-facing half goes in svof itself, generosity follows the other rage cures,
the surface is `vconfig customaff` and `vconfig customdef`, and the tree lists
are worked through name by name. The tree half is answered as of 2026-09-23,
apart from the six names wanting in-game confirmation noted above.

Answering the tree question turned up two live nil calls,
`svo.valid.tree_cured_paralysis()` and `svo.valid.tree_cured_latched()`, both
pre-existing. Both are fixed: `paralysis` in `1cc6ce3` and `latched` when
`e893d08` removed the list its handler was generated from. Detail in the
`svof-tree-list-split` memory.

### Latched and the elixir balance

**Status: RESOLVED 2026-09-22. Confirmed with a player, and the answer was
that almost none of the proposed work is needed. Landed as `648d73c`.**

The survey asked whether latched blocks elixir cures generally. It does not.
The confirmed mechanic:

- gaining latched knocks you off elixir balance **once**, not for the duration
- it is cured only by sipping health, and that sip clears the latch **instead
  of** healing you, the way applying health to a limb mends the fracture
- it does **not** block the other sip cures

So no `not affs.latched` guard anywhere, no clause in `check_sip`, and the four
purgative defences are untouched. The only real change was recording the
balance loss, which `648d73c` does with `onadded` on the entry - not
`aff.oncompleted`, because the GMCP path calls `addaffdict` directly
(`Setup.lua:656`) and never runs the aff action.

**The sip priority stays where it is. Settled 2026-09-23.** `default_prios`
orders the sip balance with `healhealth` last, which the file's own comment
makes the most important, while `dict_setup` gives an unassigned action the
lowest number, so `latched` sits at the other end. The repo owner's answer:
sipping for either one while latched cures latched anyway, so both keep their
default positions. No edit to either copy of `default_prios`.

**All of latched's handlers are wired now.** `tree_cured_latched` resolved when
`e893d08` removed the tree list, and `05c678c` put `latched` in
`empty.treecurables` on the owner's answer that an empty cure is empty
regardless. `diag_latched` was never the problem it looked like - its trigger
matches the real in-game DIAGNOSE line.

**What the survey established, and is worth keeping:** Achaea has two elixir
balances and svof's `sip`/`purgative` split is correct, proved by the two
regain lines. Nothing in svof detects an externally stripped elixir balance -
every `lostbal_sip` and `lostbal_purgative` call comes from a dict entry's own
handler. `648d73c` fixes that for latched specifically and not in general.
Full detail in the `svof-elixir-balances` memory.

### Gate the empty-cure sweeps on GMCP

**Proposed by the repo owner and landed 2026-09-23, in `3c45f82` and `b70eda5`.
This is what makes the treecurables accuracy question stop being dangerous.**

`empty.tree()` removes every `empty.treecurables` name you currently hold when a
tree touch cures nothing, on the inference that if tree cured nothing then you
had none of them. `empty.dragonheal` and `empty.shrugging` are the same
function. `empty.focus`, `empty.smoke_elm` and the herb handlers do the same
thing with their own lists. Every one of them is an assumption, and a wrong list
entry turns it into svof forgetting an affliction you still have.

The owner's rule: **never assume an affliction is gone unless GMCP agrees it is
gone, or - in blackout, where GMCP is silent - unless the cure message arrived.**

**The pattern already exists and is proven.** `svo.gaffl` is a live mirror of
the game's affliction list, maintained by the Add, Remove and List handlers in
`Setup.lua`. `svo.dict.svotossa` is the reverse of `sstosvoa` and answers "can
GMCP speak to this name at all". The List reconciler at `Setup.lua:779` already
gates its own removals on exactly that: `if val and svo.dict.svotossa[key]`.

So each sweep becomes: if GMCP can speak to the name, remove it only when
`gaffl` also says it is gone; otherwise fall back to today's behaviour.

Timing works in favour of this. GMCP is processed before the game text it
accompanies - the Remove handler's own comment says so - so by the time the
empty-cure line reaches a trigger, `gaffl` already reflects the post-cure state.

**Coverage, measured 2026-09-23.** 84 of the 89 `treecurables` are reachable
through `sstosvoa`. The five that are not: `earworm`, and the four unknowns
(`unknownany`, `unknownmental`, `unknowncrippledarm`, `unknowncrippledleg`). The
unknowns should stay unconditional, since clearing an unknown on an empty cure
is the entire point of tracking one, and `empty.tree()` already zeroes two of
their counts by hand.

`bleeding` is not in any of these lists and must not go in one. **The game does
not treat it as an affliction at all** - the owner confirmed on 2026-09-23 that
it arrives in `gmcp.Char.Vitals.charstats` as `"Bleed: N"`, alongside Rage,
Morph and Sunlight, and `Setup.lua`'s Vitals handler already acts on it:
`svo.rmaff('bleeding')` at 0, `bleeding.aff.oncompleted(n)` otherwise. GMCP owns
bleeding continuously, so an empty-cure sweep touching it could only second-
guess a live feed. `sstosvoa` carrying `internalbleeding = false` is consistent
with that rather than a gap.

An earlier version of this note said GMCP does not report bleeding. That was
wrong; it reports it through a different table, which is a stronger reason to
keep it out, not a weaker one.

**Blackout.** `Char.Afflictions` stops entirely, so `gaffl` goes stale and the
sweep has to do nothing rather than fall back to assuming. Recognition still
works there: the tree and generic text triggers are the blackout fallback by
design, which is why they exist.

**What landed.** `b70eda5` adds `presume_cured()` and routes twelve handlers
through it: the eight generated herb ones, `eat_bloodroot`, `focus`, `tree`
with its two aliases, the three smoke ones, `writhe`, both epidermal ones,
`apply_mending_head` and `sip_immunity`. `3c45f82` had to go first, because
`Char.Afflictions.List` was rebinding `svo.gaffl` out from under the alias every
write in `Setup.lua` goes through, which would have left the gate quietly inert.

**Left out, deliberately.** The eight handlers that pair a removal with an
explicit `count = 0`: `apply_mending`, both `noeffect_mending_*`, the four
`apply_health_*` and `eat_ginger`. Keeping an affliction while zeroing its count
leaves svof in a state neither half agrees with, and what the count should do
when GMCP overrules the removal is its own question. `empty.tree`'s two count
lines are fine unconditional, because neither unknown is in `svotossa` so the
gate always removes them.

**Still wanted: play testing.** This changes how svof learns a cure happened,
which no gate here can see. Gate 1.23 (`tools/test_empty_cure_gate.lua`, 13
checks, proved against three sabotages) covers the logic and nothing about real
combat. The DEF-resync capture the `svof-curing-live-behaviour` memory records
as missing is still missing.

**What it unblocks.** A wrong name in `treecurables` can no longer cause a false
removal for any affliction GMCP reports, which is 84 of the 89. So the six names
waiting on in-game confirmation are now low-stakes rather than hazardous, and
`tension` went in on that basis in `a4f3e11` - an ordinary affliction the owner
reads as most likely tree-curable, which is weaker than the other nine had and
is enough only because the gate landed first.

### The rest of the empty-cure handlers

**Found 2026-09-24 while wiring earworm. Agreed to follow the first stack PRs.**

Every `empty.*` handler is a hardcoded list, and the dictionary already holds
the same fact in each entry's `eatcure` / `applycure` / `smokecure` / `sipcure`
field. `check_derived_lists` compares only the **herb** map against it. Smoke,
salve and sip are unwatched, which is how earworm's absence from
`empty.smoke_elm` survived.

**Two names, one line.** `tension` and `unweavingspirit` both declare
`smokecure = {'elm', 'cinnabar'}` and are both absent from `empty.smoke_elm`.
Deliberately left out of `ed55ae5` rather than added on the back of earworm.
Low risk now: both are GMCP-reported, so `presume_cured` overrules the entry if
the dictionary's claim is wrong.

**A gate for the smoke handlers.** Same shape as the herb comparison that
already exists, so it is cheap, and it catches this whole class. Gate-only, no
runtime risk.

**Do not try the same for salve and sip without designing it.** A naive
item-name join produces 12 false positives out of 13 rows, for two reasons
worth knowing before anyone starts:

  The salve handlers are split by body part - `apply_mending_head` versus
  `apply_mending`, `apply_epidermal_head` versus `apply_epidermal_body` - and
  the dictionary's `applycure` says which salve, never which part. A gate has
  to carry that knowledge itself.

  The item name `health` means two different things: a salve you apply to a
  limb, and an elixir you sip. `healhealth` and `latched` are `sipcure`
  entries and have nothing to do with `apply_health_*`.

**Also unwatched:** nothing verifies that a name in `empty.treecurables` is
reachable through `sstosvoa`. That is what made earworm the one affliction the
GMCP gate could not protect, and it went unnoticed until someone looked.

### The dead `svo.valid` calls - 12, now 5

**Gauged 2026-09-23 at the repo owner's request: after, not now - but not
because it is expensive. Then the Healing seven were answered the same day and
went.**

The cost of removing one is small and known. A deleted item is *content* to
`verify_merged.py`, not structure - the comment above `ITEM_RENAME` says so and
`751f706` proved it when `svo_latched_wore_off.lua` went - so it costs one
baseline entry plus deleting its row from `known_unresolved_valid.json`, which
the gate then enforces. Nothing here is blocked on effort.

What blocks the rest is that each needs a game answer, and the phases of this
plan do not produce one. **None of the seven missing handlers has ever existed
in any released svof** - checked against all 25 of the 2018 reference xmls, not
one of `bedevilheal`, `emptyheal`, `healercure`, `nohealbalance`,
`healing_cured_insomnia`, `curedconcussion` or `sour_sparkle` is defined
anywhere in them. These triggers have fired into nothing since 2018.

**The Healing group is gone, 2026-09-23 in `607168d`.** Healing was an old
Priest skill; Priest was reworked and no longer has it, and the owner had kept
the triggers in case Achaea gave Healing to someone else. Over a decade on, it
has not. Seven items removed, `known_unresolved_valid.json` 12 entries to 5.
Left alone because they only look related: the `bedevil` Zeal defence, the
Elementalism channel folder named "Healing + Elementalism channels", and
*Passive-active heals*, which calls the live `svo.valid.passive_cure()`.

Five remain:

| group | files | the question |
|---|---|---|
| concussion | `svo_cure_concussion`, `Calcified_Skull_Concussion` | **the owner confirmed 2026-09-23 that concussion is a real affliction in the game, and svof should get an entry for it - later, as its own piece of work.** See below |
| `sour_sparkle` | 1 | what "The aftertaste of the berry turns sour" does mechanically |
| `simplecheckwrithes` | 2 bashing triggers | they want the affliction the symptom is, not the anti-illusion probe. Morindar arm break reads like `simpleunknowncrippledarm`; Annwyn aeon already calls `proper_aeon` on the line before and may want nothing else. Guessing is worse than leaving them |

#### concussion wants its own entry

**Agreed 2026-09-23, deferred.** svof models two head afflictions and the game
has a third that svof folds into one of them:

| svof entry | `gamename` | what `sstosvoa` maps to it |
|---|---|---|
| `mildconcussion` | `damagedhead` | `damagedhead` |
| `seriousconcussion` | `mangledhead` | `mangledhead`, **and plain `concussion`** |

So GMCP's own `concussion` is currently read as `seriousconcussion`
(`Dictionary_of_actions:10466`). If it is a distinct affliction rather than a
synonym, svof is mis-tracking it, curing it with the wrong salve action
(`apply restoration to head`, via `curingseriousconcussion`) and showing the
wrong name.

The two dead calls are the visible edge of the same gap: `simpleconcussion` for
gaining it and `curedconcussion` for losing it, on "As your concussion lifts,
your thinking becomes clearer." Both resolve for free once an entry exists,
because `simple` is generated from the dictionary and `generic`/`diag` take the
name.

What is needed before writing it: whether the game's `concussion` is a third
level or a synonym, what cures it, and what it does. The `Calcified Skull
Concussion` line - "Lances of pain radiate through your skull, the bones
shifting and twisting in a nauseating series of crunches" - names no severity,
which is why that trigger could never have been fixed by guessing.

Note that adding the entry is now genuinely one dictionary edit plus triggers,
which is what the whole single-source effort was for. Good first real test of
it.

The `simple` derivation did not change this. `checkwrithes` is excluded from
the generated family by name, so those two calls stay dead exactly as they
were, and they would stay excluded even if the triggers were fixed - the
exclusion is about `oncompleted` needing a name, not about the callers.

### Invert the handler families, and the GMCP tree question behind it

**Status: done 2026-09-23. Detail in `single-source-implementation-plan.md`
step 1.5a.**

Four handler families are generated from hardcoded name lists and called by
triggers that name the same affliction. The list is a second copy of what the
trigger already knows, and for `diag_` it has drifted both ways: 16 listed
names no trigger calls, 3 called names not listed.

Invert `diag_`, `generic_` and `tree_cured_`: one function each, taking the
name as an argument, the trigger passing its own. The list disappears and
adding a diagnosable affliction becomes just writing the trigger. `simple` had
to keep its per-name functions - `doc/index.rst:1684` documents
`svo.valid.simple<affliction>()` for users' own triggers and `svo.vaff` probes
for them - but lost its list all the same, by generating one per entry with an
`aff` block.

**The GMCP question is settled: triggers stay, inversion goes first.** The repo
owner asked whether GMCP should own tree cures instead. 84 of 86 tree triggers
name an affliction GMCP reports, but blackout stops `Char.Afflictions`
entirely, so the text path is the fallback by design - see the
`svof-blackout-stops-gmcp` memory. The tree triggers also close the touchtree
action, which is what spends tree balance and steps the burn ladder, and GMCP
does none of that. Making GMCP primary is still worth doing, as its own
behaviour-change commit with play testing, after the refactor.

**All four are done.** `diag` in `14dc789` (the three broken names) and
`83c0353` (the inversion); `generic_` and the whole tree family in `e893d08`,
which also folded in `tree_cure_`, the two hand-written burn handlers, and
`generic_cure`/`generic_cured`; `simple` last, generated from the dictionary
rather than from `afflist`, keeping its per-name functions.

The `simple` derivation lost nothing and gained 17 names, of which **12 are new
usable API**: `insomnia`, `mindravaged`, `mucous`, `paradox`, `parestoarms`,
`parestolegs`, `pressure`, `tension`, `unknowncure`, `unweavingbody`,
`unweavingmind`, `unweavingspirit`. The other five - `hoisted` and the four
fractures - were already defined by hand further down the file, which
overwrites the generated one. (`deef315`'s message says six and eleven. It is
five and twelve; the code is right and the arithmetic in the message is not.)

Measured two ways
that agree exactly - the dictionary literal built in a Lua sandbox, and the
brace walk in `check_derived_lists.py` - 180 entries carry an `aff` block
against `afflist`'s 155, and 155 is a strict subset. Driving all 156 shared
handlers in the old and new blocks, both extracted verbatim from the shipped
file, produced identical calls, with a negative control proving the probe could
see a difference.

Eight of the 180 are excluded by name, in `no_simple_handler`: the
anti-illusion probes. Their `aff.oncompleted` takes the symptom's real
affliction name, and `checkslows` and `checkwrithes` index `svo.affsp` with it,
so a bare call raises - `simplecheckwrithes` stays a recorded dead call rather
than becoming a live error inside lifevision processing. The other six would
have been harmless but meaningless, and excluding all eight keeps the family
meaning one thing.

Two bashing triggers still call `simplecheckwrithes` and are still wrong:
`Annwyn_Aeon.lua` and `Morindar_arm_break.lua`. They want the affliction the
symptom is, not the probe.

`cantmorph` lost its `haveskillset` test, because `svo.dict.cantmorph` is
created under the same one. That closes a small pre-existing hole: on a class
change the list re-ran and could define `simplecantmorph` while the dictionary,
which is not rebuilt then, still had no entry for it to index.

**Two call sites broke, fixed 2026-09-25 in `a73e7e5`.** The rebased `e893d08`
(`d2160f6` on the branches now) rewrote *General cures* bodies by prefix, and
two called hand-written functions, not family members: `svo cure burn` called
`generic_burn` and `svo got insomnia` called `generic_insomnia`, a defence gain
line. `generic('burn')` refused the name and `generic('insomnia')` could mark
the defence lost or kill an unrelated in-flight cure. Both bodies are restored.
`43e3ef6` then gave myrrh, blind, deathsight and waterbubble the blackout copies
in *General cures* that only kola and insomnia had. #854 on its own still
carries the two broken bodies. Detail in the `svof-inversion-regressions`
memory.

`e893d08` carried one behaviour change worth remembering: `tree_cured_latched`
was a recorded dead call while the tree question stayed open, and removing the
list made it resolve. `05c678c` then put `latched` in `empty.treecurables` too,
which is one of the six entries still wanting in-game confirmation.

**This is a prerequisite for the registration API in Phase 3, not a tidy-up.**
A user-registered affliction needs these handler families too. With the family
inverted it needs nothing, because the function takes the name and looks it up
at call time. With a hardcoded list it needs a closure rebuilt at runtime. So
1.5a turns "wire four families per custom affliction" into nothing at all -
three of the four never needed a per-name function, and `simple` now builds its
own from whatever the dictionary holds. Phase 3 has to re-run
`svo.loader.valid_simple()` after registering an entry, and that is the whole
of it.

### Four fixes to `check_guide_claims.py`
**Status: found 2026-09-21. Proposed, not discussed.**

That gate exits 1 on this checkout, 123 of 129 claims passing. While it sits
red, a real regression in it is easy to miss. Four of the six failures are the
harness rather than the code:

1. the `§7` count claim, re-expressed against `codepaste.pyre_holds`
2. the `§7` threshold claim, re-expressed against `sk.burns`, asserting the
   corrected ladder rather than the pre-853 one
3. the `§4` claim, excluding `3rdparty/` from `ALL_SRC`, since both
   `debug.getinfo` hits are vendored Penlight
4. the Step 5c claim, stripping quoted strings before matching `busy`, since
   the only hit is an English word in an updater message

The remaining two failures are the Step 5b name checks, which wait on the
transmutation cleanup above.

**Items 1 and 2 wait for the burning work** (2026-09-25). Both would re-express
the `§7` claims against `codepaste.pyre_holds` and `sk.burns`, which that work
replaces. Rewrite them against the count once it lands. Items 3 and 4 do not
depend on it.

These live in `C:\work\svof-cowork-export\from-cowork\tools\`, **not** in this
repo's `tools/`. Nothing in svof imports them and none runs in CI, so this is
document hygiene and not a build change.

### Carry the document corrections back to Cowork
**Status: found 2026-09-21. Written up, not applied.**

`C:\work\svof-cowork-export\svof-from-cowork-corrections.md` holds the full
list. The edits that are not deferred:

- the guide's "Related findings" states the pre-853 burn rule, *pyre at level+1
  blocks curing that burn*, as though it were correct. 853 corrected it to the
  burn's own rung. **Superseded 2026-09-25:** the game no longer has the rung
  ladder, so rather than correct the rule, mark it as describing a model the
  burning work removes
- the spec's section 0 wants a note that a current checkout carries 853
- the spec's section 12.6 wants `rift.vial_conversions` added as dead weight,
  since it has no reader anywhere in `src/`
- the spec's section 21 wants three rows, two for the errors above and one for
  the `defstrip` misreading made during the verification itself

### Correct four errors in the reference documents
**Status: DONE on 2026-09-21, in both copies.**

All four are fixed in place in this folder's copy, along with a dated
correction note at the top, the LF caveat on the byte figures, flags on the two
unverifiable figures, and the two removal defects added to its findings
section. Verified afterwards: no stale figure remains, every replacement
appears once, and the heading structure differs from the original by exactly
the one heading added.

The `from-cowork` copy was mirrored and is byte-identical. The derived
single-upload file `svof-cowork-from-cowork.md` was regenerated, and that
folder's README now records the correction and says the combined file is
derived. Nothing is left open here.

Full evidence in `verification-2026-09-21.md`, and the durable summary is the
`svof-reference-docs-accuracy` memory. What was wrong:

1. **The architecture map's State section describes `svo.affs` wrongly**, as
   name to `true` or a count. It is `{p = <dict entry>, sw = <stopwatch>}`.
   This is the exact model whose misreading caused the crash #853 fixed, stated
   as fact in the section a reader consults to learn the state shape. Highest
   priority of the four.
2. **The signal count is 67, not 54.** `Setup.lua` creates 65, not 53: 12 are
   written in bracket form and named after Mudlet events, and 14 of the 67 use
   plain assignment with no `or` guard, so a reload drops their handlers.
3. **"The dictionary holds 265 actions" is 267**, and is scoped to the literal
   while calling it the dictionary.
4. **The balance list has no `arms`, `left arm` or `right arm`.** The names are
   `leftarm` and `rightarm`, both initialised to the string `'unset'`, and four
   real balances are missing: `entities`, `hydra`, `humour`, `homunculus`.

Two further figures, the map's "1,488 function definitions" and "up to 23
skillset-conditional config options", state no method and cannot be checked.
Publish the extractor beside each or drop them.

Also worth adding to the map: its three byte counts are **LF** measurements and
a Windows checkout differs by exactly the line count. Four such figures were
checked and all four match under LF.

### A static check over the dictionary's removal paths
**Status: found 2026-09-21. Proposed, not discussed.**

The spec's section 18.3 already proposes a `tools/` check for a `gone` or `aff`
handler whose `rmaff` names something other than its own entry. Widen it to
cover every removal path: it would catch `mindravaged`, the `asleep` guards,
and both defects in the `svof-public-removal-api-defects` memory, which are
`svo.removeaff` recursing forever on the 8 `check*` entries and
`svo.removeafflevel` nil-calling on 174 of 189.

Neither removal defect is reachable from `src/`; both are public API only, and
both are pre-existing rather than conversion damage.

### Make a duplicated or moved item structural again in `verify_merged`
**Status: DONE 2026-09-26 as `99e354b` on #855, at the owner's request.** Moves
are matched on identical behaviour, not on name, and are declarable in
`ITEM_MOVE`; duplicates are not declarable. The original proposal follows.

`7aeae73` made `compare()` pair a tree by path whenever its item set differs,
not only when its count does. A rename, move or duplicate now reads as a
`gone|` plus an `added|` entry everywhere, which fails until the baseline is
regenerated but can be baselined. Count-differing trees already worked that
way, so this is consistency, not a new weakness. Cheap to tighten: an
`added|` path ending in a `#n` suffix is a duplicate, and a leaf name that is
both gone and added is a move. The current baseline has neither. A deliberate
move would then need a declared map, like `ITEM_RENAME`. Detail in the
`svof-item-renames-are-structural` memory.

### Report an `ITEM_MOVE` entry that matches nothing
**Status: found 2026-09-27. Proposed, not discussed.**

#852 (merged 2026-09-27 as `95a89a4`) made an unused `ITEM_RENAME` key a
structural failure, since a typo'd or re-pinned entry otherwise sits there as
dead config that reads as meaningful. `ITEM_MOVE`, added by `99e354b` on #855,
has the same weakness: `declared.get(gid) != aid` just never matches a stale
entry. It is empty, so nothing is affected yet. Once #855 is on
`in-client-svof`, track which declared moves were seen and report the rest the
way `check_unused_renames` does, structural so it cannot be baselined.
Verified before the merge that #852 and the stack combine cleanly: both
merges build, every CI check passes at 87 and 425, and 11 deliberate breaks
(#852's four fixes, the stack's move, duplicate and rename checks, three
controls) each behaved as expected.

---

## Agreed earlier, still open

These came from sessions before 2026-09-21 and each has a memory holding the
detail. Do not restate their content here.

| work | status | memory |
|---|---|---|
| The affliction name-space cleanup, five steps ending in `svo.dict` as the single source of truth | agreed 2026-08-23, first batch merged as #850 | `svof-name-space-cleanup-backlog`, `svof-affliction-name-topology` |
| Two dead diagnose triggers, `blistered` and `pyre`, as one small PR. Can land before the burning work, and helps it | agreed 2026-08-30, fixed in draft #862 | `svof-dead-diag-triggers` |
| The `asleep` bug, its own PR. Not a mechanical fix: correcting the guard makes a kill loop run for the first time | agreed, wants thought and live testing | `svof-review-followups` |
| Non-blocking findings from the 2026-08-23 review of #850 | open | `svof-review-followups` |

## The repo's own backlog

`CLAUDE.md` has a **Still open** section covering release state, the muddler
directory-read-order bug, the reference xmls, CI coverage for the live tests,
and the rest. It is loaded every session, so it is not repeated here. Read it
there and keep it authoritative for anything repo-wide.

The first item in it is the one that gates the others: nothing has shipped as a
package yet, `fork-version-66` and `in-client-svof` each carry one commit the
other does not, and both need reconciling before a release.
