# svof src/ architecture and function reference

Reference for the converted svof sources at `C:\work\svof\src`, branch
`gmcp-gated-empty-cures`, commit `6af80b3` ("Give earworm a GMCP mapping and
its place in the empty elm smoke"). It was first written against `82e7f14`
("Bump the package version to 66 for the first package release"), which was
later rebased to `d7989c4`; the two differ only in `README.md`. See the
2026-09-25 update note below for what moved between `d7989c4` and `6af80b3`.

Read `svof-project-brief.md` first. That document covers why the conversion
happened, how the package is built and verified, and what is still open. This
document covers only what is inside `src/`: what each file holds, what each
function does, and how the parts call each other.

> **`svof-project-brief.md` is a Cowork project document and is not in this
> folder.** In this checkout its role is filled by `CLAUDE.md` at the repository
> root, which is loaded into every session, and by `svof-system-spec.md`
> beside this file.

> **Corrected 2026-09-21** against the same commit, by reading `src/` rather
> than re-running the original extractor. Around thirty independent figures
> reproduced to the unit, including the whole file and manifest inventory, the
> trigger counts, the `raiseEvent` and event-handler counts, the priority
> lists, the loader hot-reload split, and the entire `blistered` finding. Four
> claims were wrong and are fixed in place: the `svo.affs` shape, the signal
> count, the dictionary entry count, and the balance list. Two figures state no
> method and are now flagged rather than trusted, and a note about LF byte
> counts was added. Two defects found during that pass were added to the
> findings section. The working is in `../verification-2026-09-21.md`.
>
> Three of the four errors had one cause: a spelling assumption. Dotted against
> bracket signal names, two-space against four-space indentation, one-word
> against two-word balance names. Grep to locate, then read the construct. A
> count derived from a regex over this codebase is wrong until proved
> otherwise.

> **Reviewed again 2026-09-25** against `82e7f14`, in a detached worktree, by
> reading every file in `src/` in full: all scripts, every trigger, alias,
> key and button through a flattened dump of the manifests, and both
> resources. The review logged 71 contradictions, 72 gaps and 60 things the
> document did not cover; the working is in
> `../architecture-review-2026-09-25.md`. All are fixed in place. The largest
> corrections: the signal bus (all 65 Setup signals are rebuilt on every
> init; what survives a class change depends on where a handler is
> connected), the prompt chain and cycle, the balance controller (a hook
> registry, not the physical-balance decision), `svo.serverignore` (it means
> the server cures it), class management (counters, not trigger groups), the
> handler, codepaste and `lostbal_` descriptions, and a dozen functions
> described by their names rather than their bodies. New sections: "Workflows"
> (every recurring sequence, a signal map generated from the source, and the
> 41 Mudlet event registrations), the 24 trigger call targets nothing
> defines, and a defect index. Everything found is pre-existing.
>
> This pass's lesson is the 2026-09-21 one again, one level up: **a name in
> svof is not a description.** `svo.update` merges tables, `echosd` is a
> colour tag, `ccnop` is not a no-op, `backup` copies xml, `sitting` tracks
> nothing, `notifypriodiffs` notifies no one, and `detect_lifevision` is about
> a mask. Read the body before describing the function. A `raiseEvent` count
> that only matches parentheses misses three events, too.

> **Brought forward 2026-09-25** from `d7989c4` to `6af80b3`, the 20 commits in
> `git log --oneline d7989c4..gmcp-gated-empty-cures`. In `src/` they change
> six scripts (the dictionary, `Setup.lua`, `Empty_cure_handling.lua` and the
> three trigger-function files), rewrite one line in each of 312 trigger files
> and in one inline trigger script, and delete 10 triggers. Every other file in
> `src/` is byte-identical between the two commits, so the rest of this
> document still describes it. What changed:
>
> * The diagnose, generic-cure and tree-cure handlers are no longer generated
>   one per name from lists. Each is a single function, `svo.valid.diag`,
>   `svo.valid.generic` and `svo.valid.tree_cured`, and the trigger passes the
>   affliction's name. The `simple<aff>` handlers are generated from the
>   dictionary rather than from a list.
> * `latched` is cured by sipping health and costs sip balance when gained,
>   instead of being dropped after 20 seconds. DIAGNOSE now records
>   `latched`, `calcifiedskull` and `calcifiedtorso` instead of clearing them.
> * Every empty-cure handler except the eight that also reset a count asks
>   GMCP first, through `presume_cured`, and keeps an affliction the game
>   still reports. `Char.Afflictions.List` clears `svo.gaffl` in place instead
>   of replacing it, which that gate depends on. `empty.treecurables` holds 90
>   names, up from 80.
> * Ten triggers are gone: seven for the Healing skill, the `latched`
>   wore-off trigger, and the tree-cure triggers for bleeding and voided. The
>   `Zeal > Tenderskin` typo is fixed.
> * `earworm` is mapped in `sstosvoa` and is in `empty.smoke_elm`.
>
> Every count, byte size and line citation in the affected passages was
> measured again at both commits with the same scripts. All but three
> reproduced this document's old figure exactly before the new figure was
> used. The three were already wrong at `82e7f14` and are corrected here: the
> dictionary is about 2.4 times the size of the next-largest file, not three;
> `Config_system.lua` is the fourth-largest file, not the second; and the
> simple-handler totals were estimates. Every moved line citation was checked
> to land on the same line of code. The passages that describe changed code were rewritten from the source
> at `6af80b3`. The handler inversion also broke two trigger call sites, which
> no gate catches: see "Two call sites the handler inversion broke" under the
> findings. They are the first defects in this document that are not
> pre-existing.
>
> **Two commits past `6af80b3`, 2026-09-25.** `a73e7e5` restores those two
> trigger bodies, and `43e3ef6` adds five triggers to `General cures`, the
> blackout copies of the herb-defence lines in `Ate` that had none (blind,
> already blind, myrrh, deathsight and waterbubble). Every count in this
> document still describes `6af80b3`; those five triggers add 5 to the
> `triggers/` totals, the main tree, `General` and `General cures`.

## How this document was produced

Every `.lua` file under `src/` was read in full, and every `.json` manifest
was parsed. The trigger tree is too large and too repetitive to read as raw
JSON, so it was flattened first: a walker read all 249 `triggers.json` files,
resolved each entry's script, and emitted every trigger's name, flags, full
pattern list and full Lua body. That flattened dump was then read end to end.
It drops only the repeated JSON boilerplate keys, not content.

Structural claims in this document are counted, not estimated. The counts
below come from walking the manifests and the filesystem together, and
reconciling the two. They were then re-derived a second time, independently, as
a check: that pass found and corrected two figures, the signal count and four
of the dictionary balance-key counts. Where a claim turns on whether something
is pre-existing or was introduced by the conversion, it was also checked
against the 25 reference XMLs at the repository root.

Where behaviour is described, it comes from reading the code. Where something
is a reading of intent rather than a statement of what the code does, the text
says so. Nothing here has been observed running in Achaea. The project brief's
caution applies: structural correctness is verified, in-play behaviour is not.

The 2026-09-25 review added three runtime methods, all in the session
scratchpad rather than the repository: `flatten.py` (the manifest flattener,
one line per item with its effective active state, flags, patterns and
script), `harness.lua` (loads the handler files under a permissive stub to
read back loop-generated handler names), and `sigmap.py` (every `emit`,
`connect`, `add_pre_emit` and `add_post_emit` call, grouped by signal).

## Verified inventory

`src/` holds 3,073 files: 2,737 `.lua`, 335 `.json`, and one extensionless
data file.

| Tree | `.lua` | `.json` | Other |
|---|---|---|---|
| `scripts/` | 147 | 55 | 0 |
| `triggers/` | 2,410 | 249 | 0 |
| `aliases/` | 170 | 25 | 0 |
| `buttons/` | 8 | 3 | 0 |
| `keys/` | 1 | 3 | 0 |
| `resources/` | 1 | 0 | 1 |

Item counts, from the manifests:

| Tree | Folders | Leaf items | Folder scripts | Leaf scripts on disk | Inline scripts | No script |
|---|---|---|---|---|---|---|
| `scripts/` | 57 | 120 | 31 | 116 | 0 | 4 |
| `triggers/` | 258 | 2,531 | 7 | 2,403 | 64 | 64 |
| `aliases/` | 24 | 169 | 1 | 169 | 0 | 0 |
| `keys/` | 2 | 1 | 0 | 1 | 0 | 0 |
| `buttons/` | 2 | 8 | 0 | 8 | 0 | 0 |

Every `.lua` file on disk is reachable from a manifest. There are no orphans
in any of the five trees: 147 of 147 scripts, 2,410 of 2,410 trigger scripts,
170 of 170 alias scripts, 1 of 1 key script, 8 of 8 button scripts.

The `scripts/` tree contains 1,925,030 bytes of Lua. At `82e7f14` it was also
counted at 1,488 function definitions at column zero; that figure was not
recounted for `6af80b3`, for the reason in the note below. The real function
count is higher, because addons
and config entries define their functions inside an enclosing table or closure
where the extractor does not see them. The file reference covers those
individually.

> **The function figure is not reproducible.** The extractor is not described
> anywhere, and different column-zero spellings give 1,124, 1,229, 1,402 and
> 1,473. Treat 1,488 as an order of magnitude, not a count, until the pattern
> is published beside it.

> **Every byte count in this document is measured with LF line endings.** A
> Windows checkout stores CRLF, so the same file measures larger there by
> exactly its line count, one CR per line. Five figures were re-checked on a
> CRLF checkout of `6af80b3` and all five match once the line count is
> subtracted: `scripts/` Lua 1,978,969 less 53,939 lines; `triggers/` Lua
> 163,878 less 2,893; `triggers.json` 1,507,748 less 56,739; luanotify 14,162
> less 398; the dictionary 525,094 less 15,481. Normalise line endings, or
> measure the git blob rather than the working tree, before treating any of
> them as wrong.

The 2,410 trigger scripts total only 160,985 bytes between them, against
1,451,009 bytes of `triggers.json`. Trigger logic is thin by design: almost
every trigger body is one call into a `svo.valid.*` or `svo.defs.*` function
defined in `scripts/`. The weight is in the patterns, not the handlers.

### Two naming rules worth knowing

muddler maps names to paths differently for folders and scripts.

* A folder becomes a directory named **exactly** as the folder is named,
  spaces and punctuation included: `svo (aliases, triggers)/`.
* A script file is the item name with **spaces replaced by underscores**, plus
  `.lua`: `Main trigger functions` becomes `Main_trigger_functions.lua`.

A folder can carry its own script. The file sits **beside** the directory, not
inside it: `svo Utilities/` and `svo_Utilities.lua` are siblings. Thirty-one
script folders, seven trigger folders and one alias folder use this.

Getting either rule wrong makes a mapping pass report large numbers of orphan
and missing files that do not exist. Both rules were confirmed against the
filesystem before the counts above were taken.

### Three structural observations

These are stated as findings, not defects. Each was checked individually
rather than assumed from a pattern.

**Ten trigger folders declare a directory that is not on disk.** All ten have
no patterns, no children and no script, and all are marked active. They are
empty groups, and an empty group has nothing to write to disk. They are
`svo UI Experiments`, `Charnel`, `Emulation`, `Anathema` and `Excision` under
`svo (aliases, triggers)/svo`, and `ashtan`, `hashan`, `cyrene`, `eleusis` and
`tsol'aa village` under `Drazik's svo bashing triggers`. The same thing
happens three times in `scripts/`, where `svo Meteor Compress`, `commandTracker`
and `svo Time Tracking` are groups whose only content is their own script.

**Sixty-four leaf triggers have no script at all.** These are pure pattern
containers. A multiline parent matches the opening line and holds the gate
open, and its children carry the logic. The trigger reference gives examples.

**Four script items have an empty body on purpose.** This is a Mudlet idiom,
not an omission. A script item registered on an event calls the function named
after the item, and that function may be defined elsewhere. `svo.savesettings`
registers `sysExitEvent` and is assigned at `Controllers.lua:620` as
`svo.savesettings = svo.QQ`. `ndb.finished_honors` registers
`NameDB finished honors` and is defined in `ndb_main_code.lua`. The other two,
`ndb.support` and `ndb.highlighter`, are plain folders. A sibling file,
`ndb.updatebyhonors.lua`, documents the idiom in its only line:
`-- this just registers the handler, the script is supposed to be blank`.
## Architecture

### The shape of the system

svof is a reactive loop wrapped around one decision. Text arrives from the
game, the system works out what state it is in, and then answers a single
question: given everything I know right now, what is the one most important
thing to do? It sends that, waits for the next prompt, and asks again.

Everything in `src/` is in service of that loop. The five trees each hold one
kind of Mudlet item, and each kind has one job:

* **`triggers/`** turns game text into facts. 2,531 triggers, almost all of
  them one line of Lua calling a named handler.
* **`scripts/`** holds the state, the rules and the decision. 147 files.
* **`aliases/`** is the user's control panel. 169 commands.
* **`keys/`** and **`buttons/`** are two small convenience surfaces.
* **`resources/`** ships two data files to the Mudlet profile folder.

A useful way to picture it: the triggers are nerve endings, `scripts/` is the
brain and spinal cord, and the aliases are the voice you use to tell the brain
what you want it to prefer.

### Six layers

Reading `scripts/` top to bottom, the code falls into six layers. Each layer
only calls downward, with one deliberate exception noted below.

```
  6  addons          limbcounter, namedb, enchanter, refiller, ...
  5  interface       aliases, config, install, custom prompt, serverside
  4  decision        dict, priorities, action system
  3  state           curing skeleton, controllers, defences
  2  input           trigger functions, diag functions, simple aff functions
  1  foundation      setup, misc, Penlight, luanotify
```

The exception is that layer 2 writes directly into layer 3's state tables
(`svo.addaff`, `svo.rmaff`). That is the point of layer 2: it exists to
translate text into state changes, so it has to reach into state.

### Load order

Every script file that is a subsystem ends by defining one function:

```lua
svo.loader.<name> = function() ... end
```

Defining the loader does nothing. The body only runs when
`svo_init_system()` calls it. This is what makes load order independent of
item order in the package, which matters because muddler's item order is not
something the sources control directly.

`svo_init_system` is registered on `sysLoadEvent` and `sysInstall`. It bails
out early and silently if any of four things is not true:

1. `svo.systemloaded` is already set. Prevents double initialisation.
2. Penlight is loaded, tested as `package.loaded['pl.tablex']`.
3. All 22 required subsystems are present in `svo.loader`, tested with
   `table.n_complement` against `tablex.keys(svo.loader)`.
4. Mudlet is at least 3.20, tested with `mudletOlderThan(3,20)`. This one is
   not silent: it prints a message telling you to update.

The silent bails are what make the design work. Mudlet runs package scripts in
whatever order it likes, so `svo_init_system` may be reached several times
before the last loader has been defined. Each early attempt does nothing. The
attempt that finds all 22 present is the one that runs.

It then clears `svo.signals` (so a class change gets a clean bus), calls the
22 required loaders in order, emits `svo.signals.systemstart`, sets
`svo.systemloaded`, and raises `svo system loaded`.

Clearing `svo.signals` happens at `svo_init_system.lua:74`, before any loader
runs, and every line of `Setup.lua` from 10 to 2074 is inside
`svo.loader.setup`. So each init, including every class change, builds a
completely new bus, and nothing in `src/` calls a loader any other way. What
decides whether a connection survives a class change is therefore not how the
signal is spelled but **where the `connect` call is**:

* A `connect` inside a loader body runs again on every init and is remade on
  the new bus.
* A `connect` at script-body time, outside any loader, attaches to the first
  bus only. It is silently lost on the first class change, and dragonform
  counts as one. NameDB is the large case: see "The addons".
* The same split applies to temp triggers and anonymous Mudlet handlers
  created inside a loader: they are created again on every init, and the
  earlier ones stay alive unless something kills them. See "Workflows".

Required subsystems, in the order they are called:

```
setup    misc     empty    dict     sk       controllers  action   pipes
rift     diag     valid_simple      valid_main           config   install
aliases  defences prio     parry    funnies  dor      customprompt serverside
```

The order is a dependency chain. `setup` creates the namespaces and the signal
bus, so it is first. `misc` provides the echo and string helpers everything
else uses. `dict` needs both, and `sk` needs `dict`. `controllers` drives the
prompt and needs `sk`. `config` needs the option handlers that earlier
subsystems installed, and `serverside` is last because it mirrors decisions
that everything before it makes.

`peopletracker` appears in the required list but commented out. It is loaded
as an addon instead.

After the core is up, ten addons load in order:

```
limbcounter  priestreporter  inker    mindnet   burncounter
elistsorter  enchanter       refiller peopletracker  fishdist
```

Each is called only `if svo.loader[addon]` is defined, so an addon that was
removed does not break the sequence.

Two things happen around this. If GMCP already has `Char.Name` when the system
loads, which is the case when you install while logged in, it emits
`svo.signals.gmcpcharname` so the GMCP-driven setup catches up. And if the
global `force_init` is set, it sends a bare newline over the socket to
provoke a fresh prompt, which is what makes a class change re-sync the prompt
statistics.

**The consequence for anyone adding code:** anything that needs the core must
register on `svo system loaded`. `tempTimer(0, ...)` used to be enough back
when svof was 25 modules. In one package it is not, because a package script
can run before `svo_init_system` does. The project brief records this as a
class of bug the conversion kept hitting, and the limbcounter's
`svo_count_show.lua` carries the fix in its current form.

### Namespaces

`svo` is the single global. Everything else is a table inside it, and most
files start by taking a local alias so the hot paths are one table lookup
shorter.

| Alias | Full name | Holds |
|---|---|---|
| `sk` | `svo.sk` | curing skeleton internals |
| `cnrl` | `svo.cnrl` | controller internals |
| `defs`, `defences` | `svo.defs`, `svo.defences` | defence handlers and defence state |
| `prio` | `svo.prio` | priority list management |
| `sp`, `sps` | `svo.sp`, `svo.sps` | parry commands and parry internals |
| `rift` | `svo.rift` | rift and inventory |
| `cp`, `cpp` | `svo.cp`, `svo.cpp` | custom prompt definitions and computed tags |
| `empty` | `svo.empty` | empty-cure fallbacks |
| `me` | `svo.me` | the character |
| `codepaste` | `svo.codepaste` | shared closures reused across dictionary entries |
| `ndb` | global `ndb` | NameDB, which is its own namespace |
| `ofs` | `svo.ofs` | offering module |
| `sys` | `svo.sys` | runtime flags: slow-curing mode (`sync`), the balance tick and action timeout, lag counters, `deffing`, `charname`, the in-game custom prompt string. The peopletracker also hangs its label functions on it |
| `html5log` | global | the HTML logger |

`valid` is `svo.valid` and holds the trigger handlers. `defs` does double duty:
`svo.defs.*` functions are defence-related trigger handlers, while
`svo.defs.switch`, `svo.defs.keepup` and `svo.defs.defup` are the user-facing
defence mode commands.

### State

Six tables carry most of the runtime state, and four more carry the rest.
`svo.affl` is the **public** affliction list, keyed by svof name, holding a
stopwatch and a count, and it is what raises `svo got aff` and `svo lost aff`.
`svo.gaffl` is the raw GMCP mirror and is keyed by the **game's** name, not
svof's: bare at level 1, `"name (2)"` and up above it. The empty-cure gate
reads it (see `Empty_cure_handling.lua`), and a `Char.Afflictions.List` clears
it in place rather than replacing it. Before `f2ab04f` the List handler
assigned `svo.gaffl = {}`, which left the public name pointing at an empty
table while Setup's own file-local alias kept the real one.
`svo.affsp` holds suspicions set by triggers before confirmation.
`svo.gdefc` is the defence equivalent of `gaffl`. Confusing any of these with
`svo.affs` is a documented source of real bugs, so do not treat the six below
as the whole picture.

**`svo.me`** is the character. Name, class, city, health, mana, endurance,
willpower and their maxima, `me.doqueue` and `me.dofreequeue` (the queued
command lists), `me.gametarget` and `me.gametargethp`, `me.wielded`,
`me.locatelist`, `me.lustlist`, `me.hoistlist`, and the timing state the lag
detection uses.

**`svo.affs`** maps affliction name to a **two-field table**, never to `true`
and never to a number:

```lua
  svo.affs[name] = {
    p  = <the svo.dict entry for this affliction>,
    sw = <a running stopwatch>,
  }                                   -- Curing_skeleton.lua:1293
```

This is the working set of what is wrong with you, and the file reference
under `Curing_skeleton.lua` describes the same construction.

**The count is not on this table.** It lives at `svo.affs[name].p.count`,
which is the same table as `svo.dict[name].count`, and is mirrored into
`svo.affl[name].count` by `svo.updateaffcount`. `svo.affs` carries only a
`__tostring` metamethod and no `__index`, so reading `affs.pyre.count` returns
nil rather than falling through, and comparing that nil raises.

That is not hypothetical. Five burn conditions read `affs.pyre.count`, raised
out of an unprotected `isadvisable`, and aborted `svo.onprompt` on every prompt
while you held a burn and a pyre together. Pull request 853 fixed all five to
`affs.pyre.p.count`. Read `.p.count`.

**`svo.defc`** maps defence name to `true`. `defc` is the current defences;
`svo.defences` is the machinery around them.

**`svo.bals`** maps balance name to `true` when you have it, with one
exception. The balance names are the currency the whole decision layer trades
in, and the authoritative list is the reset function at
`Alias_functions.lua:950`, which sets thirteen unconditionally:

```
balance  equilibrium  herb    salve   sip     purgative  smoke
moss     focus        tree    leftarm rightarm  dragonheal
```

and twelve more only behind a skillset or class gate: `voice` (voicecraft),
`hydra` (Druid), `entities` (domination), `prayer` (zeal), `shrugging`
(venom), `fitness` (seven skillsets), `rage` (the four rage skillsets),
`humour` and `homunculus` (physiology), `word` (terminus), `anathema`
(anathema), and `wrathbal` (excision). Twenty-five names in total, and which
of them exist depends on your class.

`svo.reset.bals` runs on `systemstart`. Its comment says it builds a new
table, but it sets fields on the existing `svo.bals` in place, so a gated
balance from an earlier class survives a class change. It then raises
`svo got balance` once for every key in `svo.bals`.

Two details that matter when reading a condition. The limb balances are
**`leftarm`** and `rightarm`, one word each: there is no `arms` balance and no
two-word spelling anywhere. And those two alone initialise to the **string
`'unset'`**, not `true`, which is truthy, so a limb balance reads as held until
the game says otherwise.

**`svo.conf`** is the flat configuration table: 106 base options plus up to 23
more that appear only for certain skillsets. See `Config_system.lua` in the
file reference. Both figures are reproducible. The 23 is the number of
distinct option names across the 17 conditional `config_dict:insert(1, ...)`
calls: kaido 5, voicecraft 1, weaponmastery 1, zeal 1, venom 2, devotion 1,
woodlore 1, metamorphosis 3, shindo 2, the fitness group 2, the rage group 2,
and `parry` or `guarding` 2. No single class gets all 23.

**`svo.sys`** holds the system's runtime flags rather than game state:
`sync` (slow-curing mode), `balanceid` and `balancetick` (the balance
controller's once-per-tick guard), `actiontimeout` and `actiontimeoutid`,
`lagcount` and `lagcountmax`, `deffing`, `manualdiag`, `canoutr`, and the
`sys.input_to_actions` map that turns a typed cure into a tracked action.
`Setup.lua` puts back the defaults for `sync`, the balance tick, the lag
counters, `actiontimeout` and `canoutr` on every init.

**`svo.dict`** is the action dictionary and is the centre of the system.
"The four central mechanisms" covers it in full.

### The signal bus

`src/scripts/svo (core)/3rdparty/notify/` vendors luanotify: `signal.lua` and
`double_queue.lua`, 13,764 bytes together. A signal is an object with
`connect`, `disconnect`, `emit`, `emit_with_accumulator`, `block`, `unblock`,
`add_pre_emit`, `remove_pre_emit`, `add_post_emit`, `remove_post_emit` and
`stop`. Handlers live in a `double_queue`, a FIFO with a `data_position` index
so a named handler can be found and removed in one step rather than scanned
for.

This copy is **modified from upstream**, and the changes matter:

* `connect(fn, name)`, `add_pre_emit(fn, name)` and `add_post_emit(fn, name)`
  take a name, and connecting a name that is already present **replaces**
  that handler. That is what makes a named `connect` safe to run twice on one
  bus. 203 of the 214 `connect` calls in `src/` pass a name.
* Pre-emit functions run **last in, first out**, not first in, first out as
  the docstring says: both lists use `push_front`.
* `block` and `unblock` are counted per handler. A handler blocked twice needs
  two unblocks.
* Both files register through Lua 5.1's `module()`.

**Latent defect in the replacement.** The name is looked up in one queue
(`handler_names`) and the handler is removed by that index from another
(`handlers`). `DoubleQueue:push_back` ignores a value already present, and
`disconnect` never removes the name. So every unnamed `connect` after the
first on a signal pushes a handler with no matching `""` name, and the two
queues drift apart. Once they are misaligned, reconnecting a name that is
present removes a **different** handler and leaves the old one connected.
The drift is one step for Setup's two unnamed `systemstart` handlers, and it
grows during play wherever an unnamed handler is connected and disconnected
repeatedly: the limbcounter on `before_prompt_processing` for every limb hit,
the peopletracker on `newarea` each time `clearlabels` is toggled, and the
elistsorter on `elistcaptured` per dispose. Within one init no name repeats
on those signals, and the only duplicated name in `src/`
(`sk.check_burrow_pause` on `gmcproominfo`) connects the same function, so
the defect bites only when a loader reruns on a live bus, for example when a
script is saved in the Mudlet editor.

`Setup.lua` builds **65** signals, and two more are created outside it:
`elistcaptured` in the elistsorter and `svo.signals["namedb finished honors"]`
at `ndb_main_code.lua:912`. **67 in total.** `morphskillchanged` is created
only for metamorphosis, so every other class has 64 from Setup.

They are written two ways, and the spelling matters more than it looks. Fifty
three use the dotted, idempotent form:

```lua
signals.changecuring = signals.changecuring or luanotify.signal.new()
```

Twelve more, at `Setup.lua:991` to `1002`, use a bracket form with a
space-containing name, and **no `or` guard**:

```lua
signals["svo config changed"] = luanotify.signal.new()
```

Those twelve are named after Mudlet events: `mmapper updated pdb`,
`svo config changed`, `svo defup changed`, `svo got balance`,
`svo ignore changed`, `svo keepup changed`, `svo lost balance`,
`svo prio changed`, `svo serverignore changed`,
`svo switched defence mode`, `svo system loaded` and `svo done defup`. So the
split described in the next section, signals internal and Mudlet events
public, is not quite clean: twelve signals carry the public event names
exactly.

They carry those names on purpose. `svo.events(event, ...)`, the function
behind `svo_events`, emits `signals[event:lower()]` when that signal exists.
The twelve bracket names are already lower case, so each of those Mudlet
events turns into the internal signal of the same name. The same lookup maps
`sysDataSendRequest` to `sysdatasendrequest`, `sysExitEvent` to
`sysexitevent`, `CharName` to `charname`, `RoomBrief` to `roombrief`, and
`NameDB finished honors` to NameDB's own signal. Two registrations resolve to
nothing: there is no `charvitals` or `roomnum` signal, so `CharVitals` and
`RoomNum` on `svo_events` are dead ATCP leftovers.

The two spellings behave the same on the normal path. Setup runs only inside
its loader, after `svo.signals` has been cleared, so the `or` guard never
finds an existing signal and all 65 are new objects on every init. An earlier
version of this document said the bracket twelve were replaced on a class
change while the other 53 survived. That was wrong: all 65 are replaced, and
what survives is decided by where each handler is connected (see "Load
order").

The four groups below cover the 53 dotted signals plus `elistcaptured`.

*Lifecycle:* `systemstart`, `systemend`, `connected`, `relogin`, `quit`,
`loadconfig`, `loadedconfig`, `saveconfig`, `sysexitevent`.

*GMCP fan-out:* one signal per GMCP message the system cares about, named
after the message with the dots stripped: `gmcpcharvitals`,
`gmcpcharstatus`, `gmcpcharname`, `gmcpcharafflictionslist`,
`gmcpcharafflictionsadd`, `gmcpcharafflictionsremove`,
`gmcpchardefenceslist`, `gmcpchardefencesadd`, `gmcpchardefencesremove`,
`gmcpcharitemslist`, `gmcpcharitemsadd`, `gmcpcharitemsremove`,
`gmcpcharitemsupdate`, `gmcpcharskillsinfo`, `gmcpcharskillslist`,
`gmcpiretimelist`, `gmcpiretimeupdate`, `gmcproominfo`, `roombrief`,
`enablegmcp`.

*Prompt cycle:* `before_prompt_processing`, `after_prompt_processing`,
`after_lifevision_processing`, `sync`.

*State change:* `svogotaff`, `svolostaff`, `curedwith_focus`, `limbhit`,
`changecuring`, `curemethodchanged`, `morphskillchanged`, `dragonform`,
`changed_maxhealth`, `changed_maxmana`, `canoutr`, `removed_from_rift`,
`elistcaptured`, `moved`, `newroom`, `newarea`, `anyroom`, `orgchanged`,
`charname`, `donedefup`, `sysdatasendrequest`.

Some signals are wired to each other at definition time rather than at use
time. `systemstart` connects a handler that emits `canoutr`. `gmcpcharname`
connects one that emits `enablegmcp`. `quit` gets two pre-emit handlers, one
emitting `saveconfig` and one raising the Mudlet event `svo quit`. Wiring the
chain where the signals are created means the ordering is in one file rather
than spread across the subsystems that care.

### Signals versus Mudlet events

svof uses both, for different audiences.

**Signals are internal.** They are synchronous, ordered, blockable and
stoppable, and they are how subsystems coordinate within one prompt cycle.
Nothing outside svof should connect to them.

**Mudlet events are the public surface.** `raiseEvent` is called with 54
distinct event names, every one a string literal. Counting them needs a
pattern that allows `raiseEvent"name"` and `raiseEvent "name"` with no
parentheses: `svo quit`, `svo got dragonform` and `svo lost dragonform` are
raised that way in `Setup.lua`, and a parenthesis-only count gives 51. The
events are fire-and-forget, and they are what a user's own scripts are meant
to hook.

The public events, grouped:

*Lifecycle:* `svo system loaded`, `svo quit`, `svo died`, `svo onshow`,
`svo enabled class`, `svo disabled class`, `svo before the prompt` (the first
line of `svo.onprompt`).

*State:* `svo got aff`, `svo lost aff`, `svo updated aff`,
`svo got def`, `svo lost def`, `svo got balance`, `svo lost balance`,
`svo balanceful ready`, `svo balanceless ready`, `svo got fullstats`,
`svo started fullstats`, `svo stopped fullstats`, `svo got hit by`,
`svo got dragonform`, `svo lost dragonform`, `svo rebounding start`,
`svo me.wielded updated`, `svo gametarget changed`,
`svo gametargethp changed`, `svo done with prompt`.

*Configuration:* `svo config changed` (raised 68 times, once per option that
can change at runtime), `svo prio changed`, `svo ignore changed`,
`svo serverignore changed`, `svo defup changed`, `svo keepup changed`,
`svo switched defence mode`, `svo started defup`, `svo done defup`,
`svo do changed`, `svo dofree changed`.

*Addons:* `svo limb hit`, `svo limb reset`, `svo limbcounter hit`,
`svo limbcounter reset`, `svo burncounter hit`, `svo burncounter reset`,
`svo done refilling`, `svo watchfor name changed`, `NameDB got new data`,
`NameDB saw list name`, `NameDB finished honors`, `NameDB finished all honors`,
`NameDB name deleted`, `NameDB highlightignore name changed`,
`NameDB set name changed`, `mmapper updated pdb`.

The event handler registrations live in the `.json` manifests, not the Lua.
There are 41 of them across the trees. The two central ones are
`svo (core)/Event handlers/svo_events`, which subscribes to 19 events, and
`svo_gevents`, which subscribes to the four GMCP roots. Both files are four
lines: they wrap the real handler in `pcall` and `display` the error if it
throws, so one bad handler cannot take the event loop down with it.

```lua
function svo_events(...)
	local s,m = pcall(svo.events, ...)
	if not s then display(m) end
end
```

`svo.gevents(_, key)` is the only path from GMCP into svof. It strips the dots
from the GMCP key and lowercases it, so `gmcp.Char.Afflictions.Add` becomes
`gmcpcharafflictionsadd`, and emits that signal if it exists. It reads the
full message name from its second argument, not the event name. svof relies
on Mudlet raising an event for every level of a message's name with the full
name as that argument: `Char.Afflictions.Add` can reach svof only through the
`gmcp.Char` registration. That is why four registrations (`gmcp.Char`,
`gmcp.Room`, `gmcp.Char.Status`, `gmcp.IRE.Time`) cover every subscribed
message. It also means a `Char.Status` message arrives twice, through
`gmcp.Char` and `gmcp.Char.Status`, so `gmcpcharstatus` is emitted twice per
message. Its handlers are idempotent, so the cost is only repeated work (the
`dragonform` shortlist rebuild among it). This follows from the registrations
and has not been checked against Mudlet's source or observed. Keys with no
matching signal are ignored. Because the
error is caught by the `pcall` wrapper, a GMCP handler that raises abandons
the rest of that handler and prints the error, but does not stop the next
message. The full list of the 41 registrations is under "Workflows".

### The prompt cycle

This is the loop the whole system runs on. Reading it once makes the rest of
the code legible.

**1. Text arrives.** Mudlet runs triggers against each line. Nearly every svof
trigger body is a single call, for example `svo.valid.proper_paralysis()`.
The `General > Prompt` trigger's only pattern is a Lua function that returns
true for a prompt and otherwise adds one to `svo.paragraph_length`, so every
non-prompt line is counted. The five `General > Cleanup` triggers subtract
one again for lines that must not count: a blank line, exhaling a held
breath, the rebounding aura or reflections fading, and meditation breaking.
Every `paragraph_length > 2` illusion test
depends on this count.

**2. The handler files a claim.** The handler is a `svo.valid.*` or
`svo.defs.*` function, usually in `Main_trigger_functions.lua`. It rarely
changes state itself. The usual shape is `svo.checkaction(dict.X.bal)`,
which finds or force-adds the in-flight action, followed by
`svo.lifevision.add(actions.X_bal.p, outcome, arg, lineguard)`, which files
a claim in the **lifevision** ledger described under "The four central
mechanisms". The affliction is added, the cure is credited, or the balance is
restored later, at the prompt, by the action's `oncompleted` or named
outcome. With anti-illusion on, `checkaction` does not force-add, so a line
svof did not ask for is dropped. That is the main anti-illusion check.

**3. GMCP lands.** GMCP is delivered **before** the text it accompanies. This
ordering is load-bearing and one place in the code is explicitly built around
it, in the herb-cure generator in `Main_trigger_functions.lua`:

```lua
-- sk.gmcp_cured[aff] covers the case where GMCP already removed this
-- affliction earlier in the same paragraph - GMCP is processed before
-- the text it accompanies, so affs[aff] is necessarily nil by now and
-- would otherwise make every such genuine cure look like an illusion.
```

Without that check, every real herb cure would look like an illusion, because
by the time the text handler runs the affliction is already gone from
`svo.affs`.

**4. The prompt arrives.** `General > Prompt` has four children:
`Capture flags`, `Blackout`, `Do stuffs.` and `Kai-Shin blackout`.
`Capture flags` is a **filter** trigger that captures the prompt's flag
letters. Its script records `svo.had_balance` and `svo.had_equilibrium` and
calls `svo.valid.setup_prompt()`, which clears `bals.balance`,
`bals.equilibrium` and `svo.pflags`. Its children run against the captured
letters only: `e` and `x` set the two balances, `b`, `d`, `k`, `c` and `@`
set `pflags`, and `E` sets `bals.prayer`. `Do stuffs.`, a sibling of
`Capture flags` rather than its child, compares before and after, raises
`svo lost balance` or `svo got balance` for balance and equilibrium only
(not while `svo.innews`), and calls `svo.onprompt()`. `Blackout` and
`Kai-Shin blackout` call `svo.blackout()` instead.

**5. `svo.onprompt` runs the cycle.** In order, from `Controllers.lua:240`:

* raise `svo before the prompt`, count the prompt, check blackout and the
  prompt flags
* `svo.prompt_stats()` reads `gmcp.Char.Vitals` into `stats`, then the stat
  changes are computed
* emit `before_prompt_processing`: the acrobatics prone check,
  `valid.check_life`, and `sk.onprompt_beforelifevision_do` (the anti-illusion
  `aiprompt` hooks)
* `svo.send_in_the_gnomes()`: run `svo.lifevision.validate()` to settle the
  ledger, emit `after_lifevision_processing` (the `prompttrigger` hooks,
  `cnrl.checkwarning`, the parry check), then `svo.make_gnomes_work()`
* emit `after_prompt_processing`: the custom prompt, the lock warnings,
  serverside mirrors
* `svo.defupfinish()` while deffing, `svo.fancysendall()` to echo what was
  sent, and `sk.dosendqueue()` to flush the batched commands
* record the prompt's line number and time, reset `svo.paragraph_length` to
  0, and raise `svo done with prompt`

**6. The gnomes decide.** `svo.make_gnomes_work` is a binding that the
`changecuring` signal points at one of three functions: a no-op while
`svo.logging_in`, `make_gnomes_work_sync` in slow curing (`sys.sync`), or
`make_gnomes_work_async` otherwise. The async gnome runs `work_slaves_work`,
which asks each balance's `check_*` function in a fixed order (misc for
amnesia and fear, focus, salve, sip, purgative, smoke, herb, misc again,
moss, the balanceless acts, then the balanceful acts). Most `check_*`
functions pick the single highest-priority advisable action for their
balance. `check_misc` and `check_balanceless_acts` fire every advisable
candidate. The sync gnome does nothing while any action is in flight, and
otherwise collects each balance's best candidate and does only the one with
the highest `spriority`.

The **balance controller**, `sk.balance_controller()`, is a separate and
smaller mechanism. It runs at the end of `work_slaves_work` only when the
dictionary's balanceful acts fired nothing and nothing in flight will take
balance. It does not consult the dictionary: it runs two function registries
filled by `svo.addbalanceless(name, f)` and `svo.addbalanceful(name, f)`,
which out of the box hold only the do queue (`svo check dofree` and
`svo check do`). See "Balance bookkeeping" in the workflows.

**7. The action system sends it.** `svo.doaction` records the action in
`svo.actions` and `svo.bals_in_use`, starts its timeout, and runs its
`onstart`, which sends the command through `svo.send` or the batching queue
`svo.sendc`.

**8. Back to step 1.**

### Where the interesting complexity lives

Three mechanisms carry most of the system's difficulty. Each gets its own
treatment under "The four central mechanisms".

**Illusions.** Achaea lets an opponent fabricate text that looks exactly like
a real affliction message. If svof believed all of it, an opponent could make
you cure afflictions you do not have and burn the balance you needed. The
lifevision layer is svof's answer: record what a line claims, then at prompt
time check the claims against what else was seen.

**Balance bookkeeping.** Every cure costs a balance, balances recover on their
own schedule, and some afflictions block some balances. The whole decision
layer is keyed on balance rather than on affliction, which is why the
priority lists are per balance.

**Serverside curing.** Achaea has its own curing system. svof can drive it
rather than curing directly, which means translating svof's priority lists
into the server's much smaller priority space. That space has a hard cap of 25
priorities, with 26 meaning "ignore", so svof has to compress its own ordering
into the server's. It does so silently: every position past 25 is pooled at
25, and nothing reports when that changed the order. It also has to decide,
per action, which side cures it: `svo.serverignore[action] = true` means the
server cures it and svof stays out of the way.
## The four central mechanisms

Everything else in `src/` is either feeding these four or reading from them.

### 1. The action dictionary

`Dictionary_of_actions_(affs-defs-misc).lua` is 509,613 bytes, the largest
file in the system by a factor of about 2.4 over the next, `Defences.lua`
(213,379). Its own header calls it "brains of
Svof, where it knows every action (affliction, defence, balance, etc). When to
use something, how to use something."

The `svo.dict = { ... }` literal has **267 top-level entries**, and the literal
is only **one of three** places entries reach `svo.dict`. The other two are 155
class-gated and skillset-gated `svo.dict.NAME = { ... }` assignments over 148
names, and 157 `basicdef()` calls over 134 names. Together that is **579
definitions over 542 distinct names**, of which **287 are defences**. Counting
the literal alone and calling the result "the dictionary" understates it by
more than half, mostly in defences, because almost every defence is built
outside the literal.

Each entry is one *thing*: an affliction, a defence, a balance, or a piece of
bookkeeping. Inside an entry, each key is a **balance**, and its value is the
handler for doing that thing with that balance.

```
svo.dict.asthma.herb       -- cure asthma by eating a herb
svo.dict.asthma.aff        -- what to do when you catch asthma
svo.dict.asthma.gone       -- what to do when it goes away
```

That two-level shape, action then balance, is what makes the rest of the
system possible. Nothing ever iterates the whole dictionary at prompt time.
Instead, `svo.dict_setup()` pre-sorts it into small per-balance shortlists, and
the prompt cycle only ever walks those.

Across all 267 literal entries, the balance keys used are:

| Key | Entries | Meaning |
|---|---|---|
| `gone` | 189 | the thing went away |
| `aff` | 180 | the thing was gained |
| `waitingfor` | 72 | a placeholder action, used to hold a balance while something resolves |
| `herb` | 68 | cured by eating |
| `salve` | 45 | cured by applying |
| `physical` | 26 | costs balance or equilibrium |
| `misc` | 26 | costs neither, or costs something unusual |
| `focus` | 20 | cured by Focus |
| `smoke` | 13 | cured by smoking |
| `sip` | 7 | cured by sipping |
| `purgative` | 5 | cured by a purgative |
| `happened` | 4 | an event marker |
| `moss` | 2 | cured by eating moss |
| `map`, `tempmap`, `boosted`, `weakened` | 1 each | special cases |

A handler is a table of callbacks and data. The full vocabulary:

| Field | Type | Purpose |
|---|---|---|
| `isadvisable` | function | can and should this be done right now? |
| `onstart` | function | actually send the command |
| `oncompleted` | function | it worked, update state. Nearly every handler has one, but nothing checks for it |
| `oncancel` | function | it was rolled back as an illusion |
| `onkill` | function | it was cancelled outright |
| `ontimeout` | function | it never resolved |
| `empty` | function | the cure went through and cured nothing, so you have none of the afflictions it cures: remove them (usually delegates to `svo.empty.*`, which keeps any the game still reports) |
| `onclear` | function | the negative result of an anti-illusion probe |
| `eatcure` | list | herbs that cure this, in order of preference |
| `sipcure`, `applycure`, `smokecure` | list | the potion, salve or pipe herb, read by `svo.sip`, `svo.apply` and the pipe code, and (except `applycure`) by `sys.input_to_actions` |
| `uncurable` | boolean | no cure exists; serverside sync skips it |
| `dontbatch` | boolean | in `check_misc`, at most one such action goes out per pass |
| `action` / `actions` | string / list | the literal command text |
| `aspriority` | number | priority on this balance, normal curing |
| `spriority` | number | priority on this balance, slow curing |
| `def` | boolean | this is a defence, not a cure |
| `undeffable` | boolean | serverside cannot raise this, svof must |
| `irregular` | boolean | not managed by the priority lists |
| `balanceful_act` / `balanceless_act` | boolean | whether it consumes balance |
| `customwait` / `customwaitf` | number / function | override the timeout |
| `gamename` | string | what the server calls this, when it differs |
| `onservereignore` | function | returns true if serverside should skip it. Entry-level, not handler-level |

Some fields sit on the entry rather than on a handler: `gamename`, `name`,
`count` (for levelled afflictions), `description`, `onservereignore`,
`onadded` and `onremoved` (run by `addaff` and `rmaff`), and per-entry data
such as `lovers.map`, `paradox.blocked_herb` and `rebounding.blocked`. One
more handler field, `onprioswitch`, exists on only two handlers (lines 490
and 537, health and mana healing). Serverside runs it when that action's
priority changes, so an action with no server priority of its own can mirror
the change into a server setting.

**Named outcomes.** Every other function on a handler is an outcome that a
trigger selects by name. A handler calls
`svo.lifevision.add(act, 'name', arg)`, and at the prompt the ledger runs
`act[name](arg)` instead of `act.oncompleted(arg)`. This is how one action
has several results. Examples: `noeffect`, `cured`, `fizzled`, `empty`,
`offbalance`, `nomana`, `mickey`, `all`, `helpless`, `withdrew`,
`alreadygot`, `general_cure`, `hiddencures`, `tekura`, the `relapsing` venom
checks (`camus`, `sumac` and five more), and the probe confirmations
(`sluggish`, `blehfood`, `paralysed`, `weakbreath`, `webbily`, `impaly`,
`transfixily` and others). `dict_setup` adds some that the source does not
spell out: `herb.noeffect`, `herb.mickey`, `offbalance` on focus, salve, herb
and smoke, and `focus.nomana`.
The file's own header comment is the checklist for adding one affliction, and
it is worth reading in full because it is the exact problem the project brief
lists as the deferred goal ("make `svo.dict` the single source of truth, so
adding an affliction stops requiring ~10 edits across files"). At `6af80b3`
it reads:

```
-- To add an affliction:
-- * add it in 'Dictionary of actions (affs-defs-misc)' in the dict table, with the appropriate functions and curing logic
-- * add the triggers for it (triggers section of the code editor). Each one names
--   the affliction itself, so none of these needs a list edited anywhere:
--     gaining it          svo.valid.simple<name>()      generated from the entry above
--     DIAGNOSE reports it svo.valid.diag('<name>')
--     a passive cure, or one that lands during blackout
--                         svo.valid.generic('<name>')
--     touching a tree cures it
--                         svo.valid.tree_cured('<name>')
-- * add it in 'Empty cure handling' - what a cure that cured nothing rules out
-- * add losing/curing it in 'Main trigger functions' and the appropriate triggers
-- * if gaining it needs more than "record the affliction", write that handler in
--   'Simple aff trigger functions' BELOW the generated loop, which overwrites it
-- * check failure conditions and add them, ie salves fizzling off balance
```

Four of the original nine steps are gone: the diagnose list, the simple list,
the tree list and `generic_cures_data` no longer exist, because the trigger
names the affliction and the simple handlers come from the entry. Lists that
a new affliction still has to be typed into by hand include the empty-cure
lists in `Empty_cure_handling.lua` (`empty.treecurables` among them), the
cure-line generator lists in `Main_trigger_functions.lua` (herb, salve, focus
and smoke), and `sstosvoa` when GMCP reports the affliction.

**`svo.dict_setup()`** runs over the whole dictionary and does more than five
things. It runs at load and again after every priority import (`Priorities.lua:501`)
and every runtime defence registration (`Defences.lua` 2590, 2702 and 2813),
each time followed by `dict_validate`. It treats every table-valued key of an
entry as a balance, which is why data tables such as `lovers.map` and
`lovers.tempmap` get names and priorities, and why it resets
`svo.dict.lovers.map = {}` at the end. The main steps:

1. **Fills in the identity fields.** Every handler gets `name` (as
   `action_balance`, so `asthma_herb`), `balance` (the key it sits under) and
   `action_name` (the entry it sits in). Nothing has to write these by hand,
   and `name` is the key the action system uses everywhere.
2. **Defaults the priorities to zero**, but only for real balances. `aff`,
   `gone`, `waitingfor`, `boosted` and `weakened` are skipped, with the
   comment explaining why: priorities for them make no sense, and having a
   priority is what tells serverside the action should be prioritised there.
3. **Assigns every zero priority.** Unprioritised actions are collected in
   `unassigned_actions` and `unassigned_sync_actions`. For each balance,
   every assigned `aspriority` is shifted up by the number of unassigned
   actions, and those actions get 1 to n, the least important places. The
   sync pass does the same across all balances with `spriority`. So an action
   nobody prioritised still works, at the bottom of its list.
4. **Synthesises a `gone` handler for any defence that lacks one**, so
   lifevision has something to watch when the defence drops.
5. **Adds the default named outcomes** listed earlier, and gives every entry
   an `sw` stopwatch, the one `addaff` reuses to time an affliction.
6. **Builds the shortlists**: `dict_balanceful`, `dict_balanceless`,
   `dict_herb`, `dict_misc`, `dict_misc_def`, `dict_purgative`,
   `dict_salve_def`, `dict_smoke_def`. These are what the prompt cycle
   actually iterates. The `dragonform` signal rebuilds
   `dict_balanceful_def` and `dict_balanceless_def`, restricted in
   dragonform to general, dragoncraft and `availableindragon` defences.

**`svo.dict_validate()`** checks only for duplicate priorities, per balance
and across the sync list, and echoes any it finds. It does not check for
missing fields. **Defect, pre-existing:** the sync half tests the stale `key`
left over from the async half instead of `synckey` (line 15223), so
duplicate sync priorities are either never reported or all reported.

**The literal is inside a guard.** It is wrapped in `if not next(svo.dict)
then` at line 434, and that `if` does not close at the literal's closing
brace (line 10,830). It closes at line 14,679, so every class-gated
`svo.dict.X = {...}` block is inside it too. The `basicdef` calls, the
reverse name maps, `dict_setup()` and every signal connection are outside
it. Class change empties `svo.dict` precisely so the literal can rebuild. A
hot reload of this file with the dictionary already populated rebuilds only
the `basicdef` entries, as fresh tables with no priorities.

Four of the 267 literal keys are not actions: `sstosvoa` and `sstosvod`, the
maps from the game's affliction and defence names to svof's, and the empty
`svotossa` and `svotossd`, which the loader fills by reversing the first two
(lines 14,950 to 14,956, string values only). The GMCP reconciler reads all
four, and the empty-cure gate reads `svotossa`.

After the literal table closes at line 10,830, about 3,850 lines (10,832 to
14,678) of `svo.haveskillset(...)` blocks patch class-specific entries in:
first the `prone`, `nightsight` and `shroud` patches, then every class-gated
defence and action. For example,
`prone.misc.actions` becomes `{'stand', 'recover footing'}` for
weaponmastery but plain `'stand'` otherwise, and nightsight is marked
`undeffable` for metamorphosis because serverside cannot morph to get a
specific defence up. This is how one dictionary serves every class without
carrying every class's branches at every call site.

### 2. The action system

`Action_system.lua`, 15,569 bytes, is the smallest of the core files and the
one most worth reading in full. Its header states the rule: "all `send()`'s
should be an action", with one exception for serverside commands, "as those
commands cannot be interrupted in any way".

Three tables carry all of it:

* **`svo.actions`** is a Penlight `OrderedMap` from the action's `name`
  (`asthma_herb`) to `{timerid, completed, p}`, where `p` is the dictionary
  handler. `svo.actions.asthma_herb` is how trigger handlers find the action
  they are completing. An entry force-added by `checkaction` has no timer.
* **`svo.bals_in_use`** maps balance to the set of actions currently spending
  it.
* **`svo.actions_performed`** maps `action_name` to the action, so you can ask
  "am I doing anything about bleeding?" without knowing which balance.

**`svo.doaction(act)`** does five things, in order:

1. **Works out a timeout.** Normally
   `(customwait or customwaitf() or 0) + sys.wait + syncdelay()`. Under
   serious concussion in slow-curing mode it becomes `syncdelay() + 0.3`
   instead, which is the shape that gives 1.3 seconds with aeon and 0.3
   without.
2. **Arms a `tempTimer` for that timeout.** If it fires, the action never
   resolved: it is removed from `actions`, `bals_in_use` and
   `actions_performed`, and `sys.lagcount` goes up. While `sys.lagcount` is
   below `sys.lagcountmax + 1` (4), `ontimeout` runs, the stupidity inference
   runs, and the gnomes are kicked again. At exactly 4, and not paused, it
   prints the lag warning and calls `sk.increase_lagconf()`. Past that, a
   timeout does nothing more until a prompt resets `sys.lagcount` to 0. This
   timer is the single source of both lag detection and stupidity detection,
   described below. Every `waitingfor` handler goes through the same path,
   so a timed affliction wearing off also bumps `sys.lagcount` and, while
   `sk.stupidity_count` is above zero, can feed the stupidity inference.
3. **Registers a `completed` closure** that kills the timer, calls
   `act.oncompleted` (or a named alternative handler), and emits
   `curedwith_focus` if the balance was `focus`.
4. **Marks the balance and the action as in use.**
5. **Calls `act.onstart()` inside `pcall`.** On failure it prints a clickable
   `(e!)` link carrying the error and your current `curemethod`. On success it
   starts a per-action stopwatch, reachable as
   `actions.<name>.p.actionwatch`.

The timeout path is where two symptoms are inferred rather than observed:

* **Lag.** Each timeout increments `sys.lagcount`. When it crosses
  `sys.lagcountmax`, svof prints "Warning, lag detected (while doing/curing
  X)" and calls `sk.increase_lagconf()`, which steps up `svo.conf.lag` and
  with it `sys.wait`, taken from `svo.wait_tbl`: levels 0 to 4 map to 0.7,
  1.1, 1.9, 3.5 and 3.5 seconds.
* **Stupidity.** If an action times out while `sk.stupidity_count` is above
  zero and `affs.stupidity` is not set, svof concludes you have stupidity,
  adds it, and says "I suspect we've got stupidity." Stupidity makes you do
  the wrong thing, so the evidence for it is precisely that a command you sent
  produced no result.

The rest of the API:

* **`svo.checkaction(act, input)`** is the pre-check used by trigger handlers.
  Its subtlety is the force-add: if anti-illusion is off, or `input` is true,
  it fabricates an entry for an action it never sent. That covers the case
  where a third party did something to you, so the completion handler still
  has an action to complete. `input == false` suppresses the force-add even
  with anti-illusion off.
* **`svo.checkany(...)`** is the multi-argument version, returning the first
  one in progress. It cannot force-add.
* **`svo.findbybal(balance)`** returns any one action on that balance.
* **`svo.findbybals(list)`** returns all actions across several balances, or
  nil if none.
* **`svo.will_take_balance()`** asks whether anything currently in flight on
  the `physical` balance is marked `balanceful_act`. Aliased as
  `svo.codepaste.balanceful_codepaste`.
* **`svo.actionclear(act)`** removes the action without completing it, and
  runs `oncancel`. Only lifevision calls it.
* **`svo.actionfinished(act, other_action, arg)`** completes it. Only
  lifevision calls it.
* **`svo.killaction(act)`** cancels outright: runs `onkill`, kills the timer,
  removes it from all three tables and from the lifevision ledger.
* **`svo.usingbal(which)`** and its old name `svo.usingbalance`: is anything
  spending this balance?
* **`svo.doingaction(which)`** and its old name `svo.doing`: is anything being
  done about this thing, on any balance? The comment flags the known weakness:
  it keys on the short name, so things that can genuinely happen twice at once
  need `doingaction` and `usingbal` together.
* **`svo.haveorwill(aff)`** returns true if you have the affliction *or* will
  have it once this prompt resolves without an illusion. This is the function
  that lets the decision layer act on an affliction before it is confirmed.
* **`svo.valid_sync_action(name)`** parses `actionname_balance` and checks both
  halves exist, returning a reason string when they do not.

Four of these functions share the same fifteen-line block: after removing an
action, walk `bals_in_use` and put `actions_performed[action_name]` back if
another balance still has an action for the same thing. The comment explains
it: an affliction handler can overwrite a cure handler in
`actions_performed`, and removing the affliction must not take the cure's
record with it.

`svo.doaction` also accepts two strings, `svo.doaction('healmana', 'sip')`,
which is the form `Funnies.lua` advertises. `actionfinished` and `killaction`
schedule a gnome run with `tempTimer(0)` in slow curing. `completed` and
`oncancel` run under `pcall`; `onkill` does not.

**Defect, pre-existing (same line in the reference xml at 3755).** Line 24
takes `local make_gnomes_work = svo.make_gnomes_work` when the `action`
loader runs. `svo.make_gnomes_work` is the binding that `changecuring`
switches between the async gnome, the sync gnome and a no-op, and the `sk`
loader just before has already pointed it at the async gnome. The local
never changes afterwards. So every kick through it (the timeout kick at line
89, and the slow-curing kicks at 294 and 339, which only run because
`sys.sync` is true) runs the **async** gnome in slow-curing mode, which fires
every balance's best action rather than one. Because `sk.gnomes_are_working`
is set only by the sync gnome, those sends reach `cnrl.processcommand`
looking like commands you typed, which either denies them (under
`blockcommands`) or treats them as an override and sets `svo.sacid`. Read
from the code, not observed in play.

### 3. Lifevision, the anti-illusion ledger

The problem: in Achaea an opponent can produce text that is indistinguishable
from a real affliction message. If svof acted on everything it read, an
opponent could spend your balances on afflictions you never had.

The answer is to not act on any single line. Instead, every handler that
believes something *records the claim*, and the claims are settled together at
the end of the paragraph.

**`svo.lifevision.l`** is a Penlight `OrderedMap` of claims, keyed by action
name. Order matters, because the completions run in the order the lines
arrived.

**`svo.lifevision.add(what, other_action, arg, lineguard)`** files a claim. The
`lineguard` argument is the interesting one. It says "this line is only
believable if the paragraph it arrived in is no longer than N lines", and when
several claims each set one, the **smallest wins**, with the comment giving
the reason: if two claims conflict, the tighter constraint is the more valid
one. In slow-curing mode `add` also colours the current line with
`conf.slowcurecolour`, so you can see which lines the system acted on.

**`svo.lifevision.addcust(what, where, other_action, arg)`** files a claim
against a specific slot rather than the handler's own name.

**`svo.lifevision.getlineguard()`** and **`clearlineguard()`** read and reset
the current guard.

**`svo.lifevision.validate()`** runs once per prompt and is the decision
point. It computes `paragraph_length`, subtracting one line if the game's own
curing message went off, because that is a meta message and should not count
against the guard. Then:

* If `sys.flawedillusion` is set, or the paragraph is longer than the
  lineguard allows, **this is an illusion**.
* Otherwise, **run every claim** through `svo.actionfinished`.

The line count is `svo.paragraph_length`, which the `General > Prompt`
trigger's Lua pattern builds line by line (see "The prompt cycle"), less one
when `sk.sawcuring()`. `svo.find_until_last_paragraph` and
`count_until_last_paragraph` are not part of this: symptom checkers, the
rewield check and some trigger handlers use them.

Running the claims honours `sk.stopprocessing`: once a claim sets it, the
remaining claims are cleared with `actionclear` instead of finished. The
`checkstun` probe uses this to freeze a paragraph, snapshot the ledger and
`svo.actions`, and replay them through `send_in_the_gnomes` once stun is
settled. After validation the ledger is replaced with a new `OrderedMap`, and
`sk.stopprocessing` and `sys.lineguard` are reset.

Batch mode disables the lineguard check entirely, for the reason given in the
code: commands arrive together in batch mode, and illusions are much less of a
threat now that serverside curing is immune to them.

An illusion can still be overridden. If `sys.not_illusion` is set, the claims
run anyway and svof inserts a clickable `(!i)` marker on the line explaining
that a script override cancelled the detection. Otherwise it inserts `(i)` to
say the whole paragraph was ignored.

The illusion path carries a fix worth quoting, because the comment records a
real failure mode:

```lua
-- Discarding the paragraph used to discard the balance bookkeeping with
-- it: actionclear() frees bals_in_use, so svo.usingbal() goes false,
-- while bals.<balance> was never set false because that happens in the
-- action's completed handler which is being skipped here. svof then
-- believed it still had the balance and re-sent the cure on the very
-- next prompt instead of waiting out the recovery - fast enough to
-- outrun GMCP item tracking, which failed the same illusion check
-- again. It fed itself and did not recover.
```

The fix is `consumable_balances`, the six balances whose cure physically
spends an item:

```lua
local consumable_balances = {
  herb = true, salve = true, sip = true,
  smoke = true, moss = true, purgative = true,
}
```

The reasoning in its comment is the clean statement of the principle: "An
illusion can lie about what a cure did; it cannot un-eat the herb." So on the
illusion path, svof clears every action but first notes which consumable
balances were spent, and then calls `svo.lostbal_<balance>()` for each. The
two-pass split is deliberate, and the code says so: the `lostbal_` functions
raise events and can re-enter curing, so they must not run inside the loop
that is still mutating the ledger.

There is a second, cheaper illusion check elsewhere: a line that arrives
faster than physically possible cannot be real. Several handlers compare the
elapsed time against `svo.getping()` and reject anything under `lat/2`.

### 4. The decision: gnomes, balances and priorities

The naming in this part of the code is whimsical and consistent. The functions
that decide what to do are gnomes.

**`svo.send_in_the_gnomes()`** is the entry point, called from the prompt:

```lua
function svo.send_in_the_gnomes()
  -- at first, deal with lifevision.
  svo.lifevision.validate()
  signals.after_lifevision_processing:emit()

  svo.make_gnomes_work()
end
```

**`svo.make_gnomes_work`** is not a fixed function. It is reassigned whenever
`signals.changecuring` fires, to one of three things:

```lua
signals.changecuring:connect(function()
  if svo.logging_in then
    svo.make_gnomes_work = function() end
  elseif sys.sync then
    svo.make_gnomes_work = svo.make_gnomes_work_sync
  else
    svo.make_gnomes_work = svo.make_gnomes_work_async
  end
end, "change curing types")
```

While logging in, it does nothing. Otherwise it is the asynchronous or the
synchronous gnome, and the choice is `sys.sync`, which is set by
`sk.checkaeony()` when you are in aeon or retardation.

This split is the whole difference between normal and slow curing, and it is
why every dictionary handler has two priorities.

**Asynchronous mode, `svo.make_gnomes_work_async`.** Normally you can act on
several balances at once: eat a herb, apply a salve and sip a potion in the
same moment, because they are different balances. So the async gnome asks
every balance in turn and lets each fire:

```lua
svo.check_misc(false, true) -- amnesia & fear only
svo.check_focus()
svo.check_salve()
svo.check_sip()
svo.check_purgative()
svo.check_smoke()
svo.check_herb()
svo.check_misc()            -- fails for amnesia, but works for Priest Healing...
svo.check_moss()
svo.check_balanceless_acts()
if not svo.check_balanceful_acts() and not svo.will_take_balance() then
  sk.balance_controller()
end
```

`check_misc` is called twice on purpose: once at the top restricted to amnesia
and fear, which have to be handled before anything else, and once in its
normal position. The last line is the guard that keeps balance from being
spent twice: only if nothing balanceful fired, and nothing already in flight is
going to take balance, does the balance controller get to run.

Around all of this the async gnome blocks `cnrl.processusercommand` on
`signals.sysdatasendrequest`, so svof's own sends are not mistaken for
commands you typed. If fancy command echo is on, it swaps `send` for
`svo.fancysend`, and if batching is on it also wraps `expandAlias` so that an
alias expansion breaks the current batch rather than getting swallowed by it.

**Synchronous mode, `svo.make_gnomes_work_sync`.** Under aeon you get one
action at a time, so the sync gnome cannot let every balance fire. It runs in
three steps:

1. **Refuse to overlap.** If anything is already in flight on a real balance,
   that is, any balance other than `waitingfor`, `gone` and `aff`, it logs
   "doing X, quitting for now" and returns.
2. **Collect candidates.** It calls all ten `check_*` functions with
   `true`, which makes each *return* its best action rather than doing it,
   and collects them into `action_list`.
3. **Pick exactly one.** It sorts the candidates by `spriority` and calls
   `svo.doaction(find_highest_action(action_list))`.

It also returns at once while `svo.sacid` is set (you overrode it by typing a
command, see `cnrl.processcommand`), sets `sk.gnomes_are_working` so
`processcommand` knows the send is svof's own, and with fancy echo turns
`conf.batch` off for the one action.

Both modes write a human-readable trace into `sk.syncdebug`, listing every
feasible action in order, which is what the debug output shows you when a
decision looks wrong.

**`svo.sk.balance_controller()`** does not choose from the dictionary. The
dictionary's balance and equilibrium actions are chosen by
`check_balanceful_acts` and `check_balanceless_acts`, like every other
balance. The controller runs two **function registries**, `balanceless` and
`balanceful`, which `svo.addbalanceless(name, f)` and
`svo.addbalanceful(name, f)` fill. Out of the box they hold only the do
queue, registered by `Dor.lua` at `systemstart`: `svo check dofree`
(balanceless) and `svo check do` (balanceful). The enchanter addon adds
`enchantment step`. They are the public hook for "do this when I have
balance", and the `svo balanceless ready` and `svo balanceful ready` events
(raised on a `tempTimer(0)` after the `sk` loader, and again by
`clearbalanceless` and `clearbalanceful`) are the signal to register.

The two registries behave differently across a class change.
`local balanceless = svo.balanceless or {}` reuses the table
`Create_Svof_namespace.lua` made, so balanceless hooks survive. Nothing
creates `svo.balanceful`, so `balanceful` is a fresh local on every `sk`
load and every balanceful hook is dropped on each class change until its
owner registers again on `svo balanceful ready`.

It has its own guards:

```lua
if sys.balanceid == sys.balancetick then return end
if not (bals.balance and bals.equilibrium)
   or (affs.webbed or affs.bound or affs.transfixed or affs.roped
       or affs.impale or affs.paralysis or affs.sleep) then return end
```

The first line is a tick guard, so it runs at most once per balance cycle. The
second is the list of afflictions that make physical action pointless. Then it
runs every balanceless function unconditionally, since those cost nothing, and
walks the balanceful ones until one fires. When one does, it arms a timeout
that bumps `sys.balancetick` and re-runs the gnomes.

The timeout has three cases. If the handler returned a number, that number is
the timeout. If `conf.lag` is at its maximum of 4, the timer is set to
`60*60*23`, twenty-three hours, with the comment "24 does it right away!",
which is an effective way of saying never. Otherwise it uses
`sys.actiontimeout`, 3 seconds.

Three things end the wait early by bumping `sys.balancetick` and killing
`sys.actiontimeoutid`: `svo.donext()` (the "my balanceful action is done"
call a hook makes), and `svo.gotbalance()` and `svo.goteq()`, which the
balance and equilibrium regain lines call.

**Priorities.** A priority list is per balance, and `resources/default_prios`
ships ten of them:

| List | Entries | What it orders |
|---|---|---|
| `slowcuring` | 211 | everything, for aeon and retardation mode |
| `herb` | 54 | eating |
| `physical` | 49 | balance and equilibrium actions |
| `salve` | 41 | applying |
| `misc` | 26 | everything else |
| `focus` | 19 | Focus |
| `smoke` | 9 | smoking |
| `sip` | 6 | sipping |
| `purgative` | 5 | purgatives |
| `moss` | 2 | moss |

The file's own note explains the ordering, which is the opposite of what most
people expect:

```
-- Note: The lower the priority in the list without a number, or the lower
-- number - the more important the thing is. ie, things at the bottom of the
-- list will get done before those on the top!
```

Entries can be positional or explicitly numbered, and both appear in the same
list. `physical` starts with eight positional entries and then jumps to
`[11] = "meditate"`, leaving deliberate gaps that `prio.cleargaps` can close.

Four dictionary helpers turn a priority list into a lookup the checks can use:
`svo.make_prio_table`, `svo.make_sync_prio_table`, and the `f` variants
`svo.make_prio_tablef` and `svo.make_sync_prio_tablef` which take a function
instead of a list. `svo.clear_balance_prios` and `svo.clear_sync_prios` reset
them.

### A note on hot reloading

Twenty-eight of the 32 loader files end with the same line:

```lua
if svo.systemloaded then svo.loader.action() end
```

If the system is already up when the file is re-executed, the file reloads
itself immediately rather than waiting for the next `svo_init_system`. This is
what makes editing a single script in Mudlet take effect without a restart.
The four that do not have it are `setup`, `enchanter`, `fishdist` and
`mindnet`. For `setup` that is correct, since re-running it would rebuild the
signal bus underneath live handlers. For the three addons it appears to be an
omission rather than a decision, since nothing in them is obviously unsafe to
re-run, but nothing in the code says either way. (The enchanter's trailing
reload block exists but is commented out.)

A hot reload is the one path that reruns a loader on a **live** bus, so it is
where three things go wrong that a class change avoids: named handlers are
replaced (intended), unnamed handlers are connected a second time, and the
luanotify name-replacement defect can remove the wrong handler once a signal's
queues have drifted (see "The signal bus"). Temp triggers created inside a
loader are also created again.
## File reference: `scripts/`

The `scripts/` tree has 25 top-level folders. One of them, `svo (core)`, holds
the infrastructure. Seven hold the engine. The remaining 17 are addons, one per
former Mudlet module.

A note on the folder scripts before the reference proper. Thirty-one folders in
`scripts/` carry their own `.lua` file. Most are conversion artefacts and say
so in a comment. `svo_Logger.lua`, `svo_Offering_Module.lua`, `NameDB.lua`,
`svo_Elixer_Sorter.lua` and the other addon wrappers are all variations on the
same three lines:

```lua
-- The module priority this group used to set on install has no meaning in a
-- single package: load order comes from where these items sit in the tree.

svo = svo or {}; svo.loader = svo.loader or {}
```

`Load_&_init.lua` is a comment and nothing else, explaining the same thing for
the group that used to install the module list. Eleven files are muddler's
250-byte placeholder ("Put your Lua functions here"), and four are the
16-byte `svo = svo or {}`. None of them does anything at runtime beyond
ensuring the namespace exists.

---

### `svo (core)`

Infrastructure: namespace, third-party libraries, event plumbing, load and
init, update checking, class management, and a set of small utilities.

#### `Create_Svof_namespace.lua`

Nine lines, and they run before everything else. It creates `svo`, `svo.loader`
and `ndb`, stubs `svo.autopause_on_def` and `svo.disable_seek` as empty
functions so early callers do not crash, creates `svo.balanceless`, and calls
`createBuffer('svo_prompt')`, the off-screen buffer the custom prompt is
rendered into.

#### `3rdparty/Penlight/`

Twelve vendored Penlight modules, 137,128 bytes. They are **not quite
unmodified**: every file ends with `package.loaded['pl.<name>'] = <name>`
instead of `return <name>`, which is what lets them run as Mudlet script
items, and the item order in `scripts.json` is dependency order (utils,
tablex, stringx, lexer, pretty, path, class, List, Map, OrderedMap, dir,
config). The library code itself is otherwise stock, so this reference lists
what each module provides rather than walking every function. `pl.operator`
is not vendored, so any `tablex` or `List` call given an operator string such
as `'=='` fails at `require`. `utils.lua` defines `table.pack`, `_G.pack` and
`package.searchpath` as globals on Lua 5.1.

What svof actually uses: `Setup.lua` binds seven modules into `svo.pl`
(`pretty`, `config`, `dir`, `path`, `string` for stringx, `OrderedMap`,
`tablex`). Outside Penlight itself, the real uses are `dir.makepath` for the
eight directories under `<home>/svo/`, `pretty.write` for the priority export
and debug output, a handful of `tablex` functions (`keys`, `imap`,
`find_if`, `reduce`, `map`, `index_map`), and `OrderedMap` for four tables:
`svo.actions`, `svo.lifevision.l`, `svo.defs_data` and `svo.config_dict`.
`stringx.import` is never called.

Two `OrderedMap` details matter to svof. Entries are stored as fields on the
object, so `set(key, nil)` is the only removal that also drops the key from
the order, and a plain `map[key] = v` is invisible to `iter`. And `set`
re-appends a key whose current value is `false`. No svof key collides with a
method name (checked for `defs_data` and `config_dict`). `svo.deepcopy` keeps
metatables, so the `checkstun` ledger snapshot stays an `OrderedMap`.

| File | Provides |
|---|---|
| `List.lua` | `pl.List`, a class with 48 methods: `append`, `extend`, `insert`, `put`, `remove`, `remove_value`, `pop`, `contains`, `count`, `sort`, `sorted`, `reverse`, `minmax`, `slice`, `clear`, `range`, `len`, `chop`, `splice`, `slice_assign`, `join`, `foreach`, `foreachm`, `filter`, `split`, `map`, `transform`, `map2`, `mapm`, `reduce`, `partition`, `iter`, `iterate`, plus `__concat`, `__eq`, `__tostring`, `__call` |
| `Map.lua` | `pl.Map`: `iter`, `items`, `setdefault`, `set`, `get`, `getvalues` |
| `OrderedMap.lua` | `pl.OrderedMap`: `update`, `set`, `insert`, `keys`, `values`, `sort`, `iter`. **This is the one svof depends on most**, for `svo.actions`, the lifevision ledger, `svo.defs_data` and `svo.config_dict` |
| `class.lua` | Penlight's class system: `call_ctor`, `is_a`, `class_of`, `_class`, `properties._class_init` |
| `config.lua` | `config.lines`, `config.read` |
| `dir.lua` | 17 functions including `fnmatch`, `filter`, `getfiles`, `getdirectories`, `copyfile`, `movefile`, `walk`, `rmtree`, `makepath`, `clonetree`, `dirtree`, `getallfiles` |
| `lexer.lua` | `scan`, `insert`, `getline`, `lineno`, `getrest`, `get_keywords`, `lua`, `cpp`, `get_separated_list`, `skipws`, `expecting` |
| `path.lua` | 24 path functions: `isdir`, `isfile`, `islink`, `getsize`, `exists`, `getatime`, `getmtime`, `getctime`, `splitpath`, `abspath`, `splitext`, `dirname`, `basename`, `extension`, `isabs`, `join`, `normcase`, `normpath`, `relpath`, `expanduser`, `tmpname`, `common_prefix`, `package_path` |
| `pretty.lua` | `read`, `load`, `write`, `dump`, `number`. `pretty.write` serialises priority exports; configuration is saved with `svo.tablesave` instead |
| `stringx.lua` | 36 string functions, and `stringx.import` which grafts them onto the `string` table |
| `tablex.lua` | 48 table functions. `tablex.keys` is what `svo_init_system` uses to test which loaders exist |
| `utils.lua` | 29 helpers: `quit`, `printf`, `import`, `escape`, `choose`, `readfile`, `writefile`, `split`, `memoize`, `is_callable`, `is_type`, `bind1`, `bind2`, `assert_arg`, `raise` and others |

#### `3rdparty/notify/`

luanotify, two files.

**`signal.lua`** defines the `Signal` class: `new`, `connect`, `disconnect`,
`block`, `unblock`, `emit`, `emit_with_accumulator`, `add_pre_emit`,
`remove_pre_emit`, `add_post_emit`, `remove_post_emit`, `stop`. Handlers can be
named, and in this modified copy connecting a name that is already present
replaces that handler. `block` and `unblock` take the handler function, not
its name, and are counted. They are used heavily in the gnome functions to
suppress `cnrl.processusercommand` while svof's own commands go out. The
modifications, the pre-emit LIFO order, and the latent queue-desync defect
are described under "The signal bus".

**`double_queue.lua`** defines `DoubleQueue`: `new`, `is_empty`, `push_front`,
`push_back`, `get_iterator`, `contains`, `remove`, `removeIndex`, `position`,
plus a local `refresh_first` and `removeByValue`. It maintains a
`data_position` index alongside the queue, so removing a named handler is a
lookup rather than a scan.

#### `Event handlers/`

Three items, two of which are four-line `pcall` wrappers.

* **`svo_events.lua`** wraps `svo.events` and `display`s any error. Registered
  on 19 events: `CharVitals`, `CharName`, `RoomNum`, `RoomBrief`,
  `sysDataSendRequest`, `sysExitEvent`, `mmapper updated pdb`,
  `svo lost balance`, `svo got balance`, `svo prio changed`,
  `svo system loaded`, `svo config changed`, `svo serverignore changed`,
  `svo ignore changed`, `svo defup changed`, `svo keepup changed`,
  `svo switched defence mode`, `svo done defup`, `NameDB finished honors`.
* **`svo_gevents.lua`** wraps `svo.gevents`. Registered on `gmcp.Char`,
  `gmcp.Room`, `gmcp.Char.Status` and `gmcp.IRE.Time`.
* **`svo.savesettings`** has no body. It registers `sysExitEvent`, and
  `Controllers.lua:620` does `svo.savesettings = svo.QQ`.

The real handlers, `svo.events` and `svo.gevents`, are in
`Miscellaneous_functions.lua`. They are the single fan-out point: each takes
the event name and dispatches to the matching signal.

#### `Load & init/`

**`svo_init_system.lua`** is described in full in the architecture section
above.

**`svo.remove_legacy_modules.lua`**, 10,287 bytes, is the migration path from
the 25-module install to the package. Registered on `sysInstall` and
`sysLoadEvent`. It returns at once for a `sysInstall` of any other package,
and while a sweep is already running. Everything else waits
`SAVE_DELAY = 3` seconds, so Mudlet's post-install profile save finishes
first. The module list is the 25 **old** module names, kept deliberately
even where `src/` renamed the group. Five local helpers do the work:

* `installed(list)` takes the whole list and returns the subset still
  registered, tested with `getModulePath`.
* `backup(module)` does **not** save settings. It copies the module's **xml
  file** to `<path>.svof-backup`, once only (an existing backup is never
  overwritten), because Mudlet 4.16's own profile save can truncate synced
  module xmls. Settings live under `<home>/svo/` and are never touched.
* `try_remove(list)` calls `uninstallModule` under `pcall` for every name and
  ignores the result, because a refusal returns false rather than raising.
* `sweep(found, attempt)` sorts the bootstrap module
  (`svo (install me in module manager)`) last, removes, and retries every 2
  seconds up to `MAX_ATTEMPTS = 4`, checking what is still installed each
  time.
* `finish(found)` clears `svo.removing_legacy_modules` first, reports what
  was and was not removed, and, if the bootstrap module's own uninstall
  handler cleared `svo.systemloaded`, reruns `svo_init_system` under `pcall`
  and checks `svo.systemloaded` afterwards.

**`svo.classchange.lua`** runs on `gmcp.Char.Status`, which means on every
Status message, not only on a class change. It is the reason the whole loader
mechanism has to be re-runnable. In order:

1. Take the new class from GMCP, or from an explicit override argument. If it
   is not in `svo.knownskills`, fall back to `"None"`.
2. Walk `svo.defc` and keep only defences that exist in `svo.defs_data` and
   are `type == "general"`. Those survive the reload in `temp_defs`, so svof
   does not waste balance re-raising defences that are already up. This loop
   runs **before** the class test, and it also **deletes** every `defc` entry
   that has no `defs_data` record, on every Status message.
3. Only if the class differs from `me.class`: set
   `sk.gettingfullstats = false`, kill every temporary defence trigger in
   `svo.defencetemptriggers`, and set `me.class`.
4. Emit `saveconfig`. This runs on the **old** bus, so the old class's save
   handlers write their files before the bus is replaced, and it runs after
   `me.class` already holds the new class, which is what the `my_class` file
   records.
5. Call `svo.sk.resetserversideprios()`. The comment explains why: serverside
   will otherwise keep trying to raise class-specific defences you no longer
   have, which it describes as a bug in the game.
6. Blank `svo.dict`, clear `svo.systemloaded`, and call `svo_init_system()`
   again. The dictionary is rebuilt for the new class by the
   `haveskillset` blocks at the end of the dictionary file.
7. Re-apply the surviving general defences with `svo.defences.got`, and echo
   the change.
8. Unless the system is paused, call `svo.app("off")`, svof's own unpause.
   Serverside hears about it only through the `paused` config mirror, when
   serverside is on.

This is also the path taken every time you enter or leave dragonform. What a
class change does **not** clean up: the 13 anti-illusion temp triggers and
six metamorphosis temp triggers `Setup.lua` creates at `systemstart`, the
temp triggers of the three runtime-registered defences, and the two
`sysLoadEvent`/`sysConnectionEvent` anonymous handlers Setup registers. All
are created again by the new init, so after N class changes each of those
trigger lines fires its handler N+1 times, and the old anonymous handlers
keep emitting on the old bus. Everything NameDB connected to the old bus is
lost (see "The addons").

**`svo.uninstall_all_modules.lua`** runs on `sysUninstallPackage`. It returns
immediately unless the package being removed is named `svof`. Then it clears
`svo.systemloaded` and emits `saveconfig` inside a `pcall`, with a comment
noting that this writes settings out while the system that owns them is still
loaded.

#### `Check for system updates/`

Seven items. This subsystem was rewritten for the package world and is densely
commented, with each comment recording a specific failure that shaped it.

**`Check_for_updates.lua`**

* `svo.update_repo` is `"TheLastDarkthorne/svof"`. The comment explains that
  this has to match wherever the README sends people, and that while the
  converted system is being play tested that is the fork, because
  `build.yml`'s release job is gated to it.
* `svo.update_api_url()` returns the GitHub releases-latest API URL.
* `svo.update_package_url(tag)` is a fallback. The comment warns that `tag`
  must be the raw `tag_name`, because GitHub asset URLs are tag-exact and a
  stripped "v" produces a 404.
* `svo.update_response_is_ours(url)` decides whether an HTTP event belongs to
  this check. It requires a check to be in flight and then accepts either the
  exact URL or anything ending `/releases/latest`. The comment records the bug
  this fixes: Mudlet reports the *final* URL after redirects, GitHub 301s the
  releases API when a repository is renamed, so an exact comparison left
  `svo.checkingupdates` true forever and silently killed every later check
  until Mudlet restarted.
* `svo.version_newer(candidate, current)` compares component-wise rather than
  as strings, so a future move to `1.2.3` versions does not make `1.10` look
  older than `1.9`.
* `svo.checkforupdates(kind, automatic)` is the entry point. It requires
  `getHTTP`, and prints a message naming **4.12** as the floor rather than
  4.10, because the version comparison also needs `getPackageInfo`. Automatic
  checks are throttled to `AUTO_CHECK_INTERVAL`, one hour, and the timestamp is
  written *before* the request so a failing check throttles too. The comment
  gives the reason: `svo.classchange` re-raises `svo system loaded`, so without
  throttling every trip in and out of dragonform would cost one
  `api.github.com` request against an unauthenticated limit of 60 an hour. A
  hand-typed `vupdate` is never throttled. A `CHECK_TIMEOUT` of 60 seconds
  clears the in-flight flag if nothing ever comes back. `getHTTP` is called
  inside `pcall` and its return value is checked, because it returns
  `nil, reason` on a refused start and raises no event at all.

**`Update_UI_and_Install_Engine.lua`**

* `svo.showupdatereminder()` draws the clickable update notice.
* `svo_dontupdate_click()` and `svo_doupdate_click()` are its two buttons.
* `svo.update_looks_like_package(path)` sanity-checks a downloaded file.
* `svo.package_installed(name)` tests installation state.
* `svo.install_update()` and `svo.install_downloaded_package(path)` do the
  uninstall-then-install that replaces the old per-module reload.

**`svo.update_http_done.lua`** parses the releases JSON, prefers the asset URL
the release itself carries over the constructed fallback, and is the place
that reports honestly when no package release exists yet rather than offering
a URL that would 404.

**`svo.update_http_error.lua`**, **`svo.update_download_done.lua`** and
**`svo.update_download_error.lua`** are the other three event handlers, on
`sysGetHttpError`, `sysDownloadDone` and `sysDownloadError`.

**`svo_checkupdatestart.lua`** is 75 bytes: registered on `svo system loaded`,
it calls `svo.checkforupdates("checking", true)`. The `"checking"` kind means
the automatic check, at most once an hour, announces "Checking for
updates..." and its result.

The whole update flow, end to end:

1. `svo system loaded` runs `svo_checkupdatestart`, or you type
   `vupdate [force|checking]`, which calls `checkforupdates(kind)` without
   `automatic` and so is never throttled.
2. `checkforupdates` sets `svo.checkingupdates` and `svo.announceupdates`,
   arms the 60-second timeout, and calls `getHTTP` on the releases API.
3. `sysGetHttpDone` reaches `svo.update_http_done`, which acts only if
   `update_response_is_ours`. It parses the JSON, records
   `svo.pending_update_tag` and the `svof.mpackage` asset URL, and either
   says you are current, says the release carries no package, installs
   straight away for `force`, or calls `svo.showupdatereminder(latest)`. A
   release with **zero** assets counts as installable (the fallback URL is
   built from the raw tag). Only a release that has assets but no
   `svof.mpackage` is refused up front.
4. Clicking **Install** runs `svo_doupdate_click`, then
   `svo.install_update(version, url)`, which saves the configuration, sets
   `svo.update_target` to `<home>/svof-update.mpackage`, and calls
   `downloadFile`.
5. `sysDownloadDone` reaches `svo.update_download_done`, which defers one
   turn with `tempTimer(0)` to avoid a use-after-free while Mudlet is still
   walking its handler list.
6. `svo.install_downloaded_package` checks for the zip's
   end-of-central-directory record, uninstalls `svof` (up to four tries, 2
   seconds apart, checking `getPackages()` each time), installs the file,
   confirms with `svo.package_installed`, deletes the download, and asks for
   a restart.
7. `sysDownloadError` reaches `svo.update_download_error`, which matches the
   target path against every argument and reports that nothing changed.

#### `svo Class Management/`

svof can switch on class-specific tricks automatically, based on what is
hitting you. No trigger group is toggled: enabling a class only changes two
lookup tables, and the tricks are whatever reads them.

**`svo_Class_Management.lua`**

* `svo.enableclass(class)` increments a counter in `svo.enabledskills[skill]`
  for each of the class's three skillsets in `svo.classes`, marks
  `svo.enabledclasses[class]`, and raises `svo enabled class`.
  `svo.disableclass(class)` reverses it and raises `svo disabled class`. The
  readers of those tables are: the three Vodun and Puppetry anti-illusion
  triggers (reject the line unless `vodun` or `puppetry` is enabled), the
  rebounding trigger, the blackout `aff` action (assume crippled limbs
  against `necromancy`, suspect asthma and anorexia against `curses`),
  `codepaste.checkdismemberkill` (only with `sentinel`), and the `tn`/`tf`
  aliases.
* `svo.enableallclasses()` and `svo.disableallclasses()` do all of them.
* `svo.startedfighting(class, name)` is the function every class-detection
  trigger calls, 179 trigger lines in all. The trigger tree has these
  scattered through the per-skillset folders, for example a Weaving trigger
  for a psion's Deathblow calls `svo.startedfighting("psion", matches[2])`.
  It does not count the hit itself. It calls `valid.gothit`, which claims
  `gothit.happened` in the lifevision ledger with
  `tempmap[name or '?'] = class`, so an illusion discards it. At the prompt
  the claim's `oncompleted` raises `svo got hit by`, which reaches
  `svo.registerhit` and NameDB's `ndb.setfromclass`. `Tekura > Palmstrike`
  passes `"Monk"`, which `svo.classes` does not have (it is lower case), so
  that hit never counts.

**`svo.registerhit.lua`** runs on `svo got hit by`. It is the counting logic:

1. Return unless the class is known and `conf.autoclasses` is on.
2. Increment `svo.maybefighting[class]`, and arm a `tempTimer` for
   `conf.classattackswithin` seconds that decrements it again. So the counter
   is a sliding window, not a total.
3. If the count reaches `conf.classattacksamount`, call `svo.enableclass` and
   queue a prompt message saying so.
4. Arm or renew a `tempTimer(60 * conf.enableclassesfor)` that disables the
   class again, printing a message unless you are dead. The timer takes
   seconds, so `conf.enableclassesfor` is in minutes.

It counts only while the class is not yet enabled.

**`svo_show_classes.lua`** runs on `svo onshow` and lists the enabled classes.

#### `svo Utilities/`

Sixteen small files. Each does one thing.

**`svo_Utilities.lua`** is the shared set, 19 functions:

* `svo.inslowcuringmode()` returns `affl.retardation or affl.aeon` from the
  public list. It does not read `sys.sync`.
* `svo.boxDisplay(text, colours)` draws the big attention box.
* `svo.preattack()` sends `stand` when you are prone outside slow curing.
* `mapper_can_move()` is the predicate the Mudlet mapper calls to ask whether
  it is safe to move. It is a global on purpose, since the mapper looks it up
  by name.
* `svo.echotime()` and `svo.echoafftime()` print elapsed times.
* `svo.cc(fmt, ...)` is the relay-to-channel function used everywhere the
  system wants to report to party, clan, order or tell. `svo.ccnop` is not a
  no-op: it is `cc` without the pause check, so it still reports while
  paused. Both skip slow curing. `docc` is the local that does the work,
  routing by `conf.ccto` (pt, clt, tell, ot, army, team, echo, or a clan
  name).
* `string.ordinalSuffix(n)` adds "st", "nd", "rd", "th".
* `svo.shipprompt()` only records `me.shippromptn`.
* `svo.doubleRunToSend(...)` sends its arguments only on the second call
  within 0.4 seconds: a double-press guard for keys.
* `svo.getfocusableaffs()` returns the afflictions Focus can currently cure.
* `svo.startbalancewatch()` and `svo.endbalancewatch()` bracket a balance
  timing measurement.
* `svo.countbrokenlimbs()`, `svo.countonlybrokenlimbs()` and
  `svo.havefractures()` are the limb-state queries the prompt and the
  dictionary both use.

**`commandTracker.lua`** is the stupidity detector's other half. It keeps
`lastCommands`, the five most recent commands you sent, via `commandTracker`
registered on `sysDataSendRequest`. `stupidityCheckTable` has 21 entries over
20 distinct game responses (the "cannot settle down to sleep" line is listed
twice), mapping each to the regex for the command that would legitimately
produce it,
for example `"You blink."` to `"^blink"` and `"You burp obscenely."` to
`"^(?:burp|belch)"`. `commandCheck(what)` returns true if any of your last five
commands matches. The logic is that if you see "You blink." and you did not
send `blink`, something made you do it, and that something is stupidity. Its
one caller is the `StupidityValid` symptom trigger.

**`svo_autoslickprio.lua`** runs on `svo got balance`, `svo lost aff` and
`svo got aff`, and only acts when its argument is `'herb'`. The two
affliction events pass an affliction name, never `'herb'`, so in practice it
runs only on herb balance regain, including the swap back. It handles one specific
trap: slickness stops salves working, and asthma stops smoking, so having both
at once while paralysis or impatience outranks asthma in the herb list means
you can be locked. When it sees that shape, and you have more than two
afflictions, it swaps asthma to `prio.gethighest("herb") + 1`, remembers the
old value in `svo.swapped_asthma`, and announces the emergency. When either
affliction clears it swaps back and says so.

**`svo_onimportant_aff.lua`** runs on `svo got aff` and calls
`svo.boxDisplay` for 12 afflictions it treats as important enough to interrupt
you: the four traumas and concussions, and the eight mutilated and mangled
limbs.

**`svo.autopause_on_def.lua`** runs on `svo got def` and `svo lost def`.
Nothing is configurable: it pauses on gaining `blackwind` or `astralform`,
remembering whether you were already paused, and unpauses on losing either
unless you were.

**`svo.isenemy.lua`** is 109 bytes. It returns true when the global `target`
starts with the name, and otherwise calls `ndb.isenemy(name)`
unconditionally.

**`svo.sitting.lua`** and **`svo.sleeping.lua`** both run on `svo lost aff`.
They do not track postures. On losing `prone` or `sleep` they remove the
`svo.ignore` entry that the `sit`, `lie` or `sleep` alias set with the
reason "you sat down" or "you wanted to sleep". `sitting` raises
`svo ignore changed`; `sleeping` does not, so no serverside sync is
scheduled for sleep.

**`svo_Meteor_Compress.lua`** provides `svo.updatemeteors()` and
`svo.showmeteors()`, with a local `concatmap`, for the meteor-tracking
display.

**`Custom prompt tags/@affs.lua`** defines `paracelsus_affs_customtag2`, the
affliction list tag for the custom prompt. **`@exits.lua`** defines
`svo.cpp.show_exits` and `svo.cpp.show_exits_caps`. Both register their tags
(`@affs`, `@paracelsus_affs_customtag`, `@target`, `@exits`, `@EXITS`) with
`svo.adddefinition` from an anonymous `svo system loaded` handler registered
at script-body time, and `svo_Utilities.lua` does the same for `@mem` (Lua
memory use). None of these six tags is in `cp.definitions`. `@affs.lua`'s
abbreviation table mixes the two affliction vocabularies: it has GMCP-style
names such as `asleep` and `impaled`, which svof never stores, so `sleep` and
`impale` print unabbreviated. Bleeding shows only at or above
`conf.bleedamount`.

**Curing strategy files.** Six files define the strategy tables that decide
whether a multi-cure action is worth using now: `Tree_curing_strats.lua`,
`Fitness_curing_strats.lua`, `Rage_curing_strats.lua`,
`Restore_curing_strats.lua`, `Shrugging_curing_strats.lua` and
`Dragonheal_curing_strats.lua`. They are **not** data only. Each strategy is
`{ desc = "...", function () ... end }`: a description for `vconfig2` and a
**predicate at index 1**. The dictionary's `touchtree`, `restore`,
`dragonheal`, `shrugging`, `rage` and `fitness` actions decide `isadvisable`
by running `[1]` under `pcall` for every strategy in `svo.tree`,
`svo.restore` and the rest that is not disabled in `me.disabled*func`. The
predicates read `svo.affl`, `svo.me.locks.*` (filled by
`Controllers.lua:801`), `svo.gettreeableaffs()`, `svo.es_potions` and
`me.pipes.valerian.puffs`. The function extractor finds nothing in them only
because the functions are anonymous table members. Two harmless oddities:
the shrugging `any2affs` and `any3affs` count **tree**-curable afflictions,
and `rage.any2affs` says one of them must be rage-curable but only counts
afflictions.

#### `svo_Time_Tracking.lua`

Tracks Achaean time locally between server updates. `svo.me.time` holds `h`,
`m`, a `tictimer` and `min2s = 2.5`, the real-world seconds per Achaean minute.

* `svo.sync_time(hour)` sets the hour, zeroes the minute, kills any running
  timer and starts a new one at `min2s - getNetworkLatency()`. Subtracting the
  latency is what keeps the local clock from drifting behind the server's.
* `svo.tic_time()` advances one minute, rolls over at 60 and again at 24,
  echoes the new time, and re-arms itself.

Nothing in `src/` calls either function, so the local clock never starts.

#### `svo UI Experiments/`

Three small files, and not all experimental. `Rift_label_dimensions.lua`
creates `svo.riftlabel`, the herbstat window that `Rift.lua`
(`update_riftlabel`), `Config_system.lua` (`conf.riftlabel`,
`herbstatsize`) and the `vshow herbstat` alias all use. The other two come
alive through the `makechat` alias: with the Vyzor package installed it
builds `svo.ui.chat`, a tabbed chat frame, and calls `svo_enableCommChannel()`
(from `Enable_Comm.lua`), after which `svo_captureChats` copies channel lines
into it on `gmcp.Comm.Channel.Start`. Without `makechat` those two are inert.
The matching trigger folder `svo UI Experiments` is empty.

#### `Examples/`

Five demonstration files, shipped to show users how to hook svof's public
events rather than to do anything themselves. **All five ship inactive**
(`isActive: no`), and two also return on their first line
(`if true then return end`) until edited. `eventaffs`, which their comments
ask you to enable, is a deprecated option that `Config_system.lua` forces on.

* `Customize_systems_echos.lua` defines `svo.echos.demo` and
  `svo.echosd.demo` on `svo system loaded`, showing how to add a colour scheme.
* `mm_display_affs.lua` runs on `svo done with prompt` and shows a prompt
  affliction display.
* `MyAffs.lua` (credited to Lynara) runs on `svo got aff` and `svo lost aff`
  and counts afflictions with timings.
* `svo_example_affs.lua` registers on all four of `svo got aff`,
  `svo lost aff`, `svo got def` and `svo lost def`, and is the minimal
  template.
* `svo_update_window.lua` runs on `svo got aff` and `svo lost aff` and
  maintains a separate affliction window, with a local `highlight` helper.
---

### `svo (setup, misc, empty, funnies, dor)`

Five files, 131,602 bytes. These are the first and second subsystems loaded
and the helpers everything else depends on.

#### `Setup.lua` (72,439 bytes, loader `setup`)

The first loader called. Most of it is table construction rather than
functions, which is why the extractor finds only eight top-level definitions in
a file this size.

What it builds:

* `svo.me`, `svo.affs`, `svo.affl`, `svo.defc`, `svo.bals`, `svo.stats`,
  `svo.sys`, `svo.actions`, `svo.ignore`, `svo.serverignore` and the rest of
  the state tables.
* `svo.signals`, 65 of the system's 67, along with the cross-wiring described in the
  architecture section: `systemstart` emits `canoutr`, `gmcpcharname` emits
  `enablegmcp`, `quit` pre-emits `saveconfig` and raises `svo quit`.
* `svo.knownskills`, the class-to-skillset map that `svo.classchange` and
  `svo.haveskillset` both read.
* `svo.defdefup` and `svo.defkeepup`, the per-mode defence tables.
  (`svo.defs_data`, the `OrderedMap` of defence definitions, is built in
  `Defences.lua:57`, not here.)
* `svo.es_categories`, `svo.es_shortnames` and the default `es_potions`,
  which the elistsorter and the strategy files read, and `sk.arena_areas`,
  the 38 arena area names.

Its functions:

* `svo.phpTable(...)` builds an insertion-ordered table. It is used in exactly
  one place, `defences.nodef_list` (`Defences.lua:49` and `3582`), and has
  nothing to do with priority lists.
* `svo.ripairs(t)` iterates `ipairs` in reverse, used wherever removing while
  iterating matters.
* `svo.deepcopy(t)` is the recursive copy the defence modes and the dictionary
  both use. It keeps metatables.
* `parseaffname(s)` is a local that splits GMCP's `"name (n)"` into the name
  and the count.
* `me.getitem(what)` searches `me.inventory`, which the four
  `gmcpcharitems*` handlers maintain for `location == 'inv'` only.
* `svo.haveskillset(name)` (line 380) tests a precomputed set built from
  `knownskills[me.class:lower()]` when the loader runs.
* `svo.assert(cond, msg, extra)` **raises**. It calls `extra(msg)` when a
  third argument is passed and `error(msg)` otherwise.
* `sk.checkaeony()` decides whether you are in a state that forces slow
  curing, and sets `sys.sync`. On entry it also saves and forces
  `conf.commandecho` on, emits `signals.sync`, unblocks
  `cnrl.processcommand`, kills every in-flight action except the
  `waitingfor`, `aff` and `gone` ones and `aeon_smoke`, `checkslows_misc`
  and `touchtree_misc`, and with `conf.autotsc` sets `conf.blockcommands`
  off for retardation and on for aeon. Leaving reverses the echo, the sync
  emit and the block. It does not emit `changecuring` itself; every caller
  does, and that is what swaps `svo.make_gnomes_work` between the async and
  sync gnome.
* `svo.tablesave(sfile, t)`, path first, is a patched copy of Mudlet's
  `table.save`. It is how `conf` and most other state files are written.

**What the `setup` loader wires.** Setup is not only construction. These
handlers are all connected inside the loader, so they are remade on every
init:

* **GMCP vitals.** `gmcpcharvitals` handlers read `charstats`: `Rage:` into
  `stats.battlerage`, and `Bleed: N` drives the bleeding affliction (0 calls
  `svo.rmaff('bleeding')`, anything else
  `svo.dict.bleeding.aff.oncompleted(N)`). Class-gated handlers read
  `Sunlight`, `Morph` (clears morphs and grants the morph defence),
  `Stance` and `Form` (sets `me.path` to tekura or shikudo and flips
  `sk.ignored_defences`), `Essence`, `Momentum`, the epitaph length,
  `Manifestation`, `Karma`, `Wrath`, and the GMCP-driven `anathema` and
  `wrathbal` balances.
* **The GMCP affliction reconciler** (lines 633 to 792). `Add` resolves the
  game's name through `svo.dict.sstosvoa`, calls `svo.addaffdict` (the
  internal path), copies the level into `dict[name].count`, and runs
  `checkaeony` and `changecuring`. `Remove` clears `gaffl`, decrements
  `unknownany` only for a real untracked affliction, sets
  `sk.gmcp_cured[name]` (reset on the next prompt), calls `rmaff`, and zeroes
  a levelled count. `List` clears `gaffl` in place and rebuilds it, adds
  anything missing through the public `svo.addaff`, and removes anything
  tracked that the game did not list, gated on `svo.dict.svotossa`. Clearing
  in place is the `f2ab04f` fix: the handler used to assign
  `svo.gaffl = {}`, so from the first List on the public `svo.gaffl` was
  empty while the file-local alias (line 133) kept every name, and a name
  whose `Remove` was missed was never resynced away.
* **The GMCP defence reconciler.** `Add`, `Remove` and `List` translate
  through `svo.dict.sstosvod` and call `svo.defs['got_'..name](true)` or
  `svo.defs['lost_'..name]()`. `List` removes only names in
  `svo.dict.svotossd`.
* **Room.** `gmcproominfo` sets `me.is_underwater` and emits `newroom` on a
  room number change, `anyroom` always, and `newarea` on an area change.
* **Login.** An `enablegmcp` post-emit arms a 5-second trigger for "Password
  correct. Welcome to Achaea." that clears `svo.logging_in` and emits
  `changecuring`. The first time it sets `sys.enabledgmcp`; later it emits
  `relogin` and echoes "Welcome back!". It unpauses unless
  `svo.dont_unpause_login`. Two anonymous handlers on `sysLoadEvent` and
  `sysConnectionEvent` set `svo.logging_in = true` and emit `changecuring`.
  Because they are registered inside the loader, every class change adds two
  more, and the old ones keep emitting on the old bus.
* **Max health and mana.** `changed_maxhealth` and `changed_maxmana` echo the
  change, and when both rise in one paragraph a prompt trigger removes
  `stain`.
* **`systemstart`.** 13 permanent anti-illusion temp triggers (`saidnothing`,
  `nothingtowield` twice, `nothingtoeat`, `lungsokay`, `symp_webbed`,
  `symp_roped` twice, `weakbreath`, `symp_impaled` twice, `webeslow`,
  `symp_transfixed`), a 10-second duplicate-install check, and loaders for
  `lustlist`, `hoistlist`, `ignore` (which then forces
  `svo.ignore.checkparalysis = true`), `locatelist`, `watchfor`, the
  settings of the six strategy tables (`tree`, `fitness`, `rage`,
  `restore`, `dragonheal`, `shrugging`), `serverignore`, `cadmusaffs` and
  `prefercustom`, each from `<home>/svo/config/` with a matching
  `saveconfig` writer. The `serverignore` loader also calls
  `svo.setup_default_serverignore()`. **Defect, pre-existing:** these 13
  temp triggers, and six
  metamorphosis temp triggers at lines 1583 to 1629, are never stored or
  killed, so after N class changes each of those lines fires its handler
  N+1 times.
* **Class file.** `me.class` and `me.path` persist in
  `<home>/svo/config/my_class`. With no file, the class defaults to
  `'Infernal'`.
* **Defaults.** `conf` defaults (lines 1005 to 1132) apply only while
  `not svo.systemloaded`, which is also true on every class change. `sys`
  defaults apply always. The serverside batch queue is set up here
  (`sendqueuel = 18`, maximum command 2,048 characters), and `svo.send` is
  saved as `_G.send`.
* **Class-specific trigger groups.** Lines 1270 to 1411 enable or disable
  trigger and alias groups from `haveskillset`: the Shindo, Kaido,
  Spirituality, Propagation, Necromancy, Occultism, Alchemy, Groves and
  Harmonics defence groups, Monk, Hydra (class is Druid), Voice, Prayer,
  Fitness, Rage, Humour, Word, Domination entities, Shrugging, Two-hander
  recover footing, Elementalism channels, Age tracking, and the
  Elementalism and Spirituality alias groups. This is the mechanism the
  trigger reference means by class-specific folders, not class management.

`Setup.lua` is one of only four loaders without the self-reload tail, and for
it that is correct: re-running it would rebuild the signal bus underneath live
handlers.

#### `Miscellaneous_functions.lua` (22,111 bytes, loader `misc`)

The helper library. Loaded second because everything after it uses `echof`.

**Echo and colour.** `svo.vecho`, `svo.updatevecho`, `svo.echof`, `svo.echofn`,
`svo.echon`, `svo.itf`, `svo.errorf`, `svo.snd`, `svo.showprompt`,
`svo.setdefaultprompt`, `svo.updateloggingconfig`, `ofs.windowdecho`,
`ofs.windowecho`. The `svo.echos.*` and `svo.echosd.*` pairs are the city
colour schemes: `Eleusis`, `LightGreen`, `Mhaldor`, `Ashtan`, `Shallam`,
`Targossas`, `Hashan`, `Cyrene` and `default`. `echos.X` is the scheme's
echo function, and `echosd.X()` returns the scheme's default text colour
tag, which is what `svo.getDefaultColor` points at. It is not a darker
variant. `Shallam` is kept alongside `Targossas` because the configuration
migration renames one to the other and old settings files still say
`Shallam`.

`svo.updatevecho()` picks `echos[conf.echotype] or echos[conf.org]` and sets
`svo.vecho`, `svo.getDefaultColor` and `svo.getDefaultColorNums`. It runs at
`systemstart` and on `orgchanged`. `svo.updateloggingconfig()` builds
`svo.debugf` for `conf.log` off, to a file (Mudlet's `Logger`), or to the
screen. `svo.echof` routes to a named window when its first argument is a
bare word. `svo.snd` splits on `$` and sends twice under seriousconcussion,
or under `doubledo` with stupidity.

**Tables and strings.** `svo.getHighestKey`, `svo.getLowestKey`,
`svo.getHighestValue`, `svo.getBoundary`, `svo.oneconcat`,
`svo.oneconcatwithval`, `svo.concatand`, `svo.concatandf`, `svo.keystolist`,
`svo.longeststring`, `svo.safeconcat`, `svo.containsbyname`, `svo.contains`,
`svo.basictableindexdiff`, `svo.convert_string`, `svo.convert_boolean`,
`svo.sk.reverse`, `svo.sk.anytoshort`. `svo.getHighestKey` is the one the
check functions call to pick the winner out of a priority table.

**Line handling.** `svo.deleteLineP` and `svo.deleteAllP` are the
prompt-aware delete functions. `svo.find_until_last_paragraph` and
`svo.count_until_last_paragraph` scan the lines since the last prompt. The
lineguard mechanism does **not** use them (it uses `svo.paragraph_length`);
their users are the symptom checkers (`hypochondria_symptom`,
`unparryable_symptom`), `sk.checkrewield`, and some trigger handlers.

**Sending.** `svo.fancysend(what, store)` is the send the async gnome swaps
in for `send` when `commandechotype` is `fancy`. With `conf.batch` it calls
`svo.sendc` and records the command in `sk.systemscommands`, otherwise the
saved original `send`. It repeats the command for seriousconcussion or
doubledo with stupidity (unless `sys.sendonceonly`) and `conf.repeatcmd`
times, and remembers it so `svo.fancysendall` can echo `(a|b|c)` at the end of
the prompt.

**Events.** `svo.events(event, ...)` and `svo.gevents(_, key)` are the real
bodies behind the two `pcall` wrappers in `Event handlers/`. `events` emits
`signals[event:lower()]` when it exists, and `gevents` strips the dots from
the GMCP key and lowercases it. 17 of the 19 Mudlet events on `svo_events`
resolve to a signal; `CharVitals` and `RoomNum` resolve to nothing. See "The
signal bus".

**Ignore lists.** `svo.setignore`, `svo.unsetignore`, `svo.setserverignore`,
`svo.unsetserverignore`. Each writes the table and raises the matching
`svo ignore changed` or `svo serverignore changed` event, which `svo_events`
routes back into the bracket signal of the same name, where serverside picks
it up.

**Weapons.** `gmcpcharname` sends `Char.Items.Inv`. The
`gmcpcharitemslist`, `update` and `remove` handlers maintain
`me.wielded[id]`, with a `hand` field from the `l` or `L` attribute, and
raise `svo me.wielded updated`. An involuntary unwield calls
`svo.unwielded`, which queues the item in `sk.rewielddables` and, with
`conf.autorewield`, connects `sk.checkrewield` to `before_prompt_processing`.
A GMCP re-wield completes the `rewield` action through `checkaction` and
`lifevision.add`. `enablegmcp` subscribes to `IRE.Time` and requests it.

**Misc.** `svo.syncdelay()` returns the extra delay slow curing adds.
`svo.update(t1, t2)` is **not** an update entry point: it is a recursive merge
of `t2` into `t1`, which every configuration loader uses. The update check is
`svo.checkforupdates`. `svo.yep`, `svo.nope`, `svo.red`, `svo.green` are colour
shorthands, `svo.ceased_wielding` and `svo.unwielded` track weapons, and
`svo.installationfolder()` returns where svof keeps its files. That last one
is one of the functions the project brief flags as having been rewritten: it
used to derive from `getModulePath`, which does not exist for a package.
`svo.test = 5` is a leftover.

#### `Empty_cure_handling.lua` (13,442 bytes, loader `empty`)

What to conclude when a cure went through and **cured nothing**. If you ate
goldenseal and no cure line followed, you probably have none of the
afflictions goldenseal cures, so they are removed, unless the game says you
still have one. These functions are what the dictionary's `empty` outcomes
call (see "Empty cure" in the workflows).

**`presume_cured(which)`** is the gate that all but eight of this file's
removals go through. It is a local, exported as `empty.presume_cured` and
`svo.presume_cured` so an addon or a user's own empty handler can apply the
same rule. It takes a name or a list:

1. While `affs.blackout` is set it removes nothing. Blackout stops
   `Char.Afflictions`, so `svo.gaffl` is stale rather than empty, and every
   name would read as still held.
2. Otherwise it collects the bare names in `svo.gaffl`, stripping a
   ` (n)` level suffix the way Setup's `parseaffname` does, and looks up each
   svof name's game name in `svo.dict.svotossa`.
3. It keeps every affliction the game still reports, logging it with
   `debugf`, and passes the rest to `svo.rmaff`.

A name absent from `svotossa`, which GMCP therefore cannot report, is always
removed, as it was before the gate. With no GMCP data at all, which is what a
profile looks like before its first `Char.Afflictions` message, every name
falls through to the old behaviour. The comment above the function says only
the four unknowns remain outside the gate; that is not quite right. Seven
names in the gated lists are absent from `svotossa`: `unknownany`,
`unknownmental`, `unknowncrippledarm` and `unknowncrippledleg`, plus
`blindaff` and `deafaff` in `empty.apply_epidermal_head` (`sstosvoa` maps
`blindness` and `deafness` to `false`) and `hoisted` in `empty.writhe` (not
in `sstosvoa` at all).

The handlers: `empty.eat_bloodroot`, `empty.eat_ginger`, `empty.focus`,
`empty.tree`, `empty.writhe`, `empty.smoke_elm`, `empty.smoke_valerian`,
`empty.smoke_pear`, `empty.sip_immunity`, and the salve set:
`empty.apply_epidermal_head`, `empty.apply_epidermal_body`,
`empty.apply_mending_head`, `empty.apply_mending`,
`empty.noeffect_mending_arms`, `empty.noeffect_mending_legs`,
`empty.apply_health_head`, `empty.apply_health_torso`,
`empty.apply_health_arms`, `empty.apply_health_legs`.

Lines 81 to 103 also **generate** `empty.eat_<herb>` for goldenseal, kelp,
lobelia, ginseng, ash, pear, bellwort and bloodroot. Each calls
`svo.lostbal_herb()` and passes that herb's afflictions to `presume_cured`,
skipping the madness-blocked set while `madness` is held. `eat_bloodroot` is
then redefined at line 107 to presume paralysis and slickness cured.
`empty.focus` returns at once while `madness` is held. `empty.dragonheal` and
`empty.shrugging` are aliases of `empty.tree`, which also zeroes the
`unknownmental` and `unknownany` counts unconditionally; its comment reasons
that neither unknown is in `svotossa`, so the gate always removes them
anyway. `empty.smoke_elm` rules out `earworm` as well as deadening, madness
and aeon, and its comment notes that `tension` and `unweavingspirit` also
name elm as a cure and are still absent.

**Gated and ungated.** Every handler goes through `presume_cured` except
eight that pair a removal with an explicit count reset: `apply_mending`,
`noeffect_mending_arms`, `noeffect_mending_legs`, the four `apply_health_*`
and `eat_ginger`. Those still call `svo.rmaff` directly, deliberately. The
comment above them says why: keeping an affliction while zeroing its count
would leave a state neither half agrees with, and what the count should do
when GMCP overrules the removal is an open question.

**`empty.treecurables`** holds 90 names, up from 80 at `82e7f14`. The comment
above it records the standard for adding one: confirmation from the repo
owner or in game. Neither the old 86-name tree list nor the presence of a
`Tree cures` trigger counts as evidence, because nearly every such line has a
twin in `General cures` on the same pattern. The comment names six entries that
are kept but unconfirmed (paralysis, the four fractures, and `latched`,
whose confirmed cure is SIP HEALTH), and says bleeding must not go back in:
the game reports bleeding in `Char.Vitals.charstats` as `Bleed: N`, not as
an affliction. Every remaining tree-cure trigger names an affliction in this
list. The other direction does not hold: 29 names have no tree-cure trigger,
so svof clears them on an empty tree but cannot recognise a tree curing them.

Every function here is referenced from the dictionary or
`Main_trigger_functions.lua` except `empty.smoke_pear`, which nothing calls
(the reference xml has the same single occurrence, so this is
pre-existing), and `presume_cured`, which only this file calls.

The file also exports four lists: `svo.degenerateaffs`,
`svo.deteriorateaffs`, `svo.focuscurables` and `svo.treecurables`.
`empty.treeblocks` records that madness and hypothermia block tree for the
afflictions they list. `svo.gettreeableaffs(getall)` applies those blocks
and, without `getall`, keeps only afflictions you have. The strategy
predicates call it.

#### `Funnies.lua` (15,758 bytes, loader `funnies`)

Mostly data. `svo.lifep.sayhello` and `life.sayhello` are the two functions.
The file holds the flavour responses and jokes. On `charname` and
`gmcpcharname`, `life.sayhello` waits 2 to 7 seconds, arms temp triggers for
the game's time-of-day lines, and sends `time raw`. `svo.lifep.sayhello` gags
that output with `deleteAllP`, greets you by time of day, and 2 to 5 seconds
later prints a random entry from `svo.protips` (about 95, plus class-gated
extras).

#### `Dor.lua` (7,852 bytes, loader `dor`)

The command queue. svof keeps two queues, `me.doqueue` and `me.dofreequeue`.
Both need balance, equilibrium and both arm balances before anything runs:
`svo.check_dofree` refuses otherwise, the same as `check_do`. The difference
is how they are scheduled. At `systemstart`, `check_do` is registered with
`svo.addbalanceful("svo check do")` and runs **one** queued item per balance;
`check_dofree` is registered with `svo.addbalanceless("svo check dofree")`
and runs **every** queued item at once, without being the
balance-consuming action. Queued strings are split on `$` and run through
`expandAlias`, so an entry can be an alias. A queued function is `pcall`ed.

* `svo.doadd(cmd)` and `svo.doaddfree(cmd)` append.
* `svo.dofirst(cmd)` and `svo.dofreefirst(cmd)` prepend.
* `svo.donext()` is the "my balanceful action is done" call. It bumps
  `sys.balancetick`, kills `sys.actiontimeoutid`, and reruns the gnomes
  (unless called from a trigger), which reopens the balance controller's
  once-per-tick guard.
* `svo.dor(cmd)` is do-repeat: keep sending until told to stop.
* `sk.check_do()` and `svo.check_dofree()` are the per-prompt drains.
* `sk.getactiondo()` returns the pending action.
* `svo.undo()`, `svo.undofree()`, `svo.undoall()`, `svo.undoallfree()` remove
  entries.
* `svo.doshow()` prints both queues.

Each mutation raises `svo do changed` or `svo dofree changed`, which is how
the custom prompt knows to redraw, and calls `svo.make_gnomes_work()` unless
the traceback contains `Trigger`, so typing `do x` acts at once.

Two small defects, both pre-existing: `svo.undo()` with no argument echoes
"Removed ..." but removes nothing (lines 198 to 205), and `svo.doshow` reads
`me.dorepeat`, which nothing sets (the flag is `me.doqueue.repeating`).

---

### `svo (actions dictionary)`

One file, `Dictionary_of_actions_(affs-defs-misc).lua`, 509,613 bytes, loader
`dict`. The dictionary itself is described in the mechanisms section. Its
functions:

**Four locals for monk classes.** `tekura_ability_isadvisable(new_stance)` and
`shikudo_ability_isadvisable(new_form)` share one shape: the stance or form is
advisable if either defup or keepup wants it, you do not already have it, you
are on the right path (`me.path == 'tekura'` or `'shikudo'`), nothing
balanceful is in flight, and you are not riding.
`tekura_stance_oncompleted(new_stance)` and
`shikudo_form_oncompleted(new_form)` clear all the sibling stances or forms
and then set the new one, since they are mutually exclusive.

**`svo.codepaste`**, 18 shared closures defined in the dictionary (lines 138
to 412) that entries reuse rather than duplicate, plus `balanceful_codepaste`
from `Action_system.lua:200`, 19 in all:

| Function | Does |
|---|---|
| `writhe` | the writhe action shared by every restraint |
| `checkreavekill`, `checkdismemberkill` | instakill **warnings**, not kill logic: humour count 2, 3 or 4, and bound plus impaled when fighting a Sentinel |
| `badaeon` | warns ("walk out") when you hold aeon plus asthma, stupidity, voided, or asthma with anorexia |
| `addrestobreakleg`, `addrestobreakarm` | **add** a limb-break affliction, but only when anti-illusion is off, health dropped, the paragraph has 3 or more lines, or recklessness has been held long enough. The Tekura path batches breaks for `latency + conf.tekura_delay` so a double hit lands together. The arm version also emits `canoutr` |
| `remove_focusable` | decrements `unknownmental` by one, removing it at zero. Every `gone` of a focusable mental calls it |
| `remove_stackableaff` | decrement a stacking affliction |
| `nonstdcure` | true while a tree, restore or shrugging action is in flight |
| `nonmorphdefs` | metamorphosis only |
| `smoke_elm_pipe`, `smoke_valerian_pipe`, `smoke_skullcap_pipe` | the three pipe smokes |
| `balanceful_defs_codepaste` | are we mid-way through a balanceful defence |
| `addunknownany` | record an affliction we know we got but cannot name |
| `remove_burns`, `pyre_holds` | burn-level handling |
| `serversideahealthmanaprio` | keep serverside's health/mana priority in step with ours |
| `balanceful_codepaste` | alias assigned in `Action_system.lua` to `svo.will_take_balance` |

**Burn levels.** `sk.next_burn`, `sk.current_burn` and `sk.previous_burn` walk
the ablaze severity ladder.

**Dictionary machinery.** `svo.basicdef` builds a plain defence entry.
`svo.find_lowest_async` and `svo.find_lowest_sync` find the lowest-priority
action on a balance. `svo.dict_setup` and `svo.dict_validate` are described
above. `svo.make_prio_table`, `svo.make_sync_prio_table`,
`svo.make_prio_tablef`, `svo.make_sync_prio_tablef` build the lookups;
`svo.clear_balance_prios` and `svo.clear_sync_prios` reset them.
`svo.sk.check_retardation` is the retardation test that feeds `sk.checkaeony`.
`svo.basicdef(which, command, balanceless, gamename, undeffable)` builds a
`physical` defence with `def = true`, `balanceless_act` or
`balanceful_act`, and the standard defup and keepup `isadvisable`.

**Patterns that recur across entries**, worth knowing before reading one:

* **Restoration's two-stage cure.** A restoration salve's `oncompleted`
  spends salve balance and starts a `curing<aff>.waitingfor` with
  `customwait = 6`. The heal line completes it (mutilated to mangled to
  crippled, serious to mild), and `ontimeout` assumes it worked. `empty` is
  the same as `oncompleted` because the apply gives no message.
* **Timed afflictions.** Uncurable afflictions that wear off (stun,
  unconsciousness, numbed arms, pinshot, dehydrated, timeflux, voided,
  hamstring, stain, degenerate, deteriorate and about 20 more) are an `aff`
  that starts a `waitingfor` whose `customwait` is the duration, and
  `ontimeout` removes it. Several have no `ontimeout` (inquisition, lullaby,
  icing, flamefisted, voided, galed and others), so they clear only
  on a cure line.
* **`latched` is cured by a sip.** Until `a707668` it was a timed
  `waitingfor` with a 20-second `customwait`, never cured and dropped after
  20 seconds whether or not it was still held. Its entry (line 7,932) now
  has a `sip` handler that sends `sip health`, advisable while `affs.latched`
  is set and no latched action is in flight, whose `oncompleted` and `empty`
  both call `svo.lostbal_sip()` and remove the affliction. An entry-level
  `onadded` calls `svo.lostbal_sip()` too, because gaining latched costs
  elixir balance once. It is on `onadded` rather than `aff.oncompleted`
  because the GMCP `Add` path calls `addaffdict` directly and never runs the
  `aff` action. `latched` has no line in `default_prios`, so `dict_setup`
  places it at the bottom of the `sip` list.
* **Anti-illusion probes.** A `check*` entry's `aff.oncompleted` accepts the
  affliction at once when `svo.paragraph_length > 2` (a one-line illusion
  cannot produce a long paragraph) and otherwise only sets
  `svo.affsp[aff]`. The probe's `misc.isadvisable` fires on that suspicion,
  its reply selects a named confirmation, and `onclear` handles the negative.
* **Burn ladder.** ablaze, severe, extreme, charred, melting. Each mending
  apply steps down one rung, `all` clears every burn, and `pyre_holds` skips
  a rung pyre would restore.
* **Pause while transforming.** dragonform, mace, viridian, rejuvenate and
  the morphs pause the system (`unpauselater`), and a `waitingfor*`
  unpauses on completion, cancel or timeout.
* **Diagnose on unknowns.** `diag.physical` fires when `sys.manualdiag` is
  set, or `unknownmental` reaches `conf.unknownfocus`, or `unknownany`
  reaches `conf.unknownany`.
* `blackout.aff` adds disrupt after 4.5 seconds and, when class management
  shows necromancy or curses enabled, schedules assumed crippled limbs or
  suspected asthma and anorexia.

**Connections made in this loader.** `curedwith_focus` calls
`svo.dict.unknownmental.focus[what]()` on every focus completion, so each
focus cure also decrements `unknownmental`. `newroom` drops `listen`,
`block`, `eavesdrop` and `lyre`, removes impale ("We escaped"), and runs
`sk.check_retardation`. `systemstart` builds `sys.input_to_actions` from the
`sipcure`, `eatcure`, `smokecure`, `action` and `actions` of every non-probe
handler, which is how a typed cure becomes a tracked action. The `dragonform`
signal (emitted at `systemstart` and on every `gmcpcharstatus`, which also
sets or clears the `dragonform` defence from `gmcp.Char.Status.race`)
rebuilds the defence shortlists.

**Defects in the dictionary, all pre-existing** (the same text is in the
reference xml):

* `unweavingbody.aff.oncompleted` (line 8614) and
  `crescendo.aff.oncompleted` (9045) call `svo.addaffdict(dict.X)`, and no
  `dict` exists in scope, so both raise. Both are mapped in `sstosvoa`. The
  GMCP `Char.Afflictions.List` handler adds a missing affliction through the
  public `svo.addaff`, which runs `aff.oncompleted`, so a list containing
  either one raises inside the handler and abandons the rest of that resync:
  later additions, `checkaeony`, `changecuring`, and every removal. The GMCP
  `Add` path uses `addaffdict` directly and is unaffected.
* `fortifiedair.oncompleted` tests `defc.fortifiedwaterand` (12640), a typo
  for `fortifiedwater and`, so fortifying air last never grants
  `fortifyall`.
* `aria.physical.onstart` calls `svo.apply(svo.dict.aria.salve, ...)` when
  deaf, and `aria` has no `salve` handler.
* `bonding`'s `gone` is nested inside `physical` (11513). `dict_setup`
  synthesises a top-level one, which hides it.
* `oncuredleft` exists on eight `curing*` waitingfors and nothing calls it.
* `dict_validate`'s sync half tests the wrong variable (see "The action
  dictionary").

---

### `svo (curing skeleton, controllers, action system)`

Three files, 142,467 bytes. This is the engine.

#### `Action_system.lua` (15,569 bytes, loader `action`)

Fully described in the mechanisms section. Functions: `svo.doaction`,
`svo.checkaction`, `svo.checkany`, `svo.findbybal`, `svo.will_take_balance`,
`svo.findbybals`, `svo.actionclear`, `svo.actionfinished`, `svo.killaction`,
`svo.usingbal` (alias `svo.usingbalance`), `svo.doingaction` (alias
`svo.doing`), `svo.haveorwill`, `svo.valid_sync_action`.

#### `Curing_skeleton.lua` (80,698 bytes, loader `sk`)

The largest engine file, with 108 top-level functions. Six groups.

**1. The ten balance checks.** These are the per-balance decisions, and they
all share one shape. `svo.check_herb` is representative:

```lua
svo.check_herb = function(sync_mode)
  -- can we even eat?
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

Four things to read out of that, because most of the ten follow it:

* The guard is "do I have the balance, is it already spoken for, and is there
  any affliction that makes this pointless".
* Candidates come from two places: your current afflictions, and the defence
  shortlist, but the defence shortlist only when you are actively deffing or
  `keepup` is on.
* Each candidate must pass `isadvisable()`, must not be on either ignore list,
  and must be physically possible: either you can outrift, or you are holding
  the herb.
* `sync_mode` flips the whole function from *doing* to *returning*, and swaps
  `aspriority` for `spriority`. That single parameter is the entire async
  versus slow-curing split.

The ten: `svo.check_sip`, `svo.check_purgative`, `svo.check_salve`,
`svo.check_herb`, `svo.check_misc`, `svo.check_smoke`, `svo.check_moss`,
`svo.check_focus`, `svo.check_balanceful_acts`, `svo.check_balanceless_acts`.
`check_misc` takes a second parameter, `onlyamnesia`, because amnesia and fear
have to be handled before everything else.

Where they depart from the herb shape:

* **Not all pick one.** In async mode `check_misc` walks every advisable
  candidate from highest to lowest priority and does each, letting only one
  `dontbatch` action through (lines 236 to 250). `check_balanceless_acts`
  also fires every candidate. The rest pick the single best.
* `check_sip` considers only held afflictions plus `healhealth` and
  `healmana`, with no defence shortlist. `check_moss` considers only
  `healhealth` and `healmana`, and only when `conf.secondarymoss` is off.
* `check_smoke` has no `usingbal('smoke')` guard; it tests
  `not svo.doingaction(i)` per candidate instead. Asthma and mucous block it,
  and it adds `checkasthma` when asthma is suspected.
* `check_misc` has no balance gate at all, only stun and unconsciousness.
  While asleep, only the `sleep` action passes.
* `check_focus` needs any affliction, focus balance, `can_usemana()`,
  `conf.focus`, willpower above 75, none of impatience, sandfever or
  inquisition, and the cadmus rules.
* `check_balanceful_acts` and `check_balanceless_acts` need balance,
  equilibrium, both arms, and for Druids hydra. Their candidates are
  `dict_balanceful(_def)` and `dict_balanceless(_def)`.
* Every check skips an action when `conf.serverside and
  svo.serverignore[action]`, that is, when the server is curing it.

`svo.sk.checking_herb_ai()` is the anti-illusion pause: with `waitherbai` on,
svof will not eat again while a herb claim is still unsettled.

**2. Lifevision.** `svo.lifevision.add`, `addcust`, `getlineguard`,
`clearlineguard`, `validate`, and the local `run_through_actions`. Described
in the mechanisms section.

**3. Affliction and balance state.**

* `svo.addaff(x)` dispatches on type: a table goes to the internal path, a
  string to the public one.
* `old_internal_addaff(new_aff)` (local) is the fast path. It returns early if
  the affliction is already present, creates `svo.affs[name]` with a pointer to
  the dictionary entry and a running stopwatch, calls `onadded` if the
  dictionary defines one, and then, only if `svo.affl[name]` was not set,
  mirrors it into `svo.affl`, emits `svogotaff` and raises `svo got aff`. The
  two tables are different on purpose: `svo.affs` is the internal record with
  its stopwatch, `svo.affl` is the public list.
* `old_public_addaff(new_aff)` (local) is the API path, with asserts on the
  name. It prefers the dictionary's `aff.forced` handler, falls back to
  `aff.oncompleted`, and only then to the internal add. Then it unblocks
  `cnrl.checkwarning`, re-runs `sk.checkaeony()`, emits `changecuring` and runs
  `codepaste.badaeon()`. That four-step tail is what makes an affliction that
  causes aeon immediately switch the system into slow curing.
* `svo.addaffdict` is an alias for the internal path.
* `svo.rmaff(old)` accepts a table and recurses, or a name. It clears
  `svo.affl` first and raises `svo lost aff`, then clears `svo.affs`, then
  calls `onremoved`. The ordering is commented: `onremoved` runs after the
  tables are clean because handlers there read current state. It also emits
  `signals.svolostaff`, and echoes how long you had the affliction when
  `conf.showafftimes` is on.
* `svo.removeaff(which)` is the public version, which also clears the pending
  lifevision claim and runs the same `checkaeony` and `changecuring` tail. Its
  own comment says the two should be merged. **It also recurses into itself
  forever** when the entry has no `gone` sub-table, which is the case for the
  eight `check*` predictions its own assert admits. See the findings section.
* `svo.removeafflevel(which)` decrements a stacking affliction.
* `svo.updateaffcount(which)` raises `svo updated aff` with the new count.
* `svo.addbalanceless`, `svo.removebalanceless`, `svo.addbalanceful`,
  `svo.removebalanceful`, `svo.clearbalanceful`, `svo.clearbalanceless`
  manage the two lists the balance controller walks.

**4. The seventeen `lostbal_*` functions.** One per balance:
`svo.lostbal_tree`, `lostbal_focus`, `lostbal_shrugging`, `lostbal_fitness`,
`lostbal_rage`, `lostbal_prayer`, `lostbal_voice`, `lostbal_sip`,
`lostbal_herb`, `lostbal_salve`, `lostbal_moss`, `lostbal_purgative`,
`lostbal_smoke`, `lostbal_dragonheal`, `lostbal_word`, `lostbal_anathema`,
`lostbal_wrathbal`. The last three exist only for terminus, anathema and
excision. Each clears `bals.<name>` and raises `svo lost balance` with the
name. The lifevision illusion path calls these by name,
`svo['lostbal_'..balance]`, which is why the naming has to stay exactly
regular.

For every balance the game announces the return of, the timer each one arms
is a **failsafe**, not the restore. It restores the balance only if nothing
else has since: `sk.<bal>tick` must still match and `bals.<bal>` must still
be false. The primary restore is the game's own "you may eat another herb"
style line, handled through the ledger (see "Balance bookkeeping" in the
workflows). The failsafe times are `conf.ai_reset*bal`: herb 2.5 seconds,
sip 10 (Setup's default of 7 is migrated to 10 on every load, see
`Config_system.lua`) and doubled with addiction, salve 5, moss 10,
purgative 10, smoke 2, dragonheal 20 plus ping, focus 5 or 8 with rixil.
Shrugging, fitness, rage (15 plus ping), prayer (3 plus ping), voice (10 plus
ping) and word (17 plus ping) use fixed values. **Tree is the exception**:
its timer, `sys.treetimer`, has no tick check, so it restores the balance
unconditionally when it fires (`conf.treebalance`, else 16 or 40 seconds
plus ping by `conf.efficiency`, plus 10 with ninkharsag) and echoes "Can
touch tree again." The game's line ("You may utilise the tree tattoo
again.") goes through `valid.gottree` and the ledger like any other, and its
completion kills `sys.treetimer`.
`lostbal_anathema` and `lostbal_wrathbal` arm no timer, because GMCP vitals
drive those two. `lostbal_herb` also opens `sk.blockherbbal` for
`ai_minherbbal` seconds (0.5 for a mickey), during which a herb regain line
is rejected as too fast.

**5. The fourteen symptom checkers.** `svo.sk.retardation_symptom`,
`stupidity_symptom`, `illness_constitution_symptom`, `transfixed_symptom`,
`stun_symptom`, `impale_symptom`, `aeon_symptom`, `paralysis_symptom`,
`haemophilia_symptom`, `webbed_symptom`, `roped_symptom`, `impaled_symptom`,
`hypochondria_symptom`, `unparryable_symptom`. Each is called from a trigger
that saw a line consistent with the affliction, and decides whether the
evidence is enough to add it. Each counts sightings in a decaying window
(`syncdelay() + sys.wait * n`, or a fixed time) and acts at a threshold of 2,
3 or 4. Eight of the fourteen do nothing with `conf.serverside` on:
stupidity, illness_constitution, transfixed, impale, paralysis, webbed,
roped and impaled. `retardation_symptom` probes with `checkslows` under
anti-illusion, and adds `unknownany` under blackout.

**6. Everything else.**

* `svo.errorf`, `svo.echon`, `svo.contains` are local re-exports.
* `find_highest_action(tbl)` (local) picks the highest `spriority`.
* `work_slaves_work()` (local) is the async ordering.
* `svo.make_gnomes_work_async`, `svo.make_gnomes_work_sync`,
  `svo.send_in_the_gnomes`, `svo.sk.balance_controller` are the decision loop.
* `svo.update_rift_view()` refreshes the rift display.
* `svo.sk.getuntilprompt()` returns text between here and the prompt.
* `svo.sk.makewarnings()` and `svo.sk.warn()` build the lock warnings.
  `sk.warn(name)` throttles: once given, the same warning stays silent for
  its `time` seconds. `makewarnings` rebuilds the table at `systemstart`,
  `orgchanged` and `curemethodchanged`, with pipe names for the current
  `curemethod`.
* `sk.onprompt_beforeaction_add/do` and
  `sk.onprompt_beforelifevision_add/do` are the two prompt hook queues.
  `svo.prompttrigger(name, func)` is the public wrapper around the first.
* `sk.doingstuff_inslowmode()`, `sk.checkwillpower()`,
  `svo.sk.increase_lagconf()`. `checkwillpower` swaps `svo.can_usemana` for
  a stricter version below 1,000 willpower and back above 1,500.
  `increase_lagconf` caps at 3 and needs two calls within 10 seconds, and 30
  seconds after an increase it resets the level from
  `3 * getNetworkLatency()`. **Defect, pre-existing:** `sk.increasedlag` is
  set true both on an increase and when the 10-second window lapses, and
  nothing clears it, so the automatic lag increase happens at most once per
  Mudlet session.
* Morph handling: `svo.sk.clearmorphs`, `inamorph`, `validmorphskill`,
  `inamorphfor`, `updatemorphskill`.
* `svo.sk.enable_single_prompt()`, `svo.sk.showstatchanges()`.
* Parry support: `svo.sk.have_parryable()`, `svo.sk.cant_parry()`.
* `sk.check_burrow_pause()`, `svo.sk.check_shipmode()`.
* `svo.balanceful_used()`, `svo.getping()`, `svo.sk.sawcuring()`,
  `svo.sk.sawqueueing()`, `svo.amiwielding()`.
* Sending: `sk.sendqueuecmd`, `svo.sendcuring`, `sk.dosendprios`,
  `svo.sendcuringprio`, `sk.dosendqueue`. This is the batching transport.
  `svo.sendc` is `sk.sendqueuecmd`: it queues strings (flushing before 2,048
  characters) or runs a `{func, args}` entry after flushing. `sk.dosendqueue`
  sends one command plainly, up to 10 joined with `conf.commandseparator`,
  up to 9 as `9multicmd {a}{b}...` (the server alias
  `sk.setup9multicmd` sets up at login), or more as
  `setalias multicmd a/b/...` plus `multicmd`, in chunks of 10. It flushes on
  a `tempTimer(0)` and at the end of `onprompt`, never while logging in.
  `svo.sendcuring` prefixes `curing `. `svo.sendcuringprio` batches
  `curing priority [defence] <x> <n>` into four queues (normal and slow,
  affliction and defence), wrapping slow ones in
  `curingset switch slowcuring`, and `sk.dosendprios` rate-limits to four
  sends a second.
* `svo.sk.setup9multicmd()` and `svo['9multicmd_cleared']()` handle the
  command separator.
* `svo.sk.fix_affs_and_defs()` does not reconcile with GMCP. It flips blind,
  deaf and (for fire elementals) ablaze between affliction and defence,
  from the current mode's defup and keepup and `mindseye`, then calls
  `sk.updateserversideprios`. Defup and keepup changes call it.
* `svo.sk.checkrewield()` runs once on `before_prompt_processing` and fills
  `svo.dict.rewield.rewieldables` unless the paragraph shows a voluntary
  unwield. `sk.removed_something` marks a GMCP item removal for one prompt.
* `newroom` drives arena mode from `sk.arena_areas` when `conf.autoarena` is
  on (not under dementia or unknown afflictions). Leaving an arena resets
  both arm balances. **Defect, pre-existing:** that path raises
  `svo config changed` with ``"arena`"``, a stray backtick (line 2181).
* Three more `gmcpcharitemslist` handlers: `inr all` for the `inra` flow
  (`sk.inring`), picking up herbs from the room for `vget herbs`
  (`sk.retrieving_herbs`, through `doaddfree("get <id>")`), and Occultism's
  heartstone and simulacrum defences.

#### `Controllers.lua` (46,200 bytes, loader `controllers`)

The prompt cycle and the user command path. 36 top-level functions.

**`svo.onprompt()`** is the function everything else exists to serve. In
order:

1. Raise `svo before the prompt`, set `sk.processing_prompt`, clear
   `sk.systemscommands`, increment `svo.promptcount`.
2. `checkblackout()` and `check_promptflags()`, two locals that read the
   prompt's own flag characters.
3. Zero `sys.lagcount`. Reaching a prompt is proof that the lag cleared.
4. `svo.prompt_stats()` and `calculatestatchanges()`.
5. Emit `before_prompt_processing` inside `pcall`, with a clickable `(e!)`
   error link on failure.
6. **`svo.send_in_the_gnomes()`**, which validates lifevision, emits
   `after_lifevision_processing`, and runs the decision.
7. Show stat changes, if `showchanges` and the echo mode call for it here.
8. Emit `after_prompt_processing` inside `pcall`.
9. Show stat changes, if the echo mode calls for it here instead.
10. `svo.defupfinish()` if a defup run is in progress.
11. `svo.fancysendall()` to flush echoed commands, then `sk.dosendqueue()` to
    flush the batch.
12. Record `svo.lastpromptnumber` and `svo.lastprompttime`. The comment
    explains why reading Mudlet's already-computed timestamp is safe where
    calling the clock would not be.
13. Reset `svo.paragraph_length` to 0, clear `sk.processing_prompt`, raise
    `svo done with prompt`.

**Prompt reading.** `svo.valid.setup_prompt`, `check_promptflags` (local),
`checkblackout` (local), `svo.blackout`, `svo.prompt_stats`,
`calculatestatchanges` (local), `svo.goteq`, `svo.gotbalance`,
`svo.gotarmbalance`, `svo.extended_eq`.

* `svo.prompt_stats()` reads `gmcp.Char.Vitals` into `stats`. It **pauses
  the whole system** when GMCP vitals are absent, fills blanks during
  blackout, and substitutes `conf.assumestats` percent under blackout or
  recklessness. It emits `changed_maxhealth` and `changed_maxmana`, whose
  handlers recompute `sys.siphealth`, `sys.mosshealth`,
  `sys.transmuteamount`, `sys.corruptedhealthmin`, `sys.bloodswornoff`,
  `sys.sipmana`, `sys.mossmana` and `sys.manause`.
* `svo.goteq()`, `svo.gotbalance()` and `svo.gotarmbalance()` are called by
  the equilibrium, balance and Monk arm-balance regain triggers. Each bumps
  `sys.balancetick` and kills `sys.actiontimeoutid`, which is how a regained
  balance reopens the balance controller. `svo.blackout()` is called by the
  blackout prompt triggers and sets the flag `checkblackout` reads.
* **Disrupt inference.** On `svo lost balance` for equilibrium, after
  `conf.noeqtimeout` (5 seconds) without equilibrium, and not in an
  `extended_eq` action, news, or already disrupted, svof adds `disrupt` (and
  `confusion` when `me.passive_eqloss`). Regaining equilibrium removes it.
  Off with serverside. These handlers listen on the bracket signals, which
  are fed by svof's own `raiseEvent("svo lost balance", ...)` from the prompt
  trigger going out to Mudlet and back in through `svo_events`.
* `gmcpcharstatus` sets `sys.charname` and `me.name`. `gmcpcharname` clears
  `svo.innews` and sets `sk.logged_in`.
* `svo.newbals` is written from the GMCP vitals `bal` and `eq` fields and
  read by nothing in `src/`.

**The prompt pipeline** is an `after_prompt_processing` handler. It copies
the real prompt into the `svo_prompt` buffer, replaces it with the custom
prompt, prefixes `?:` under recklessness or blackout, inserts the clickable
`(a)` slow-curing marker (green while you override, red while acting, blue
when idle, with `sk.syncdebug` as its link), inserts `(p)` when paused, and
moves the result to the single-prompt console when that is on.

**Stats.** `svo.cnrl.update_siphealth`, `svo.cnrl.update_sipmana`,
`svo.cnrl.update_wait`, `svo.can_usemana`, `svo.sk.check_fullstats`,
`svo.fullstats`.

**Priority manipulation at runtime.** `svo.prio_makefirst(action, balance)`
sets the action's `spriority`, its place in the **slow-curing** list, to 500,
remembering the original so `svo.prio_undofirst()` can swap it back. Its one
caller is the `shh` alias, always with an explicit balance. When the balance
is not given, it tries to work it out, but only if the action uses exactly
one real balance, counting `aff` and `waitingfor` out. **Defect, unreachable
from `src/`:** that path declares `local balance = false` inside the `if`,
so the balance it works out is discarded and the assert on the next line
always fails. Both take a serverside before-state snapshot so the change can
be mirrored. `svo.prio_swap` and `svo.prio_slowswap` are the general forms.
**Defect, pre-existing:** `prio_slowswap` asserts `balance and balance2`
before assigning `balance2`, so swapping two `action_balance` names (the
`vswapslow` alias, which passes `echoback = true`) always prints "What
balances do you want to use for swapping?" and then swaps anyway.

**Lock warnings.** `cnrl.lockdata` is a table of lock name to test function.
`cnrl.checkwarning()` rebuilds `cnrl.warnings` and `me.locks` from it, and
manages its own subscription: when the first lock appears it unblocks
`cnrl.dolockwarning` on `after_prompt_processing`, and when the last one
clears it blocks both itself and `dolockwarning` again. So the check only runs
while there is something to check. `svo.givewarning`,
`svo.givewarning_multi` and `svo.prefixwarning` are the display side.
`givewarning` goes through `givewarning.happened` and the lifevision ledger,
with lineguard 1 under anti-illusion, so an illusion cannot fake a warning.
The eight locks in `cnrl.lockdata` are soft, venom, hard, dragon, rift,
rift 2, slow and true.

**Command path.** Both functions see every send, through
`sysdatasendrequest`. They are not split into "svof's" and "yours":

* `svo.cnrl.processusercommand` maps a typed command to a dictionary action
  through `sys.input_to_actions` and runs `doaction` for it with `send`,
  `sendc` and `sendAll` stubbed out, so a cure you type by hand is tracked
  and completed by the same triggers as one svof sends. It also handles
  `qq` and `quit` (`QQ`, switch to the `empty` defence mode, `inra`) and
  `ir` rift parsing. The gnomes block it while they send, so svof's own
  sends are not registered twice, and `sk.systemscommands` catches batched
  sends that escape the block.
* `svo.cnrl.processcommand` is **blocked except in slow curing**
  (`sk.checkaeony` unblocks it). It is the aeon and retardation filter for
  what you type. With `conf.blockcommands` on and an action in flight, it
  `denyCurrentSend()`s your command ("denying X"). With it off, it treats
  your command as an override and sets `svo.sacid`, a timer for
  `syncdelay + latency + conf.sacdelay` during which the sync gnome does
  nothing. It also detects retardation ending: each command arms a timer,
  and if no "sluggish" line cleared `sk.sawsluggish` by then, retardation is
  removed. `curing ...` commands, and anything sent while
  `sk.gnomes_are_working`, are exempt.

`svo.curingcommand(command)` and `svo.queuecommand(command)` are the two
server-curing entry points: each sets a flag, routes the command through
`processusercommand` with the forced argument, and queues a prompt trigger to
clear the flag. `curingcommand` also deletes the line if `gagservercuring` is
set.

**Output ordering.** `svo.printorder` and `svo.printordersync` render the
lists with `^^` and `vv` links that call `prio_swap` and `prio_slowswap`, and
show the serverside number (capped at 25) next to svof's when serverside is
on.

**Full stats.** `svo.fullstats(callback)` connects `sk.check_fullstats` to
`after_prompt_processing`, un-ignores serverside `healhealth` and `healmana`
for the duration, and runs the callback (a function or a string) when health
and mana are full.

**Prompt hooks.** `svo.prompttrigger(name, func)` asserts its arguments and
forwards to `sk.onprompt_beforeaction_add`. It is the public way to say "do
this once, at the next prompt", and it is used everywhere: the mindnet report,
the rune identifier, the class-enable message, the NameDB birthday capture.

**`svo.aiprompt()`** is the anti-illusion prompt check.

**`svo.lyre_step()`** is the lyre helper. It refuses without balance and
equilibrium, turns `conf.lyre` on if it is off, unpauses, forces one gnome
run, sends the lyre action if it is not already going, and restores the flags.

**`svo.QQ()`** emits `signals.quit`. Line 620 assigns
`svo.savesettings = svo.QQ`, which is what the empty `svo.savesettings` script
item calls on `sysExitEvent`.

---

### `svo (alias and defence functions)`

Two files, 258,828 bytes.

#### `Alias_functions.lua` (45,449 bytes, loader `aliases`)

The bodies behind the 169 aliases. 34 functions.

**Toggles and config.** `svo.togglesip`, `svo.toggle_ignore`, `svo.aconfigs`,
`svo.aconfig`, `svo.aconfig2`, `svo.app` (the pause toggle), `svo.dop` (do
pause), `svo.dv` (diagnose), `svo.adf` (check defences), `svo.asave`,
`svo.aupdate`.

**Display.** `svo.ashow`, `svo.showaffs`, `svo.showbals`,
`svo.showserverside`, `svo.showcurelist`, `svo.show_ignore`,
`svo.ignorelist`, `svo.afflist`, `svo.viewmetadefs`.

**Manual overrides.** `svo.manualdef`, `svo.manualdiag`, `svo.vaff` and
`svo.vrmaff` (add or remove an affliction by hand), `svo.adddefinition`.

**Serverside.** `svo.enableallserverside`, `svo.enabledefaultserverside`.

**Resets.** `svo.reset.affs`, `svo.reset.general`, `svo.reset.defs`,
`svo.reset.bals`.

**Other.** `svo.inra` (rift everything riftable), `svo.get_herbs` (pick up
herbs).

The 34 is 33 top-level functions plus `svo.transmute`, which is defined
inside a Kaido skillset gate at line 1166. What some of them actually do:

* `svo.app(what, quiet)` is the pause toggle. `svo.dop` pauses the do queue.
* `svo.dv()` sets `sys.manualdiag` so the dictionary's diagnose action fires.
  `svo.adf()` sets `me.manualdefcheck` and runs
  `svo.doaction(dict.defcheck.physical)`. While it is set, `speed` and
  `sileris` stop being advisable, so their own messages cannot collide with
  the `DEF` list.
* `svo.aupdate()` only opens the documentation URL; it updates nothing.
  `svo.aconfigs()` does nothing at all.
* `svo.inra()` sets `sk.inring` and requests GMCP `Char.Items.Inv`. When the
  inventory list arrives, a `gmcpcharitemslist` handler sends `inr all` and
  clears the flag. `svo.get_herbs()` sends `ql` with `sk.retrieving_herbs`
  set, and the room item handler picks the herbs up.
* `svo.vaff(aff)`: called from a trigger, it goes through
  `valid.proper_<aff>` or `valid.simple<aff>`. Typed by hand, it calls the
  `aff` action's `forced` or `oncompleted` directly, then `checkaeony` and
  `changecuring`. `svo.vrmaff` is the reverse, through `gone`.
* `svo.ashow()` (`vshow`) raises `svo onshow`, so addons append their own
  lines.

The four resets:

* `reset.affs` removes every affliction except `lovers`.
* `reset.general` kills every action and clears the prompt hook queue,
  `sk.gmcp_cured` and `sk.removed_something`.
* `reset.defs` keeps every defence with `stays_on_death` and clears parry. It
  is connected to `charname` and `gmcpcharname`, so it runs at every login.
* `reset.bals` runs on `systemstart` (see "State").

**Defect, pre-existing, reachable for excision users.** Because
`reset.bals` initialises `bals.wrathbal`, the vitals handler in `Setup.lua`
(line 590) calls `valid.usedwrathbalbalance()` whenever GMCP says
`wrathbal: No` while `bals.wrathbal` is true. That handler claims
`stolebalance.happened` with `'anathema'` instead of `'wrathbal'`
(`Main_trigger_functions.lua:4393`), whose completion calls
`svo['lostbal_anathema']()`. That function exists only with the `anathema`
skillset, so the call raises, `bals.wrathbal` stays true, the same error
repeats on every vitals update until the balance returns, and the
`@wrathbal` prompt tag never changes.

#### `Defences.lua` (213,379 bytes, loader `defences`)

The defence system. 38 top-level functions, and a very large amount of
per-defence data.

**Core state.** `defences.got(def)` and `defences.lost(def)` are the two
functions every defence path funnels into. Each is two lines: flip
`svo.defc[def]` only if it changes, and raise `svo got def` or
`svo lost def`. There are no timers. `defences.gettime(defence, max)`
returns `(max - ceil(elapsed/max)) .. 'm'` from
`svo.dict[defence].stopwatch`, or `""`. Nothing in `src/` calls it, nor
`defences.urlify`, `defences.complete_def` or `defences.get_def_list`.
`svo.defs_data` itself, the `OrderedMap` of every defence's data, is built
here at line 57.

**Defence modes.** svof keeps named sets of defences, and each mode has two
lists: `defup`, the defences to raise when you run a defup, and `keepup`, the
ones to restore automatically whenever they drop.

* `defs.switch(mode, echoback, nodefup)` changes mode and starts a defup
  unless `nodefup`. `defs.quietswitch(mode)` changes only the mode and the
  rift precache, with no defup and no events.
* `defs.defup(which, status, mode, echoback, reshow)` and
  `defs.keepup(which, status, mode, echoback, reshow)` edit the two lists. A
  string status goes through `convert_string`, and nil toggles. Turning a
  defence on runs its `defs_data.onenable(mode, which, 'defup'|'keepup',
  echoback)` and aborts if that returns false. Both raise
  `svo defup changed` or `svo keepup changed`, then call
  `sk.fix_affs_and_defs()` and `make_gnomes_work()`.
* `svo.create_defmode`, `svo.copy_defmode`, `svo.rename_defmode`,
  `svo.delete_defmode` manage modes.
* `svo.defload()` loads them from disk. `sk.sanitize` and `sk.desanitize`
  swap spaces and underscores, so a defence name can become a handler name
  (`svo.defs.got_<name>`) and back for display. Storage never sees them.

**Running a defup.** `svo.defupfinish()` is called from `onprompt` while
`sys.deffing` is set and decides whether the run is complete.
`svo.defupcancel()` aborts it. `sk.showwaitingdefup()` shows what is still
outstanding, and `sk.have_defup_defs()` tests whether anything is.

**Reading the game's defence list.** `defs.defstart`, `defs.defline`,
`defs.defprompt` and `svo.process_defs` parse the `DEF` output.

**Display.** `show_defs` (local), `svo.show_current_defs`, `svo.show_defup`,
`svo.show_keepup`, `defences.print_def_list`, `defences.get_def_list`,
`defences.urlify`, `defences.complete_def`.

**Special cases.** `defs['lost_shield']`, `defs['lost_riding']` and
`defs['block_failed']` are valid identifiers; the brackets are only style.
What makes them special is that they **override** the generated handler of
the same name: `lost_shield` claims `shield.gone` and also recolours the
line, `lost_riding` claims `riding.physical` with the named outcome
`dismount`, and `block_failed` claims `block.physical` with `failed`.
`sk.loginonbasic()` switches to the `basic` mode with `nodefup` on the first
`charname` or `gmcpcharname`, then disconnects from those two and stays
connected to `relogin` only.

**Skills.** `svo.ignoreskill(skill)` and `svo.showhidelist()` manage
`sk.ignored_defences`, which only hides skillsets or single defences from the
defence **display** lists (`show_defs`). `showhidelist` says so in its
header. It changes no curing or defup behaviour. `Setup.lua` flips `tekura`
and `shikudo` in it on a Monk form switch.

**`svo.detect_lifevision()`** is about the lifevision **mask** (and the
Shadowcloak and the phylactery), not the `svo.lifevision` ledger. It sends
`Char.Items.Inv` and a blank line so the three inventory scanners run. The
`Detect_lifevision` trigger calls it.

**The `defs_data` field vocabulary.** `type` (general, dragoncraft, or a
skillset), `on` and `onr` (exact or regex gain lines), `on_only` (a gain line
that counts only if you asked for it: it claims without force), `on_free`,
`off`, `offr` and `offs` (exact, regex and substring loss lines),
`off_free`, `def` and `defr` (the `DEF` list line), `nodef` (never on `DEF`,
so it is an "additional" defence), `invisibledef` (never on `DEF`, but
`process_defs` must not clear it), `custom_def_type` (a channel-style group
reset by a `def<type>start` line), `specialskip`, `onenable`, `ondef` (a
value to show beside the name), `onshow`, `mana` (`'little'` or truthy,
shown as m or M), `tooltip`, `staysindragon`, `availableindragon`,
`stays_on_death`, and `offline_defence` (kept across logout).

**How every defence trigger is made.** No defence has a Mudlet trigger item.
A `systemstart` handler (line 3279) calls `defload()`, resets
`defences.def_types`, then walks `defs_data` and creates a
`tempExactMatchTrigger`, `tempRegexTrigger` or `tempTrigger` per pattern,
recording the ids in `svo.defencetemptriggers` so class change can kill them.
Each fires one of three generated handlers:

* `defs.got_<name>`: if the dictionary has an entry for the defence, it
  claims that entry's first non-`gone` balance action through `checkaction`
  (forced for `custom_def_type`, and for metamorphosis when you are using
  that balance) and files it in the ledger, or with `force` finishes it at
  once, bypassing lifevision. Otherwise it calls `defences.got`.
* `defs.lost_<name>`: claims `dict[def].gone` if it exists, else calls
  `defences.lost`.
* `defs.def_<name>`: records the `DEF` list line in
  `defences.def_def_list` (or in `nodef_list` for class defences while in
  dragonform) and deletes the line. For a `nodef` defence it counts only
  while a `defcheck` is in flight.

The same handler also blanks defup and keepup for every mode, seeds
`sk.ignored_defences`, and merges the saved defup and keepup back over the
blanks with `svo.update`.

**Three runtime-registered defences.** `enablemindnet`, `enablelifevision`
and `enableshroud` each add a `defs_data` entry and (for lifevision and
shroud) a `svo.dict` entry at runtime, create their own temp triggers
**outside** `svo.defencetemptriggers`, snapshot priorities, rerun
`dict_setup` and `dict_validate`, report priority changes, and emit
`dragonform`. Each runs from a `systemstart` `tempTimer(0)` when its `conf`
flag is set, or from a `gmcpcharitemslist` scanner that sets the flag,
raises `svo config changed`, and disconnects itself.

**Persistence.** `saveconfig` writes `<home>/svo/defup+keepup/`: `defup`,
`keepup`, `ignored_defences` and `offline_defences` (the
`offline_defence` defences you have). `defload` reads them back and grants
the offline ones again.

**Defects, all pre-existing:**

* The `relogin` handler at line 3234 collects `t[#t+1] = defc` instead of
  the name, so it calls `defences.lost(defc)` and clears nothing. It is
  masked because `reset.defs` runs on `gmcpcharname` at every login.
* The inventory scanners' `if not t.location == 'inv'` guard is always
  false, so they scan every item list. The phylactery match has a double
  space (`"a  phylactery of sixth sense"`). `enableshroud` registers only
  `on[1]` and `on[2]`, so the Blood Maiden cloak line never counts. After a
  class change the three runtime defences' triggers are not killed, so each
  is created again.
* In the data: `lipread.specialskip` reads an undefined global `mindseye`,
  so it is always skipped; `rest.off` has a stray second string; Kaido
  `boosting.onenable` sets heartsfury instead of regeneration; and the
  occultism simulacrum `offr` and an alchemy empower `on` line carry the
  placeholder `<fix me, insert character name here>`.

---

### `svo (trigger functions)`

Three files, 170,229 bytes. This is layer 2: the handlers the 2,531 triggers
call.

#### `Main_trigger_functions.lua` (156,348 bytes, loader `valid_main`)

The single largest concentration of functions in the system: **361 top-level
definitions**, nearly all of them `svo.valid.*` or `svo.defs.*`. The count is
every line that starts at column zero with `function`, `local function`,
`<name> = function` or `local <name> = function`; the same spelling gives
359 at `82e7f14`, the figure this document used to carry.

Rather than list 361 signatures, here is the grammar, then the groups.

**The grammar.** A handler is named for the line it handles. The usual body
is `svo.checkaction(dict.X.bal)` without force, then
`if actions.X_bal then lifevision.add(actions.X_bal.p, outcome, arg,
lineguard) end`. State changes happen later, at the prompt, when the ledger
runs the claim. With anti-illusion on, `checkaction` does not force-add, so
a line svof did not ask for is simply dropped: that is the main
anti-illusion check. Beyond it, the confirmation step takes four forms:

1. **Was I doing something that would explain this line?**
   `svo.checkaction(svo.dict.X.herb)` before completing it.
2. **Is the timing physically possible?** Compare against `svo.getping()` and
   reject anything under `lat/2`.
3. **Does the rest of the paragraph agree?** Set a lineguard, and let
   `lifevision.validate` settle it.
4. **Did GMCP already tell me?** The `sk.gmcp_cured` check, described below.

**Illusion control.** `svo.valid.caught_illusion`, `svo.not_illusion`,
`svo.ignore_illusion`, `svo.show_info`,
`svo.vm.last_line_was_prompt`.

**The GMCP ordering fix.** The herb-cure generator builds one
`valid.herb_cured_<aff>` handler per herb-curable affliction
(`valid.<aff>_cured` exists only for heartseed, hypothermia and the four
health-elixir fractures), and its condition carries the comment that
explains the GMCP ordering:

```lua
-- sk.gmcp_cured[aff] covers the case where GMCP already removed this
-- affliction earlier in the same paragraph - GMCP is processed before
-- the text it accompanies, so affs[aff] is necessarily nil by now and
-- would otherwise make every such genuine cure look like an illusion.
elseif (not conf.aillusion or (conf.aillusion and (affs[aff] or sk.gmcp_cured[aff]
  or affs.unknownany or affs.unknownmental or svo.affsp[aff]))) then
```

Read that condition out: accept the cure if anti-illusion is off, or if you
still have the affliction, or if GMCP already removed it this paragraph, or if
you have an unknown affliction that this could have been, or if it is in the
pending set.

**Generic cures.** One handler, `svo.valid.generic(aff)` (line 3343), serves
every trigger in `General cures`, and the trigger passes the name:
`svo.valid.generic('paralysis')`. It replaced a 112-entry
`generic_cures_data` list that generated one `valid['generic_'..aff]`
function per name, 46 of which no trigger called. These are the cures that
happen without svof asking: passive cures and cures that land while you are
blacked out, which is also why GMCP cannot replace them. The handler reports
a name with no dictionary entry through `svo.errorf` and returns. Otherwise
it claims `<aff>_gone` during a passive-cure paragraph; otherwise claims the
action svof was doing for that affliction; otherwise finds an in-flight
action on a balance the affliction also has, kills it and claims the
matching one; otherwise attributes the cure to tree or restore. That third
step reaches beyond the affliction's own actions, which is what makes a
wrong name here expensive (see "Two call sites the handler inversion
broke"). `valid.passive_cure` sets `svo.passive_cure_paragraph`, enables
the generics, and at the prompt decrements `unknownmental` or `unknownany`
when the cure removed nothing known.

Four hand-written handlers with the same prefix are **not** part of this
family: `svo.valid.generic_insomnia()` (a defence gain line),
`valid.generic_burn(number)` (steps the burn ladder down) and the fracture
pair `svo.valid.generic_cure(aff)` and `svo.valid.generic_cured(aff)`, which
file the `general_cure` and `general_cured` outcomes on `<aff>_gone` for the
four counted fractures. The fracture pair takes the name as an argument and
has no name guard. At `6af80b3` nothing calls `generic_insomnia` or
`generic_burn`, because their two triggers were rewritten to call
`svo.valid.generic`.

The gating is a straight swap of two trigger sets, not a simple on and off:

```lua
svo.disable_generic_trigs = function ()
  disableTrigger("General cures")
  enableTrigger('Ate') enableTrigger('Sip') enableTrigger('Applied')
  enableTrigger('Smoke') enableTrigger("Focus mind")
end
```

`enable_generic_trigs` does the inverse. The two sets are meant to be
mutually exclusive, because they would otherwise both match the same line:
the normal containers expect a cure svof asked for, and the generic set
expects one it did not. In practice they are not: `'Applied'` and
`"Focus mind"` are two of the known unresolved names (the real groups are
`Applied salve` and `Focus`), so enabling the generics leaves those two
containers on alongside `General cures`, and only `Ate`, `Sip` and `Smoke`
are actually swapped.

`svo.check_generics()` decides which set is live, and tracks *why* separately
in `svo.generics_enabled_for_blackout` and `svo.generics_enabled_for_passive`,
so a passive cure during a blackout does not turn the generics off when the
passive-cure paragraph ends. Entering blackout announces "Enabled blackout
curing" and leaving it announces the reverse; the passive-cure path switches
silently. It runs from a prompt hook registered as `"check generics"`, and the
file calls `disable_generic_trigs()` then `check_generics()` once at load to
establish the starting state.

`svo.valid.passive_cure` is the shared handler that sets
`svo.passive_cure_paragraph`.

**Other generated families.** The file builds handlers in loops for
`valid[aff..'_woreoff']`, `valid[aff..'_cured']`, `valid[aff..'_apply']`,
`valid['writhed'..aff]`, `valid['got'..balance]`, `valid['proper_'..name]`
and `valid['proper_'..status..name]`, plus the cure-line families described
under "Cross-cures" below. That is why the extractor lists entries with
brackets and concatenation in them. The diagnose, generic-cure and tree-cure
families are no longer generated: each is one function that takes the name
from its trigger.

**Tree cures.** `svo.valid.tree_cured(what)` (line 2906) serves every trigger
in `Tree cures`: `svo.valid.tree_cured('paralysis')`. It replaced an 86-name
list, two hand-written burn handlers and two per-fracture families, all with
the same body and differing only in the string handed to lifevision, which
`touchtree.misc.oncompleted` branches on. `what` is an affliction name or one
of six special strings in `TREE_SPECIAL`: `'burn'`, `'all burns'`, and
`'<fracture> cured'` for the four counted fractures. Anything else is
reported through `svo.errorf`, because `touchtree.misc.oncompleted` would
otherwise pass it to `svo.rmaff`, which ignores a name it does not know. A
valid call claims `touchtree_misc` if a touch is in flight and sets the file's
`tree_cure` flag, which makes `tree2` skip the empty-cure sweep.

**The groups.**

| Group | Representative members |
|---|---|
| Symptom detection | `symp_asleep`, `symp_impale`, `symp_stupidity`, `symp_transfixed`, `symp_paralysis`, `symp_stun`, `symp_illness_constitution`, `symp_webbed`, `symp_impaled`, `symp_roped`, `symp_haemophilia`, `symp_anorexia`, `symp_dizziness_fell` |
| "Proper" confirmations | `proper_aeon`, `proper_retardation`, `proper_stun`, `proper_paralysis`, `proper_hypersomnia`, `proper_asthma`, `proper_asthma_smoking`, `proper_impatience`, `proper_relapsing`, `proper_sensitivity`, `proper_webbed`, `proper_chill`, `proper_transfix`, `proper_clumsiness`, `proper_weakness`, `proper_disloyalty`, `proper_illness`, `proper_lethargy`, `proper_addiction`, `proper_anorexia`, `proper_slickness`, `proper_recklessness`, `proper_recklessness2`, `proper_haemophilia`, `proper_hamstring`, `proper_stain`, `proper_ablaze`, `proper_sleep`, `proper_impale` |
| Balance regain | `gotherb`, `gotsalve`, `gotpurgative`, `gotragebalance`, `gotprayerbalance`, `usedprayerbalance`, `touched_treeoffbal`, and the generated `got<balance>` family |
| Cure confirmation | `ate1`/`ate2`, `sip1`/`sip2`, `tree1`/`tree2`, `apply1`/`apply2`, `smoke1`/`smoke2`, `applyelixir1`/`applyelixir2`, `focus1`/`focus2`. The numbered pairs are the empty-cure bracket, described after this table |
| Cure failure | `salve_fizzled`, `health_fizzled`, `health_noeffect`, `salve_offbalance`, `salve_had_no_effect`, `plant_had_no_effect`, `sip_had_no_effect`, `salve_slickness`, `potion_slickness`, `missing_herb`, `no_refill_herb`, `no_outr_herb`, `noeffect_moss`, `noeffect_pear`, `restoration_noeffect`, `underwater_nopear`, `unlit_pipe`, `empty_pipe`, `empty_light`, `nothingtoeat`, `nobalance`, `nothingtowield`, `nosymptom`, `tootired_focus`, `nomana_focus`, `nomana_clot`, `failed_focus_impatience`, `smoke_failed_asthma` |
| Defences | `defs.got_block`, `got_morph`, `got_dragonform`, `got_dragonbreath`, `got_viridian`, `got_mace`, `got_speed`, `got_blind`, `got_deaf`, `already_blind`, `alreadyhave_dragonform`, `cancelled_dragonform`, `cancelled_mace`, `viridian_cancelled`, `notonland_viridian`, `viridian_inside`, `cant_empower`, `salve_got_caloric`, `salve_got_mass`, and the herb-defence set `gotherb_myrrh`, `gotherb_kola`, `gotherb_deathsight`, `gotherb_thirdeye`, `gotherb_insomnia` with their `gotskill_` counterparts |
| Sileris and quicksilver | `defs.sileris_start`, `sileris_finished`, `sileris_slickness`, `valid.sileris_flayed` |
| Class-specific | `swashbuckling_jab`, `swashbuckling_poison`, `swashbuckling_acciaccatura`, `swachbuckling_pesante`, `swachbuckling_martellato`, `voicecraft_tremolo`, `voicecraft_vibrato`, `subterfuge_hallucinations`, `subterfuge_confusion`, `subterfuge_bite`, `subterfuge_camus`, `subterfuge_sumac`, `subterfuge_bind`, `kaido_choke`, `magi_deepfreeze`, `necromancy_shrivel`, `knighthood_disembowel`, `sylvan_heartseed`, `sylvan_eclipse`, `sylvan_lacerate1`/`2`, `shin_phoenix`, `meta_glare`, `skirmish_drag`, `skirmish_lacerate`, `skirmish_gouge`, `doublehander_hit` |
| Venoms | `venom_crippledleftarm`, `venom_crippledrightarm`, `venom_crippledleftleg`, `venom_crippledrightleg`, `relapsing_camus`, `relapsing_sumac`, `relapsing_vitality`, `relapsing_oleander`, `relapsing_colocasia`, `relapsing_oculus`, `relapsing_prefarar`, `relapsing_asthma` |
| Humours | `humour_wrack`, `humour_truewrack`, `got_humour`, `got_pressure`, `sanguine_inundate`, `choleric_inundate`, `melancholic_inundate`, `phlegmatic_inundate`, `focus_choleric` |
| Limbs | `limb_hit`, `broken_legs`, `bad_legs`, `update_break`, `expend_torso`, and the six `devastate_*` handlers for cripple, mangle and mutilate on arms and legs, plus `smash_high` |
| Parry | `parry_limb`, `parry_none`, `cant_parry` |
| Pipes | `fillskullcap`, `fillelm`, `fillvalerian`, `alreadyfull`, `litpipe`, `litallpipes`, `pipe_emptied` |
| Writhing | `writhe`, `writheimpale`, `writhe_helpless`, and the generated `writhed<aff>` family |
| Tarot | `tarot_aeon`, `aeon_card`, `lust_card`, `rebounding_deathtarot` |
| Life and death | `died`, `check_life`, `lost_arena`, `lost_ffa`, `won_arena`, `svo.connected` |
| Unknown afflictions | `valid.remove_unknownmental`, `valid.remove_unknownany` |
| Tekura helpers | `saw_tekura_in_paragraph` (local), `all_in_one_tekura` (local) |

`svo.missing_enchant` and `svo.missing_tinderbox` are the two "you are out of
a consumable" handlers that do not follow the `valid.` naming.

**The empty-cure bracket.** Each cure container (see the trigger reference)
has a first child and a later child that call the numbered pair. The first
(`ate1`, `sip1`, `apply1`, `smoke1`, `tree1`, `applyelixir1`, `focus1`)
resets a flag: `svo.herb_cure`, `svo.sip_cure`, `svo.apply_cure`,
`svo.smoke_cure`, `tree_cure`, `svo.applyelixir_cure` or `svo.focus_cure`.
Any specific cure handler that matches in between sets it. The second fires
after the result lines, and if the flag is still false it files the
in-flight action with the **`empty` outcome**, which runs the dictionary's
`empty` (usually `svo.empty.eat_<herb>` and its siblings). `ate2` also
rejects a result faster than `getping()/2`, widens the lineguard to 2 for
addiction, swellskin or a serverside `[CURING]` line, and arms a one-line
trigger for cadmus and paradox follow-ups. `ate1` turns arena mode on
automatically and, under anti-illusion, queues an `aiprompt` check that
marks the eat as an illusion if GMCP removed no item
(`sk.removed_something`).

**Cross-cures.** The generated `herb_cured_<aff>`, `smoke_cured_<aff>`,
`focus_cured_<aff>`, `salve_cured_<aff>`, `curing<aff>` (restoration), and
`herb_helped_`/`smoke_helped_` handlers first look for their own action. If a
**different** action on the same cure is in flight (you ate goldenseal for
impatience and it cured stupidity), they `killaction` that one, force-add
the matching one, and claim it. `herb_cured_` and `herb_helped_` carry the
`sk.gmcp_cured` clause quoted earlier.

**Balance regain goes through the ledger.** `gotherb` (rejected inside
`sk.blockherbbal`), `gotsalve` (rejects a restoration heal faster than
`conf.ai_minrestorecure`), `gotpurgative`, the generated `got<bal>` for moss,
focus, sip, purgative, dragonheal, smoke and tree, the class `got*` handlers
and the `force*` handlers all push the balance name into
`svo.dict.gotbalance.happened.tempmap` and claim `gotbalance_happened`. At
the prompt its `oncompleted` sets `bals[x] = true`, raises
`svo got balance`, ends the balance stopwatch, and for tree kills
`sys.treetimer`. The `used*balance` handlers claim `stolebalance.happened`,
which calls `svo['lostbal_'..x]`. This is the primary restore that the
`lostbal_*` timers back up.

**Two blocked signal handlers.** `valid.check_life` is unblocked on death
and unpauses when health returns. `valid.check_recklessness` is unblocked by
`recklessness.onadded` and removes recklessness when GMCP vitals are below
maximum.

**Limbs.** `valid.limb_hit` records `me.lasthitlimb`, highlights, unblocks
`svo.sp_checksp`, emits `signals.limbhit` and raises `svo limb hit`. The
generated `proper_<mangled|mutilated><limb>` handlers insist the limb is
named in the paragraph and batch Tekura combinations. The Bard
`swashbuckling_poison`, `acciaccatura`, `tremolo` and `vibrato` delay
crippled limbs so the mangle is cured first, and a `limbhit` with two weapon
hits (a DSL) applies the delayed venoms at once. `valid.pyradius` deletes the
cure lines, re-feeds them with `feedTriggers`, and maps each cured
affliction to the one pyradius swaps it for.

`systemstart` also disables `General cures` and toggles
`Pre-parse anti-illusion` by `conf.aillusion`.

**Defects, all pre-existing** (the same text is in the reference xml):

* `valid.update_break` calls `valid.simple['mangled'..limb]()` (line 2011).
  `valid.simple` is not a table, so when a restore is in flight and an
  "upgrade break" trigger fires, it raises instead of adding the mangled
  limb. The intended call is `valid['simplemangled'..limb]`.
* `valid.litpipe` (2092) and `valid.empty_light` (2639) index
  `svo.dict.lightelm`, `lightvalerian` and `lightskullcap`, which do not
  exist (only `lightpipes` does), so both raise every time.
  `svo.missing_tinderbox` checks `actions.light*_physical`, which can never
  be set.
* `valid.vodun_throttle = valid.kaido` (1348): there is no `valid.kaido`, so
  the `Vodun throttle` trigger raises. The intended target is
  `valid.kaido_choke`.
* `valid.usedwrathbalbalance` claims `stolebalance` with `'anathema'` rather
  than `'wrathbal'` (4393). See `Alias_functions.lua` for why this is
  reachable.
* `valid.got_blind` tests `defs.blind` (a handler namespace) instead of
  `defc.blind`, so it can add hypochondria while blind is up as a defence.
* `valid.symp_asleep` and `valid.transfixily` test `affs.asleep` and
  `actions.asleep_aff`. The affliction is `sleep`, so those guards are dead.
* Duplicate definitions: `svo.valid.relapsing_oculus` (1308 and 1313, the
  second wins), and `svo.defs.got_dragonform` (a function at 289, then
  replaced at 894 by `svo.dict.waitingfordragonform.waitingfor.oncompleted`).

#### `Simple_aff_trigger_functions.lua` (8,498 bytes, loader `valid_simple`)

172 `simple<name>` handlers for every class, plus `simplecantmorph` for
metamorphosis and `simpleage` for aeonics, for afflictions whose detection
needs no reasoning about whether to believe the line. The file **generates**
`svo.valid.simple<name>` from the dictionary (lines 44 to 52): one for every
`svo.dict` entry whose
`aff` is a table, except the eight anti-illusion probes named in
`no_simple_handler`, whose `aff` means "a symptom that is this or an
illusion" and whose `oncompleted` takes the real affliction's name. That is
172 of the 180 literal entries with an `aff` block, plus `cantmorph` for
metamorphosis, whose entry is created under the same skillset gate. The loop
runs over whatever `svo.dict` holds when the loader runs, so a new
affliction gets its handler from its entry, and it replaced a 155-name
`afflist` that 17 affliction entries were missing from. It then hand-writes
eleven that need more, which overwrite what the loop made:
`svo.valid.simplehoisted`, `simpleprone`, `simplewebbed`, `simpleblackout`,
`simplebleeding`, `simplelovers`, `simpleunknowncrippledleg`,
`simpleunknowncrippledarm`, `simpleunknowncrippledlimb`, `simpleunknownany`,
`simpleunknownmental`. It also overwrites the four fractures with a counted
family, and adds `simpleage` for aeonics. Each of the fifteen overwritten
names has a generated handler first, so the hand-written ones add no names.
`doc/index.rst` documents the family for users' own triggers, and since
`38efede` it says every affliction `vshow afflist` lists has one.

"Simple" does not mean immediate. Every `simple<aff>` does
`svo.checkaction(dict.X.aff, true)` and `lifevision.add(...)`: a forced claim
settled at the prompt, like any other gain. `simplebleeding` does nothing
unless `conf.preclot`. `simplehoisted` and `simplelovers` honour
`conf.autowrithe` with `hoistlist`, and `conf.autoreject` with `lustlist`.
`simpleblackout` inserts at ledger position 1 with `addcust`, so stun checks
do not delay it. The unknown handlers accumulate counts across a paragraph
and set `reckhp` and `reckmana` for the recklessness cross-check.

**Defect, pre-existing (reference xml line 316):**
`svo.valid.proper_crippledleftleg = valid.simplecrippledrightleg`. Its one
caller, the inactive Qwindor bashing trigger `Morindar legbreak`, calls both
left and right and records only the right leg.

The three `unknown` ones are the interesting part of the design. When svof
knows it was afflicted but cannot tell with what, it records
`unknownany`, `unknownmental` or one of the crippled-limb placeholders. The
illusion checks in `Main_trigger_functions.lua` then accept a cure for
*anything in that category*, which is how the system stays usable when it has
incomplete information.

#### `Diag_trigger_functions.lua` (5,383 bytes, loader `diag`)

Four functions: `svo.valid.diagnose_start`, `svo.valid.empty_diagnose` and
`svo.valid.diagnose_end`, which bracket a DIAGNOSE, and
`svo.valid.diag(name, ...)` (line 101), which every line in between calls.
The 149 children of the `svo diag` trigger fill the bracket: 147 call
`svo.valid.diag('<name>')` or, for the ten counted afflictions (the four
humours, bleeding, the four fractures and pressure), pass a count as well,
`svo.valid.diag('bleeding', matches[2])` (pressure passes `t[matches[2]]`,
a level looked up from its wording); `Finished` calls `diagnose_end`; and
`blistered` has no body.

`svo.valid.diag` replaced two lists that generated one `diag_<aff>` function
per name, 160 in all. They had drifted both ways: 16 listed names no
trigger called, and three called names (`latched`, `calcifiedskull`,
`calcifiedtorso`) were missing, so DIAGNOSE cleared those three every time
it reported them. `bleeding` was in both lists and `voyria` twice; neither
is expressible now. The handler:

* Tells a counted call from a plain one with `select('#', ...)`, not by
  testing the value, so a counted trigger whose capture does not resolve
  (pressure's level table, given a level it does not know) still stores
  `tonumber(nil)` and lets `diagnose_end` clear the affliction, as before.
* Reports a name that is not `godfeelings` and has no dictionary entry with
  an `aff` block through `svo.errorf`, instead of letting `diagnose_end`
  index a missing entry later.
* Stores `true` for a plain call and annotates the line with `(new)` or how
  long you have had it, or stores the count for a counted call. Either way it
  adds `(currently ignored)` for an ignored affliction.

A diagnose is svof's resynchronisation point, but it does not simply clear
and rebuild:

1. `diagnose_start` files a lifevision claim for `diag_physical` only if svof
   sent the diagnose. Under anti-illusion, an unrequested one closes the
   `svo diag` gate and marks the line `(i)`.
2. Each `svo.valid.diag(name)` writes into `sk.diag_list` and annotates the
   line with `(new)` or how long you have had it.
3. `diagnose_end` removes every affliction you hold that the game did not
   list, except a whitelist (lovers, retardation, hoisted, paradox, and for
   some classes cantvitality and cantmorph), corrects counts, and for every
   newly listed affliction force-adds its `aff` action and files a
   **lifevision claim**, so new ones arrive at the prompt through the same
   `aff.oncompleted` as any other gain. It clears `svo.affsp`, runs
   `checkaeony` and `changecuring`, and closes the gate.

A `godfeelings` line aborts the whole diagnose.
---

### `svo (install, config, pipes, rift, parry, prios)`

Six files, 192,979 bytes. Everything the user configures.

#### `Config_system.lua` (103,789 bytes, loader `config`)

The fourth-largest file in the system, after the dictionary, `Defences.lua`
and `Main_trigger_functions.lua`. Almost all of it is one table.

**`svo.wait_tbl`** is the lag ladder, five levels from 0 to 4, each with a
delay and a message:

| Level | `sys.wait` | Named |
|---|---|---|
| 0 | 0.7 | normal |
| 1 | 1.1 | decent |
| 2 | 1.9 | severe |
| 3 | 3.5 | awfully terrible |
| 4 | 3.5 | "you're on a mobile in the middle of nowhere" |

Levels 3 and 4 share a delay. The difference is behavioural, and level 4's own
message says so: it is not for fighting or for bashing with `dor`, it is for
scripts that rely on `do`, such as enchanting. That matches the balance
controller, which special-cases level 4 by setting the retry timer to 23 hours.

**`svo.config_dict`** is a Penlight `OrderedMap` of **106 base options**, plus
up to **23 more** inserted conditionally by skillset. Ordered, because the
order is the order `vconfig` prints them and the order the installer asks
about them.

Each entry is a table of callbacks and metadata:

| Field | Purpose |
|---|---|
| `type` | `boolean`, `number`, `string` or `custom` |
| `percentage` | this number is a percentage |
| `min`, `max` | bounds for a number |
| `onenabled` / `ondisabled` | run when a boolean flips, and print the explanation |
| `onset` | run when a value is set |
| `onshow` | render this option in `vconfig` |
| `onmenu` | render it in a menu |
| `check` | validate a proposed value |
| `installstart` | set the default during install |
| `installcheck` | validate during install |
| `vconfig1` / `vconfig2` | which of the two `vconfig` pages this appears on |
| `vconfig2string` | the label on page two |

The `blockcommands` entry is a good example of the pattern, because it does
something none of the others do: both its `onenabled` and `ondisabled` check
for `denyCurrentSend` and warn that the option cannot work without it, and
`onshow` prints a different line depending on whether the Mudlet build has it.
So the option stays visible and settable on an older Mudlet, and simply tells
you it will not take effect.

The 106 base options:

```
blockcommands autoslick focus siprandom autoclasses havelifevision havemindnet
autoarena haveshroud focuswithcadmus cadmusaffs lyre ninkharsag shipmode
lyrecmd commandseparator buckawns burrowpause freevault deathsight tree
treebalance restore dragonheal breath ignoresinglebites ignoresinglestabs
efficiency clot insomnia thirdeye moss showchanges changestype log showbaltimes
showafftimes doubledo repeatcmd singleprompt singlepromptsize singlepromptblank
singlepromptkeep waitherbai waitparalysisai commandecho commandechotype
curemethod customprompt relight gagrelight gagotherbreath gagbreath gageqbal
gagserverside gagservercuring ccto mosshealth pagelength herbstatsize mossmana
siphealth sipmana refillat manause lag unknownfocus unknownany bleedamount
manableedamount corruptedhealthmin valerianid skullcapid treefunc restorefunc
dragonhealfunc elmid eventaffs gagclot autorewield preclot org slowcurecolour
hinderpausecolour autoreject lustlist autowrithe hoistlist echotype dragonflex
assumestats healthaffsabove warningtype burstmode oldts batch steedfollow
autotsc medprone unmed classattacksamount classattackswithin enableclassesfor
gmcpaffechoes gmcpdefechoes releasechannel
```

The conditional inserts, by skillset:

| Condition | Adds |
|---|---|
| `kaido` | `transmute`, `transmuteamount`, `transsipprone`, `kaidodeaf`, `kaidoblind` |
| `voicecraft` | `dwinnu` |
| `weaponmastery` | `recoverfooting` |
| `zeal` | `benediction` |
| `venom` | `shruggingfunc`, `shrugging` |
| `devotion` | `bloodswornoff` |
| `woodlore` | `weapon` |
| `metamorphosis` | `transmorph`, `truemorph`, `morphskill` |
| **not** `tekura` / `tekura` | `parry` / `guarding` |
| `shindo` | `shindodeaf`, `shindoblind` |
| any of discipline, malignity, valour, dominion, shindo, kaido, metamorphosis | `fitness`, `fitnessfunc` |
| any of discipline, malignity, valour, dominion | `rage`, `ragefunc` |

Every insert is `config_dict:insert(1, ...)`, so class options land at the top
of the list rather than the bottom. Note the `tekura` case: everyone except
tekura monks gets `parry`, and tekura monks get `guarding` instead, from the
`else` branch at line 1713. The 23 is the number of distinct names across
all 17 of these calls, counting the two parry options separately; no single
class gets all 23.

**`tntf_tbl`** is the `tn`/`tf` (turn on, turn off) table. It covers
`aillusion`, `arena`, `keepup`, `bashing`, `raid` and `serverside`. Each entry
has `on`, `off`, and optionally `alreadyon` and `alreadyoff` handlers, so
turning on something already on gives a different message from turning it on
fresh. A loop after the table registers each entry's shortcuts as aliases into
the same table. `svo.tntf_set(what, onoff, quiet)` is the setter.

**Persistence.** The loader creates `getMudletHomeDir() .. "/svo/config"` at
load. The `saveconfig` handler writes `conf` with `svo.tablesave` (Mudlet's
table pickle) to `<home>/svo/config/conf`; `pl.pretty` is used only for
priority exports. Loading recovers from a corrupt file rather than failing.

**Load order of configuration.** `Setup.lua` applies defaults. This loader
then merges `<home>/svo/config/conf` over them with `svo.update`, runs the
migrations, and initialises every option still undeclared to `false` or
`0`. The migrations are more than three:

* `ai_minherbbal` 0.7 or 1.2 becomes 1.1; `ai_resetherbbal` 5 becomes 2.5.
* `ai_resetsipbal` 5 becomes 7 **and then** 7 becomes 10. The two steps
  chain, so Setup's default of 7 is always turned into 10: the effective sip
  failsafe is 10 seconds.
* `ai_resetpurgativebal` 5 becomes 10.
* `Shallam` becomes `Targossas` (a city was destroyed and replaced in the
  game), and `recovery` becomes `efficiency`.
* `gagserverside` defaults on, `eventaffs` is forced true, and
  `conf.releasechannel` is forced to `'inclient'` on every load.

Load-time side effects: the bashing triggers are switched on or off; the
`riding` action is made balanceful or balanceless by `freevault` (then a
`dragonform` emit rebuilds the shortlists); `burrowpause` connects
`sk.check_burrow_pause` to `gmcproominfo`; a default custom prompt is set
after 10 to 15 seconds; and single prompt, the herbstat label and logging
are applied. **Inconsistency, pre-existing:** `shipmode` connects
`sk.check_shipmode` to `newroom` only in its `onenabled`, never at load, so
after a restart or a class change the ship-mode failsafe is not wired even
with the option on. `burrowpause` does it both ways.

`svo.config.set(what, option, echoback)` accepts yes and no words for
booleans, range-checks numbers, validates strings with `check`, and opens
`onmenu` for custom options. It raises `svo config changed` on a
`tempTimer(0)`, continues the installer if one is running, and runs the
gnomes. `svo.tntf_set` raises the event immediately. `tn serverside` runs
`setup_default_serverignore`, drops old "using server-side curing" ignores,
calls `setupserverside()`, and sends `curing afflictions on`, `sipping on`,
`defences on`, `focus on|off`, `batch on`, `config advancedcuring on`,
`reporting on`, and `curing on` unless paused.

Two small defects, pre-existing: the `morphskill` option's `installstart`
clears `svo.sp_config.morphskill` instead of `conf.morphskill`, so a
reinstall never asks it again; and the `weapon` option's `onshow` is a
string formatted at load that never updates.

**Functions.** `svo.conf_printinstallhint(which)` prints the right "use
`vconfig X ...` to answer" line for an option's type, and `conf_installhint`
(local) returns the same text as a string for the installer. `svo.tntf_set`.
`svo.sk.show_all_confs()` prints everything. `svo.config.setoption`,
`svo.config.deloption` and `svo.config.set` are the read/write API.
`svo.config.showcolours()` and `svo.config.showprompt()` are the two
interactive configuration screens.

#### `Install_system.lua` (13,324 bytes, loader `install`)

The `vinstall` flow.

* `installdata` is the table of GMCP probes: which skills to ask the game
  about in order to work out what you are.
* `svo.installclear()` resets install state.
* `svo.installstart(fresh)` begins. `vinstall fresh` is a two-step
  confirmation, because it discards existing settings.
* `svo.install.ask_install_questions()` walks `config_dict` in order, asking
  about every option that has an `installstart` or `installcheck`.
* `svo.install.check_install_step()` validates an answer and advances.
* `svo.install.checkskillgmcp()`, `checkinvgmcp()` and `checkskilllist()` are
  the three GMCP probes, confirming that skills, inventory and the skill list
  all arrive before the install can complete.

The flow in order. `installstart` sends `Char.Skills.Get` for every
`installdata` entry with a `gmcp` field (plus the survival group and, for
metamorphosis, the metamorphosis group) and `Char.Items.Inv`, and unblocks
the three probe handlers. It sends `config screenwidth 0` and the in-game
`CONFIG PROMPT CUSTOM` string, runs every option's `installstart`, zeroes the
pipe ids, and sets `org` from the GMCP city and dragonflex and dragonheal
from level 99. `checkskillgmcp` answers each probe, and `installclear` arms a
5-second timeout that sets unanswered booleans false and then starts
`ask_install_questions`. That asks the first option, in `config_dict` order,
with `conf` nil and an `installcheck`, and prefills `vconfig <name> ` on the
command line. Every `svo.config.set` advances it. At the end it blocks the
probes, runs `saveconfig`, offers parry setup, precache and colours, sets the
default prompt, and asks for a restart.

Defects, pre-existing: `checkinvgmcp` assigns pipe ids from inventory items
named "pipe" through `svo.pipe_assignid` (which also sends `empty <id>`), but
its location guard `if not t.location == 'inv'` is always false, so it scans
every item list; the `pipes` entry's `ii pipe` command is never sent; and
`vinstall fresh` calls `os.remove` on the `svo` directory, which cannot
remove a non-empty directory, then resets defup and keepup to `basic` and
`combat` only.

#### `Priorities.lua` (16,146 bytes, loader `prio`)

Priority list management. Thirteen functions.

**The model.** Priorities live only on the dictionary handlers, as
`aspriority` and `spriority`. Files exist only for export and import, which
the file's own header says. At `systemstart`, `prio.import('current')` loads
`<home>/svo/prios/current`, falling back to
`installationfolder()/default_prios`, and a `saveconfig` pre-emit exports
`current`. The file format is Lua, `balance = { [n] = "action" }`, run in a
`setfenv` sandbox.

* `prio.list(echoback)` lists the saved priority **files**.
  `prio.getlist(balance)` returns a balance's list.
* `prio.getsortedlist(balance)` returns it in importance order. This is what
  serverside diffing compares against.
* `prio.gethighest(balance)` returns the top number and its action.
* `prio.getnumber(action, balance)` returns one action's priority. The
  autoslick logic and the health/mana serverside mirror both use it.
* `prio.getaction(n, balance)` and `prio.getslowaction(n)` go the other way.
* `prio.sortlist(actions, balance)` sorts a list of action names by their
  priority on that balance. `svo.missing_enchant` uses it.
* `prio.insert(action, balance, number, echoback)` moves an action to a
  position and shifts the rest, setting `aspriority` (or `spriority` for
  `slowcuring`) on each moved action. It raises `svo prio changed` **once
  per moved action**, with a fourth `'slowcuring'` argument for the sync
  list.
* `prio.cleargaps(balance)` closes the deliberate numbering gaps.
* `prio.usedefault(echoback)` reloads **every** list from
  `resources/default_prios`.
* `prio.export(balance, args)` writes a list out.
* `prio.import(name)` reads a file in. It clears each imported balance, sets
  the numbers, reruns `dict_setup` and `dict_validate`, and reports
  serverside differences with `sk.notifypriodiffs(before, after)`.

**Defects, pre-existing:** `prio.insert` for `slowcuring` at an empty slot
calls `insertat`, which indexes `svo.dict[<action_balance>]['slowcuring']`
and raises; and moving an action that is not in the list raises at
`t[oldnum] = nil` with a nil index.

`prio.import` carries a fix worth noting because it changes observable
behaviour: the failure path used to `send` silently, which meant a bad import
looked like nothing happening. It now calls `svo.echof` and returns.

#### `Rift.lua` (36,178 bytes, loader `rift`)

Tracks what you are carrying and what is in the rift, and generates the
commands that use them.

**Data.** Herb and mineral lists in four forms: `herbs_plural`,
`herbs_singular`, `herbs_singular_sansprefix`, and the matching `items_*` set.
`herb_conversions` and `vial_conversions` map between the names the game uses
in different messages.

**Regeneration on `curemethod` change.** This is the interesting part. When you
change how you get cures, `Rift.lua` **rebuilds** five functions on
`curemethodchanged` rather than branching inside them: `sk.can_eat_for`,
`svo.sip`, `svo.apply`, `sk.synceat` and `sk.asynceat`. The cost of deciding
"am I eating from the rift or from my inventory" is paid once per
configuration change instead of on every cure. `sk.syncfill` and
`sk.asyncfill` are ordinary functions that choose the herb when called (the
comment says pipes are filled too rarely to be worth recompiling), and
`siprandom` is a fixed local.

`svo.sip` and `svo.apply` are rebuilt but do not vary: they always use
`sipcure[1]` and `applycure[1]`, the concoctions name. So `curemethod`
changes what is eaten and what fills pipes (and sileris, in the dictionary),
never what is sipped or applied. With `conf.siprandom`, `svo.sip` picks a
random vial id from the elistsorter's `svo.es_vialids`.

There is a second swap on top of it. `svo.eat` is not one of the rebuilt
functions; it is a binding, reassigned whenever `signals.changecuring` fires:

```lua
svo.signals.changecuring:connect(function ()
  if sys.sync then svo.eat = sk.synceat else svo.eat = sk.asynceat end
end, 'update svo.eat on aeon/retardation')
```

So `curemethod` decides what the two eat functions contain, and aeon decides
which of the two `svo.eat` points at. By the time a dictionary handler calls
`svo.eat`, both questions are already settled and there is no branch left to
take. `svo.signals.systemstart` emits `curemethodchanged` once at load, to
create them in the first place. `svo.fillpipe` is a second binding of the
same kind: `sk.syncfill` in slow curing and `sk.asyncfill` otherwise,
swapped on `changecuring`.

`sk.synceat` eats if the herb is in your inventory and otherwise only
outrifts it, so the next sync action eats. `sk.asynceat` eats and outrifts
together. `rift.outr(what)` takes one argument, tops up to the current
defence mode's precache amount, and arms `sys.blockoutr`.

**Persistence.** `<home>/svo/rift+inv/`: `rift`, `inv` (reset to zero on
load, since you cannot hold herbs across a login), and `precachedata`, one
table per defence mode, of which `rift.precache` is the current mode's.
`enablegmcp` subscribes to `IRE.Rift`, but nothing listens to `gmcp.IRE.*`
except `IRE.Time`, so rift contents are tracked from text lines only.

**Functions.** `rift.resetriftcontents()`, `rift.resetinvcontents()`,
`rift.update_riftlabel()`, `rift.outr(what)`,
`rift.checkprecache()`, `svo.intlen(n)`, `svo.riftline`, `svo.showrift`,
`svo.showinv`, `svo.showprecache`, `svo.setprecache`, `svo.invline`,
`svo.riftremoved`, `svo.riftadded`, `svo.riftnada`, `svo.riftate`,
`svo.pocketbelt_added`, `svo.pocketbelt_removed`, `svo.toggle_riftlabel`.

Precaching is the mechanism that keeps a working supply out of the rift so a
cure never has to wait on an outrift.

#### `Pipes.lua` (10,611 bytes, loader `pipes`)

Two pipes are tracked, and every field is doubled: `lit`/`lit2`, `id`/`id2`,
`arty`/`arty2`, `puffs`/`puffs2`, `filledwith`/`filledwith2`,
`maxpuffs`/`maxpuffs2`.

* `svo.lastlit()` records which pipe was lit last.
* `svo.pipeout()` handles a pipe going out.
* `svo.pipestart()` begins parsing a PIPES list.
* `svo.parseplist()`, `svo.parseplistempty()`, `svo.parseplistend()` parse it.
* `svo.pipe_assignid(id)` assigns an id to a slot.

Pipe state is saved to its own file, `<home>/svo/pipes/conf`, on
`saveconfig`, and loaded when the loader runs, with defaults added for fields
introduced later. It is not part of the configuration file.
`pipes.expectations` is a rotating guess at which pipe goes out next;
`svo.pipeout()` marks the first unlit one and rotates. `connected` marks
non-artefact pipes unlit on login. **Defect, pre-existing:** the PIPES list
parser fills primary then secondary pipes, but its empty-slot pass compares
the status against `'Lit'` (capitalised) and reads a `status2` that is never
set, so pipes assigned from empty slots are always marked unlit.

#### `Parry.lua` (12,931 bytes, loader `parry`)

Which limb to parry.

* `sps.parry_options` is the five strategies: **full**, **lasthit**,
  **lasthit opposite limb**, **lasthit opposite side**, and **manual**.
* `svo.sp_limbs` is the limb list.
* `svo.check_sp_satisfied()` tests whether the current parry matches what the
  strategy wants.
* `sps.sp_fillup()` fills the parry priority list.
* `sps.installnext()` steps the parry installer.
* `sp.setup()`, `sp.nextprio()`, `sp.setparry()`, `sp.setparrylevel()`,
  `sp.show()` are the `vp` command bodies.
* `svo.sp_setparry()` and `svo.sp_checksp()` are the runtime path.
* `sps.checkcustomparry()` handles a user-supplied strategy.
* `sps.something_to_parry()` is the "is there anything worth parrying" test.

The flow: `valid.limb_hit` unblocks `svo.sp_checksp` on
`after_lifevision_processing`. It recomputes `sp_config.parry_shouldbe` for
the strategy (a custom function strategy also reruns on every `svogotaff`
and `svolostaff`), calls `check_sp_satisfied` to set `sys.sp_satisfied`, and
blocks itself again. The dictionary's balanceless `doparry.physical` fires
while not satisfied and sends `parry`, `guard` or `clawparry <limb>`. The
`full` strategy needs `parry_actionlevel` numbers, whose install step is
commented out, so it works only if you set them by hand with
`sp.setparrylevel`. The configuration is saved to
`<home>/svo/config/sp_config` and loaded when the loader runs.

**Defect, pre-existing:** `sp.setup()` assigns the file-local `sp_config` a
new table without updating `svo.sp_config`, so after `vsetup sp` the parry
commands (which read `svo.sp_config`) and the saved file (which writes the
local) disagree until reload.

---

### `svo (custom prompt, serverside)`

Two files, 55,111 bytes.

#### `Custom_prompt.lua` (22,366 bytes, loader `customprompt`)

svof can replace the game's prompt with one built from tags.

**`svo.cp.definitions`** maps a tag string to the function that computes it.
**`svo.cpp`** holds those functions, **64** of them: 55 named `compute_*`,
`unknown_stats`, and eight generated in two loops
(`compute_<stat>_percent` and `compute_<stat>_colour` for health, mana,
endurance and willpower). The table below groups the named ones; it does not
list the eight generated ones or `compute_age`, `compute_anathemabal`,
`compute_manifestation`, `compute_wrathbal` and `compute_wrath`. Many exist
only for a skillset, and where the skillset is absent the tag is still
defined, as `"''"`. `@essence` is defined only for `necromancy`, although
`compute_essence` also exists for `oppression`.

| Group | Tags |
|---|---|
| Vitals | `compute_diffhealth`, `compute_diffmana`, and their `_paren` and `_bracket` variants, `unknown_stats` |
| Balances | `compute_eqbal`, `compute_armbal`, `compute_voicebal`, `compute_entitiesbal`, `compute_prayerbal`, `compute_humourbal`, `compute_homunculusbal`, `compute_shruggingbal`, `compute_dragonhealbal`, `compute_wordbal` |
| State | `compute_defs`, `compute_prone`, `compute_Prone`, `compute_pause`, `compute_slowcuring`, `compute_morph`, `compute_power`, `compute_power_color`, `compute_karma`, `compute_momentum`, `compute_essence`, `compute_battlerage` |
| Class-specific | `compute_kai`, `compute_kai_colour`, `compute_shin`, `compute_shin_colour`, `compute_monkpath`, `compute_stanceform`, `compute_stanceform_verbose`, `compute_weaponmastery` |
| Target | `compute_gametarget`, `compute_gametarget_colour`, `compute_gametargethp` |
| Time and world | `compute_timestamp`, `compute_servertimestamp`, `compute_day`, `compute_month`, `compute_year`, `compute_age_colour`, `compute_sunlight`, `compute_at` |
| Passthrough | `compute_promptstring`, `compute_promptstringorig`, `compute_reverse_xp` |

Two more live in `svo (core)/svo Utilities/Custom prompt tags/`:
`svo.cpp.show_exits` and `svo.cpp.show_exits_caps`, plus
`paracelsus_affs_customtag2` for the affliction list. Those, and `@mem`, are
registered at runtime through `adddefinition` and are not in
`cp.definitions` (see `svo Utilities/`).

**Building the prompt.** `cp.generatetable(str)` tokenises the prompt string.
It matches **longest tag first**, which is what stops `@health` being parsed as
`@heal` followed by `th`. `cp.makefunction()` takes no argument. It returns
unless `conf.customprompt` is set **and** `sk.logged_in` is true, calls
`cp.generatetable(conf.customprompt)` itself, and compiles
`return table.concat({...})` with `loadstring` into a single function, so
rendering the prompt at every prompt is one call rather than a walk over the
definition table. If the compile fails it falls back to an empty display and
logs through `debugf`. If the prompt uses `@gametarget`, `@gametargethp`,
`@weaponmastery` or `@servertimestamp`, it also sends
`sys.ingamecustomprompt`, a `CONFIG PROMPT CUSTOM` line, so the game's
prompt carries those fields, and gags the confirmation with a one-shot
trigger. `cp.adddefinition(tag, func)` is the public way to add a tag, and
reruns `makefunction`.

**When it runs and who renders it.** `makefunction` is connected to
`gmcpcharname` (the comment says login, not `systemstart`, so the in-game
prompt can be set), runs at once if the system is already loaded, and runs
again from `cp.adddefinition`. Until then `cp.display()` returns `''`.
`cp.display()` is called by the `after_prompt_processing` prompt pipeline
(`Controllers.lua:364`) and by `svo.showprompt()`
(`Miscellaneous_functions.lua:204`, into the `svo.bottomprompt` window when
that is in use). `systemstart` also copies `conf.customprompt` into
`conf.oldcustomprompt` if that is unset or `'off'`.

**Defect, pre-existing:** literal text between tags is emitted as `'...'`
without escaping, so an apostrophe or a backslash in `conf.customprompt`
makes the compile fail and the prompt goes blank.

The colour table is imported from Mudlet: every Mudlet `color_table` name
becomes its own `^<name>` tag that emits that colour.

#### `Serverside.lua` (32,745 bytes, loader `serverside`)

The bridge to Achaea's own curing system, and the most constrained part of the
system.

**The constraint.** The server's priority space is small. `sk.sendpriorityswitch`
caps it explicitly:

```lua
-- caps at 25, so pool everything after on 25
if priority > 25 then priority = 25 end
```

and `sk.sendpriorityignore` uses 26 as the ignore value for an affliction and
`reset` for a defence, and returns while `svo.logging_in`. So svof's own
priority lists, which run to 211 entries for slow curing, have to be
compressed into 1 to 25, with everything past 25 pooled at 25. Nothing
reports when that pooling changes the order.

**What `svo.serverignore` means.** `serverignore[action] = true` means **the
server cures it and svof skips it**. The `check_*` functions skip an action
when `conf.serverside and svo.serverignore[i]`, and
`sk.shouldignoreserverside(action)` is true when
`not serverignore[action]`, that is, when svof keeps it. So
`setup_default_serverignore()`, which runs only when the table is empty,
sets **every** serverside-capable action to `true` (hand it to the server)
and then `impale`, `lovers` and `selfishness` to `false` (svof keeps them;
the comments say the server does not stack writhing, handle lust, or remove
selfishness).

**Only afflictions and defences translate.** Both send functions check:

```lua
if svo.dict[action][balance].def then           -- it is a defence
elseif svo.dict[action].aff
   and not svo.dict[action].aff.notagameaff then -- it is an affliction
else                                             -- neither, skip it
```

Anything svof does that the game does not model as an affliction or a defence
simply is not mirrored. `notagameaff` is the flag that marks svof's own
bookkeeping entries so they are never sent.

**`svo.dict[action].gamename`** is what handles the cases where the server
calls something by a different name. The comment in the dictionary explains
why the field exists at all: the server's names were revealed years after
svof was written.

**Change detection, not resending.** Every send goes through a cache:

```lua
if cache[action] == priority then
  svo.debugf("%s is already on %s, ignoring", action, cache[action])
  return
end
```

`sk.priochangecache` holds what the server currently believes.
`sk.getbeforestateprios()` snapshots before a change,
`sk.getafterstateprios()` snapshots after, and `sk.updateserversideprios()`
diffs them with `svo.basictableindexdiff` and sends only the differences. It
also refuses to run while `svo.logging_in` or before `svo.systemloaded`,
because priorities shuffle during startup and mirroring that noise would be
pointless traffic. A stopwatch, `sk.updateserverwatch`, times the diff,
because on a 211-entry list it is not free. After sending, it stores a fresh
before-state for the next change.

**What triggers a sync.** `sk.priochangetimer` is a `tempTimer(0)` debounce.
It is armed by `svo prio changed` and by `sk.handleserversideswitch`, which
is connected to `svo ignore changed`, `svo keepup changed`,
`svo serverignore changed`, `svo switched defence mode` and `svo done defup`
(plus `sk.handleserversideswitch_keepup`, which reacts only for the current
mode). Those connections are **blocked** at `svo system loaded` when
serverside is off, and unblocked or blocked again by `vconfig serverside`.

**Possible defect, not verified live.** `sk.updateserversideprios` returns
early while `svo.logging_in` or before `svo.systemloaded` **without
clearing `sk.priochangetimer`**, and every scheduler arms a new timer only
when that field is nil. So if a sync is scheduled during login (for example
by `loginonbasic`'s `svo switched defence mode`) and fires before the
"Password correct" line clears `logging_in`, no later change reaches the
server until `vconfig serverside` is toggled. Whether it happens depends on
the order in which the game sends `Char.Name` and that line.

**`sk.splitbals`** and **`sk.splitdefs`** are the translation step. svof stores
slow-curing priorities as one flat list of `action_balance` names; the server
wants them per balance. `splitbals` splits one into the other.
`sk.splitdefs(balance, list)` does more than split: it drops `uncurable` and
`irregular` actions, moves defences that are on defup or keepup and not
ignored into their own list, moves ignored defences and ignored afflictions
into two "disabled" lists (which then get `sendpriorityignore`), and drops
every other defence, including `undeffable` ones.

**`sk.notifypriodiffs(before, after)`** has nothing to do with the 25 cap and
prints nothing. It diffs two snapshots and raises `svo prio changed` for
every action whose index moved. It is the event source for the paths that
change many priorities at once: `prio.import`, and the runtime
`enablemindnet`, `enablelifevision` and `enableshroud`, which rerun
`dict_setup`.

**The rest of the API.** `sk.resetserversideprios()` resets both lists and
blanks the cache. `sk.shouldignoreserverside(action)` is true when the action
is on `svo.ignore`, is kept by svof (`not serverignore`), is a defence that
is off keepup (outside defup) or off defup (during defup), or its
dictionary `onservereignore()` says so. `sk.handleserversideswitch()` and
`sk.handleserversideswitch_keepup()` schedule the sync described earlier.
`sk.getallserversideactions()` enumerates everything mirrorable.
`sk.getblankbeforestateprios()` is the empty snapshot, with every priority
negative so everything differs.

**`vconfig serverside` on.** Resets the cache, takes the blank before-state,
sends `PRIORITY RESET`, forces a full sync, runs every dictionary
`onprioswitch`, and then mirrors `healthaffsabove`, `mosshealth`,
`mossmana`, keepup (`defences on/off`), focus, clot, insomnia, `clotat`,
`siphealth` and `sipmana` (0 unless the server handles `healhealth` and
`healmana`), `curemethod` (as `transmutation` and `fallback` on or off), and
`manathreshold`.

**Toggles the server owns.** `sk.canfocus()`, `sk.togglefocusserver()`,
`sk.canclot()`, `sk.toggleclotserver()`, `sk.toggleinsomniaserver()`.

**Configuration mirrors.** A set of handlers keep the server in step whenever
one of these changes: `healthaffsabove`, `moss`, `mosshealth`, `mossmana`,
`clot`, `siphealth`, `sipmana`, `bleedamount`, `manause`, `curemethod`,
`paused`, `keepup`. The `sync` signal switches between the `normal` and
`slowcuring` curingsets. `paused` uses `svo.force_send` rather than the queue,
so `curing on` and `curing off` keep their order. Focus is toggled from
`svogotaff`, `after_prompt_processing` and every configuration change, and is
turned off while you have cadmus unless `focuswithcadmus` is on and you have
one of `me.cadmusaffs`. Clot is turned off while `corrupted` and health is
below `sys.corruptedhealthmin`.

**Setup and its two failure modes.** `svo.setupserverside()` prepares the
curingsets. It runs on `charname` and `gmcpcharname`, sends
`curingset new normal` and `curingset new slowcuring`, and opens a window of
5 seconds plus ping (`svo.serversidesetup`) in which the curingset and alias
limit messages count. svof needs **two curingsets** (`NORMAL` and `SLOWCURING`) and
**two aliases** on the server, and the game limits both. When either is full:

* `svo.hitcuringsetlimit()` explains you need two curingset slots, prints
  clickable `CURINGSET LIST` and `CURINGSET DELETE` links, and then calls
  `svo.tntf_set('serverside', 'off', true)` to turn serverside off rather
  than leave it half-configured.
* `svo.hitaliaslimit()` does the same for aliases, with `ALIAS LIST` and
  `CLEARALIAS` links.

`svo.setup_default_serverignore()` populates the default list when it is
empty: every serverside-capable action handed to the server, except
`impale`, `lovers` and `selfishness`, which svof keeps (see "What
`svo.serverignore` means").
---

### The addons

Seventeen folders, one per former Mudlet module. Ten register a loader and are
called from `svo_init_system`'s addon list. The other seven are pure trigger
and alias packs whose script folder holds only the namespace stub.

Addon options are registered with `svo.config.setoption(name, spec)` rather
than being written into `config_dict`, so an addon can add its own `vconfig`
entries without the core knowing it exists. That is the extension point.

**How each addon hooks into init.** The ten with a `svo.loader.<name>` are
called from `svo_init_system`'s addon list, so they rerun on every class
change and reconnect to the new bus. NameDB is different: `ndb_load` is
registered with `registerAnonymousEventHandler("svo system loaded",
ndb_load, true)`, **one-shot**, and `ndb.init()` (the database) runs at
script-body time. The module era did the same with `tempTimer(0, ...)`, so
this is pre-existing.

**Consequence of the one-shot, pre-existing.** Everything `ndb_load`
connects to `svo.signals` lives on the first bus only. After the first class
change (dragonform included), the new bus has none of: the three
`saveconfig` handlers (the highlightignore list, city politics, and
`VACUUM`), and `svo.signals["namedb finished honors"]`, the signal NameDB
creates for itself. So highlightignore and city-politics edits made after a
class change are not saved. `ndb.loadsettings`, which runs on every
`svo system loaded`, then reloads the stale city-politics file over the table
at the next class change, reverting them. Honors chaining survives only
through a separate anonymous `svo got balance` handler. This is reasoned
from the code and has not been tested.

**Anonymous Mudlet handlers.** Besides NameDB's two, script-body
`registerAnonymousEventHandler` calls exist for the `@mem`, `@exits`,
`@affs`/`@target` and `@bl` prompt tags, `svo_count_show`'s
`changelimbcount` option, and the enchanter's `gmcp.Char.Items.List` handler
for `svo.check_ourobori`. These are what the reinstall-leak item in
`CLAUDE.md` refers to.

#### `svo (limbcounter)` (loader `limbcounter`)

Counts how many more hits a limb needs before it breaks. Two files.

**`svo_limbcounter.lua`** (18,571 bytes). Its loader opens by disabling every
class-specific limbcounter trigger group, then enabling exactly the one that
matches `svo.me.class` or dragonform. `svo.lc_classlist` names the fourteen
supported cases: Magi, Paladin, Infernal, Runewarden, Monk, Priest, Dragon,
Druid, Blademaster, Sentinel, Sylvan, earth Elemental Lord, Unnamable, None.
Because the loader runs again on every class change, the trigger set follows
the class automatically. Three gaps: there are no `svo Blademaster
limbcounter` or `svo None limbcounter` groups, so those two classes enable
nothing (a silent no-op), and the Shikudo branch tests
`me.path == "Shikudo"` while `Setup.lua` stores `'shikudo'`, so Shikudo monks
get no limbcounter at all.

State: `svo.lc_list` (per-person, per-limb counts), `svo.lc_break_at` (default
10), `svo.lc_lasthit`, `svo.lc_myclass`, `svo.lc_shikudodamage`,
`svo.lc_shikudoskill` (three tiers: lowest, middle, highest), `svo.lc_shaping`
for Sculpting stage, `svo.lc_limbreset`.

Functions: `svo.lc_prep_at()` returns `lc_break_at - 1`, the count at which a
limb is prepped rather than broken. `svo.lc_hit(person, limb, amount)` is the
one every limbcounter trigger calls. `svo.lc_shikudohit(person, limb, tier)`
is the monk version, taking a tier name rather than a number.
`svo.lc_shikudocount(person, low, mid, high)` sets the three tiers.
`svo.lc_shikudodamagecheck()` and `svo.lc_priestdamage()` handle the two
damage modifiers. `svo.lc_appliedreset(part, person)` resets a limb when you
see it healed. `svo.lc_smash()` and `svo.lc_ignore()` handle the two "that did
not land" cases. `svo.lc_checklimbcounter()` re-evaluates and raises
`svo limbcounter hit`. `svo.lc_reset()`, `svo.lc_show()`,
`svo.lc_sethitsneeded(person, n)`, `svo.lc_synchits()`. `svo.lc_prompttag`,
`lc_prompttag2` and `lc_prompttag3` are three prompt tag variants, registered
at loader time with `svo.adddefinition`. `get_other_prepped` is a local.

The flow: `svo.lc_hit` queues `{limb = damage}` in a local `hittable`,
enables the two "Don't register" triggers, and connects
`lc_checklimbcounter` to `before_prompt_processing` (unnamed), which applies
the damage, raises `svo limbcounter hit`, reports, and disconnects itself.
That connect and disconnect on every hit is one of the places the luanotify
queue drift grows (see "The signal bus").

**Defects, all pre-existing:**

* `svo.lc_smash()` (from the `svolc Don't register 2` trigger) calls
  `signals.before_prompt_processing:disconnect(...)` with no local
  `signals`, so it always raises.
* `svo.lc_priestdamage` is first a boolean and then redefined as a toggle
  that overwrites itself with a boolean, so its second call raises. The
  Priest `Fragility` trigger calls `svo.lc_damagecheck`, which nothing
  defines.
* `get_other_prepped` compares a count with the function `svo.lc_prep_at`,
  so "also prepped" is never reported.
* `lc_sethitsneeded` and `lc_synchits` read a global `lc_lasthit` (never
  set) instead of `svo.lc_lasthit`, so "sync" always says it is tracking
  nobody. `lc_show`'s empty check compares a table with `{}`.
* `lc_countshow` has hit tables only for Runewarden; Infernal and Paladin
  index a nil table.
* The Tekura punch triggers pass `svo.conf.larmdamage`, but the option is
  `armdamage`, so every punch counts as 1. The unreachable Shikudo branch
  also calls a misspelled `disablTrigger`, and its `Hyperfocus` trigger calls
  `svo.lc_shikudodamage(...)`, which is a string.

**`svo_count_show.lua`** (8,123 bytes) holds `svo.lc_counttable`, the
health-range to hit-count tables per class and weapon style, and the functions
`svo.lc_countshow`, `svo.lc_countshowknight`, `svo.lc_changestart`,
`svo.lc_changeend`, `svo.lc_addcount`, `svo.lc_deletecount`.

It also carries one of the conversion's documented fixes, and the comment is
the clearest single statement of the load-order problem in the whole
repository:

```lua
-- Registered on "svo system loaded", not at body time.
--
-- svo.config does not exist when this body runs. On the modules that was
-- survivable by accident: on a fresh install the script happened to run after
-- the config subsystem, so the option registered once and was lost from the
-- first restart onward. In one package svo.config is guaranteed absent here,
-- so this raised at load and `changelimbcount` never registered at all - the
-- conversion turned an intermittent loss into a permanent one.
--
-- "svo system loaded" is the convention the rest of the system already uses
-- for exactly this; tempTimer(0, ...) is not enough, since a script can run
-- before svo_init_system does.
registerAnonymousEventHandler("svo system loaded", function()
  svo.config.setoption("changelimbcount", { ... })
end)
```

The trigger side has 71 triggers in 16 folders, one group per class, described
in the trigger section below.

#### `svo (burncounter)` (loader `burncounter`)

Tracks how many burn levels a target is carrying, for Magi. Two files.

`burncounter_code.lua`: `svo.bl_count(person, what)` is the single entry point
and takes one of seven operations, matching seven triggers: `"only ablaze"`,
`"add level"`, `"add to all"`, `"remove level"`, `"dehydrate"`,
`"lost dehydrate"`, `"remove ablaze only"`. An eighth trigger,
`svobl Don't register`, calls `svo.bl_ignore()`. `sk.bl_checkburncounter()`
re-evaluates; it is one unnamed `after_prompt_processing` handler, connected
once and switched with `block` and `unblock` rather than reconnected.
`svo.bl_ignore()`, `svo.bl_reset()`, `svo.bl_show()`.

**Defects, pre-existing:** `svo.bl_ignore()` calls `table.remove` on a
string (the queued action), so the "Don't register" trigger always raises;
and `bl_reset('all')` rebinds the local `bl_list`, leaving `svo.bl_list`
(which the `@bl` tag reads) stale.

`svo_Magi_burncounter.lua` is the folder script and holds `bl_setup` (local)
and `svo.bl_prompttag`. The project brief records this file as one of the
casualties of a bulk scripted edit during the conversion: blanking the addon
group scripts destroyed `svo.bl_prompttag` along with them.

#### `svo (elistsorter)` (loader `elistsorter`)

Parses `ELIST`, `ELIST2` and `VLIST` and reports what is decaying.

It creates its own signal at load: `svo.signals.elistcaptured`, by requiring
`notify.signal` directly. It is one of two places outside `Setup.lua` that
create one; NameDB creates `svo.signals["namedb finished honors"]`
(`ndb_main_code.lua:912`).

State: `svo.es_vials` (vial id to months, potion and sips), `svo.es_potions`
(category to potion to totals), `svo.es_vialids`, `svo.es_knownstuff`,
`svo.es_capturing`, `svo.es_categories`, `svo.es_shortnamesr`,
`svo.storedvials`.

Functions: `svo.es_capture()` starts a capture and works out from the line
whether it is venoms or elixirs. `svo.es_captured(isvlist)` prints the report
and emits `elistcaptured`. The `svo_Capture_elist_stop` **trigger**, not this
function, restores `config pagelength` to `conf.pagelength` (at least 20);
`es_dispose` sets it to 250.
`svo.es_appendrequest()`, `svo.es_refillfromkeg()`,
`svo.es_dodisposing()` with its local `emptyvial`, `svo.es_dispose()`,
`svo.load_elist_data()`, `svo.load_potions_data()`, and a local `checkdecays`.

`svo.put_vials_away.lua` is a separate script registered on `svo quit`, so
your vials get stowed when you log out.

The vial trigger also handles obfuscated vials: any vial marked `Obfuscated`
with sips at or below `conf.obfsips` is put into `conf.obfcontainer` and
recorded in `svo.storedvials`.

#### `svo (enchanter)` (loader `enchanter`)

Automates making enchanted items. 32,380 bytes, the largest addon.

It registers three options of its own at load:
`haveenchantmentmedallion`, `enchantgetgold` (default
`"get 1 gold from pack"`) and `enchantputgold` (default
`"put 1 gold in pack"`). Each `onshow` renders a clickable line, so the
`vconfig2` page lets you toggle or retype the value without knowing the
command.

**`enchantments`** is a hard-coded table of **32 recipes**: `purity`,
`pestilence`, `negation`, `dreamcatcher`, `bauble`, `fresist`, `concealment`,
`icewall`, `comprehension`, `whirlwind`, `magic`, `brooch`, `firewall`,
`electric`, `cold`, `orb`, `cube`, `mushroom`, `monolith`, `knife`, `key`,
`flame`, `fist`, `hearing`, `eye`, `worrystone`, `meteor`, `waterwalking`,
`scabbard`, `stasis`, `firelash`, `star`. Each has a `fullname` used in the
begin command, a `type` of `"creation"` or `"enchantment"`, an `ingredients`
list and an `actions` list.

The engine is a queue that runs as a **balanceful function**:
`svo.addbalanceful("enchantment step", enchantmentStep)` hands it to the
balance controller, and each step sends every balanceless action at once and
stops at the next balanceful one. `enchantmentQueue` holds items still to
make, `enchantmentActions` the steps for the current one, and locals
`addToActionQueue`, `enchantNextItem`, `enchantmentStep`, `startEnchanting`
and `endEnchanting` drive it. `getOIDs` and `getSameItems` are the two
inventory helpers, and `enchant` is the local that queues an order. It stops
keeping selfishness and riding **up** while it works, remembers whether they
**were up** (`hadSelfishness`, `hadRiding`), and afterwards sets keepup to
that, not to the old keepup setting.

Public functions: `svo.reenchant()` repeats the last order,
`svo.parse_enchant_arguments(str)` parses the `enchant` alias,
`svo.get_enchant_cost(item)` and the local `printEnchantCosts` report what a
job will take, and `svo.check_ourobori()` identifies the two ouroboros in the
room.

`svo.reenchant` appears twice in the file, but the first (line 871) is inside
a `--[[ ]]` comment, so there is only one live definition. The trailing
reload block is commented out too, so saving the script does not rerun the
loader.

#### `svo (namedb)` (no loader)

The largest addon and effectively its own system, in its own `ndb` namespace.
It keeps a SQLite database of every player it has seen and highlights their
names by affiliation.

**`ndb.init.lua`** creates the database with `db:create("NameDB", ndb.schema)`
and then runs per-column `ALTER TABLE` migrations, so an old database gains
new columns rather than being rebuilt. The schema covers `name`, `class`,
`city`, `city_rank`, `city_soldier`, `guild`, `order`, `race`, `gender`,
`dragon`, `immortal`, `xp_rank`, `combat_rank`, `combat_rating`, `might`,
`mark`, `infamous`, `divorces`, `arms`, `motto`, `warcry`, `birth_day`,
`birth_month`, `birth_year`, `birth_hidden`, `cityenemy`, `houseenemy`,
`orderenemy`, `notes`, `title`, `iff` (the manual enemy or ally override
that `ndb.isenemy` checks first), `importance` and `level`: 33 columns.

**`ndb_main_code.lua`** (29,327 bytes) is the API, 59 functions:

* *Affiliation tests:* `ismhaldorian`, `iscyrenian`, `isshallamese`,
  `istargossian`, `iseleusian`, `isashtani`, `ishashani`, `isundead`,
  `isclass`, `isdragon`, `isimmortal`, `isenemy`, `issoldier`,
  `isonlycityenemy`, `iscityenemy`, `isperson`, `exists`, `ismark`,
  `isinfamous`.
* *Getters and setters:* `getclass`, `setclass`, `getcity`, `getcityrank`,
  `getnotes`, `getxprank`, `setmark`, `setinfamous`, `setdragon`, `setiff`,
  `addname`, `getname`, `getnamebytitle`, `getrankincity`.
* *Name matching:* `findname(line)` pulls a player name out of a line,
  `findnames(line)` pulls all of them, `findfromtable(str, tbl)` matches
  against a list.
* *Pluralisation and colour:* `getpluralclass`, `getpluralcity`, `getcolor`,
  `getcolorn`, `getcolorp`, and a local `getcolor`.
* *Highlighting:* `loadhighlights()` rebuilds every highlight trigger,
  `singlehighlight(name)` does one, `cleartriggers()` removes them,
  `highlight()` applies, `loadhighlightignore()` reads the exemption list.
* *Honors engine:* `honors(name)` starts an HONORS on someone,
  `cancelhonors()` stops, `finished_honors()` runs on
  `NameDB finished honors`, `honors_next()` advances a batch,
  `updatebyhonors()` runs on `NameDB got new data`.
* *Import and export:* `doexport`, `doimport`, `getimportfields`.
* *Display:* `showinfamous`, `showhelp`.
* *Merge:* `tablemerge`.
* `ndb_load` is a local, registered one-shot (see "How each addon hooks into
  init").

**Defect, pre-existing:** `ndb.loadhighlights()` calls
`collectgarbage('stop')` and returns early when `conf.ndbpaused`,
**without** restarting the collector. With name highlighting paused, every
call (at load, and from every highlight option change) leaves Lua's garbage
collector stopped until something else runs a full collect.
`ndb.doexport`'s underscore-field pruning never runs
(`not next(t) == nil`), and `ndb.valid.classes` has four classes the
pluralisation table lacks.

**The other NameDB files.** `ndb.aliases.lua` holds `showwhois`,
`exportmenu`, `importmenu`, `checkqw`. `ndb.configs.lua` (33,695 bytes) is the
NameDB configuration UI, with `ndb.setuporders`, `ndb.configs`,
`ndb.showpolitics` and nested renderers `showcities`, `showwatchfor`,
`showdivines`, `showenemies`, `showordermembers`, plus setup helpers
`setupwatchfor`, `setupcities`, `setuprogues`, `setupenemies`, `setupdivines`
and `addhighlightignore`. `ndb.valid.lua` holds `isvalidcity`, `isvalidhouse`,
`isvalidclass`, `isvalidrace` and the reference lists: cities, classes,
houses, races, infamous ranks, city ranks and the twelve Achaean months.
`ndb.fixes.lua` holds `ndb.fixed_set`, a corrected version of the database
library's set. `ndb.downloaded_file.lua` has `ndb.downloaded_file` (on
`sysDownloadDone`) and `ndb.getinfo`. `ndb.getinfo` (the website API path) is
commented out of `honors_next` ("Achaea disallowed use of website
scraping"), but the `Honors` **trigger** still calls
`ndb.getinfo(ndb.honorsname)` on every HONORS, so each honors also downloads
`api.achaea.com/characters/<name>.json`, which `ndb.downloaded_file` merges
and follows with a second `NameDB finished honors`. `ndb.setfromclass.lua` runs on
`svo got hit by` and infers a class from what hit you.
`ndb.addhighlightname.lua` is registered on six events and is the single
re-highlight trigger. `ndb.loadsettings.lua`, `ndb.onshow.lua`,
`ndb.showqwi.lua`, `ndb.ui.lua` (`showhonorswindow`, `hidehonorswindow`) and
`ndb.close.lua` (`db:close()` on `sysExitEvent`) are the small ones.
`ndb.updatebyhonors.lua` is the file whose whole content is the comment
explaining the empty-script idiom.

**Third-party.** `Pluralization.lua` adds `string.pluralize`,
`string.singularize`, `string.endswith` and the helpers `isPlural`,
`isSingular`, `isIrregular`. `Ordinal.lua` adds `string.ordinalSuffix`, which
is also defined in `svo_Utilities.lua`; whichever loads later wins.
`Stats.lua` adds `stats.mean`, `mode`, `median`, `standardDeviation`,
`maxmin`, on a **global** `stats` table, and `Pluralization.lua`'s helpers
are globals too. `Seconds_to_human.lua` adds `seconds2human`.

`resources/ndb-help.lua` (10,008 bytes) is NameDB's help text, shipped as a
resource rather than embedded.

#### `svo (peopletracker)` (loader `peopletracker`)

Tracks who is where. `Peopletracker_code.lua` registers five options with
their own `check`, `onset`, `onenabled`, `ondisabled`, `installstart` and
`onshow` callbacks (none has `onmenu`), then defines `sys.clean_old_labels()`,
`sys.clear_labels()` with its local `clearlabels`, and
`sys.update_people_labels()`. `svo_People_Tracker.lua` holds
`svo.buildwhosummary()` and its four local renderers `wrapname`,
`rendergeneral`, `rendergroups` and `renderwatchfor`. This is the other
~105-line function the project brief records as having been destroyed by a
bulk edit during the conversion.

It integrates with the Mudlet mapper through `mmp.pdb` and
`mmp.pdb_lastupdate`. It both raises `mmapper updated pdb` (from its own
triggers and the `qwho` alias) and listens to it, redrawing at the next
prompt through `sk.onprompt_beforeaction_add`. Toggling `clearlabels`
connects or disconnects an unnamed `newarea` handler, one of the places the
luanotify queue drift grows.

#### `svo (priestreport)` (loader `priestreporter`)

Locates people with a guardian angel and reports back.
`svo_load_maincode_priestreport.lua` holds `svo.trace()` (no argument; it is
the timer callback), `svo.priestapo_trace(name, location)` and a local
`announce_between_two_rooms`. The loader returns unless you are a Priest or
an Apostate. `svo.disable_seek.lua` is registered on `svo got dragonform`,
`svo lost dragonform` and `svo system loaded`, because a dragon has no
angel. `svo_onshow_priestreport.lua` runs on `svo onshow`. **Defect,
pre-existing:** the loader forces `conf.reportdelay = 2` and
`conf.bettertrace = true` on every run, so those two options never persist.

#### `svo (refiller)` (loader `refiller`)

Refills vials. `svo.rf_brewpot()`, `svo.rf_refill()`,
`svo.rf_magichappened()`, `svo.rf_fillnext()`, `svo.rf_nextpotion()`,
`svo.rf_missingstuff()`, `svo.rf_cancel()`. `svo.rf_check_trans.lua` is
registered on `gmcp.Char.Skills` and checks for **Transcendent Remedies**
and **Transcendent Toxicology** (`rf_transrefiller`, `rf_transtoxicology`),
not Transmutation. Either raises the batch from 10 to 12 and changes the
multiplier from 5 to 4. Its `break` stops at the first match, so having both
reads only one.

The same folder's **aliases** carry the vial-shuffling commands: `putvials`,
`getvials` and `givevials` each set a flag and then loop on the game's
response, moving 50 vials at a time, and `givevials` restores selfishness
afterwards if it took it down.

#### `svo (inker)` (loader `inker`)

Inks tattoos. `svo.ti_ink()`, `svo.ti_inknext()`,
`svo.ti_finishedinking(onstencil)`, `svo.ti_cancelinking()`,
`svo.ti_interrupted()`, `svo.ti_cantink(reason)` where reason is one of
`"inks"`, `"skill"` or `"space"`, `svo.ti_printTable()`, `svo.isPlace()`, and
a local `doneinking`. It registers two options with `onshow`, `onenabled` and
`ondisabled` callbacks. Inking pauses svof (`svo.app('on')`) and unpauses
when done. **Defects, pre-existing:** `svo.ti_interrupted()` with
`autoreink` off cancels (clearing `svo.ti_inking`) and then indexes it, so it
raises; and the `autoreink` messages print a literal `&lt;0,250,0&gt;`,
double-escaped in the original xml.

#### `svo (mindnet)` (loader `mindnet`)

Two triggers and almost no code. On seeing someone enter or leave the area, if
`conf.mindnet` is on and NameDB says they are an enemy, it collects the names
and uses `svo.prompttrigger` to report them all at once at the next prompt
rather than one line at a time. The trigger bodies carry three commented-out
alternative report formats, so a user can pick between name only, name plus
count, and name plus count plus area. The loader itself defines only
`onenabled`, `ondisabled` and `onshow`.

#### `svo (fishdist)` (loader `fishdist`, triggers inactive)

Tracks how much fishing line is out, credited to Trilliana. The loader defines
`svo.telldistance` and the three config callbacks. The ten triggers ship
inactive. It keeps its state in a global `fdistance` and appends `@fishdist`
to `conf.customprompt` on enable (raising if no custom prompt is set). The
`decay on pole` trigger sets `fdistance = lineout`, a nil global, instead of
the string.

#### `svo (logger)` (no loader)

`HTML5_logger.lua`: `html5log.recordline()`, `html5log.recordcurrentline()`,
`html5log.showlabel()` and the global `html5log_stoplogging()`. Driven by the
`startlog` and `stoplog` aliases.

#### `svo (offering)` (no loader)

`svo.corpse_stuff.lua` is registered on `gmcp.Char.Items.List` and handles
corpses for offering, defiling, sanctifying and the rest. Its single trigger
catches the two "that shrine is already as powerful as possible" messages,
undoes the queued offer, and restores selfishness if the queue had it.

#### `svo (reboundingsileristracker)` (no loader, triggers only)

Fifteen triggers, no script file beyond the namespace stub. All the logic is
in the trigger bodies. It watches for rebounding and sileris or quicksilver
being razed or flayed off your target, colours the line blue, sets
`svo.rt_razed` or `svo.rt_flayed` with a two-second expiry, and then when it
sees the target smoke or apply, schedules two `tempTimer` warnings at six and
seven seconds (rebounding) or 7.5 and 8.5 seconds (coatings) counting down to
when the defence comes back up. If the defence does come back and matches the
name it was watching, it highlights that line gold on firebrick.

It covers seven ways to strip rebounding: self-removal, generic raze, magi
staff raze, serpent flay, knight fracture, two-handed cutting carve and
two-handed blunt carve.

#### `svo (runeidentifier)` (no loader, triggers only)

Three triggers. Two carry the same rune table inline, mapping the descriptive
phrase the game prints to a rune name and effect, for example
`"like an open eye"` to `wunjo` / `cure blind`. The totem version knows 13
runes, the person-and-ground version 21.

`fehu` is the interesting entry: its effect is a function rather than a string,
because the rune cycles through three uses in order. It tracks position in
`svo.fehu`, returning `"strip insomnia"`, then `"sleep"`, then
`"strip kola"`, and registers a `svo.prompttrigger("clear fehu", ...)` to
reset at the next prompt.

The identified rune is written into the line with `cinsertText` rather than
echoed separately, so the annotation sits where the rune was named.

#### `svo (stormhammertarget)` (no loader, triggers only)

Seven triggers. `Check ih` reads item numbers from the room, skips a list of
twelve scenery types (totem, sigil, blanket, shrine, steed, hippogriff,
pegasus, beehive, lever, gate, box), skips your own entourage, and fills
`target1`, `target2` and `target3`. `Capture ents` learns your entourage ids
for bees, efreeti, weird and golem so they can be skipped.

#### `svo (aliases, triggers)`

No script beyond `svo = svo or {}`. This is the wrapper folder that holds the
2,307-trigger main tree and the 114-alias main set.
---

## File reference: `triggers/`

2,531 triggers in 258 folders, across 15 top-level groups. 2,403 have a `.lua`
file, 64 carry their script inline in the manifest, and 64 have none.

The thing to know before reading this section: **the trigger tree holds almost
no logic**. All 2,410 trigger scripts together are 160,985 bytes, against
1,451,009 bytes of manifest. The typical body is one line:

```lua
svo.valid.proper_paralysis()
```

The patterns are the content. The handlers are all in `scripts/`.

### Counts by top-level group

| Group | Triggers | Subfolders |
|---|---|---|
| `svo (aliases, triggers)` | 2,307 | 216 |
| `svo (limbcounter)` | 71 | 16 |
| `svo (namedb)` | 65 | 5 |
| `svo (reboundingsileristracker)` | 15 | 0 |
| `svo (peopletracker)` | 11 | 1 |
| `svo (refiller)` | 11 | 0 |
| `svo (fishdist)` | 10 | 1 (inactive) |
| `svo (inker)` | 8 | 0 |
| `svo (burncounter)` | 8 | 1 |
| `svo (priestreport)` | 8 | 1 |
| `svo (stormhammertarget)` | 7 | 1 |
| `svo (elistsorter)` | 4 | 0 |
| `svo (runeidentifier)` | 3 | 0 |
| `svo (mindnet)` | 2 | 1 |
| `svo (offering)` | 1 | 0 |

### The main tree: `svo (aliases, triggers) > svo`

2,307 triggers in 215 subfolders. Sixty-six direct child folders.

| Folder | Triggers | Subfolders | Active |
|---|---|---|---|
| General | 874 | 24 | yes |
| svo Bashing triggers | 541 | 100 | **no** |
| General defences | 109 | 10 | yes |
| Miscellaneous | 78 | 6 | yes |
| Poisons + Generic lines | 64 | 1 | yes |
| Weaponmastery | 36 | 4 | yes |
| Chivalry | 31 | 4 | yes |
| Vodun & Puppetry | 31 | 0 | yes |
| Voicecraft | 31 | 0 | yes |
| Dragoncraft | 30 | 0 | yes |
| Striking | 25 | 0 | yes |
| Weatherweaving | 24 | 1 | yes |
| Herb tracker | 20 | 1 | yes |
| Subterfuge | 20 | 0 | yes |
| Apostasy | 19 | 0 | yes |
| Elementalism, Occultism | 18 each | 0 | yes |
| Artificing | 17 | 0 | yes |
| Metamorphosis | 16 | 0 | yes |
| Two Arts | 15 | 0 | yes |
| Swashbuckling | 14 | 0 | yes |
| Propagation, Telepathy, Physiology | 13 each | 0 | yes |
| Tarot, Tekura | 12 each | 0 | yes |
| Crystalism, Hypnosis, Spirituality | 11 each | 0 | yes |
| Domination, Necromancy, Pranks, Runelore | 10 each | 0 | yes |
| Zeal, Devotion | 9 each | 0 | yes |
| Kaido, Woodlore, Alchemy | 8 each | 0 | yes |
| Aeonics, Groves, Riding, Skirmishing | 6 each | 0 | yes |
| Harmonics, Psionics, Spiritlore | 5 each | 0 | yes |
| Curses, Shindo, Sculpting, Pestilence, Weaving | 3 each | 0 | yes |
| Evileye, Reclamation, Shadowmancy, Pervasion, Memorium | 2 each | 0 | yes |
| Pipelist | 4 | 0 | yes |
| Duress, Ignition | 1 each | 0 | yes |
| svo UI Experiments, Charnel, Emulation, Anathema, Excision | 0 | 0 | yes (empty) |

### `General` (874 triggers, 24 subfolders)

The largest and the only one that matters for basic operation.

**The multiline container pattern.** Six of `General`'s direct children are
triggers with no script and a large number of children. They exist to match the
first line of a curing message and hold the multiline window open while the
children match what follows:

| Container | Children | Patterns |
|---|---|---|
| `Ate` | 63 | 3 |
| `Applied salve` | 30 | 2 |
| `Focus` | 20 | 2 |
| `Apply elixir` | 12 | 2 |
| `Sip` | 6 | 2 |
| `Prompt` | 4 | 1 |

So the `Ate` container matches "You quickly eat ..." and its 63 children each
match one possible result. This is why 48 of the 64 script-less triggers are
not a defect: they are gates, and their children carry the work.

**`Prompt` and its children** are the heartbeat of the whole system.
`Prompt`'s only pattern is a Lua function that returns true on a prompt and
otherwise adds one to `svo.paragraph_length`. Its four children are
`Capture flags`, `Blackout`, `Do stuffs.` and `Kai-Shin blackout`. Under
`Capture flags`, a filter trigger, sit `Eq`, `Balance`, `Blind`, `Deaf`,
`Kola`, `Cloak`, `At sign` and `Prayer`, which run against the captured flag
letters only. `Do stuffs.` is a sibling of `Capture flags`, not its child,
and is the one that matters: it raises `svo lost balance` and
`svo got balance` for balance and equilibrium, and then calls
`svo.onprompt()`. Every cure svof sends from the prompt originates from that
single call. `Blackout` (`-` or ` Vote-`) and `Kai-Shin blackout` (`-<n>-`)
call `svo.blackout()`. The full sequence is in "The prompt cycle".

**`Cleanup` (5)** is part of the same mechanism: its triggers subtract one
from `svo.paragraph_length` for a blank line, an exhaled breath, the
rebounding aura or reflections fading, and meditation breaking, so those
lines do not count against a lineguard.

**Balance regain lines** are single triggers directly in `General`: herb,
moss, sip, salve, purgative (two lines), focus, smoke, dragonheal and tree
call `svo.valid.got<bal>()`; "You have recovered balance on all limbs."
calls `svo.gotbalance()` and "You have recovered equilibrium."
`svo.goteq()`. The class balance folders (Hydra, Monk, Prayer, Voice,
Domination, Shrugging, Humour, Fitness, Rage, Word, Age) set `bals.*`
directly or through `svo.valid.used<bal>balance` and `got<bal>balance`.

**Server-side output.** `[Curing]: X` calls `svo.curingcommand`, and
`[System]: Running queued ... command: X` calls `svo.queuecommand`. A set of
gag triggers hide serverside confirmations when `gagserverside` is on.

**Login and editors.** `svo connect` matches the Achaea banner, calls
`svo.connected()`, pauses (`svo.app("on", true)`) unless already paused, and
sets `svo.innews`. The news, composer and registration triggers set and clear
`svo.innews` and pause and unpause around them.

**`svo diag` (149 children).** One trigger per affliction the game can report
in a DIAGNOSE. 147 bodies are a single call that names the affliction,
`svo.valid.diag('calcifiedskull')`, with a count as a second argument for the
ten counted ones; one of them (`blackout`) is an inline script. `Finished`
calls `svo.valid.diagnose_end()`, and `blistered` has no body. All of them
share the one handler in `Diag_trigger_functions.lua`, so the trigger's
wording is the only place svof records that an affliction shows in DIAGNOSE.

**The 22 remaining subfolders:**

| Folder | Triggers | Purpose | Active |
|---|---|---|---|
| `General cures` | 97 | passive cures and cures during blackout | **no**, switched on by `svo.check_generics` |
| `Tree cures` | 88 | Tree balance cures | yes |
| `Symptoms` | 76 | lines that imply an affliction without naming it | yes |
| `Random aff lines` | 43 | afflictions from miscellaneous sources | yes |
| `Passive-active heals` | 24 | heals you did not ask for | yes |
| `Server-side commands` | 12 | catching the game's own curing output | yes |
| `svo Writhes` | 11 | writhing out of restraints | yes |
| `Two-hander recover footing` | 11 | weaponmastery footing | **no** |
| `svo Parry` | 6 | parry results | yes |
| `Ship prompt` | 6 | the ship prompt format | yes |
| `Cleanup` | 5 | line tidying | yes |
| `Newsroom-Editor` | 5 | news reading | yes |
| `Humour balance`, `Monk balances` | 4 each | balance tracking | **no** |
| `Hydra balance`, `Prayer balance`, `Voice balance`, `Fitness balance`, `Word balance`, `Registration` | 3 each | balance tracking, registration | Hydra, Fitness and Registration yes; the rest **no** |
| `Domination entities balance`, `Shrugging balance`, `Age tracking` | 2 each | balance tracking, age | **no** |
| `Rage balance` | 1 | balance tracking | **no** |

The inactive balance folders are class-specific. They are switched by the
`setup` loader itself (`Setup.lua` lines 1270 to 1411) from `haveskillset`,
on every init, not by class management: `svo.enableclass` toggles no trigger
group at all.

`Tree cures` is a **folder with patterns** ("You touch the tree of life
tattoo." plus a spacer), active, acting as its own chain head. Its comment
"this folder is supposed to be off" is stale, copied from `General cures`.
Its cure lines call `svo.valid.tree_cured('<name>')`: 83 calls over 61
affliction names and all six special strings (`'burn'`, `'all burns'` and
the four `'<fracture> cured'`). Every affliction name they pass is in
`empty.treecurables`. That became true when `6648cc0` removed the bleeding
and voided tree triggers, which attributed cures tree cannot make. Almost
every line here has a twin in `General cures` on the same pattern, so a
`Tree cures` trigger is not evidence that tree cures its affliction.

`General cures` ships inactive. Its cure lines call
`svo.valid.generic('<name>')`, 74 calls over 58 names, two of which are
broken (`'burn'` and `'insomnia'`, see the findings), plus four calls each
to `generic_cure` and `generic_cured` for the fractures. `svo.check_generics()`
(`Main_trigger_functions.lua:3414`) turns it on for blackout or a
passive-cure paragraph through `enable_generic_trigs()` (line 3405), which
also disables `Ate`, `Sip` and `Smoke`. It also tries to disable `Applied`
and `Focus mind`, which do not exist, so during blackout `Applied salve` and
`Focus` stay on alongside the generic set.

### `svo Bashing triggers` (541 triggers, 100 subfolders, inactive)

Ships inactive. Six contributor sets, credited by name:

| Set | Triggers | Subfolders |
|---|---|---|
| Drazik's | 371 | 78, one per area |
| Qwindor's | 64 | 5 |
| Kard's and Searnla's | 25 | 0 |
| Leighann's | 16 | 10 |
| Elvellien's | 6 | 0 |
| Lang's | 6 | 0 |
| Per-NPC | 8 | 0 |

Drazik's set is organised by Achaean area: `annwyn`, `azdun`, `umbrin`,
`istarion`, `falaq'tor`, `dardanic grasslands`, `bitterfork`, `sparrows rest`,
`isle of prin`, `great hunt caves`, `moghedu`, `tir murann`, `ruins of
morindar` and 65 more. Five of those area folders are empty: `ashtan`,
`hashan`, `cyrene`, `eleusis` and `tsol'aa village`.

### `General defences` (109 triggers, 10 subfolders)

Ten class-specific defence sets, nine of them inactive and enabled by the
`setup` loader from `haveskillset`:
`Healing + Elementalism channels` (18), `Harmonics defences` (16),
`Spirituality defences` (14), `Propagation defences` (6), `Shindo defences`
(4), `Kaido defences` (4), `Groves defences` (3, the only active one),
`Occultism defences` (1), `Necromancy defences` (1), `Alchemy defences` (1).

### `Miscellaneous` (78 triggers, 6 subfolders)

Display and quality of life, not curing.

* `Highlights` (18) colours lines of interest.
* `Links To Click` (18) turns things into clickable links.
* `BoxDisplay` (15, plus a `Flags` subfolder of 7) is the large attention box,
  and includes the tumble and somersault timers.
* `Nice meteor stuff` (9).
* `Inline ASCII bars` (5) draws health and mana bars into the line.
* Loose triggers in the folder handle forest defence lines, gagging other
  people's breath messages, long-equilibrium actions, tab and backspace
  removal, `Common do next's`, and the `9multicmd` command separator.

### The per-skillset folders

Fifty-two folders, one per Achaean skillset, holding the class-specific attack
and defence lines. They follow one pattern: a trigger matches the attack, and
the body calls either `svo.valid.<something>` to record what the attack did, or
`svo.startedfighting("<class>", matches[2])` to tell the class manager who is
fighting you.

Four have their own subfolders: `Chivalry` (Malignity, Discipline, Valour,
Dominion), `Weaponmastery` (Dual Blunt, Two-handed, Sword and Shield, Dual
Cutting), `Weatherweaving` (Watersprout) and `Occultism` (Chaosrays hit).

### `svo (limbcounter)` triggers (71 in 16 folders)

One folder per class, and the limbcounter loader enables exactly one of them:

| Folder | Triggers | Active by default |
|---|---|---|
| `svo Monk limbcounter` | 36, in `Shikudo` (26) and `Tekura` (10) | no |
| `svo Knight limbcounter` | 17, in `Cutting`, `Sword and Shield`, `Blunt`, `Two handed` (with `Battlefury Focus`) | no |
| `svo Meta limbcounter` | 6 | **yes** |
| `svo Priest limbcounter` | 3 | no |
| `svo earth Elemental Lord limbcounter` | 2 | no |
| `svo Dragon limbcounter` | 2 | no |
| `svo Sylvan limbcounter` | 1 | no |
| `svo Magi limbcounter` | 1 | no |

Three classes have a fixed break count rather than a health-derived one, and
say so in their triggers: Earth Lords break at 5, Dragons break at 4. The
`Guesstimates` triggers in the other sets ship disabled with a comment telling
you to test and fill in your own counts for your weapon.

`Battlefury Focus` is a two-trigger folder that flips `svo.lc_checkdamage`
between speed and precision, which halves or doubles the damage each hit is
counted as.

### `svo (namedb)` triggers (65 in 5 folders)

* `Data Capture > Lists` (33) parses every list the game can print:
  `cwho`, `hwho`, citizens, house members, clan who, party who, order members,
  `qw` and `qw2`, friends, clan positions, city/house/order enemies, and
  birthdays. Each follows the same shape: a header trigger opens a capture
  with a long `fireLength`, a body trigger collects names, and a stop trigger
  closes it, merges into the database with `db:merge_unique`, and raises
  `NameDB got new data`.
* `Data Capture > Honors on a person` (22) parses an HONORS, one trigger per
  line type: age, XP rank, combat rank, city and rank, city soldier,
  housemate, might, divorces, arms, motto and warcry, marks, infamy, and the
  immortal markers.
* `Data Capture > Various common things` (6) catches new characters appearing:
  house newcomers, rebirths, and citizenship.
* `Scripting Examples` (4) ships inactive and is documentation. One trigger
  even says so in its body: "if you'd like to use this trigger, enable it and
  move it out of the NameDB folder - so your changes to it will stay".

The `qw 2` trigger is worth noting because it is a dispatcher: depending on
`ndb.qwtype` it will re-honors everyone, group by city, report a city's
citizens to a channel, show marks, or show infamous players.

### The 64 script-less triggers

Broken down:

* **48 are multiline containers** with children. Correct by design.
* **8 are highlight-only**, with `highlight: yes` and no script: `Angel drain`,
  the four `Chaosrays hit` colours, `KoTH flag`, `Parried` and
  `CTF flag planted`. Correct by design: colouring a line needs no code.
* **8 have neither a script nor a highlight**, so they match text and do
  nothing:

| Trigger | Pattern |
|---|---|
| `General > svo diag > blistered` | `suffering from horribly blistered skin.` |
| `General > Tree cures > svo humour blocked tree` | exactMatch |
| `Psionics > Transcendence full` | two regexes |
| `Psionics > Transcendence percent` | two regexes |
| `Psionics > Transcendence empty` | one regex |
| `Drazik's ... > annwyn > annwyn loki` | two exactMatches |
| `Drazik's ... > caverns of riagath > riagath stuns` | four exactMatches |
| `Drazik's ... > riparium > kraken blackout` | one exactMatch |

**All eight are empty in the 25 reference XMLs too.** This was checked
directly against `svo (aliases, triggers).xml`: each of the eight appears once,
and each has an empty `<script>` element. So these are pre-existing gaps in
svof, not losses introduced by the conversion.

The `blistered` one is the most consequential. `blistered` is a fully modelled
affliction: it has a dictionary entry at line 9,150 with `aff`, `gone` and
`waitingfor` handlers, so `svo.valid.diag('blistered')` would be accepted and
`svo.valid.simpleblistered` is generated from the entry, and it has a custom
prompt abbreviation (`blis`) in `@affs.lua`. Its diagnose trigger is the only
one of the 149 with no body, so a DIAGNOSE that reports blistered records
everything else and silently drops it. The fix is the one-line body
`svo.valid.diag('blistered')`.

The three Psionics `Transcendence` triggers are the other notable pair: they
capture what looks like a resource gauge and do nothing with it.

---

## File reference: `aliases/`

169 aliases in 24 folders, every one with a `.lua` file. All patterns are
regexes. 114 of them are in the main `svo (aliases, triggers) > svo` folder,
and the other 55 belong to addons (the addon table below adds up to 55).

### Main set: `svo (aliases, triggers) > svo`

**System.** `vshow` (basic info), `vversion`, `vhelp` (opens the docs),
`vsave`, `vupdate` and `vupdate prios`, `vinstall` and `vinstall fresh`,
`vlua <code>`, `vecho <text>` (feeds the text through the trigger engine with
`feedTriggers`, `$` as a line break: the testing hook). `vupdate
[force|checking]` calls `svo.checkforupdates(kind)` without `automatic`, so
it is never throttled. `vversion` still prints `conf.releasechannel`, the
retired GitHub Pages channel.

**Configuration.** `vconfig`, `vconfig2`, `vconfig_<option> [value]`,
`vconfigs` (calls `svo.aconfigs()`, which is empty), `vsetup sp` /
`vshow sp` (parry), `vsetup pc` / `vshow pc` (precache), `vsetup colours` /
`vshow colours`.

**Pausing and curing.** `pp [on|off]`, `dop [on|off]`, `hh [balance]`
(toggle sip priority), `shh` (health as main slow-curing priority),
`tsc [on|off]` (command override in slow curing).

**Toggles**, all of the form `xx [on|off]`: `cll` clot, `mss` moss, `trk`
health and mana change display, `ss` rebounding, `sl` selfishness, `br`
breath, `th` deaf, `va` riding, `med` meditation, `ts` shielding,
`sbites` single bites, `stabs` single stabs, `dil` dilation, `rfl` reflection
(Elementalism, inactive).

**Turn on and off.** `tn <thing>` and `tf <thing>` drive `tntf_tbl`.

**Diagnostics.** `dv` (diagnose asap), `df` (check defences asap), `diagnose`,
`def`.

**Display.** `vshow a|affs`, `vshow b|bals`, `vshow p|precache`,
`vshow cl|curelist`, `vshow d|defs`, `vshow defup`, `vshow k|keepup`,
`vshow h|hidelist`, `vshow ignore`, `vshow ignorelist`, `vshow afflist`,
`vshow do`, `vshow lustlist`, `vshow hoistlist`, `vshow watchfor`,
`vshow herbstat`, `vshow serverside`, `vlistprios`.

**Defence modes.** `vdefs [mode]`, `vdefs cancel`, `vdefup <def> [on|off]`,
`vkeepup <def> [on|off]`, `vcreate defmode <name>`,
`vrename defmode <old> <new>`, `vdelete defmode <name>`,
`vcopy defmode <a> TO <b>`.

**Priorities.** `vshowprios <balance>` (also `vp <balance>`),
`vset <action> <balance> <n>`, `vswap <a> <b> <balance> [n]`,
`vswapslow <a> <b>`, `vcleargaps <balance>`, `vexportprio <balance> [args]`,
`vimportprio [name]`.

**Parry.** `vp nextprio <limbs>`, `vp parrystrat [strategy]`, `vp show`,
`p<limb>` where limb is one of `n`, `h`, `tt`, `rl`, `ll`, `ra`, `la`.

**The `do` queue.** `do <cmd>`, `dofirst <cmd>`, `dofree <cmd>`,
`dofreefirst <cmd>` (also `dff`), `do<n> <cmd>`, `dofree<n> <cmd>`,
`dor [cmd]`, `undo [what]`, `undoall`, `undofree`, `undoallfree`.

**Afflictions and ignoring.** `vaff <name>`, `vrmaff <name>`,
`vignore <what>`, `vreset`, `vreseta`, `vresetb`, `vaeon`.

**Priority emergencies.** `pva` (paralysis and asthma), `avs` (slickness and
impatience), `pvd` (paralysis and darkshade). Each swaps a pair of priorities
in one keystroke.

**Rift and herbs.** `ir [herb|mineral]`, `inra` (rift everything riftable),
`vgeth` / `vget herbs`, `lp` (light all pipes).

**Lyre.** `lyr` on, `lyf` off, `lyc` cure and re-lyre.

**Movement and misc.** `b <dir>` and `ub` (block and unblock a direction),
`vault`/`mount`/`board <name>`, `sit`, `lie`, `sleep`, `fl` and `sfl`
(fullstats), `cc <text>` (relay to channel), `fx` and `fxx` (fix angel,
Spirituality, inactive), `makechat` (UI experiment).

* `sit` and `lie` put `prone` on ignore with the reason "you sat down" and
  raise `svo ignore changed`, clearing it after a second if you never went
  prone. `sleep` does the same for `sleep` without the event. The
  `svo.sitting` and `svo.sleeping` scripts remove the entries.
* `b <dir>` and `ub` drive the `block` defence through keepup unless `block`
  is ignored. `vault`, `mount` and `board` remember `ridingskill` and
  `ridingsteed`.
* `makechat` builds a Vyzor chat window and turns on channel capture (see
  `svo UI Experiments/`).
* The `ndb` cheatsheet alias loads `<installationfolder>/ndb-help.lua` with
  `loadstring("return " .. s)`.

### Addon aliases

| Addon | Aliases |
|---|---|
| `namedb` | 26: `whois`, `honours`, `ndb set/delete/export/import/stats/cancel/infamous`, `ndb honorsnew`, `ndb update all`, `ndb update unranked`, `ndb delete all/unranked/<name>`, `iff`, `qw`, `qw2`, `qw update`, `qwc`, `qwm`, `qwi`, `qwic`, `ppof`, `npp`, `vshow highlightignore`, `city/house/order enemies [add]`, `ndb [long]` |
| `peopletracker` | 5: `qwho` (with `m`, `g`, `w` variants), `gotop`, `ppwith`, `ppin`, `vshow watchfor` |
| `refiller` | 5: `compound`/`brew`, `refill next potion`, `putvials`, `getvials`, `givevials` |
| `priestreport` | 3: `tr <person>`, `seek <person>`, `vshow locatelist` |
| `elistsorter` | 3: `elist`/`vlist`, `dispose of decays by: <x>`, `vialsout` |
| `limbcounter` | 4: `nn [person]` (reset), `vsl` (status), `shn [person] <n>` (set hits needed), `kk` (sync hits) |
| `enchanter` | 2: `enchant <args>`, `reenchant` |
| `logger` | 2: `startlog`, `stoplog` |
| `stormhammertarget` | 2: `stm`, `ih` |
| `burncounter` | 1: `vsl` |
| `inker` | 1: `ink <what> on <where> [of <person>]` |
| `offering` | 1: `v(offer\|drop\|get\|defile\|sanctify\|give\|put) [target]` |

Note that `vsl` is defined twice, once in the limbcounter and once in the
burncounter. Neither alias is class-gated, so both fire for everyone:
`lc_show()` and `bl_show()` both print.

---

## File reference: `keys/`, `buttons/`, `resources/`

**`keys/`** holds exactly one key, `Toggle bashing`, in
`svo (aliases, triggers) > svo`. It is bound to keyCode 16777265 (Qt
`Key_F2`) with no modifier, and starts `svo.dor("kill <target>")` or turns
the repeating do off. The project brief records that a raw `keyCode` is one
of the five things upstream muddler cannot represent, which is part of why
the fork is required.

**`buttons/`** holds a toolbar, `svo`, which ships `isActive: no`, with one
button `Show affs` and a `Show prios` group of seven: `Herb`, `Focus`,
`Salve`, `Purgative`, `Sip`, `Balance` and `Slow curing mode`. They call
`svo.showaffs()`, `svo.printorder(<balance>)` and `svo.printordersync()`.
The manifests carry button-only fields (`isFlatButton`, `mButtonState`,
`posX`/`posY`, `sizeX`/`sizeY`, `useCustomLayout`, `buttonColumn`,
`buttonRotation`); several `sizeX`/`sizeY` values look uninitialised (for
example 121309952 and 470220885), carried over from the original export.

**`resources/`** holds two files, shipped to `<profile>/svof/`:

* **`default_prios`** (10,617 bytes, 466 lines) is the ten default priority
  lists, described in the mechanisms section. Header: version marker `--v01`,
  and a credit line, "Priorities list 'default' by Iakimen, exported @
  07/06/19 16:40:53". The `slowcuring` list has 211 entries with indices up
  to 240, leaving gaps.
* **`ndb-help.lua`** (10,008 bytes) is NameDB's help text: 43 entries, loaded
  as `return` plus the file's body.

The project brief records these as one of the things the conversion had to
fix: they used to sit beside the module XMLs, and in a package they were not
present at all until they were made resources.
---

## How the parts interact: three traces

The reference above lists the pieces. These three traces follow a single thing
all the way through, which is the only way the interactions become visible.

### Trace 1: an affliction arrives and is cured

**The line.** `You feel your limbs seize up with paralysis.`

**1. The trigger fires.** Five different triggers can produce paralysis, in
`Vodun & Puppetry`, `Shindo`, `Occultism`, `svo Bashing triggers` and
`Elvellien's` set. Each body is one line:

```lua
svo.valid.proper_paralysis()
```

**2. The handler decides how much to believe.**

```lua
function svo.valid.proper_paralysis()
  if not conf.aillusion or svo.ignore.checkparalysis then
    valid.simpleparalysis()
  elseif not affs.paralysis then
    svo.checkaction(svo.dict.checkparalysis.aff, true)
    lifevision.add(actions.checkparalysis_aff.p)
  end

  if conf.paused and conf.hinderpausecolour then
    selectCurrentLine() fg(conf.hinderpausecolour) resetFormat() deselect()
  end
end
```

Two paths. With anti-illusion off, it goes to `valid.simpleparalysis()` in
`Simple_aff_trigger_functions.lua`. That does **not** add the affliction
immediately: like every `simple<aff>`, it force-adds the `paralysis_aff`
action with `svo.checkaction(dict.paralysis.aff, true)` and files a
lifevision claim, which the prompt settles. "Simple" means no reasoning about
whether to believe the line, not a bypass of the ledger. With anti-illusion
on, it does not claim the affliction at all. It force-adds the
`checkparalysis` action with `svo.checkaction(..., true)` and files a
lifevision claim, which means "I saw something that says paralysis; settle
it at the prompt".

**3. The prompt arrives.** `General > Prompt > Do stuffs.` calls
`svo.onprompt()`, after the `Capture flags` filter has read balance and
equilibrium from the prompt.

**4. Lifevision settles.** `svo.lifevision.validate()` compares the paragraph
length against any lineguard. If it passes, `svo.actionfinished` runs the
claim, which calls `svo.dict.checkparalysis.aff.oncompleted()`:

```lua
oncompleted = function (withaff)
  if true then
    svo.addaffdict(svo.dict.paralysis)
    signals.after_lifevision_processing:unblock(cnrl.checkwarning)
    svo.killaction(svo.dict.checkparalysis.misc)
    if withaff then svo.addaffdict(svo.dict[withaff]) end
  end
end
```

Now `svo.affs.paralysis` is set, `svo.affl.paralysis` is set, `svo got aff` is
raised, and the lock-warning check is unblocked.

**5. The decision runs.** `svo.make_gnomes_work_async()` calls
`svo.check_herb()`. Paralysis is in `svo.affs`, so it is a candidate. Its
`isadvisable` is `return (affs.paralysis) or false`, which passes. It is not in
either ignore list. `sys.canoutr` is true or you are holding bloodroot. Its
`aspriority` goes into the `prios` table.

**6. The action goes out.** Assuming paralysis wins,
`svo.doaction(svo.dict.paralysis.herb)` arms a timeout, records `herb` as in
use, and calls `onstart`, which is
`svo.eat(svo.dict.paralysis.herb)`. `svo.eat` points at `sk.asynceat` (or
`sk.synceat` in slow curing), which `Rift.lua` regenerated for your current
`curemethod`, so it either outrifts and eats, or eats from inventory. The
cure list is `{'bloodroot', 'magnesium'}`.

**7. The cure lands.** The `General > Ate` multiline container matches, its
first child calls `valid.ate1()` (reset `svo.herb_cure`), and the child for
the specific result, `svo cured paralysis`, calls
`svo.valid.herb_cured_paralysis()`. That sets `svo.herb_cure`, checks the
`paralysis_herb` action is in flight (or that GMCP already removed paralysis,
see `sk.gmcp_cured`), and files a claim. At the **next** prompt the ledger
runs the action's completion:

```lua
oncompleted = function()
  svo.rmaff('paralysis')
  svo.lostbal_herb()
  svo.killaction(svo.dict.checkparalysis.misc)
end
```

`svo.rmaff` clears both tables, raises `svo lost aff`, and then calls
`svo.dict.paralysis.onremoved`, which clears the pending-paralysis flag and
calls `svo.donext()`, reopening the balance controller now that paralysis no
longer blocks it. `svo.lostbal_herb()` clears the herb balance and arms its
failsafe timer. The real restore is the game's herb-balance line later:
`valid.gotherb` claims `gotbalance.happened`, and the prompt after that sets
`bals.herb` and raises `svo got balance`.

**8. If the cure was empty.** The eat went through but no cure line matched,
so `svo.herb_cure` is still false when the container's later child calls
`valid.ate2()`. That files the action with the `empty` outcome, and at the
prompt `empty.eat_bloodroot()` runs: it spends herb balance and passes
paralysis and slickness to `presume_cured`, since a bloodroot that cured
nothing suggests you had neither. Outside blackout, each is removed unless
GMCP still reports it, so a paralysis the game still lists stays in
`svo.affs` and is cured again. During blackout nothing is removed.

**9. If nothing ever came back.** The timeout from step 6 fires, `sys.lagcount`
goes up, and if `sk.stupidity_count` was non-zero svof concludes you have
stupidity. Four timeouts before the next prompt print the lag warning and
raise `conf.lag` (see "The action system").

### Trace 2: anti-illusion probing

Seven of the eight `check*` dictionary entries work the same way, and the
pattern is worth naming because it is the system's most distinctive idea.

When a line claims an affliction that would be expensive to believe wrongly,
svof does not believe it and does not disbelieve it. It **sends a harmless
command whose response settles the question**:

| Entry | Probe | Question it answers |
|---|---|---|
| `checkslows` | `say` | am I slowed |
| `checkanorexia` | `eat something` | can I eat |
| `checkimpatience` | `focus` | can I focus |
| `checkasthma` | `hold breath`, then `smoke <valerian>` | can I breathe |
| `checkhypersomnia` | `insomnia` | am I asleep-prone |
| `checkstun` | `eat something` | am I stunned |
| `checkwrithes` | `outr` | am I restrained |

Each is a `misc` entry with `uncurable = true`, so the priority system never
tries to "cure" the check itself. Its `aff` entry carries
`notagameaff = true`, so serverside is never told about it.

`checkparalysis` is the eighth and is **switched off**, in two places, both
commented:

```lua
isadvisable = function()
  return false -- hardcoded to be off, as there's no known solution currently that works
```

```lua
oncompleted = function (withaff)
  -- disabled, as fling no longer works and illusions are not so prevalent
  if true then
```

The `if true then` keeps the original condition visible as dead code
underneath. So paralysis is accepted on sight rather than probed, and the
reason given is that the probe command (`fling paralysis`) no longer works.

### Trace 3: a priority change reaching the server

**The command.** `vset paralysis herb 3`

**1. The alias fires.** `Set an affliction priority`, pattern
`^vset (\w+) (\w+) (\d+)$`, and its body is
`svo.prio.insert(matches[2], matches[3], matches[4], true)`.

**2. No before-state is taken here.** The before-state is
`sk.priosbeforechange`, which the **previous** sync left behind (it is blank
at `svo system loaded` and after `vconfig serverside`).

**3. The list changes.** `prio.insert` shuffles the list itself and sets
`aspriority` (or `spriority` for `slowcuring`) on each moved action. It does
not call `prio.sortlist`.

**4. `svo prio changed` is raised once per moved action**, not once, and
`svo_events` routes each into the bracket signal. Its first listener arms the
`sk.priochangetimer` debounce (a `tempTimer(0)`), so many changes produce one
sync. Its second runs the moved action's `onprioswitch`, if it has one.

**5. `sk.updateserversideprios()` runs.** It refuses if you are logging in, if
no change timer is pending, or if `svo.systemloaded` is false. Otherwise it
takes the after-state, and for each balance diffs before against after with
`svo.basictableindexdiff`.

**6. Only differences are sent.** For each changed action,
`sk.sendpriorityswitch` looks up the new number, **caps it at 25**, checks
`sk.priochangecache` to see whether the server already has that value, and only
then sends. The name sent is `svo.dict[action].gamename` if the dictionary
defines one, otherwise the action name. The send goes through
`svo.sendcuringprio`, which batches into `sk.dosendprios` on its own
`tempTimer(0)`. After sending, the sync stores a fresh before-state for next
time.

**7. Nothing reports compression.** Everything past 25 is pooled at 25
silently. `sk.notifypriodiffs` is unrelated: it raises `svo prio changed`
for the bulk paths (`prio.import` and the runtime defence registrations). With
a 211-entry slow-curing list mapped onto 25 server priorities, collapsed
orderings are not a rare case, and you are not told about them.

Two caveats on this trace: the possible stuck `sk.priochangetimer` after
login (see `Serverside.lua`), and two `prio.insert` defects (see
`Priorities.lua`).

---

## Workflows

The traces follow one example each. This section describes every recurring
workflow as a sequence of calls, naming the file that owns each step. Most of
them end at the prompt, so read "The prompt cycle" first. Everything here was
read from `82e7f14` and brought forward to `6af80b3` (see the update note at
the top); none of it was observed in play.

### Startup

1. Mudlet loads the package. `Create_Svof_namespace.lua` creates `svo`,
   `svo.loader`, `ndb` and `svo.balanceless`, stubs `svo.autopause_on_def`
   and `svo.disable_seek`, and creates the `svo_prompt` buffer.
2. Every script body runs. Most only define `svo.loader.<name>`. The
   exceptions do real work now, before the core exists: the anonymous
   `svo system loaded` handlers for the `@mem`, `@exits`, `@affs`, `@target`
   and `@bl` tags and for `changelimbcount`, the enchanter's
   `gmcp.Char.Items.List` handler, NameDB's one-shot `ndb_load` handler, and
   `ndb.init()`, which opens the database.
3. `sysLoadEvent` (or `sysInstall`) reaches `svo_init_system`, and
   `svo.remove_legacy_modules`, which waits 3 seconds before looking for old
   modules.
4. `svo_init_system` checks its guards, clears `svo.signals`, and calls the
   22 loaders. What each contributes to the running system:
   * `setup`: the state tables, 65 signals, `conf` and `sys` defaults, the
     class from `my_class`, the class trigger groups, and the GMCP
     vitals, affliction, defence, room and login handlers.
   * `misc`: echo, `svo.events`/`svo.gevents` routing, weapon tracking.
   * `empty`, `dict`: the empty-cure functions, then the dictionary (the
     literal only when `svo.dict` is empty), `basicdef` entries, the reverse
     name maps, `dict_setup`, `dict_validate`, and the dictionary's signal
     connections.
   * `sk`: the balance checks, lifevision, the gnomes, and the
     `changecuring` handler, which it emits once so `svo.make_gnomes_work`
     points at the async gnome. It raises `svo balanceless ready` and
     `svo balanceful ready` on a `tempTimer(0)`.
   * `controllers`: `svo.onprompt`, the prompt pipeline, the command filters,
     disrupt inference, and lock warnings.
   * `action`: the action system (and the stale `make_gnomes_work` local).
   * `pipes`, `rift`: load `pipes/conf` and `rift+inv/`.
   * `diag`, `valid_simple`, `valid_main`: the trigger handlers. Many are
     generated in loops, the `simple<aff>` family from the dictionary as it
     stands when `valid_simple` runs; the diagnose, generic-cure and
     tree-cure handlers are single functions that take the name.
   * `config`: merge `config/conf` over the defaults, run the migrations,
     apply the load-time side effects.
   * `install`, `aliases`, `defences` (`defs_data`), `prio`, `parry`
     (`sp_config`), `funnies`, `dor`, `customprompt`, `serverside`.
5. It emits `systemstart`. Its listeners (15 in `Setup.lua` alone) include:
   `reset.bals`; the defence trigger generator and `defload`;
   `prio.import('current')`; the list and strategy loaders in `Setup.lua`;
   the 13 anti-illusion temp triggers; the `curemethodchanged` emit that
   builds `svo.eat` and its siblings; `sk.makewarnings`; `svo.updatevecho`;
   `sys.input_to_actions`; the `dragonform` emit that builds the defence
   shortlists; the do queue's `addbalanceful` and `addbalanceless`; the
   runtime defence registrations on a `tempTimer(0)`; and the generic-cure
   trigger reset.
6. It sets `svo.systemloaded` and raises `svo system loaded`. Listeners:
   serverside (blocks its sync connections when serverside is off, and takes
   a blank before-state), `svo_checkupdatestart`, `ndb.configs`,
   `ndb.loadsettings`, `svo.disable_seek`, the anonymous tag registrations,
   and, the first time only, `ndb_load`.
7. If GMCP already has `Char.Name` (installing while logged in), it emits
   `gmcpcharname` so the login work in the next workflow runs now. It echoes
   the version, calls the ten addon loaders, and sends a newline if
   `force_init` is set.

### Login

1. `sysConnectionEvent` (and `sysLoadEvent`) reach the two anonymous handlers
   Setup registered: `svo.logging_in = true`, then `changecuring`, which
   turns `svo.make_gnomes_work` into a no-op. The batching queue also refuses
   to flush while `logging_in`.
2. The `svo connect` trigger matches the Achaea banner: `svo.connected()`
   emits `connected` (pipes marks non-artefact pipes unlit), the system pauses
   unless it already was, and `svo.innews` is set.
3. GMCP `Char.Name` arrives and becomes `gmcpcharname`. Its listeners:
   `Controllers.lua` sets `sk.logged_in` and clears `svo.innews`;
   `Setup.lua` emits `enablegmcp`, which subscribes the GMCP modules, requests
   `IRE.Time`, and (post-emit) arms the 5-second "Password correct" trigger;
   `Miscellaneous_functions.lua` requests `Char.Items.Inv`; `reset.defs`
   clears defences that do not survive death; `sk.loginonbasic` switches to
   the `basic` mode without a defup (first login only); `svo.setupserverside`
   creates the two curingsets; `sk.setup9multicmd` defines the server alias;
   `cp.makefunction` compiles the custom prompt and sends the in-game prompt
   format; and `life.sayhello` schedules the greeting.
4. "Password correct. Welcome to Achaea." clears `svo.logging_in` and emits
   `changecuring`, so the gnomes work again. The first time it sets
   `sys.enabledgmcp`; on later logins it emits `relogin` and echoes "Welcome
   back!". It unpauses unless `svo.dont_unpause_login`.
5. `Char.Status` reaches `svo.classchange`. If the class differs from the one
   in `my_class`, the whole system reinitialises (next workflow).

The one known hazard here is the possible stuck `sk.priochangetimer`: a
serverside sync scheduled in step 3 and fired before step 4 is dropped and
never rescheduled (see `Serverside.lua`).

### Class change and dragonform

`svo.classchange` is described step by step in the file reference. What
matters for the rest of the system is what a reinit keeps and what it loses.

* **Rebuilt:** every signal, and every connection made inside a loader;
  `svo.dict` (emptied first so the literal rebuilds); `defs_data` and its
  temp triggers (the old ones are killed); the `balanceful` registry (empty,
  until its users register again); `conf` (defaults, then the file that the
  pre-change `saveconfig` just wrote).
* **Kept:** `svo.balanceless` and its hooks; the fields of `svo.bals`,
  including gated balances from the old class; general defences in
  `svo.defc`, granted again with `defences.got`.
* **Duplicated:** the 13 anti-illusion and six metamorphosis temp triggers,
  the runtime defences' temp triggers, and Setup's two anonymous login
  handlers. Each reinit adds another set.
* **Lost:** every `connect` made at script-body time, which in practice
  means everything NameDB's one-shot `ndb_load` connected: its three
  `saveconfig` writers and its own `namedb finished honors` signal.
* **Throttled:** the update check, which `svo system loaded` would otherwise
  run on every dragonform.

### Gaining an affliction

There are six ways in. The first four go through the lifevision ledger; the
GMCP paths do not, because GMCP cannot be faked by another player.

1. **A plain affliction line.** The trigger calls `valid.simple<aff>()` or
   `valid.proper_<aff>()`. Either force-adds `dict.<aff>.aff` with
   `checkaction(..., true)` and files a claim. At the prompt the ledger runs
   `aff.oncompleted`, which calls `svo.addaffdict`: `svo.affs[name]` and
   `svo.affl[name]` are set, `svogotaff` is emitted and `svo got aff` raised.
2. **A line worth doubting.** With anti-illusion on, `proper_<aff>` claims a
   `check<aff>` probe instead. Its `aff.oncompleted` accepts the affliction at
   once if `svo.paragraph_length > 2`, and otherwise only sets
   `svo.affsp[aff]`. The probe's `misc` action then becomes advisable, sends
   its harmless command, and the reply selects a named outcome that confirms
   the affliction, or `onclear`.
3. **A symptom.** A line that implies an affliction without naming it calls
   `sk.<aff>_symptom()`, which counts sightings in a decaying window and adds
   the affliction at its threshold. Eight symptom checkers stand down under
   serverside.
4. **An unknown affliction.** `simpleunknownany` and `simpleunknownmental`
   count what svof cannot name. When `unknownany` reaches `conf.unknownany`
   or `unknownmental` reaches `conf.unknownfocus`, `diag.physical` becomes
   advisable and svof sends DIAGNOSE. `diagnose_end` then files a claim for
   every affliction the game lists that svof did not have.
5. **GMCP `Char.Afflictions.Add`.** `gmcpcharafflictionsadd` translates the
   game's name through `svo.dict.sstosvoa`, calls `svo.addaffdict` directly,
   copies the level into the count, and runs `sk.checkaeony()` and
   `changecuring`.
6. **GMCP `Char.Afflictions.List`.** A full resync: it adds anything missing
   through the public `svo.addaff` (which runs `aff.oncompleted`) and removes
   anything tracked that the game did not list. Two entries with a broken
   `oncompleted` abort this resync (see the dictionary defects).

During blackout the game sends no `Char.Afflictions` messages at all (the
`svof-blackout-stops-gmcp` memory has the evidence), so only the text paths
can report anything, and svof falls back on assumptions such as
`blackout.aff`'s. The public `svo.addaff` also unblocks `cnrl.checkwarning`,
reruns `sk.checkaeony()`, emits `changecuring` and runs `codepaste.badaeon()`,
which is what makes an affliction that causes aeon switch to slow curing at
once.

### Curing an affliction

1. **Choose.** At the prompt a gnome runs the balance checks. The best
   advisable action for a balance goes to `svo.doaction`.
2. **Send.** `doaction` records the action, arms its timeout, and runs
   `onstart`: `svo.eat`, `svo.sip`, `svo.apply`, a smoke, or a focus. The
   command goes out through `send` or the batching queue.
3. **Answer.** The game's reply lands in a cure container (`Ate`, `Sip`,
   `Applied salve`, `Apply elixir`, `Focus`, `Smoke`, or `Tree cures`):
   * The first child resets the container's cure flag.
   * A specific cure line calls its handler (`herb_cured_<aff>` and so on),
     which sets the flag and claims its own action. If a **different** action
     on the same cure was in flight, it kills that one and claims the right
     one (the cross-cure).
   * A failure line selects a named outcome: `fizzled`, `offbalance`,
     `noeffect`, `mickey`, and others.
   * If no cure line matched, the later child finds the flag still false and
     files the action with the `empty` outcome (the next workflow).
   * If nothing comes back at all, the timeout fires (lag and stupidity
     inference).
4. **Settle.** At the next prompt the ledger runs the claim. A cure's
   `oncompleted` calls `svo.rmaff` (clearing `affl`, raising `svo lost aff`,
   clearing `affs`, running `onremoved`) and `svo.lostbal_<balance>()`.
5. **Recover.** The game's balance line later calls `valid.got<bal>`, which
   claims `gotbalance.happened`. The prompt after that sets the balance and
   raises `svo got balance`. The `lostbal_` failsafe timer covers a missed
   line.

**GMCP usually gets there first.** `Char.Afflictions.Remove` arrives before
the cure text. Its handler clears `gaffl`, sets `sk.gmcp_cured[name]`, and
calls `svo.rmaff`. When the text handler runs, `affs[name]` is already nil,
and the `sk.gmcp_cured` clause is what stops it treating the genuine cure as
an illusion, so the action still completes and the balance is still spent.
`sk.gmcp_cured` is cleared at the next prompt.

**Variations.** Restoration salves complete in two stages (the heal line
arrives later, see the dictionary's recurring patterns). Tree's timer
restores the balance unconditionally, whichever of it and the game's line
comes first. Passive cures and
cures during blackout arrive through the `General cures` triggers and
`svo.valid.generic`, which `check_generics` switches on.

### Empty cure

An "empty" cure is one that went through and cured nothing, which proves you
had none of the afflictions it can cure.

1. The container's first child (`ate1`, `sip1`, `apply1`, `smoke1`, `tree1`,
   `applyelixir1` or `focus1`) sets `svo.herb_cure` (or its sibling) to
   false.
2. Any specific cure handler that matches sets it to true.
3. The container's later child (`ate2` and siblings) sees it still false and
   files the in-flight action with the `empty` outcome. `ate2` also rejects a
   result faster than half the ping, and widens the lineguard for
   addiction, swellskin or a serverside `[CURING]` line.
4. At the prompt the ledger runs the handler's `empty`, usually an
   `svo.empty.*` function: spend the balance, and hand every affliction that
   cure would have cured, except those `madness` protects, to
   `presume_cured`.
5. `presume_cured` removes nothing during blackout. Otherwise it removes each
   name unless `svo.gaffl` shows the game still reports it, looked up through
   `svo.dict.svotossa`. A name GMCP cannot report is removed, as before.
6. `empty.tree` (and its aliases for dragonheal and shrugging) also zeroes
   the `unknownmental` and `unknownany` counts.

Eight handlers skip step 5 and remove directly with `svo.rmaff`, because
each also resets a count: `apply_mending`, the two `noeffect_mending_*`, the
four `apply_health_*` and `eat_ginger`. Some `empty` outcomes in the
dictionary also remove afflictions themselves and so bypass the gate, for
example `latched`'s `sip.empty` and the rage action's `misc.empty` (inlove,
justice, generosity, pacifism and peace).

### Balance bookkeeping

svof tracks balance in three separate places, and most confusion comes from
treating them as one:

* **`svo.bals[name]`**: does the game say you have it? Set false by
  `svo.lostbal_<name>()`, set true at the prompt by the
  `gotbalance.happened` claim, or by the prompt flags for balance and
  equilibrium, or by GMCP vitals for `anathema` and `wrathbal`.
* **`svo.bals_in_use[name]`**: has svof already spent it on something in
  flight? Set by `doaction`, cleared when the action finishes, is cleared,
  or times out. `svo.usingbal(name)` reads it.
* **The balance controller's tick**: has anything balanceful been done this
  balance cycle? `sys.balanceid` against `sys.balancetick`, bumped by
  `svo.donext()`, `svo.gotbalance()`, `svo.goteq()`,
  `svo.gotarmbalance()`, and the action timeout.

How a balance moves:

1. **Lost.** A cure's `oncompleted` calls `svo.lostbal_<name>()`, which clears
   `bals.<name>`, raises `svo lost balance`, and arms a failsafe timer. A
   `used<bal>balance` line claims `stolebalance.happened`, which does the same
   at the prompt. For balance and equilibrium, `Capture flags` clears them on
   each prompt and `Do stuffs.` raises the events.
2. **Regained.** The game's regain line calls `valid.got<bal>()` (herb and
   salve reject one that arrives impossibly fast). The claim settles at the
   prompt: `bals.<name> = true`, `svo got balance`, the balance stopwatch
   ends. If no line comes, the failsafe timer restores it, but only if
   nothing else has.
3. **After an illusion.** The paragraph's claims are thrown away, but any
   consumable balance they spent (herb, salve, sip, smoke, moss, purgative)
   is still lost, because an illusion cannot un-eat a herb.
4. **Inferred.** Five seconds without equilibrium after losing it, outside a
   long-equilibrium action, adds `disrupt`.

### Illusion defences

svof layers its defences against faked lines. In the order a line meets them:

1. **Pre-parse anti-illusion** triggers, switched on with `conf.aillusion`.
2. **Class gating**: the Vodun and Puppetry triggers reject a line unless
   class management has that class enabled.
3. **No force-add**: under anti-illusion `checkaction` does not invent an
   action for a line svof did not ask for, so the handler has nothing to
   claim and the line is dropped.
4. **Timing**: `ate2`, `gotherb`, `gotsalve` and others reject results faster
   than physically possible.
5. **Probes**: the `check*` actions and their harmless commands.
6. **Permanent anti-illusion temp triggers**: 13 lines such as "you have
   nothing to eat" that contradict a claimed state.
7. **The lineguard**: at the prompt, a paragraph longer than the tightest
   lineguard any claim set is an illusion, marked `(i)`, and its claims are
   cleared.
8. **Prompt checks**: `aiprompt` hooks, such as `ate1`'s check that GMCP
   really removed an item.
9. **Warnings** go through the ledger too, so an illusion cannot fake one.

GMCP is not checked at all. It is trusted, and the reconcilers apply it
directly.

### Slow curing (aeon and retardation)

1. The public add and remove paths, the GMCP reconciler and a diagnose all
   run `sk.checkaeony()` after changing afflictions. With aeon or
   retardation it sets `sys.sync`, forces command echo, emits `sync`,
   unblocks `cnrl.processcommand`, and kills in-flight actions except the
   probes it needs. With `conf.autotsc` it sets `blockcommands` off for
   retardation and on for aeon.
2. The caller emits `changecuring`. `svo.make_gnomes_work` becomes the sync
   gnome, `svo.eat` becomes `sk.synceat`, and `svo.fillpipe` becomes
   `sk.syncfill`. Serverside's `sync` handler switches the server to the
   `slowcuring` curingset.
3. At each prompt the sync gnome does nothing while an action is in flight,
   and otherwise does the single candidate with the highest `spriority`.
4. What you type passes `cnrl.processcommand`. With `blockcommands` it is
   denied while svof is acting; without, it counts as an override and sets
   `svo.sacid`, which holds the gnome off for a moment.
5. Retardation ends when a command gets no "sluggish" reply in time; aeon
   ends when it is cured. `checkaeony` reverses step 1 and the caller emits
   `changecuring` again.

The prompt shows the `(a)` marker throughout: green while you override, red
while svof is acting, blue while idle. Beware the stale gnome binding in
`Action_system.lua`, which runs the async gnome on some slow-curing kicks.

### Defences

* **Gained or lost by text.** A generated temp trigger calls
  `defs.got_<name>` or `defs.lost_<name>`. If the dictionary has an entry,
  the handler claims its action and the prompt runs `oncompleted`, which
  calls `defences.got`; otherwise it calls `defences.got` or
  `defences.lost` directly. Either way `svo got def` or `svo lost def` is
  raised.
* **Gained or lost by GMCP.** `Char.Defences.Add` and `Remove` translate
  through `sstosvod` and call `defs.got_<name>(true)` (finish at once,
  no ledger) or `defs.lost_<name>()`. `Char.Defences.List` removes tracked
  defences it does not list, but only those in `svo.dict.svotossd`, the
  ones the server knows by name.
* **Checked with `DEF`.** `svo.adf()` runs `defcheck.physical`, which sends
  `def`. `defs.defstart` claims it and clears parry state. Each line calls
  `defs.def_<name>`, which records it and deletes the line. `defs.defline`
  files `defcheck_physical`. At the prompt `svo.process_defs()` removes every
  defence not listed, adds every listed one you lacked, and `defs.defprompt`
  prints the result.
* **Raised with a defup.** `defs.switch(mode)` sets the mode and
  `sys.deffing`, raises `svo switched defence mode` and
  `svo started defup`, and runs the gnomes. Every defence action's
  `isadvisable` checks `(sys.deffing and defdefup[mode][def]) or
  (conf.keepup and defkeepup[mode][def])`, and the balance checks consider
  the defence shortlists only while deffing or with keepup on. After each
  prompt `svo.defupfinish()` asks `sk.have_defup_defs()` what is still
  missing, and when nothing is, clears `sys.deffing`, raises
  `svo done defup` and emits `donedefup`.
* **Kept up.** The same `isadvisable` test with keepup on means a defence
  that drops is raised again at the next opportunity. Serverside mirrors
  keepup as `defences on` or `off`.

### Serverside sync

1. Something changes a priority or what svof hands to the server:
   `prio.insert` or `prio.import` (`svo prio changed`), an ignore or
   serverignore edit, a keepup change, a mode switch, or the end of a defup.
2. The listener arms `sk.priochangetimer`, a `tempTimer(0)`, if none is
   pending, so a burst of changes becomes one sync.
3. `sk.updateserversideprios()` takes the after-state, splits each balance
   into afflictions, kept defences and the two disabled lists
   (`sk.splitdefs`, `sk.splitbals` for slow curing), and diffs against
   `sk.priosbeforechange`.
4. For each difference, `sk.sendpriorityswitch` caps the number at 25,
   checks `sk.priochangecache`, and queues `curing priority ...` through
   `svo.sendcuringprio`. Disabled entries get `sk.sendpriorityignore` (26, or
   `reset` for a defence).
5. `sk.dosendprios` sends the batches, at most four a second, and the sync
   stores the new before-state.

Separately, the configuration mirrors send `curing` settings whenever the
matching option changes, and `svo.setupserverside()` recreates the two
curingsets at every login.

### Changing a setting

1. `vconfig <option> <value>` calls `svo.config.set`, which validates the
   value by type (`check`, `min`/`max`, yes and no words) and runs the
   option's `onset`, `onenabled` or `ondisabled`.
2. On the next turn it raises `svo config changed`, which `svo_events` routes
   into the bracket signal. Serverside's 15 listeners mirror the relevant
   settings to the server.
3. If the installer is running, it moves to the next question. The gnomes
   run, so the change takes effect at once.
4. The value reaches disk only at the next `saveconfig`.

`tn` and `tf` go through `svo.tntf_set`, which raises the event immediately.

### Saving and persistence

`saveconfig` is emitted by `vsave`, at the end of an install, before an
update, on class change, on uninstall, and as a pre-emit of `quit`. `quit`
is emitted by `svo.QQ`, which runs on `qq` and `quit` (through
`processusercommand`) and on `sysExitEvent` (through `svo.savesettings`).
`quit` also raises `svo quit`, which stows your vials.

Everything lives under the profile directory:

| Path | Written by | Holds |
|---|---|---|
| `svo/config/conf` | `Config_system.lua` | `conf` |
| `svo/config/my_class` | `Setup.lua` | class and Monk path |
| `svo/config/lustlist`, `hoistlist`, `ignore`, `locatelist`, `watchfor` | `Setup.lua` | the named lists |
| `svo/config/tree`, `fitness`, `rage`, `restore`, `dragonheal`, `shrugging` | `Setup.lua` | which strategies are disabled |
| `svo/config/serverignore`, `cadmusaffs`, `prefercustom` | `Setup.lua` | serverside split, cadmus list, custom cure list |
| `svo/config/sp_config` | `Parry.lua` | parry strategy and levels |
| `svo/config/svo.es_potions`, `svo.es_knownstuff` | elistsorter | potion totals and known vials |
| `svo/config/highlightignore` | NameDB | names never highlighted |
| `svo/defup+keepup/defup`, `keepup`, `ignored_defences`, `offline_defences` | `Defences.lua` | defence modes |
| `svo/prios/current` (and exported lists) | `Priorities.lua` | priorities |
| `svo/pipes/conf` | `Pipes.lua` | pipe ids and state |
| `svo/rift+inv/rift`, `inv`, `precachedata` | `Rift.lua` | rift, inventory, precache per mode |
| `svo/namedb/citypolitics` | NameDB | city relations |
| `Database_namedb.db` (Mudlet's `db`) | NameDB | the player database |
| `svof/default_prios`, `svof/ndb-help.lua` | the package | read-only shipped resources |
| `svof-update.mpackage` | the updater | a download in progress |
| `log/svof.txt`, `svolog.html` | logging, the HTML logger | logs |

The `svo/` tree is the user's and survives reinstalling; `svof/` is replaced
with the package.

### Updating

See `Check for system updates/` in the file reference for the full sequence
from `svo system loaded` to the restart prompt.

### Signal map

Who emits and who listens, generated from every `emit`, `connect`,
`add_pre_emit` and `add_post_emit` call in `src/` outside `3rdparty/`. A
signal with no emitter listed is fed by `svo.events` (a Mudlet event) or
`svo.gevents` (a GMCP message). Counts above one are shown.

| Signal | Emitted by | Listened to by |
|---|---|---|
| `systemstart` | `svo_init_system` | Setup 15 (+1 post), Defences 4, Dictionary 2, Dor 2, Alias_functions, Curing_skeleton (+1 post), Custom_prompt, Main_trigger_functions, Miscellaneous_functions, Priorities, Rift (+1 post) |
| `before_prompt_processing` | `svo.onprompt` | Main_trigger_functions 5, svo_limbcounter 3, Curing_skeleton, Miscellaneous_functions |
| `after_lifevision_processing` | `send_in_the_gnomes` | Controllers, Curing_skeleton, Parry |
| `after_prompt_processing` | `svo.onprompt` | Controllers 3, Serverside 2, burncounter |
| `changecuring` | Setup 6, Dictionary 6, Curing_skeleton 4, Alias_functions 3, Rift 2, Diag | Curing_skeleton (gnome binding), Rift 2 (`svo.eat`, `svo.fillpipe`) |
| `curemethodchanged` | Config_system, Rift | Rift 4, Curing_skeleton |
| `dragonform` | Dictionary 6, Config_system 6, Defences 4 | Dictionary (+ Setup post-emit) |
| `saveconfig` | Alias_functions, Install_system, Setup, the updater, `svo.classchange`, `svo.uninstall_all_modules` | Setup 13, NameDB 3, elistsorter 2, Config_system, Defences, Parry, Pipes, Rift (+ Priorities pre-emit, Setup post-emit) |
| `quit` | `svo.QQ` | Setup, Peopletracker (+ Setup 2 pre-emits: `saveconfig`, `svo quit`) |
| `gmcpcharname` | GMCP, `svo_init_system` | Setup, Controllers, Miscellaneous_functions, Alias_functions, Curing_skeleton, Custom_prompt, Defences, Funnies, Serverside |
| `charname` | Mudlet `CharName` | Alias_functions, Curing_skeleton, Defences, Funnies, Serverside |
| `enablegmcp` | Setup | Miscellaneous_functions, Rift (+ Setup post-emit) |
| `relogin` | Setup | Defences 2 |
| `connected` | Main_trigger_functions | Pipes |
| `gmcpcharvitals` | GMCP | Setup 12, Controllers |
| `gmcpcharstatus` | GMCP (twice per message) | Controllers, Dictionary |
| `gmcpcharafflictionsadd`, `gmcpcharafflictionsremove`, `gmcpcharafflictionslist` | GMCP | Setup (the reconciler) |
| `gmcpchardefencesadd`, `gmcpchardefencesremove`, `gmcpchardefenceslist` | GMCP | Setup (the reconciler) |
| `gmcpcharitemslist` | GMCP | Curing_skeleton 3, Defences 4, Install_system, Miscellaneous_functions, Setup |
| `gmcpcharitemsadd` | GMCP | Setup, Defences |
| `gmcpcharitemsupdate` | GMCP | Setup, Defences, Miscellaneous_functions |
| `gmcpcharitemsremove` | GMCP | Setup, Defences, Miscellaneous_functions, Curing_skeleton |
| `gmcpcharskillsinfo`, `gmcpcharskillslist` | GMCP | Install_system |
| `gmcpiretimelist`, `gmcpiretimeupdate` | GMCP | Setup |
| `gmcproominfo` | GMCP | Config_system 2, Setup |
| `roombrief` | Mudlet `RoomBrief` | Setup |
| `newroom` | Setup 2 | Dictionary 4, Config_system, Curing_skeleton |
| `newarea` | Setup | Peopletracker 2 |
| `anyroom` | Setup 2 | nothing |
| `svogotaff` | Curing_skeleton | Serverside 2, Parry, Setup |
| `svolostaff` | Curing_skeleton | Parry |
| `curedwith_focus` | Action_system 2 | Dictionary |
| `limbhit` | Main_trigger_functions | Main_trigger_functions |
| `canoutr` | Dictionary 24, Main_trigger_functions 5, Alias_functions, Setup | Setup |
| `changed_maxhealth`, `changed_maxmana` | Config_system, Controllers | Controllers, Setup |
| `orgchanged` | Config_system 3 | Miscellaneous_functions (+ Curing_skeleton post-emit) |
| `morphskillchanged` | Config_system | Curing_skeleton |
| `removed_from_rift` | Rift | Main_trigger_functions |
| `donedefup` | Defences | Dictionary |
| `sync` | Setup 2 | Serverside |
| `sysdatasendrequest` | Mudlet `sysDataSendRequest` | Controllers 2 (the two command filters) |
| `sysexitevent` | Mudlet `sysExitEvent` | Peopletracker |
| `elistcaptured` | elistsorter | elistsorter |
| `namedb finished honors` | Mudlet event | NameDB (first bus only) |
| the twelve bracket signals | their Mudlet events | Serverside 29 (15 of them on `svo config changed`), Controllers 3 (`svo got balance`, `svo lost balance`), NameDB 1 (`svo config changed`, first bus only), Peopletracker (`mmapper updated pdb`). `svo defup changed` has no listener |

### Mudlet event registrations

41 script items register Mudlet events in their manifests. These are the
entry points from Mudlet into svof:

| Item | Events |
|---|---|
| `svo_events` | the 19 listed under "Signals versus Mudlet events" |
| `svo_gevents` | `gmcp.Char`, `gmcp.Room`, `gmcp.Char.Status`, `gmcp.IRE.Time` |
| `svo_init_system`, `svo.remove_legacy_modules` | `sysLoadEvent`, `sysInstall` |
| `svo.classchange` | `gmcp.Char.Status` |
| `svo.uninstall_all_modules` | `sysUninstallPackage` |
| `svo.savesettings` | `sysExitEvent` |
| the updater: `svo.update_http_done`, `update_http_error`, `update_download_done`, `update_download_error` | `sysGetHttpDone`, `sysGetHttpError`, `sysDownloadDone`, `sysDownloadError` |
| `svo_checkupdatestart` | `svo system loaded` |
| `svo.registerhit`, `ndb.setfromclass` | `svo got hit by` |
| `svo_show_classes`, `ndb.onshow`, `svo_onshow_priestreport` | `svo onshow` |
| `svo_autoslickprio` | `svo got balance`, `svo got aff`, `svo lost aff` |
| `svo_onimportant_aff` | `svo got aff` |
| `svo.autopause_on_def` | `svo got def`, `svo lost def` |
| `svo.sitting`, `svo.sleeping` | `svo lost aff` |
| `commandTracker` | `sysDataSendRequest` |
| `svo_captureChats` | `gmcp.Comm.Channel.Start` |
| `svo.put_vials_away` | `svo quit` |
| `svo.corpse_stuff` | `gmcp.Char.Items.List` |
| `svo.disable_seek` | `svo got dragonform`, `svo lost dragonform`, `svo system loaded` |
| `svo.rf_check_trans` | `gmcp.Char.Skills` |
| `ndb.finished_honors` | `NameDB finished honors` |
| `ndb.updatebyhonors` | `NameDB got new data` |
| `ndb.downloaded_file` | `sysDownloadDone` |
| `ndb.configs`, `ndb.loadsettings` | `svo system loaded` |
| `ndb.close` | `sysExitEvent` |
| `ndb.showqwi` | `NameDB finished all honors` |
| `ndb.addhighlightname` | `NameDB finished honors`, `svo watchfor name changed`, `NameDB highlightignore name changed`, `NameDB set name changed`, `NameDB saw list name`, `NameDB name deleted` |
| the five `Examples` (inactive) | `svo system loaded`, `svo got aff`, `svo lost aff`, `svo got def`, `svo lost def`, `svo done with prompt` |

Several svof events make a round trip. The prompt trigger raises
`svo lost balance`; Mudlet delivers it to `svo_events`, which emits the
bracket signal, where the disrupt inference listens. `svo.setignore` raises
`svo ignore changed`, which comes back the same way to serverside. That is
why those twelve signals carry the Mudlet event names.

---

## Extension points

If you are adding to svof, these are the seams it was built with.

**Adding an affliction** is the one the system is worst at, and the dictionary
file's own header is the checklist (quoted under "The action dictionary").
Since `6af80b3` it takes fewer edits: the dictionary entry, which also
produces `svo.valid.simple<name>`; its triggers, which name the affliction
themselves when they call `svo.valid.diag`, `svo.valid.generic` or
`svo.valid.tree_cured`; the empty-cure lists in `Empty_cure_handling.lua`;
the cure-line lists in `Main_trigger_functions.lua`; and `sstosvoa` if GMCP
reports it. For a name in the dictionary but not in `sstosvoa`, svof ignores
what GMCP says about it, and the empty-cure gate cannot keep it; `earworm`
was in that position until `6af80b3`. The project brief names collapsing this into the
dictionary alone as the deferred goal that motivated the whole conversion.

**Writing an empty-cure handler:** call `svo.presume_cured(list)` rather than
`svo.rmaff(list)`, so an affliction the game still reports is kept and
nothing is removed during blackout.

**Adding a configuration option** is clean: call
`svo.config.setoption(name, spec)` from inside a loader. Addons do this rather
than touching `config_dict`. The spec is the same shape as a `config_dict`
entry.

**Adding a prompt tag** is clean: `cp.adddefinition(tag, func)`. The tokeniser
picks up longest-match-first, so a new tag cannot break an existing one by
being a prefix of it.

**Reacting to svof** from your own script: register on the Mudlet events, not
the signals. `svo got aff`, `svo lost aff`, `svo got def`, `svo lost def`,
`svo got balance`, `svo lost balance` and `svo done with prompt` are the
useful ones, and `svo (core)/Examples/svo_example_affs.lua` is the template
(it ships inactive, like all five examples). A handler connected to a signal
from outside a loader is dropped on the first class change.

**Doing something when you have balance:** `svo.addbalanceful(name, f)` or
`svo.addbalanceless(name, f)`, the way the do queue and the enchanter do.
Register on `svo balanceful ready` and `svo balanceless ready`, and register
the balanceful one again after every class change, because `balanceful` is
rebuilt empty on each `sk` load. A balanceful function returns truthy when it
used balance, and calls `svo.donext()` when its action finishes.

**Doing something once at the next prompt:** `svo.prompttrigger(name, func)`.

**Queueing commands:** `svo.doadd`, `svo.doaddfree` and friends in
`Dor.lua`. A queued string can be an alias.

**Deferring until svof is up:** register on `svo system loaded`. Not
`tempTimer(0, ...)`, which was sufficient under the 25-module layout and is not
in a single package.

**Adding a trigger:** put one call in the body and the logic in a script. The
existing tree has 2,410 bodies averaging 67 bytes; anything much larger than
that is out of keeping and, more practically, is code you cannot reach from
anywhere else.

---

## Findings

Everything here was checked individually rather than inferred from a pattern.
Where a comparison against the 25 reference XMLs settles whether something is
pre-existing or introduced, that comparison was run.

### Verified structural facts

* All 3,073 files in `src/` are accounted for. Every `.lua` file in all five
  trees is reachable from a manifest, and every manifest entry that should
  have a script has one, except the cases listed below.
* 2,307 triggers in the main tree. The project brief cites 2,317, which
  was right at `82e7f14`; the 10 triggers removed since account for the
  difference.
* The `svo.dict` literal holds 267 entries, and the dictionary as a whole holds
  579 definitions over 542 distinct names across three construction sites, of
  which 287 are defences. `svo.dict_setup` derives their names, balances and
  priorities rather than requiring them to be written by hand.
* The configuration holds 106 base options plus up to 23 skillset-conditional
  ones.
* The default priority lists hold 422 entries across ten balances, of which
  211 are the single slow-curing list.
* 28 of the 32 loaders are hot-reloadable. `setup` correctly is not.
  `enchanter`, `fishdist` and `mindnet` appear to be omissions.

### Eight triggers that match text and do nothing

Listed in full in the trigger section. All eight are equally empty in the 25
reference XMLs, checked directly, so **none of them is a conversion loss**.
They are pre-existing gaps in svof.

The one worth acting on is `General > svo diag > blistered`. `blistered` is a
fully modelled affliction with a dictionary entry, a generated
`svo.valid.simpleblistered` handler and a custom prompt abbreviation, and
`svo.valid.diag('blistered')` would accept it. Its diagnose trigger is the
only one of 149 with no body. The fix is that one line in one file.

The three Psionics `Transcendence` triggers capture what looks like a resource
gauge and discard it. The remaining four are in inactive bashing groups or are
single tree-cure lines.

### Empty groups

Ten trigger folders and three script folders declare a directory that muddler
does not create, because they have no children. All ten trigger folders were
checked against `svo (aliases, triggers).xml` and all ten are empty groups
there too. This is not a defect. It is worth writing down only because any
tool that walks the manifests and the filesystem together will report them, and
they are easy to mistake for missing files.

### Disabled by design

Several things ship switched off and say so in a comment. These are worth
knowing before assuming something is broken:

* `checkparalysis` is hardcoded off, because `fling paralysis` no longer works.
  The original condition is preserved underneath an `if true then`.
* `General > General cures` (97 triggers) ships inactive and is switched on by
  `svo.check_generics` only during blackout or a passive-cure paragraph.
* `svo Bashing triggers` (541 triggers) ships inactive.
* Nine of the ten `General defences` subfolders ship inactive and are enabled
  by the `setup` loader from `haveskillset`.
* All five `svo (core)/Examples` scripts and the `svo` button toolbar ship
  inactive.
* Every limbcounter class group except `svo Meta limbcounter` ships inactive;
  the loader enables the right one on every class change.
* The `Guesstimates` triggers ship disabled with a comment telling you to
  measure and fill in your own break counts.
* `svo (fishdist)`, `qwho (svo people tracker)` and NameDB's
  `Scripting Examples` ship inactive.

### Duplicate definitions

* `string.ordinalSuffix` is defined twice, in `svo_Utilities.lua` and in
  NameDB's `Ordinal.lua`. Load order decides which survives.
* The `vsl` alias exists in both the limbcounter and the burncounter. Neither
  is class-gated, so both fire and both print.
* `svo.valid.relapsing_oculus` is defined twice in
  `Main_trigger_functions.lua` (1308 and 1313); the second wins.
* `svo.defs.got_dragonform` is a function at line 289 and is replaced at 894
  by `svo.dict.waitingfordragonform.waitingfor.oncompleted`.

(`svo.reenchant` only looks duplicated: the first copy is inside a comment.)

None of these is currently causing a visible problem beyond the double `vsl`
output. They are the kind of thing that starts causing one when load order
changes, which in a single package it can.

### Two defects in the public removal API

Both are in `Curing_skeleton.lua`, both have **no caller anywhere in `src/`**,
so they are reachable only from a user's own script, and both are
**pre-existing**: the identical text is in
`svo (curing skeleton, controllers, action system).xml` at 1373 and 1400.

**`svo.removeaff` recurses into itself forever.**

```lua
  if affs[which] then
    if svo.dict[which].gone then
      svo.dict[which].gone.oncompleted()
    else
      svo.removeaff(which)     -- calls itself; nothing has changed
    end
```

Nothing between the two calls alters `affs[which]` or `svo.dict[which].gone`,
so the else arm is an unbounded self-call ending in a stack overflow. It is
reachable for the eight entries carrying `aff` with no `gone`, which are
exactly the `check*` predictions, and which are exactly what the assert above
the branch admits. It was almost certainly meant to be `svo.rmaff(which)`.

`svo.removeafflevel`, twenty lines below, shows where it came from: it is the
same function with one branch changed, and *its* else arm calls
`svo.removeaff`, where that is a different function and the fallback makes
sense. One was copied from the other and the call was never retargeted.

**`svo.removeafflevel` nil-calls on 174 of 189 entries.** Its gone arm is
`svo.dict[which].gone.general_cure(amount or 1, not keep)`, but only 15 of the
189 `gone` sub-tables define `general_cure`: the four humours, `crackedribs`,
`crescendo`, `horror`, `pressure`, `pyre`, `skullfractures`, `torntendons`,
`wristfractures` and the three `unweaving*`. Its assert only checks that the
name is a known affliction, so it admits all 180 and raises on everything that
is not levelled. Loud rather than silent, so less dangerous than the first, but
the guard tests the wrong property.

Both want the static dictionary check the project's backlog already proposes
for `rmaff` naming, widened to cover every removal path. One check would cover
these two, the `mindravaged` mis-naming, and the dead `asleep` guards.

### Trigger bodies that call handlers nothing defines

Found in the 2026-09-25 review. Loop-generated handler names cannot be found
by grep, so they were read back at runtime: `Main_trigger_functions`,
`Simple_aff_trigger_functions`, `Diag_trigger_functions`, `Defences` and
`Controllers` were loaded under a permissive stub (real Penlight,
`haveskillset` true for every skillset, the `systemstart` callbacks run
once), giving 1,056 `svo.valid` and 999 `svo.defs` names. Those, plus every
statically defined name, were compared with every `svo.valid.X(` and
`svo.defs.X(` call in trigger, alias, key and button bodies (847 and 108
names called). **At `82e7f14`, 24 call targets were defined nowhere.** Each
appears in the reference xmls only at its call site, so all are
pre-existing. Mudlet raises "attempt to call a nil value" when the line
fires. A wider pass over every `svo.<name>(` call in item bodies (157 names)
found one more, `svo.lc_damagecheck`.

**At `6af80b3`, 10 of the 24 remain**, plus `svo.lc_damagecheck`. The other
14 are gone:

* Fixed (8): `diag_calcifiedskull`, `diag_calcifiedtorso` and `diag_latched`
  (DIAGNOSE records them, `2f00a3a`, then `svo.valid.diag`); `simplelatched`
  and `generic_latched` (`a707668`, then the inversions); `tree_cured_latched`
  and `tree_cured_paralysis` (resolved by `svo.valid.tree_cured`);
  `simpletinderskin` (the typo, `976a8ff`).
* Removed with their triggers (6): `latched_woreoff` (`a707668`), and
  `healercure`, `emptyheal`, `nohealbalance`, `bedevilheal` and
  `healing_cured_insomnia` (the seven Healing triggers, `e5339e6`).

| Called | Fired by | Why it is missing |
|---|---|---|
| `valid.focus_cured_weakness` | `Focus > svo cured weakness` (an inline script) | the focus list lacks weakness |
| `valid.curedconcussion` | `svo cure concussion` (General, active) | no handler (see the concussion memory) |
| `valid.simpleconcussion` | `Sculpting > Calcified Skull Concussion` | no dictionary entry named `concussion`, so the simple family has no handler |
| `defs.curedblind` | `Tree cures > svo cured blind tree` (active), generic | no handler |
| `defs.cureddeaf` | `General cures > svo cured deaf` | no handler |
| `valid.sour_sparkle` | `General cures > svo sour sparkle` | no handler |
| `defs.got_spirit`, `got_boundspirit`, `got_fortifiedspirit` | `Healing + Elementalism channels > Spirit` | the Spirit channel was Healing's |
| `valid.simplecheckwrithes` | two Qwindor bashing triggers (inactive) | `checkwrithes` is a probe, excluded from the simple family by `no_simple_handler` |
| `svo.lc_damagecheck` | `svo Priest limbcounter > Fragility` (enabled for Priests) | no handler |

**What the gates see.** `tools/check_valid_callsites.py` (from `976a8ff`)
resolves every generator loop and the dictionary-derived simple family, and
checks every `svo.valid.X(` call in trigger and alias `.lua` files against
them. Its record, `tools/known_unresolved_valid.json`, holds five call sites
over four names at `6af80b3`. Three things are outside its reach:

* **Inline manifest scripts.** It reads `.lua` files only, so the 64 inline
  trigger scripts are unchecked. That is why `focus_cured_weakness`, an
  unresolved call on an active trigger, is not in its record.
* **`svo.defs` calls**, including the `defs.*` rows above.
* **Names passed as arguments.** It resolves `svo.valid.diag`, `generic` and
  `tree_cured` as defined functions and never looks at the string they are
  given. A wrong name is reported only at runtime, by each handler's own
  `svo.errorf` guard, and only if the name has no dictionary entry at all.
  A name that exists but means something else passes both. The next section
  is two such calls.

`check_renamed_callsites.py` still checks item names only.

### Two call sites the handler inversion broke

**Introduced on `gmcp-gated-empty-cures`, not pre-existing.** `d2160f6`
rewrote each `General cures` trigger from `svo.valid.generic_<name>()` to
`svo.valid.generic('<name>')`. Two of those triggers did not call a member of
the generated family. They called hand-written functions whose names only
share the `generic_` prefix, and the rewrite changed what they do:

| Trigger (`General > General cures`) | Line | Before `d2160f6` | Now |
|---|---|---|---|
| `svo cure burn` | "The fires consuming you diminish somewhat." | `svo.valid.generic_burn()`: claims `ablaze_gone` with `generic_reducelevel`, stepping the burn ladder down one rung | `svo.valid.generic('burn')`: `svo.dict.burn` does not exist, so it reports "a generic-cure trigger names "burn"" and does nothing |
| `svo got insomnia` | "You suddenly feel incapable of falling asleep." | `svo.valid.generic_insomnia()`: completes an in-flight insomnia herb or skill action, and nothing else | `svo.valid.generic('insomnia')`: runs the generic body on the insomnia **defence** entry (below) |

The insomnia case is the worse one, because the guard passes: `insomnia` has
a dictionary entry. In a passive-cure paragraph the generic body claims
`insomnia.gone`, whose `oncompleted` calls `defences.lost('insomnia')`, on
the line that says you just gained it. Outside one, it completes an insomnia
action if one is in flight, as before. If none is, it takes the first
in-flight action on a balance the insomnia entry also has (`herb`, `misc` or
`gone`), kills it, and files the insomnia handler for that balance instead:
an unrelated herb cure in flight during blackout is killed and never
completes. Both triggers are active, but they sit in `General cures`, which
ships inactive and is on only while `check_generics` enables it, that is,
during blackout or a passive-cure paragraph. Read from the code, not
observed.

`valid.generic_burn` and `svo.valid.generic_insomnia` were left with no
callers. **Fixed in `a73e7e5`**, which restores both trigger bodies to their
2018 originals; `single-source-groundwork` (#854) on its own still carries
both. No gate
caught either: the call-site gate sees `svo.valid.generic` as defined,
`verify_merged.py` accepted both as two of the 167 one-line script
differences in its baseline, and the handler's guard fires for `burn` only
at runtime.

### Defect index

Every defect this document describes, grouped by effect, with the section
that explains it. All but the first group were compared with the reference
xmls and are **pre-existing**: none was introduced by the conversion. None
has been observed in play.

**Introduced after `82e7f14`, on `gmcp-gated-empty-cures`:**

* `General cures > svo cure burn` calls `svo.valid.generic('burn')`, which
  refuses the name, so a passive or blackout burn reduction is no longer
  credited; `svo got insomnia` calls `svo.valid.generic('insomnia')`, which
  can mark the insomnia defence lost or kill an unrelated in-flight cure
  (the two call sites the handler inversion broke). Fixed in `a73e7e5`,
  after the commit this document describes.

**Raises an error when reached:**

* The 10 remaining undefined trigger call targets and `svo.lc_damagecheck`
  (see "Trigger bodies that call handlers nothing defines").
* `unweavingbody` and `crescendo` call `svo.addaffdict(dict.X)`; a GMCP
  affliction list containing either aborts the resync (dictionary).
* `valid.update_break`, `valid.litpipe`, `valid.empty_light`,
  `valid.vodun_throttle` (`Main_trigger_functions.lua`).
* `valid.usedwrathbalbalance` names `'anathema'`: repeats on every vitals
  update for an excision user (`Alias_functions.lua`).
* `aria.physical.onstart` calls `svo.apply` on a missing handler
  (dictionary).
* `prio.insert` for an empty slowcuring slot or an action not in the list
  (`Priorities.lua`).
* `svo.removeaff` recurses forever; `svo.removeafflevel` nil-calls on 174 of
  189 entries (earlier in these findings).
* limbcounter: `lc_smash`, the second `lc_priestdamage` call, `lc_countshow`
  for Infernal and Paladin; burncounter: `bl_ignore`; inker:
  `ti_interrupted` with `autoreink` off; the offering trigger's
  `disableTriger` (the addons).
* An apostrophe or backslash in `conf.customprompt` blanks the prompt
  (`Custom_prompt.lua`).

**Wrong behaviour, silently:**

* NameDB's one-shot `ndb_load`: after the first class change its settings
  stop saving, and city politics revert (the addons).
* `ndb.loadhighlights` stops the garbage collector when highlighting is
  paused (NameDB).
* The stale `make_gnomes_work` local runs the async gnome in slow curing
  (`Action_system.lua`).
* The luanotify name-replacement desync can remove the wrong handler after a
  hot reload (the signal bus).
* A serverside sync scheduled during login can leave `sk.priochangetimer`
  stuck (`Serverside.lua`); possible, not verified.
* Every class change duplicates 13 anti-illusion temp triggers (19 with
  metamorphosis), the runtime defences' triggers, and two anonymous login
  handlers (class change).
* `sk.increase_lagconf` works once per Mudlet session (`Curing_skeleton.lua`).
* `dict_validate`'s sync half tests the wrong variable; `fortifiedair`'s
  `fortifiedwaterand` typo; `bonding`'s nested `gone`; `oncuredleft` never
  called (dictionary).
* The `relogin` handler clears nothing (masked by `reset.defs`); the
  inventory scanners' location guard; the phylactery double space; the
  shroud's missed Blood Maiden line; `lipread`, `rest.off`,
  `boosting.onenable`, and two `<fix me>` placeholders (`Defences.lua`).
* `valid.got_blind` tests `defs.blind`; the `asleep` guards;
  `proper_crippledleftleg` records the right leg; the duplicate
  `relapsing_oculus` (trigger functions).
* `prio_makefirst`'s unreachable no-balance path; `prio_slowswap`'s false
  error (`Controllers.lua`).
* `sp.setup` updates only the local parry config (`Parry.lua`); pipes from
  empty slots always read unlit (`Pipes.lua`); `checkinvgmcp` scans every
  list and `vinstall fresh` cannot delete the folder (`Install_system.lua`).
* `shipmode` is not wired at load; `morphskill` is never asked again; the
  `weapon` option's display never updates (`Config_system.lua`).
* priestreport forces two options on every load; refiller reads only one
  Transcendent skill; limbcounter's missing Blademaster and None groups,
  Shikudo case mismatch, `get_other_prepped`, `lc_lasthit` global and
  `larmdamage`; burncounter's stale `svo.bl_list` (the addons).
* `svo.undo()` with no argument removes nothing; `svo.doshow` reads a field
  nothing sets (`Dor.lua`).
* The arena `svo config changed` argument has a stray backtick
  (`Curing_skeleton.lua`).
* The generic-cure swap leaves `Applied salve` and `Focus` on during
  blackout, through the unresolved names `'Applied'` and `"Focus mind"`
  (trigger functions).
* Trigger patterns that can never match (`tonguetied`, `Hammerfist`,
  `Transcendence empty`, the last `svo lost prayer` regex), `multimatches`
  read by non-multiline `Judgement` triggers, `Palmstrike`'s `"Monk"`,
  the `Unread messages` stop name, `fishdist`'s `lineout`, NameDB's
  `Infamous` nil guard, and the `Symptoms` arm triggers' typo (the trigger
  reference).

**Harmless or dead:**

* `CharVitals` and `RoomNum` on `svo_events` resolve to no signal;
  `svo defup changed` has no listener; `svo.newbals`, `svo.sync_time`,
  `svo.tic_time`, `svo.aconfigs`, `empty.smoke_pear`, `svo.test`, and
  `defences.gettime`, `urlify`, `complete_def` and `get_def_list` have no
  callers.
* `Char.Status` reaches `svo_gevents` twice per message, by inference from
  the registrations.
* `ndb.getinfo` still downloads each honoured name from the Achaea API,
  although the comment beside the disabled call says Achaea disallowed
  website scraping. Worth a decision rather than a fix.

### Trigger bodies with other small defects

These were found while reading the flattened trigger dump and are listed in
full here because the trigger reference only summarises them:

* `Symptoms > Full, injured, or restrained arms` tests
  `affs.unwknowncrippledarm` (typo) and, like `Damaged arms`,
  `missingleftarm` and `missingrightarm`, which svof never sets.
* `Prayer balance > svo lost prayer`'s last regex has `(w\+)` and
  `incleansing`, so it never matches.
* `Vodun & Puppetry > tonguetied` has a regex written as `exactMatch`;
  `Tekura > Hammerfist` starts `^(|w+)`; `Psionics > Transcendence empty`
  ends `$ - 0`.
* `Zeal > Judgement two` and `three` read `multimatches`, which only AND
  triggers fill.
* `Links To Click > Unread messages (old) > Stop` closes `"Unread messages"`,
  not the real name (the fire length of 100 closes it anyway).
* `General > prompt` (which resets `Focus`) ships inactive and has been dead
  since the fire-length fix, per its own comment.

### What the comments record

The conversion's own scar tissue is preserved in comments, and the four worth
reading before touching anything are:

1. **`Curing_skeleton.lua`, `consumable_balances`.** Discarding an illusion
   paragraph used to discard the balance bookkeeping with it, so svof believed
   it still had the balance and re-sent the cure on the very next prompt, fast
   enough to outrun GMCP item tracking and fail the same check again. It fed
   itself and did not recover.
2. **`svo_count_show.lua`.** Registering a config option at script-body time
   worked by accident under 25 modules and never works in one package. The
   conversion turned an intermittent loss into a permanent one.
3. **`Check_for_updates.lua`, `update_response_is_ours`.** Mudlet reports the
   final URL after redirects, GitHub 301s the releases API when a repository
   is renamed, so an exact URL comparison left the in-flight flag set forever
   and silently killed every later update check.
4. **`Main_trigger_functions.lua`, the `sk.gmcp_cured` check.** GMCP is
   processed before the text it accompanies, so without this check every
   genuine herb cure looks like an illusion.

### What has not been established

This document describes what the code does when read. It does not establish
that svof cures or tracks correctly in play. Nothing here was observed
running. The project brief's position stands: structural correctness against
the originals and syntax under real Lua 5.1 are verified, behaviour under real
play is not.
