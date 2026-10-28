# Plan: `vcustomaff`, defining afflictions svof doesn't know

Written 2026-10-20, against `defences-single-source` at `3daf75b` (#866).
Stacks on #866, because it reuses `vcustomdef`'s surface.

## The user's choices, 2026-10-20

1. **New afflictions first.** The first version defines afflictions svof
   doesn't know. Changing svof's own comes later: their lines are about 2,300
   fixed trigger items, not data, unlike the defence records `vcustomdef`
   changes.
2. **Both name spaces.** The renames in the name-space backlog stay their own
   work. Clash checks test a new name against svof's names and GMCP's names
   alike, because 45 GMCP names map to a different svof name and some cross
   over (GMCP `mangledleftarm` is svof `mutilatedleftarm`).
3. **The game's commands** are `AFFLICTION LIST` and `AFFLICTION SHOW <aff>`,
   the counterparts of `DEFENCE LIST` and `DEFENCE SHOW`.

## The game's record

`AFFLICTION LIST` prints "All afflictions", a rule, then one name to a line,
a page at a time, with `[Type MORE if you wish to continue reading. (10%
shown)]`. It reads the way `DEFENCE LIST` does, so `custom_gamelist`'s page
reader carries over.

`AFFLICTION SHOW <aff>` (the user's captures, 2026-10-20):

```
Affliction:         Addiction to curatives
Diagnose:           suffering from addiction.
Afflicted msg:      You feel a terrible hunger grow within you.
Cured msg:          Your terrible addiction seems to wane.
Cure(s):            Eat Ginseng / Eat Ferrum
Description:        Addiction causes you to slurp your elixirs and tonics
thirstily, using twice as many sips. ...
NoRandomCure:       No
WhisperingMadness:  Yes
Enlighten:          Yes
Tzantza:            Yes
Accentato:          Yes
CadmusCurse:        No
```

A timed affliction has `Afflicted msg: none`, `Cured msg: none`, an
`Expire msg:`, `Cure(s): Time`, and a last `Default time: 15 seconds` line.

What each field gives a definition:

| Field | Used for |
|---|---|
| `Affliction` | the reply's subject. It's a display name ("Addiction to curatives") with no GMCP name in brackets, so the reply is matched on the name's start, as `answers()` already allows |
| `Diagnose` | the DIAGNOSE line, fed to `svo.valid.diag(name)` |
| `Afflicted msg` | the gain line, unless `none` |
| `Cured msg` | the cure line, unless `none` |
| `Expire msg` | the line a timed affliction ends on |
| `Cure(s)` | the cure actions, alternatives split on `/` |
| `NoRandomCure` | `Yes` keeps it out of tree, shrugging, panacea and other random cures (the user, 2026-10-20) |
| `Default time` | how long a timed affliction lasts. Every timed affliction has one (the user, 2026-10-20) |
| `Description` | shown, not used |
| `WhisperingMadness` | `Yes` makes it one of svof's madness afflictions (the user, 2026-10-20): its cures get the `not affs.madness` guard svof's own mental cures have, and it joins `madness_affs` in `Empty_cure_handling.lua`, which a herb cure skips while you have madness |
| `Enlighten`, `Tzantza`, `Accentato`, `CadmusCurse` | stored, not used (the user, 2026-10-20) |

GMCP's `Char.Afflictions` entries already carry the cure, for example
`{"cure":"EAT KELP","name":"clumsiness",...}` in the login capture, so a
definition made from an affliction you have takes its GMCP name and cure
without asking the game. GMCP gives one cure, not the alternatives, and an
empty one for some. The two fight captures hold these forms: `EAT <herb>`,
`APPLY <salve> TO <place>`, `APPLY <salve>` with no place, `SMOKE <herb>`,
`SIP <elixir>` and `STAND`.

Values wrap onto the next line at the game's screen width, as in `Description`
and `Expire msg`. The defence reader joins those already (`fetch_wraps`).

## Order of work

No live testing in Mudlet while the user is playing (2026-10-20). So step 3
comes first, then steps 1, 2 and 4 against the cure forms known so far, and
step 0 once Mudlet is free. Step 1 refuses a cure form it doesn't know, so
step 0 only adds forms. Nothing built before it has to change.

## Step 0. Capture the game's whole record, and check svof's own against it

On muddlertest, with svof paused, once Mudlet is free: `AFFLICTION LIST`, then `AFFLICTION SHOW`
for every name, saved as a generated file,
`claude-notes/reference/affliction_show.lua`. It's the only full source for
which cure forms exist, so step 1 is built against it, not against three
samples.

Then a check script compares svof's own data with it, and reports:

- `NoRandomCure` against svof's tree, shrug and panacea lists. This settles
  the six tree names still waiting on the owner's in-game confirmation.
- `Cure(s)` against each svof affliction's cure actions.
- `Cure(s): Time` and `Default time` against svof's timed afflictions and
  their waits, such as the unverified `customwait = 30` on `flamefisted`.
- `Afflicted msg`, `Cured msg` and `Diagnose` against svof's trigger
  patterns, through the catalog in step 3.
- `WhisperingMadness` against `madness_affs` and the `not affs.madness`
  guards on svof's own cures.

Findings are recorded, not fixed here. Each fix changes behaviour, so each is
its own commit and the owner's call, the way the tree lists were.

## Step 1. `svo.basicaff(name, spec)`, for new afflictions only

A builder that makes a dictionary entry from a table. It doesn't convert
svof's existing afflictions: that's the on-hold Part 2 of the dict-as-data
design, and nothing here needs it.

The spec, all from `AFFLICTION SHOW` or GMCP, with the player able to change
each:

- `gmcp`: the GMCP name, taken only when the game confirms it, as for defences
- `gain`, `cured`, `expire`, `diag`: lines, each one or more, with
  `gainpattern` and the like for lines that vary
- `cures`: a list such as `{ "eat ginseng", "eat ferrum" }`
- `norandomcure`, `time`

From `cures` it builds one action per balance in svof's usual shape: an `aff`
block, a `gone` block, and for each cure an action on that balance whose
`isadvisable` is "afflicted, and the cure's balance is up", and whose
`oncompleted` removes the affliction. The full list of cure forms comes from
step 0. The ones seen so far:

- `Eat <herb>`: herb balance, through `rift` for the herb and its mineral, so
  "Eat Ginseng / Eat Ferrum" is one action, as svof's own entries do it.
  `rift` loads after `dict` (single-source plan correction A), so this works
  only because the builder runs at registration, after systemstart.
- `Apply <salve> to <place>`, and `Apply <salve>` with no place: salve
  balance.
- `Smoke <herb>`: smoke balance, through svof's pipes.
- `Sip <elixir>`: the elixir's balance, sip or purgative, as svof's own
  entries split them.
- `Stand`: balance and equilibrium, as svof's `prone` does it.
- `Time`: no action. The affliction is removed by its expire line, or by a
  timer of `Default time` seconds.

A `WhisperingMadness` definition's cures also get the `not affs.madness`
guard.

A cure form the builder doesn't know is refused with its text, rather than
guessed.

## Step 2. Register and unregister

`svo.afflictions.register(name, spec)` and `unregister`, the counterparts of
`defences.register`. Registering:

- puts the entry in `svo.dict` and runs the part of `dict_setup` that one
  entry needs
- adds `sstosvoa[gmcp] = name`, so GMCP's Add, Remove and List track it,
  including the claim gate from #858
- makes temporary triggers for its lines, recorded so unregistering and the
  next systemstart remove them. Gain and cure lines go through lifevision
  like svof's own
- gives each cure action a priority place, kept across sessions as `vcustomdef`
  keeps a defined defence's
- adds it to the random-cure lists unless `norandomcure`
- adds it to `madness_affs` when it's a madness affliction. That list is local
  to `Empty_cure_handling.lua` today, so it moves onto `empty`, with svof's
  own 15 names unchanged

Found while building step 1 (2026-10-20), so registering also has to:

- **Join the cure-line handlers' sets.** `herb_cured_<aff>`, `smoke_cured_`,
  `salve_cured_` and `focus_cured_` are made by four loops in
  `Main_trigger_functions.lua`, each from a fixed list, and each looks for
  any action in flight that uses the same cure, because the game picks which
  affliction a cure takes. svof eating kelp for a defined affliction, and
  the game curing clumsiness, needs clumsiness's handler to find that
  action. So the loops read a defined affliction's actions at call time,
  from a table registering fills, and a defined affliction gets a
  `herb_cured_<name>` of its own the same way.
- **Join svof's empty-cure handlers.** An empty kelp aimed at clumsiness
  rules out a defined kelp affliction too. Step 1 already has a defined
  affliction's own empty cure run svof's handler for that cure and then rule
  itself out. The reverse is what's left: `empty.herb_affs` and
  `empty.madness_affs` are public now (step 1), so registering adds the name
  to the herb's list, and the smoke, salve and sip handlers, whose lists are
  still literals, get the same treatment.
- **Make `simple<name>`**, the gain handler the `Simple_aff_trigger_functions.lua`
  loop makes for every entry with an `aff` block at load, and add its cures
  to `sys.input_to_actions`, which maps a command you type to the action.

**Where it lives.** A script of its own, `Custom afflictions`
(`Custom_afflictions.lua`), with the loader `customaffs` straight after
`defences` and before `prio` (the user, 2026-10-20). `verify_merged` refuses
a new top-level item by design, so it's declared in a new `TOP_LEVEL_ADDED`
list, which keeps it in the load order check and digests its whole tree.
Moving `vcustomdef` into a `Custom defences` script waits for #866 to merge
(TASKS). Until then, step 4 reaches the `vcustomdef` helpers it shares
through a table `Defences.lua` makes public.

`Stand` isn't a cure form step 1 takes: svof's one stand cure is `prone`'s,
whose conditions are about being knocked down. It's refused like any other
unknown form, until step 0 shows an affliction that needs it.

Under serverside, serverside cures it, as it cures every affliction the game
has, and svof tracks it and sets its serverside priority. With serverside off,
svof cures it with the actions from step 1.

## Step 3. A catalog of svof's own affliction lines

Defence clash checks read the defence records. Affliction lines live in
trigger items, so a generated catalog, like `defence_catalog.lua`, lists each
trigger pattern with the affliction its script adds or cures. It's built from
`src/triggers` by a tool and checked as a gate, so it can't go stale. Clash
checks and step 0's comparison both read it.

## Step 4. `vcustomaff`

The same forms as `vcustomdef`, saved in `svo/custom/affs`:

- `vcustomaff` lists your definitions, with links
- `vcustomaff <name>` starts one, filled from `AFFLICTION SHOW` and from GMCP
  when you have it
- `vcustomaff game` reads `AFFLICTION LIST` and lists the afflictions svof
  doesn't know, as links. A second section lists the ones svof knows under
  another name, as `gmcpname (svofname)` (the user, 2026-10-20)
- fields, `test`, `install`, `delete`, `export [file]`, `import <file>`

Clashes are refused on install and at every load: a name in either name space,
a GMCP name svof maps already, or a line or pattern one of svof's triggers
matches.

### Built, 2026-10-20

`svo.gamereader.show` and `svo.gamereader.list` are the readers `vcustomdef`
had, made shared at the user's word ("Share, but rename the function"), with
`vcustomdef` using them unchanged. `vcustomaff` sets up its own pair. The
game facts it needed, from the user, 2026-10-20:

- `AFFLICTION SHOW` for a name the game doesn't have prints "There is no
  such affliction."
- `MORE` past the end of `AFFLICTION LIST` prints the line `DEFENCE LIST`'s
  does
- every name `AFFLICTION LIST` shows is a GMCP name, as in `DEFENCE LIST`

The trigger catalog also leaves out a filter trigger's children, which match
what it captured, and a substring or start-of-line pattern that matches lines
in general, such as `Damaged arm`'s `You`.

## Tests

- `tools/test_afflictions.lua` on `svof_world`, for each class: build,
  register, gain by line and by GMCP, cure on each balance, a timed
  affliction expiring by line and by timer, unregister leaving nothing, and
  each clash refused. Each feature's parts are switched off in turn to show a
  check fails, as for defences.
- The catalog gate, and `verify_merged --baseline` as usual.
- A live run on muddlertest: define one from `AFFLICTION SHOW`, and gain and
  cure it, as far as the test character can be given an affliction.

## Decisions, 2026-10-20

The user's answers to the plan's four questions:

1. `vconfig customdefinitions off` switches off affliction definitions too.
2. `vcustomaff game` lists the afflictions svof knows under another name in
   a section of their own, as `gmcpname (svofname)`.
3. Every timed affliction has a `Default time`, as far as the user knows, so
   the timer always has a length. One without it is refused, rather than
   left to GMCP's Remove.
4. Of the five ability fields, only `WhisperingMadness` is used: it's svof's
   `madness`, so those afflictions join svof's madness afflictions.

## Step 0 capture and live run, 2026-10-21

The user freed Mudlet ("You can now test things on my test profile"). The
whole record is in `claude-notes/reference/affliction_show.lua`: 203 names,
every SHOW answered. It overturned three premises:

- 43 of the 203 titles don't start with the name (grievouswounds is
  "Grievously wounded", icebound "Restricted by frozen bonds"), so the SHOW
  reader matches a reply by order (`by_order`), and watches the player's own
  SHOWs so it leaves their replies alone.
- `Cure(s)` can carry a second route on its own indented line, such as
  `Focus Mind` or `Time` (22 afflictions, all svof's own). The reader joins
  entries with " / " (`entries`).
- 6 Time-cured afflictions have no `Default time` (asphyxiating, coldfate,
  cremated, deathsickness, mindravaged, silenced), against decision 3.
  Still refused; the user's call.

`AFFLICTION LIST`'s last page has no MORE prompt, so its end line never
comes; the reader already ends at the prompt.

Cure forms in the record: Eat, Smoke, Apply (epidermal, mending, caloric,
restoration, health), Sip (immunity, health), Focus Mind, Time, Writhe,
Concentrate, Compose, Stand, Wake. Of the 33 svof doesn't know, 4 can't be
installed for their cure (Apply Health To Torso, Sip Health, Writhe, or no
`Cure(s)` line at all) and 6 for the missing time. mindravaged and tonguetied
are in `svo.dict` but GMCP doesn't map them.

The catalog refused 9 of the 33 falsely. It now records triggers the way
Mudlet runs them: AND triggers with a delta of 0 (`all`), fire-length-0
chain children with their parents' patterns (`need`), spacer triggers'
children as plain lines, svo diag's children as DIAGNOSE lines (`diag`), and
other chains' children left out. A Time-only affliction's Cured msg now ends
it, as accentato's does.

Live on muddlertest: `vcustomaff game`, SHOW fills (by order too, both
orders of the player's own SHOW), install, gain and cure by line and GMCP,
relaunch, delete. A cure line alone doesn't remove an affliction GMCP still
lists (`gmcp_refuse_remove`), by design. The profile was restored from a
checksummed backup.

Still to do: step 0's comparison of svof's own data against the record.

## Tracking only, 2026-10-22

The user: "afflictions that cannot be cured should only be tracked indeed."
`svo.affcures` keeps a cure svof can't give as `{ kind = 'game', text }`,
and no `Cure(s)` as no cures; `basicaff` builds no action for either, and
with no cure of svof's the cure line runs the entry's gone. 27 of the 33
afflictions svof doesn't know install now. The five left are timed with no
`Default time` in the capture, which the user believes every timed one has;
asked again with the captured lines.

## Live run, 2026-10-23 (#871 at dcd4963)

The user's go-ahead: "You can use my test profile now for it". Session W2 on
muddlertest, a Serpent, serverside off, 34 checks, all pass:

- `icebound` (Cure(s): Writhe) filled from AFFLICTION SHOW, installed with no
  curing action of svof's (only aff and gone); its gain line fired
  `simpleicebound` and, with GMCP's Add, tracked it; its cure line fired
  `icebound_cured` and, with GMCP's Remove, ended it.
- `deathsickness` (Cure(s): Time, no Default time) installed with no timer,
  lasted 8s on GMCP's Add alone, ended on GMCP's Remove alone, and its gain
  and cure lines fired their handlers with GMCP's Add and Remove.
- Both deleted; nothing left in the dictionary.

Two traps: the first run (W1) picked `lapsingconsciousness`, which svof maps
to `false` on purpose and rightly refuses to define; and the character was
blind, so `ql` gave "You are blind and can see nothing but darkness." and no
exits line for the one-shot feed. W2 feeds on either. The profile was
backed up (tar plus sha1 of 214 files), restored after, and matched by
checksum; the run's copy is kept beside the backup.

#866's open premise, checked offline the same day: in
`svof-live-testing/captures/fight2-death.jsonl` the game sent a GMCP Remove
for each of the four defences held (mindseye, insomnia, blindness,
deafness), all before hp read 0. That character had no speed.

## Step 0 comparison, 2026-10-23

`reference/step0-comparison.lua` (run from the svof-affs checkout) compares
svof's entries against `reference/affliction_show.lua`; its output is
`reference/step0-comparison-2026-10-23.txt`. 149 of the 203 map to an svof
entry with an aff block. Expected differences, not findings: Writhe, Stand,
Wake, Concentrate and Compose are svof's misc actions; Apply Health is on
svof's sip balance; fear's focus is switched off; insomnia's cohosh raises
the defence. What is left, for the user to decide, one commit each:

- **Cures.** hypochondria: the game says lobelia/argentum, svof eats
  kelp/aurum. madness (GMCP whisperingmadness): the game says
  lobelia/argentum and no random cure, svof smokes elm/cinnabar and tree
  cures it. (Both fixed in #874, 2026-10-24; the random cures in #873.)
  peace and stuttering: the game also lists Focus Mind, svof has
  no focus action; lovers too (svof rejects). generosity: svof also focuses
  it, the game lists only bellwort.
  (Fixed in #876, 2026-10-25: focus for peace, inlove and stuttering,
  none for generosity; it also adds the Focus chain lines paranoia, dementia
  and hallucinations lacked and drops the weakness line that called nothing.)
- **Places.** The game says "To Body" for heartseed, hypothermia,
  mildtrauma, serioustrauma and calcifiedtorso, svof applies "to torso";
  frozen and shivering are "Apply Caloric", svof applies "to body".
  (Not a finding: "to torso" and "to body" cure the same, the user said
  2026-10-25. Nothing to change.)
- **Times** (game Default time against svof's waitingfor customwait):
  flamefisted and icing 15 against 30 (svof's `-- ??` guesses), voided 15
  against 20, galed 15 against 10, hecate 16 against 22, pinshot 21 against
  20, timeflux 60 against 50, revealed 60 against 80, blackout 4 against 60;
  corruption, palpatar, phlogistication and vitrification wait 999. svof's
  wait can be a fallback rather than the cure time, so each wants reading.
  (Read and fixed in #877, 2026-10-25: pinshot, timeflux, revealed, galed,
  flamefisted and icing take the game's time; hecate, blackout, voided and
  the 999s keep theirs, reasons in tools/test_timed_waits.lua. #877 also adds
  vitrified's expiry line and revealed's gain line from the record.)
- **Random cures** (NoRandomCure against `empty.treecurables`). The game
  says none, svof's tree cures: crescendo, mildconcussion, degenerate,
  deteriorate, disrupt, dissonance, horror, laceratedthroat, latched, pyre,
  madness. The game says random cures take it, svof's tree doesn't:
  indifference, manaleech, phlogistication, unweavingspirit. Whether the
  game's random cures are the tree's is the question; see the tree-curing
  evidence note.

## WhisperingMadness against svof's madness lists, 2026-10-24

The game marks 14 `WhisperingMadness: Yes`: addiction, agoraphobia,
confusion, dementia, hallucinations, hypersomnia, impatience, lovers (svof
`inlove`), loneliness, masochism, paranoia, recklessness, stupidity,
vertigo. svof acts on madness in three places, and each differs:

- **Cure actions that wait while madness is held** (dictionary
  `isadvisable`): missing agoraphobia (herb and focus), inlove (herb) and
  stupidity's herb (its focus waits); extra lethargy and illness (GMCP
  nausea), both `No`.
- **`madness_affs`** in Empty_cure_handling (an empty herb under madness
  doesn't rule these out): missing agoraphobia and inlove; extra illness and
  lethargy. (madness itself left it in #874.)
- **`empty.treeblocks.madness`** (tree can't cure these under madness):
  missing vertigo; otherwise the 13 (madness itself leaves it in #873).
- `empty.focus` returns whole under madness, so an empty focus rules out
  nothing, the non-madness focus afflictions included.

Assumes `WhisperingMadness: Yes` means madness keeps the affliction from
being cured, as svof's lists treat it; not confirmed by the game's text.

Checked against the news boards (2026-10-24): Classleads 108 (2022-10-12)
made whispering madness "just a focus balance extender", no longer giving a
focus affliction when you focus, and nothing says it blocks cures. The
field is likely that old focus pool, so the comparison above may not call
for aligning the lists at all: svof's whole madness-blocks-cures model may
predate the 2020 Occultist rework. Wants an in-game check first. See the
memory note achaea-whispering-madness.
