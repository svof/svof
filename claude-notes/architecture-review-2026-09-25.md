# Architecture review, 2026-09-25

Working notes for a full re-read of `src/` at `82e7f14`, checking
`reference/svof-src-architecture.md` claim by claim and collecting the
function-interaction detail it lacks. The worktree used is a detached checkout
of `82e7f14` in the session scratchpad, so `gmcp-gated-empty-cures` was never
touched.

Status key: **OK** confirmed, **WRONG** contradicted by the source, **GAP**
true but incomplete, **NEW** not in the document.

Line numbers are for `82e7f14`.

---

## Load and init (`svo (core)/Load & init/`, `Create_Svof_namespace.lua`)

- **OK** `svo_init_system` guards: `systemloaded`, Penlight, 22 required via
  `table.n_complement`, `mudletOlderThan(3,20)` (loud, and also bails if the
  function is absent). Order of the 22 and the 10 addons is exact.
- **OK** after `raiseEvent("svo system loaded")`: `gmcpcharname:emit()` if
  `gmcp.Char.Name` exists, version echo with homepage link, addon loop,
  `force_init` newline.
- **NEW, and it changes the signal section.** `svo_init_system` sets
  `svo.signals = nil` (line 74) *before* any loader runs, and every line of
  `Setup.lua` is inside `svo.loader.setup = function()` (line 10 to 2067). So
  every init, including every class change, builds a brand new bus: all 65
  Setup signals are new objects, whatever their spelling. The `X = X or new()`
  guard never has anything to find on this path. The document's "the other 53
  survive" is wrong. What matters is not the spelling but **where a connection
  is made**: a `connect` inside a loader is remade on reinit, a `connect` at
  script-body time (outside any loader) is attached to the old bus and is lost
  on the first class change. Tracked per file below.
- **NEW** `svo.classchange` runs on `gmcp.Char.Status` (every Status message,
  not only class changes). The defc stash loop runs before the class test and
  deletes any `defc` entry with no `defs_data` record on every Status message.
  When the class does change: `gettingfullstats = false`, kill
  `svo.defencetemptriggers`, set `me.class`, `saveconfig:emit()` (on the OLD
  bus, so the save handlers of the old class run), `sk.resetserversideprios()`,
  `svo.dict = {}`, `systemloaded = false`, `svo_init_system()`, re-`got` the
  stashed general defences, echo, and `svo.app("off")` unless paused.
- **OK** `uninstall_all_modules`: name gate, `systemloaded = nil`, pcall'd
  saveconfig.
- **OK** `Create_Svof_namespace.lua` content (10 lines with no trailing newline;
  `wc -l` says 9).

## `Setup.lua` (loader `setup`, 2,066 lines)

- **OK** 65 `luanotify.signal.new()` calls: 53 dotted plus 12 bracket.
  **GAP** `morphskillchanged` (line 970) exists only for metamorphosis, so a
  non-morph class has 64.
- **WRONG** "`svo.defs_data` ... built in Setup". It is `Defences.lua:57`.
- **WRONG** "`svo.phpTable` ... is what lets priority lists mix positional and
  numbered entries." It is an insertion-ordered table used in exactly one
  place, `defences.nodef_list` (`Defences.lua:49` and `3582`).
- **WRONG** "`svo.assert` reports through svof's echo rather than raising." It
  calls `extra(msg)` when a third argument is passed and otherwise
  `error(msg)`. It raises.
- **WRONG (minor)** `svo.tablesave(t, path)`; the signature is
  `(sfile, t)`, path first. It is a patched copy of Mudlet's `table.save`.
- **GAP** Setup's function list omits `svo.haveskillset` (line 380), which is
  defined here from a precomputed `available_skills` set built from
  `knownskills[me.class:lower()]` at loader time.
- **GAP** `parseaffname` splits GMCP's `"name (n)"` into `name, n`.
  `me.getitem(name)` searches `me.inventory`, which the four
  `gmcpcharitems*` handlers maintain for `location == 'inv'` only.
- **GAP** `sk.checkaeony` does more than set `sys.sync`: on entry it saves and
  forces `conf.commandecho = true`, emits `signals.sync`, unblocks
  `cnrl.processcommand` on `sysdatasendrequest`, kills every in-flight action
  except `waitingfor`/`aff`/`gone` balances and `aeon_smoke`,
  `checkslows_misc`, `touchtree_misc`, and with `conf.autotsc` sets
  `blockcommands` off for retardation and on for aeon. Exit reverses echo,
  sync, and the block. It does **not** emit `changecuring` itself; callers do.
- **WRONG (trigger section)** "The inactive balance folders are class-specific.
  They are switched on by the class management system ... the same mechanism
  `svo.enableclass` uses." They are switched by the `setup` loader itself,
  lines 1263 to 1404, from `haveskillset`: Shindo/Kaido/Spirituality/
  Propagation/Necromancy/Occultism/Alchemy/Groves/Harmonics defences, Monk,
  Hydra (class == Druid), Voice, Prayer, Fitness, Rage, Humour, Word,
  Domination entities, Shrugging balances, Two-hander recover footing,
  Elementalism channels, Age tracking, plus the Elementalism and Spirituality
  alias groups.

### What Setup wires, which the document does not describe

- **GMCP vitals parsing.** `gmcpcharvitals` handlers read `charstats`:
  `Rage:` to `stats.battlerage`, and **`Bleed: N` drives the bleeding
  affliction**: 0 calls `svo.rmaff('bleeding')`, otherwise
  `svo.dict.bleeding.aff.oncompleted(N)`. Class-gated handlers add
  `Sunlight`, `Morph` (calls `sk.clearmorphs` and `defences.got(morph)`),
  `Stance`/`Form` (sets `me.path` tekura or shikudo and flips
  `sk.ignored_defences`), `Essence`, `Momentum`, `epitaph_length`,
  `Manifestation`, `Karma`, `Wrath`, and the GMCP-driven `Anathema` and
  `wrathbal` balances (call `valid.gotanathemabalance` and friends).
- **GMCP affliction reconciler** (lines 633 to 785), the #846 to #848 work:
  Add resolves through `svo.dict.sstosvoa`, calls `svo.addaffdict` (internal
  path), copies the level into `dict[name].count` and `updateaffcount`, then
  `checkaeony` plus `changecuring`. Remove clears `gaffl`, decrements
  `unknownany` only for a real untracked affliction, sets
  `sk.gmcp_cured[name]` and queues its reset on the next prompt, `rmaff`s, and
  zeroes a levelled count. List rebuilds `gaffl`, `addaff`s (public path)
  anything missing, and `rmaff`s anything tracked that the game did not list,
  gated on `svo.dict.svotossa`.
- **GMCP defence reconciler.** Add, Remove and List translate through
  `svo.dict.sstosvod` and call `svo.defs['got_'..name](true)` or
  `svo.defs['lost_'..name]()`; List removes only names in
  `svo.dict.svotossd`.
- **Room.** `gmcproominfo` sets `me.is_underwater`, emits `newroom` on a room
  number change, `anyroom` always, `newarea` on an area change. The ATCP
  `roombrief` path does the same for `newroom`/`anyroom`.
- **Login.** `enablegmcp` post-emit arms a 5-second
  `tempBeginOfLineTrigger("Password correct. Welcome to Achaea.")` that clears
  `svo.logging_in` and emits `changecuring`; first time sets
  `sys.enabledgmcp`, later emits `relogin` and echoes "Welcome back!";
  unpauses unless `svo.dont_unpause_login`. Two anonymous handlers on
  `sysLoadEvent` and `sysConnectionEvent` set `svo.logging_in = true` and emit
  `changecuring`. **They are registered inside the loader**, so every class
  change registers two more; the old ones keep emitting on the old bus.
- **Max health and mana.** `changed_maxhealth`/`changed_maxmana` echo the
  change (skipped when the traceback contains `Alias`) and, when both rise in
  one paragraph, a `prompttrigger("check stain expiring")` removes `stain`.
- **`systemstart` handlers**: 13 permanent anti-illusion temp triggers
  (`saidnothing`, `nothingtowield` twice, `nothingtoeat`, `lungsokay`,
  `symp_webbed`, `symp_roped` twice, `weakbreath`, `symp_impaled` twice,
  `webeslow`, `symp_transfixed`), the 10-second duplicate-install check, and
  loaders for `lustlist`, `hoistlist`, `ignore` (**then forces
  `svo.ignore.checkparalysis = true`**), `locatelist`, `watchfor`, `tree`,
  `fitness`, `rage`, `restore`, `dragonheal`, `serverignore`, `cadmusaffs`,
  `prefercustom`, and `shrugging`, all under `<home>/svo/config/`, each with a
  matching `saveconfig` writer. The serverignore/cadmus/prefercustom loader
  also calls `svo.setup_default_serverignore()`.
- **NEW, a leak.** The 13 `systemstart` temp triggers and the six
  metamorphosis temp triggers at lines 1576 to 1622 are never stored or
  killed. Each init creates a fresh set, so after N class changes (dragonform
  counts) each of those lines fires its handler N+1 times.
- **Class file.** `me.class` and `me.path` persist in
  `<home>/svo/config/my_class`; with no file the class defaults to
  `'Infernal'`.
- **`conf` defaults** (lines 998 to 1125) apply only when
  `not svo.systemloaded`, which is true on every class change too.
- **`sys` defaults** always: `sync false`, `balanceid 0`, `balancetick 1`,
  `lagcount 0`, `lagcountmax 3`, `actiontimeout 3`, `canoutr true`, the
  in-game `CONFIG PROMPT CUSTOM` string (with `*k` for weaponmastery),
  `input_to_actions`, `last_used`.
- `sk.*tick` counters, `sk.priochangecache = {special = {}}`, the serverside
  batch queue (`sendqueue`, `sendqueuel = 18`, max command 2048), and
  `svo.send = _G.send`.
- `svo.es_categories`, `svo.es_shortnames(r)` and default `es_potions` are
  built here, not in the elistsorter.
- `sk.arena_areas`, the 38 arena area names.

## `Miscellaneous_functions.lua` (loader `misc`)

- **NEW, the real reason for the 12 bracket signals.** `svo.events(event,
  ...)` is `signals[event:lower()]:emit(...)` when that signal exists. So the
  19 events on `svo_events` resolve by lowercased name: `sysDataSendRequest`
  to `sysdatasendrequest`, `sysExitEvent` to `sysexitevent`, `CharName` to
  `charname`, `RoomBrief` to `roombrief`, the 12 bracket names to themselves,
  and `NameDB finished honors` to `svo.signals["namedb finished honors"]`.
  **`CharVitals` and `RoomNum` resolve to nothing**: there is no `charvitals`
  or `roomnum` signal, so those two registrations are dead (ATCP leftovers).
  The bracket signals exist so a Mudlet event can be turned into an internal
  signal; that is why they carry the event names exactly.
- **NEW** `svo.gevents(_, key)` strips dots and lowercases the GMCP key:
  `gmcp.Char.Afflictions.Add` becomes `gmcpcharafflictionsadd`. Unknown keys
  are ignored. This is the only path from GMCP into svof.
- **WRONG** "`svo.update()` is the update entry point". `svo.update(t1, t2)`
  is a recursive table merge of `t2` into `t1`, used by every config loader.
  The update check is `svo.checkforupdates`.
- **WRONG** "`echos` is the scheme and `echosd` its darker variant."
  `echosd.X()` returns the scheme's default text colour tag; it is what
  `svo.getDefaultColor` points at.
- **GAP** `svo.updatevecho` picks `echos[conf.echotype] or echos[conf.org]`
  and sets `svo.vecho`, `svo.getDefaultColor`, `svo.getDefaultColorNums`; it
  runs at `systemstart` and on `orgchanged`. `svo.updateloggingconfig` builds
  `svo.debugf` for `conf.log` off, file (Mudlet `Logger`), or echo.
  `svo.echof` routes to a named window when the first argument is a bare
  word. `svo.snd` splits on `$` and double-sends under seriousconcussion or
  `doubledo` plus stupidity.
- **GAP** `svo.fancysend(what, store)`: with `conf.batch` it calls
  `svo.sendc` and records the command in `sk.systemscommands`, otherwise the
  saved original `send`; it repeats for seriousconcussion or
  doubledo+stupidity (unless `sys.sendonceonly`) and `conf.repeatcmd` times,
  and remembers the command for `svo.fancysendall` to echo as `(a|b|c)` at the
  end of the prompt.
- **Weapon tracking.** `gmcpcharname` sends `Char.Items.Inv` and a newline.
  `gmcpcharitemslist`, `update`, `remove` maintain `me.wielded[id]` with a
  `hand` field from the `l`/`L` attribute and raise `svo me.wielded updated`.
  An involuntary unwield calls `svo.unwielded`, which queues the item in
  `sk.rewielddables` and, with `conf.autorewield`, connects `sk.checkrewield`
  to `before_prompt_processing`. A GMCP re-wield completes the `rewield`
  action through `checkaction` plus `lifevision.add`.
- `enablegmcp` subscribes to `IRE.Time` and requests it.
- `svo.setignore`, `unsetignore`, `setserverignore`, `unsetserverignore`
  write the table and raise the matching `svo ... changed` event, which
  `svo_events` routes back into the bracket signal of the same name.
- `find_until_last_paragraph` and `count_until_last_paragraph` scan
  `getLines(lastpromptnumber, last line)`. Whether lifevision uses them is
  checked under `Curing_skeleton.lua`.
- `svo.test = 5` is a leftover.

## `Empty_cure_handling.lua` (loader `empty`)

- **GAP** the function list misses the generated
  `empty.eat_<herb>` for goldenseal, kelp, lobelia, ginseng, ash, pear,
  bellwort and bloodroot (lines 21 to 43). Each calls `svo.lostbal_herb()`
  and removes that herb's affliction list, skipping the madness-blocked set
  while `madness` is held. `eat_bloodroot` is then redefined at line 47 to
  remove paralysis and slickness.
- **GAP** `empty.dragonheal` and `empty.shrugging` are aliases of
  `empty.tree`, which also zeroes the `unknownmental` and `unknownany`
  counts. Exported lists: `svo.degenerateaffs`, `svo.deteriorateaffs`,
  `svo.focuscurables`, `svo.treecurables`; `empty.treeblocks` says madness
  and hypothermia block tree for their listed afflictions.
  `svo.gettreeableaffs(getall)` applies those blocks and, without `getall`,
  keeps only held afflictions.
- Whether every `empty.*` is referenced from a dictionary `empty` field is
  checked under the dictionary.

## `Dor.lua` (loader `dor`)

- **WRONG** "`me.dofreequeue` for commands that do not [need balance]".
  `svo.check_dofree` refuses unless balance, equilibrium and both arm
  balances are all held, same as `check_do`. The difference is how they are
  scheduled: at `systemstart`, `check_do` is registered with
  `svo.addbalanceful("svo check do")` and runs **one** queued item per
  balance; `check_dofree` is registered with
  `svo.addbalanceless("svo check dofree")` and runs **every** queued item at
  once without being the balance-consuming action.
- **GAP** queued strings are split on `$` and run through `expandAlias`, so
  a queue entry can be an alias. A queued function is `pcall`ed.
- **GAP** `svo.donext()` bumps `sys.balancetick`, kills
  `sys.actiontimeoutid`, and reruns the gnomes (unless called from a
  trigger). It is the "my balanceful action is done" signal that re-opens the
  balance controller's once-per-tick guard.
- **GAP** every queue mutation calls `svo.make_gnomes_work()` unless the
  traceback contains `Trigger`, so typing `do x` acts immediately.
- **NEW, pre-existing?** `svo.undo()` with no argument echoes "Removed ..."
  but never removes anything (lines 198 to 205). `svo.doshow` reads
  `me.dorepeat`, which nothing sets; the flag is `me.doqueue.repeating`.
  Classification against the XML pending.

## `Funnies.lua` (loader `funnies`)

- **GAP** on `charname` and `gmcpcharname`, `life.sayhello` waits 2 to 7
  seconds, arms temp triggers for the game's time-of-day lines, and sends
  `time raw`; `svo.lifep.sayhello` gags that output with `deleteAllP`, greets
  by time of day, and 2 to 5 seconds later prints a random entry from
  `svo.protips` (about 95, plus class-gated extras).

## `Action_system.lua` (loader `action`)

- **OK** the timeout formula, the three tables, the `completed` closure, the
  `pcall(onstart)` and `(e!)` link, the stopwatch, `checkaction`'s force-add,
  `checkany`, `findbybal(s)`, `will_take_balance` aliased as
  `codepaste.balanceful_codepaste`, `usingbal`/`usingbalance`,
  `doingaction`/`doing`, `haveorwill`, `valid_sync_action`, and the shared
  "put `actions_performed` back" block in four functions.
- **GAP** `svo.actions` itself is the third table: a Penlight `OrderedMap`
  from `act.name` to `{timerid, completed, p}`. A force-added entry from
  `checkaction` has no timer.
- **GAP** the timeout path is gated: `ontimeout`, the stupidity inference and
  the gnome kick only run while `sys.lagcount < sys.lagcountmax + 1` (4). At
  exactly 4, and not paused, it echoes the lag warning and calls
  `sk.increase_lagconf()`. Past it, a timeout does nothing more.
- **GAP** `doaction` also takes two strings, `('healmana', 'sip')`, which is
  the public form `Funnies.lua` advertises.
- **GAP** `checkaction(act, input)`: `input == false` suppresses the force-add
  even with anti-illusion off.
- **GAP** `actionfinished` and `killaction` schedule a gnome run with
  `tempTimer(0)` when `sys.sync` is set. `actionfinished` calls `completed`
  under `pcall`; `oncancel` is `pcall`ed, `onkill` is not.
- **NEW, a pre-existing defect.** Line 24 captures
  `local make_gnomes_work = svo.make_gnomes_work` when the `action` loader
  runs. `svo.make_gnomes_work` is a binding that `changecuring` reassigns
  between the async gnome, the sync gnome and a no-op. The `sk` loader, which
  runs just before, emits `changecuring` once, so the snapshot is normally
  `make_gnomes_work_async` and never changes afterwards. Every call through the
  local (the timeout kick at line 89, and the slow-curing kicks at 294 and 339,
  which only run *because* `sys.sync` is true) therefore runs the **async**
  gnome in slow-curing mode, which fires every balance's best action rather
  than one. The same line is in `svo (curing skeleton, controllers, action
  system).xml` at 3755, so it predates the conversion. Behaviour in play not
  observed; whether `cnrl.processcommand` or `blockcommands` masks it is
  checked under `Controllers.lua`.

## `Curing_skeleton.lua` (loader `sk`, 2,521 lines)

### The balance checks
- **GAP, and WRONG for misc.** Not all ten "do the single best one".
  `check_misc` in async mode walks every advisable candidate from highest to
  lowest priority and `doaction`s each, skipping a second `dontbatch` action
  once one has gone out (lines 236 to 250). `check_balanceless_acts` likewise
  fires every candidate. The others pick one.
- **GAP** the guards differ per balance and the document generalises one:
  - `check_sip`: candidates are held afflictions plus `healhealth` and
    `healmana` only; no defence shortlist.
  - `check_purgative`, `check_salve`, `check_herb`: afflictions plus
    `dict_purgative`/`dict_salve_def`/`dict_herb` when deffing or keepup.
    Herb also needs `sys.canoutr or sk.can_eat_for(...)`, and waits while a
    `check*` probe is in flight with `waitherbai`.
  - `check_smoke`: no `usingbal('smoke')` guard; per candidate
    `not svo.doingaction(i)`. Blocked by asthma and mucous. Adds
    `checkasthma` when `svo.affsp.asthma`.
  - `check_moss`: only `healhealth`/`healmana`, and only when
    `conf.secondarymoss` is off.
  - `check_misc`: no balance gate at all, only stun and unconsciousness;
    while asleep only the `sleep` action passes. `onlyamnesia` checks just
    `amnesia` and `fear`. Candidates: afflictions, `dict_misc`, and
    `dict_misc_def` when deffing or keepup.
  - `check_focus`: needs any affliction, focus balance, `can_usemana()`,
    `conf.focus`, willpower above 75, no impatience, sandfever or inquisition,
    and cadmus rules.
  - `check_balanceful_acts` and `check_balanceless_acts`: balance,
    equilibrium, both arms, and for Druids hydra; candidates are
    `dict_balanceful(_def)` and `dict_balanceless(_def)`.

### Two different "balance" mechanisms, which the document merges
- **WRONG** prompt cycle step 6, "The balance controller decides. For each
  balance you currently have, it asks the dictionary what the
  highest-priority thing it could do with that balance is." That is
  `work_slaves_work` calling the `check_*` functions. `sk.balance_controller`
  does not consult the dictionary at all.
- **NEW** `sk.balance_controller` runs two **function registries**,
  `balanceless` and `balanceful`, filled by `svo.addbalanceless(name, f)` and
  `svo.addbalanceful(name, f)`. Out of the box they hold only the do queue:
  `svo check dofree` and `svo check do` (registered from `Dor.lua` at
  `systemstart`). They are the public hook for "do this when I have balance".
  The controller runs only when the dictionary's `check_balanceful_acts`
  fired nothing and nothing in flight will take balance; it is gated by
  `balanceid ~= balancetick`, balance plus equilibrium, and the seven
  hindering afflictions; it runs every balanceless function, then balanceful
  ones until one returns truthy, then arms `sys.actiontimeoutid` (the number
  returned, 23 hours at lag 4, else `sys.actiontimeout` of 3 seconds) which
  bumps `balancetick` and reruns the gnomes. `svo.donext()` is the early
  release.
- **NEW, asymmetry.** `local balanceless = svo.balanceless or {}` reuses the
  table `Create_Svof_namespace.lua` made, so user balanceless hooks survive a
  class change. `svo.balanceful` is never created, so `balanceful` is a fresh
  local on every `sk` load and user balanceful hooks are dropped on every
  class change. `svo balanceless ready` and `svo balanceful ready` are raised
  on a `tempTimer(0)` after load, and again by `clearbalanceless` and
  `clearbalanceful`, as the "register your hooks now" signal.

### Gnomes
- **OK** `work_slaves_work` order, the double `check_misc`, the final guard,
  the async wrapper (block `processusercommand`, swap global `send` for
  `fancysend`, wrap `expandAlias` into the batch), and the sync gnome's three
  steps. **GAP** the sync gnome also returns while `svo.sacid`, and with fancy
  echo it turns `conf.batch` off for the one action.
- **OK** the `changecuring` rebinding of `svo.make_gnomes_work`, done inside
  the loader and followed immediately by `sk.checkaeony()` and
  `changecuring:emit()`.

### Lifevision
- **OK** `add`, `addcust`, `getlineguard`, `clearlineguard`, the illusion
  test, `(!i)`, `(i)`, `consumable_balances`, and the two-pass `lostbal_`
  replay.
- **GAP** `run_through_actions` honours `sk.stopprocessing`: once set, the
  remaining claims are `actionclear`ed instead of finished. After validation
  the ledger is replaced with a new `OrderedMap`, `sk.stopprocessing` and
  `sys.lineguard` reset.
- **WRONG (Misc section)** "`svo.find_until_last_paragraph` and
  `svo.count_until_last_paragraph` are how the lineguard mechanism measures a
  paragraph." Lifevision uses `svo.paragraph_length`, less one when
  `sk.sawcuring()`. `find_until_last_paragraph` is used by symptom checkers
  (`hypochondria_symptom`, `unparryable_symptom`), `sk.checkrewield`, and
  trigger handlers.

### Affliction state
- **OK** `old_internal_addaff`, `old_public_addaff`, the tail,
  `addaffdict`, `rmaff` ordering, `removeaff` recursion, `removeafflevel`
  nil-call. **GAP** `rmaff` also emits `signals.svolostaff` and echoes the
  affliction's duration when `conf.showafftimes`.

### `lostbal_*`
- **WRONG** "The nineteen `lostbal_*` functions". There are 17, and the list
  that follows the heading names exactly those 17. `lostbal_word`,
  `lostbal_anathema` and `lostbal_wrathbal` exist only for terminus, anathema
  and excision.
- **GAP** "arms a timer that restores it" misdescribes the timer's role. For
  every balance the game announces (herb, salve, sip, moss, purgative, smoke,
  focus, and the class ones), the timer is a **failsafe**: it restores the
  balance only if nothing else has since (`sk.<bal>tick` must still match and
  `bals.<bal>` must still be false). The primary restore is the game's own
  "you may eat another herb" style line handled in `Main_trigger_functions.lua`.
  The timeouts are `conf.ai_reset*bal` (herb 2.5 s, sip 7 s, doubled with
  addiction, salve 5, moss 10, purgative 10, smoke 2, dragonheal 20 plus
  ping, focus 5 or 8 with rixil) and fixed values for shrugging, fitness,
  rage (15 plus ping), prayer (3 plus ping), voice (10 plus ping), word (17
  plus ping). **Tree is different**: its timer has no tick check, so it
  restores unconditionally (`conf.treebalance`, else 16 or 40 plus ping by
  `conf.efficiency`, plus 10 with ninkharsag) and echoes "Can touch tree
  again." (Corrected later in this review: there **is** a game line, "You
  may utilise the tree tattoo again.", handled by `valid.gottree`, whose
  completion kills `sys.treetimer`. An earlier version of this note said
  there was none.)
  `lostbal_anathema` and `lostbal_wrathbal` arm no timer because GMCP drives
  them. `lostbal_herb` also opens `sk.blockherbbal` for `ai_minherbbal`
  seconds (0.5 for a mickey) and skips that when voided with no effect.

### Symptoms, lag, and the rest
- **GAP** each symptom checker counts sightings in a decaying window
  (`syncdelay() + sys.wait * n`, or fixed) and acts at a threshold of 2, 3 or
  4. Eight of the fourteen do nothing with `conf.serverside` on: stupidity,
  illness_constitution, transfixed, impale, paralysis, webbed, roped, impaled.
  `retardation_symptom` under anti-illusion probes with `checkslows`, and
  under blackout adds `unknownany`.
- **GAP** `sk.warn(name)` throttles: once warned, the same warning is silent
  for its `time` seconds. `sk.makewarnings` rebuilds the table at
  `systemstart`, `orgchanged` and `curemethodchanged`, with pipe names per
  `curemethod`.
- **NEW, pre-existing?** `sk.increase_lagconf` caps at 3 and needs two calls
  within 10 seconds, but `sk.increasedlag` is set true both on an increase and
  when the 10-second window lapses, and nothing anywhere clears it. So the
  automatic lag increase happens at most once per Mudlet session. 30 seconds
  after an increase it resets the level from `3 * getNetworkLatency()`
  against `wait_tbl[i].n`.
- **GAP** `sk.checkwillpower` swaps `svo.can_usemana` for a stricter version
  below 1000 willpower and back above 1500.
- **NEW** `newroom` drives arena mode from `sk.arena_areas` when
  `conf.autoarena` (not under dementia or unknown afflictions); leaving an
  arena resets both arm balances. **Defect**: that path raises
  `svo config changed` with `"arena`"` (a stray backtick, line 2181).
- **NEW** three more `gmcpcharitemslist` handlers: `inr all` for the `inra`
  flow (`sk.inring`), picking up herbs from the room for `vget herbs`
  (`sk.retrieving_herbs`, via `doaddfree("get <id>")`), and Occultism's
  heartstone and simulacrum defences.
- **NEW, the batching transport.** `svo.sendc` is `sk.sendqueuecmd`: queue
  strings (flushing before 2048 characters), or run a `{func, args}` entry
  after flushing. `sk.dosendqueue` sends one command plainly, up to 10 joined
  with `conf.commandseparator`, up to 9 as `9multicmd {a}{b}...` (the server
  alias `sk.setup9multicmd` sets at login), or more as
  `setalias multicmd a/b/...` plus `multicmd` in chunks of 10. It flushes on
  a `tempTimer(0)` and at the end of `onprompt`, never while logging in.
  `svo.sendcuring` prefixes `curing `. `svo.sendcuringprio` batches
  `curing priority [defence] <x> <n>` into four queues (normal and slow,
  affliction and defence), wrapping slow ones in `curingset switch
  slowcuring`, and `sk.dosendprios` rate-limits to four sends per second.
- **GAP** `sk.fix_affs_and_defs` flips blind, deaf and (for fire elementals)
  ablaze between affliction and defence from the current mode's defup and
  keepup and `mindseye`, then calls `sk.updateserversideprios`.
- **GAP** `sk.checkrewield` runs once on `before_prompt_processing` and fills
  `svo.dict.rewield.rewieldables` unless the paragraph shows a voluntary
  unwield; `sk.removed_something` marks a GMCP item removal for one prompt.

## `Controllers.lua` (loader `controllers`)

- **OK** the 13-step `svo.onprompt` list in the Controllers file reference is
  exact, including the first line, `raiseEvent("svo before the prompt")`.
- **WRONG** the architecture section's version of the same cycle ("emit
  before_prompt_processing, read prompt flags and recompute balances, run
  lifevision.validate, emit after_lifevision_processing, run the balance
  controller, emit after_prompt_processing, redraw the custom prompt").
  Prompt flags and stats are read **before** `before_prompt_processing`, and
  the step after lifevision is `svo.make_gnomes_work()`, not the balance
  controller. The file's own diagram at lines 214 to 238 is the accurate one:
  `before_prompt_processing` runs `prompt_stats`, the acrobatics prone check,
  `valid.check_life` and `sk.onprompt_beforelifevision_do` (`svo.aiprompt`);
  then `send_in_the_gnomes` runs `lifevision.validate`, then
  `after_lifevision_processing` (`svo.prompttrigger` hooks,
  `cnrl.checkwarning`, `sp_checksp`), then `make_gnomes_work`; then
  `after_prompt_processing` (custom prompt, `cnrl.dolockwarning`).
- **NEW, `svo before the prompt`** is raised by `onprompt` and is missing
  from the document's grouped list of public events. Count to be settled.
- **WRONG** "`svo.cnrl.processcommand` handles svof's own commands,
  `svo.cnrl.processusercommand` handles what you type." Both see every send
  through `sysdatasendrequest`. `processcommand` is **blocked except in slow
  curing** (`sk.checkaeony` unblocks it) and is the aeon/retardation
  command filter for what you type: with `conf.blockcommands` and an action
  in flight it `denyCurrentSend()`s your command ("denying X"); with it off
  it treats your command as an override and sets `svo.sacid`, a timer for
  `syncdelay + latency + conf.sacdelay` during which the sync gnome does
  nothing, then resumes. It also detects retardation ending: each command
  arms a timer, and if no "sluggish" line cleared `sk.sawsluggish` by then,
  retardation is removed. `curing ...` commands and commands sent while
  `sk.gnomes_are_working` are exempt. `processusercommand` maps a typed
  command to a dictionary action through `sys.input_to_actions` and runs
  `doaction` for it with `send`, `sendc` and `sendAll` stubbed out, so a
  manual cure is tracked and completed by the same triggers; it also handles
  `qq`/`quit` (`QQ`, switch to `empty` defs, `inra`) and `ir` rift parsing.
  The async gnome blocks it so svof's own sends are not re-registered, and
  `sk.systemscommands` catches batched sends that escape the block.
- **NEW, consequence for the `make_gnomes_work` capture.**
  `sk.gnomes_are_working` is set only by the sync gnome. When the stale
  async gnome runs in slow curing (see `Action_system.lua`), its sends reach
  `processcommand` looking like yours: denied under `blockcommands` (which
  `autotsc` turns on for aeon), or treated as an override that sets
  `svo.sacid` (autotsc's retardation setting). Read from code, not observed.
- **GAP** `svo.prio_makefirst` sets `spriority` (the slow-curing list) to
  500, not a per-balance priority. It is used only by the `shh` alias,
  always with an explicit balance. **Defect, unreachable from `src/`:** the
  no-balance path declares `local balance = false` inside the `if`, so the
  balance it works out is discarded and the assert on the next line always
  fails.
- **NEW, defect.** `svo.prio_slowswap` asserts `balance and balance2` before
  `balance2` is assigned, so swapping two `action_balance` names (the
  `vswapslow` alias passes `echoback = true`) always prints "What balances do
  you want to use for swapping?" and then carries on and swaps.
- **NEW** `svo.prompt_stats` reads `gmcp.Char.Vitals` into `stats`, **pauses
  the whole system** when GMCP vitals are absent, fills blanks during
  blackout, substitutes `conf.assumestats` percent under blackout or
  recklessness, and emits `changed_maxhealth`/`changed_maxmana`, whose
  handlers recompute `sys.siphealth`, `sys.mosshealth`,
  `sys.transmuteamount`, `sys.corruptedhealthmin`, `sys.bloodswornoff`,
  `sys.sipmana`, `sys.mossmana` and `sys.manause`.
- **NEW** `svo.goteq`, `svo.gotbalance` and `svo.gotarmbalance` are called by
  the `svo got eq`, `svo got balance` and Monk arm-balance triggers; each
  bumps `sys.balancetick` and kills `sys.actiontimeoutid`, which is how a
  regained balance reopens the balance controller. `svo.blackout()` is
  called by the blackout prompt trigger and sets a flag `checkblackout` reads.
- **NEW** disrupt inference: on `svo lost balance` for equilibrium, after
  `conf.noeqtimeout` (5 s) without equilibrium, not in `extended_eq`
  (long-eq actions), news, or already disrupted, add `disrupt` (and
  `confusion` when `me.passive_eqloss`). Regaining equilibrium removes
  disrupt. Off with serverside. These listen on the bracket signals, which
  are fed by svof's own `raiseEvent("svo lost balance", ...)` going out to
  Mudlet and back in through `svo_events`.
- **NEW** the prompt pipeline handler on `after_prompt_processing` copies the
  real prompt to the `svo_prompt` buffer, replaces it with the custom prompt,
  prefixes `?:` under recklessness or blackout, inserts the clickable `(a)`
  slow-curing marker (green while overriding, red while acting, blue idle,
  link shows `sk.syncdebug`), inserts `(p)` when paused, and moves the result
  to the single-prompt console.
- **NEW** `gmcpcharstatus` sets `sys.charname` and `me.name`; `gmcpcharname`
  clears `svo.innews` and sets `sk.logged_in`.
- **NEW** `svo.newbals` is written from GMCP vitals `bal`/`eq` and read by
  nothing anywhere in `src/`.
- `svo.givewarning(tbl)` goes through `givewarning.happened` and lifevision,
  with lineguard 1 under anti-illusion. The eight locks in `cnrl.lockdata`:
  soft, venom, hard, dragon, rift, rift 2, slow, true.
- `printorder`/`printordersync` render the lists with `^^`/`vv` links that
  call `prio_swap`/`prio_slowswap`, and show the serverside number (capped at
  25) next to svof's when serverside is on.
- `svo.fullstats` connects `sk.check_fullstats` to `after_prompt_processing`,
  un-ignores serverside `healhealth`/`healmana` for the duration, and runs a
  callback (function or string) when full.

## `Dictionary_of_actions_(affs-defs-misc).lua` (loader `dict`, 15,444 lines)

Read in full.

### Layout and rebuild semantics
- Lines 41 to 50 declare the ten shortlists; 52 to 421 hold the four monk
  helpers, the codepaste helpers and the burn ladder.
- **NEW** the literal is inside `if not next(svo.dict) then` (line 428), and
  that `if` does not close at the literal's `}` (10793): it closes at line
  14642, so **every class-gated `svo.dict.X = {...}` block is inside it too**.
  `basicdef` calls (14682 onward), the `svotossa`/`svotossd` reverse maps,
  `dict_setup()` and every signal connection are outside it. Consequences:
  classchange's `svo.dict = {}` is what lets the literal rebuild; a hot reload
  of this file with the dictionary populated rebuilds only the `basicdef`
  entries (fresh tables with no priorities) and re-runs `dict_setup`.
- **WRONG** "After the literal table closes at line 10,793, roughly 400 lines
  of `svo.haveskillset(...)` blocks patch class-specific entries in." It is
  about 3,850 lines (10795 to 14641): the `prone`/`nightsight`/`shroud`
  patches, then every class-gated defence and action.
- **OK** 155 class-gated `svo.dict.X = {` assignments over 148 names and 157
  `basicdef()` calls over 134 names (re-counted).
- **NEW** four of the 267 literal keys are not actions: `sstosvoa`,
  `sstosvod` (the serverside-to-svof name maps) and the empty `svotossa`,
  `svotossd`, which the loader fills by reversing the first two after the
  `basicdef` calls (lines 14913 to 14919), only for string values.
- `svo.basicdef(which, command, balanceless, gamename, undeffable)` builds a
  `physical` defence with `def = true`, `balanceless_act` or
  `balanceful_act`, and the standard defup/keepup `isadvisable`.

### `codepaste`
- **WRONG** "`svo.codepaste`, 17 shared closures". The dictionary defines 18
  (lines 132 to 406) and `Action_system.lua:200` adds
  `balanceful_codepaste`, 19 in all. The table in the document lists 18 and
  omits `nonmorphdefs`, which exists only for metamorphosis.
- **WRONG descriptions** in that table:
  - `badaeon` is not "the aeon re-check". It warns (`sk.warn 'badaeon'`, "walk
    out") when you hold aeon plus asthma, stupidity, voided, or asthma with
    anorexia.
  - `addrestobreakleg`/`addrestobreakarm` do not describe "restoration needed
    to fix a broken limb". They **add** a limb-break affliction, but only when
    anti-illusion is off, health dropped, the paragraph has 3 or more lines,
    or recklessness has been held long enough; the Tekura path batches breaks
    for `latency + conf.tekura_delay` so a double hit lands together. The arm
    version also emits `canoutr`.
  - `remove_focusable` does not "clear afflictions Focus would have taken". It
    decrements `unknownmental` by one, removing it at zero. Every `gone` of a
    focusable mental calls it.
  - `checkreavekill` and `checkdismemberkill` are instakill **warnings**
    (humour count 2/3/4; bound plus impaled when fighting a Sentinel), not
    kill logic.
  - `nonstdcure` is "tree, restore or shrugging is in flight".

### The handler vocabulary the document's field table misses
- Entry-level fields: `gamename`, `name`, `count`, `description`,
  `onservereignore` (entry-level, not handler-level as the table implies),
  `onadded`, `onremoved`, plus per-entry data (`lovers.map`/`tempmap`,
  `paradox.blocked_herb`, `rebounding.blocked`, `checkstun.templifevision`).
- Handler fields: `sipcure`, `applycure`, `smokecure` beside `eatcure` (they
  are what `svo.sip`/`svo.apply`/`svo.eat` pick from, and what
  `sys.input_to_actions` maps typed commands with), `uncurable`,
  `dontbatch`, `irregular`, `customwait`/`customwaitf`, `onclear` (the
  negative outcome of a probe).
- **Named outcomes.** Every other function key on a handler is an outcome a
  trigger can select by name, passed as `other_action` to
  `lifevision.add(act, 'name', arg)` and invoked as `act[name](arg)`:
  `noeffect`, `cured`, `fizzled`, `empty`, `offbalance`, `nomana`, `mickey`,
  `all`, `helpless`, `impale`, `dragged`, `withdrew`, `alreadygot`,
  `alreadyhave`, `cancelled`, `inundated`, `general_cure`, `general_cured`,
  `generic_reducelevel`, `lost_level`, `hiddencures`, `relaxed`, `camusbite`,
  `sumacbite`, `sylvanhit`, `tekura`, `renew`, `forced`, `checkdeaf`, the
  `relapsing` venom checks (`camus`, `sumac`, `oleander`, `colocasia`,
  `oculus`, `prefarar`, `asthma`), the probe confirmations (`sluggish`,
  `blehfood`, `paralysed`, `impatient`, `weakbreath`, `badlungs`,
  `hypersomnia`, `webbily`, `impaly`, `transfixily`, `truename`), and more.
  This is the mechanism by which one action has several outcomes.
- **NEW** `dict_setup` generates default outcomes the source does not spell
  out: `herb.noeffect` (`lostbal_herb(true)`), `herb.mickey` (lose herb
  balance for 0.5 s and gain illness), `offbalance` on focus, salve, herb and
  smoke, and `focus.nomana` (start `nomana.waitingfor`).

### Patterns worth naming
- **Restoration two-stage cure.** A restoration salve's `oncompleted` spends
  salve balance and starts a `curing<aff>.waitingfor` with `customwait = 6`;
  the heal line completes it (mutilated to mangled to crippled, serious to
  mild), and `ontimeout` assumes it worked. `empty` is `oncompleted` because
  the apply gives no message.
- **Timed afflictions.** Uncurable afflictions that wear off (stun,
  unconsciousness, numbed arms, pinshot, dehydrated, timeflux, voided,
  hamstring, stain, degenerate, deteriorate and about 20 more) are an `aff`
  that starts a `waitingfor` whose `customwait` is the duration; `ontimeout`
  removes it. Several have no `ontimeout` (inquisition, lullaby, icing,
  flamefisted, latched, voided, galed and others), so they only clear on a
  cure line. **Every `waitingfor` timeout goes through the generic
  `doaction` timeout path**: it bumps `sys.lagcount` and, while
  `sk.stupidity_count > 0`, infers stupidity.
- **Anti-illusion probes.** A `check*` entry's `aff.oncompleted` accepts the
  affliction at once when `svo.paragraph_length > 2` (a single-line illusion
  cannot produce a long paragraph), and otherwise only sets
  `svo.affsp[aff]`. The probe's `misc.isadvisable` fires on that suspicion;
  its reply selects a named confirmation, and `onclear` handles the negative.
  `checkstun` snapshots `lifevision.l` and `svo.actions`, sets
  `sk.stopprocessing` to freeze the paragraph, and replays it through
  `send_in_the_gnomes` once stun is settled. `relapsing` also sets
  `sk.stopprocessing` when the paragraph has nothing checkable.
- **Burn ladder.** ablaze to severe to extreme to charred to melting; each
  mending apply steps down one, `all` clears every burn, `pyre_holds` skips a
  rung pyre would restore.
- **Strategy-driven actions.** `touchtree`, `restore`, `dragonheal`,
  `shrugging`, `rage` and `fitness` decide `isadvisable` by `pcall`ing
  `func[1]` of every entry in `svo.tree`, `svo.restore`, `svo.dragonheal`,
  `svo.shrugging`, `svo.rage`, `svo.fitness` not disabled in
  `me.disabled*func`. Those tables are the curing strategy files.
- **Pause-while-transforming.** dragonform, mace, viridian, rejuvenate and
  morphs pause the system (`unpauselater`) and a `waitingfor*` unpauses on
  completion, cancel or timeout.
- **Dragonform.** The `dragonform` signal (connected here, emitted at
  `systemstart` and on every `gmcpcharstatus`, which also sets or clears the
  `dragonform` defence from `gmcp.Char.Status.race`) rebuilds
  `dict_balanceful_def`/`dict_balanceless_def`, restricted in dragonform to
  general, dragoncraft and `availableindragon` defences.
- `blackout.aff` adds disrupt after 4.5 s and, when `svo.enabledskills`
  (class management's enemy-skill counter) shows necromancy or curses,
  schedules assumed crippled limbs or suspected asthma and anorexia.
- `diag.physical` fires automatically when `sys.manualdiag`, or unknownmental
  reaches `conf.unknownfocus`, or unknownany reaches `conf.unknownany`.

### `dict_setup` and `dict_validate`
- **GAP** `dict_setup` does more than five things. Beyond the identity fields,
  the zero defaults, the synthesised `gone` and the shortlists, it adds the
  default outcomes above, gives every entry a `sw` stopwatch (the one
  `old_internal_addaff` reuses), and **assigns every zero priority**: per
  balance it shifts every assigned `aspriority` up by the number of
  unassigned actions and gives those actions 1..n (least important); the
  sync pass does the same across all balances. So step 3's "records what has
  no priority yet so the validator can report gaps" is **wrong**: the lists
  exist to place unprioritised actions at the bottom.
- It walks every table-valued key as a "balance", which is why data tables
  such as `lovers.map` and `lovers.tempmap` get names and priorities (the
  document's `map`/`tempmap` "special cases") and why the function resets
  `svo.dict.lovers.map = {}` at the end.
- It is re-run by `Priorities.lua:501` (prio import) and three places in
  `Defences.lua` (2590, 2702, 2813), each followed by `dict_validate`.
- **WRONG** "`svo.dict_validate()` ... catches a handler with no
  `oncompleted`". It checks only for duplicate priorities, per balance and in
  the sync list, and echoes them. **Defect:** the sync half tests the stale
  `key` from the async half instead of `synckey` (line 15186), so sync
  duplicates are either never reported or all reported.

### Other connections made in this loader
- `curedwith_focus` calls `svo.dict.unknownmental.focus[what]()` on every
  focus completion, so each focus cure also decrements unknownmental.
- `newroom`: drop `listen` (subterfuge), `block`, `eavesdrop`, `lyre`;
  remove impale and echo "We escaped"; `sk.check_retardation` (blocked until
  retardation is gained).
- `systemstart`: builds `sys.input_to_actions` from `sipcure`, `eatcure`,
  `smokecure`, `action` and `actions` of every non-`check*` handler
  (`applycure` is not used), which is how a typed cure becomes a tracked
  action.

### Defects found (all pre-existing: same text in `svo (actions dictionary).xml`)
- **`unweavingbody.aff.oncompleted` (8578) and `crescendo.aff.oncompleted`
  (9009) call `svo.addaffdict(dict.X)`.** There is no local `dict` in this
  file and no global of that name anywhere in `src/`, so both raise. Both are
  mapped in `sstosvoa`, and the GMCP `Char.Afflictions.List` handler adds a
  missing affliction through the public `svo.addaff`, which calls
  `aff.oncompleted`: a list containing either one raises inside the handler
  and abandons the rest of the resync (later additions, `checkaeony`,
  `changecuring`, and every removal). `svo_gevents` catches it and
  `display`s the error. The GMCP Add path uses `addaffdict` directly and is
  unaffected.
- `fortifiedair.oncompleted` tests `defc.fortifiedwaterand` (12603), a typo
  for `fortifiedwater and`, so fortifying air last never grants `fortifyall`.
- `aria.physical.onstart` calls `svo.apply(svo.dict.aria.salve, ...)` when
  deaf; `aria` has no `salve` sub-table.
- `bonding`'s `gone` is nested inside `physical` (11476), so the entry has no
  top-level `gone`; `dict_setup` synthesises one, which masks it.
- `oncuredleft` exists on eight `curing*` waitingfors and nothing calls it.

## `Diag_trigger_functions.lua` (loader `diag`)

- **WRONG** "Three functions". Beside `diagnose_start`, `empty_diagnose` and
  `diagnose_end`, the file generates **160** `svo.valid.diag_<aff>`
  handlers: 151 plain names (the list has 152 with `voyria` twice) and 10
  counted ones (humours, bleeding, the four fractures, pressure), with
  `bleeding` in both lists so the counted version wins. The trigger section
  of the document says the handlers are generated here; the file section
  says three functions. The first is right.
- **GAP** "clears the affliction table and rebuilds it". `diagnose_start`
  files a lifevision claim for `diag_physical` only if svof sent the
  diagnose; under anti-illusion an unrequested one closes the `svo diag`
  gate and marks the line `(i)`. Each `diag_<aff>` writes into
  `sk.diag_list` and annotates the line with `(new)` or the held duration.
  `diagnose_end` then `rmaff`s every held affliction the game did not list,
  except a whitelist (lovers, retardation, hoisted, paradox, plus
  cantvitality and cantmorph for some classes), corrects counts, and for
  every newly listed affliction force-adds its `aff` action and files a
  **lifevision claim** (so new ones arrive at the prompt, through the same
  `aff.oncompleted` as any other gain). It clears `svo.affsp`, runs
  `checkaeony` plus `changecuring`, and closes the gate. A `godfeelings`
  line aborts the whole diagnose.

## `Simple_aff_trigger_functions.lua` (loader `valid_simple`)

- **WRONG** "Eleven handlers". The file generates `svo.valid.simple<aff>` for
  about 165 afflictions (the `afflist` at line 18, plus `cantmorph` for
  metamorphosis), then hand-writes 11 that need more (the ones the document
  lists), a counted family for the four fractures, and `simpleage` for
  aeonics.
- **WRONG** (Trace 1) "`valid.simpleparalysis()` ... adds the affliction
  immediately." Every `simple<aff>` does `svo.checkaction(dict.X.aff, true)`
  and `lifevision.add(...)`: a forced claim settled at the prompt, not an
  immediate add. "Simple" means "no reasoning about whether to believe it",
  not "bypasses the ledger".
- **NEW** `simplebleeding` does nothing unless `conf.preclot`;
  `simplehoisted` and `simplelovers` honour `conf.autowrithe`/`hoistlist` and
  `conf.autoreject`/`lustlist`; `simpleblackout` inserts at ledger position 1
  with `addcust` so stun checks do not delay it; the unknown handlers
  accumulate counts across a paragraph and set `reckhp`/`reckmana` for the
  recklessness cross-check.
- **Defect (pre-existing, XML line 316):**
  `svo.valid.proper_crippledleftleg = valid.simplecrippledrightleg`. Its one
  caller, the inactive Qwindor bashing trigger `Morindar legbreak`, calls
  both left and right and records only the right leg.

## `Main_trigger_functions.lua` (loader `valid_main`, 4,640 lines)

### The handler grammar, restated from the code
- A cure or event line usually does `svo.checkaction(dict.X.bal)` without
  force, then `if actions.X_bal then lifevision.add(actions.X_bal.p,
  outcome, arg, lineguard)`. With anti-illusion on, checkaction does not
  force-add, so a line that svof did not ask for is simply dropped. That is
  the main anti-illusion check; the document's four "forms" are secondary.
- **NEW, the empty-cure mechanism.** Each curing container has a first and a
  second handler: `ate1`/`ate2`, `sip1`/`sip2`, `apply1`/`apply2`,
  `smoke1`/`smoke2`, `tree1`/`tree2`, `applyelixir1`/`applyelixir2`,
  `focus1`/`focus2`. The first resets a flag (`svo.herb_cure`,
  `svo.sip_cure`, `svo.apply_cure`, `svo.smoke_cure`, `tree_cure`,
  `svo.applyelixir_cure`, `svo.focus_cure`); any specific cure handler sets
  it. The second fires on the line after, and if the flag is still false it
  files the in-flight action with the **`empty` outcome**, which runs the
  dictionary's `empty` (usually `empty.eat_<herb>` and friends: remove every
  affliction that cure could have cured). The document's "(numbered pairs
  are) the command going out and the effect landing" is not what they are.
  `ate2` also rejects a result faster than `getping()/2`, stretches the
  lineguard to 2 for addiction, swellskin or a serverside `[CURING]` line,
  and arms a one-line trigger for cadmus and paradox follow-ups. `ate1`
  auto-enables arena mode and, with anti-illusion, queues an `aiprompt`
  that marks the eat as an illusion if GMCP removed no item
  (`sk.removed_something`).
- **Cross-cures.** The generated `herb_cured_<aff>`, `smoke_cured_<aff>`,
  `focus_cured_<aff>`, `salve_cured_<aff>`, `curing<aff>` (restoration) and
  `herb_helped_`/`smoke_helped_` handlers first look for their own action;
  if a *different* action on the same cure is in flight (you ate goldenseal
  for impatience and it cured stupidity), they `killaction` that one,
  force-add the matching one, and claim it. `herb_cured_` and
  `herb_helped_` carry the `sk.gmcp_cured` clause quoted in the document.
- **WRONG naming** "The herb-cure generator builds one `valid.<aff>_cured`
  handler per herb-curable affliction". The herb family is
  `valid.herb_cured_<aff>`. `valid.<aff>_cured` exists only for heartseed,
  hypothermia and the four health-elixir fractures.
- **Balance regain goes through the ledger.** `gotherb` (rejected inside
  `sk.blockherbbal`), `gotsalve` (rejects a restoration heal faster than
  `conf.ai_minrestorecure`), `gotpurgative`, the generated `got<bal>` for
  moss, focus, sip, purgative, dragonheal, smoke, tree, the class `got*`
  handlers and `force*` all push the balance name into
  `svo.dict.gotbalance.happened.tempmap` and claim `gotbalance_happened`;
  at the prompt its `oncompleted` sets `bals[x] = true`, raises
  `svo got balance`, ends the balance stopwatch, and for tree kills
  `sys.treetimer`. `used*balance` handlers claim `stolebalance.happened`,
  which calls `svo['lostbal_'..x]`. This is the primary restore that the
  `lostbal_*` timers back up.
- **Generic cures.** **WRONG count:** `generic_cures_data` has 112 entries,
  111 distinct (`hallucinations` twice), not 110. Each `generic_<aff>`
  claims `<aff>_gone` during a passive-cure paragraph; otherwise claims the
  action svof was doing for that affliction; otherwise finds any in-flight
  action on a balance the affliction also has, kills it and claims the
  matching one; otherwise attributes it to tree or restore. The trigger
  swap in `check_generics` is as the document says.
- `valid.passive_cure` sets `svo.passive_cure_paragraph`, enables generics,
  and at the prompt decrements unknownmental or unknownany when a cure
  removed nothing known.
- `systemstart` also disables `General cures` and toggles
  `Pre-parse anti-illusion` by `conf.aillusion`.
- Two signal handlers live here, connected blocked: `valid.check_life`
  (unblocked on death, unpauses when health returns) and
  `valid.check_recklessness` (unblocked by `recklessness.onadded`, removes
  recklessness when GMCP vitals are below max).
- Limbs: `valid.limb_hit` records `me.lasthitlimb`, highlights, unblocks
  `svo.sp_checksp`, emits `signals.limbhit` and raises `svo limb hit`. The
  generated `proper_<mangled|mutilated><limb>` insist the limb is named in
  the paragraph and batch Tekura combos. Bard `swashbuckling_poison`,
  `acciaccatura`, `tremolo` and `vibrato` delay crippled limbs so the
  mangle is cured first; `limbhit` with two weapon hits (a DSL) applies the
  delayed venoms at once.
- `valid.pyradius` deletes the cure lines, re-feeds them with
  `feedTriggers`, and maps each cured affliction to the one pyradius swaps
  it for.

### Defects (all pre-existing: the same text is in `svo (trigger functions).xml`)
- `valid.update_break` calls `valid.simple['mangled'..limb]()` (line 2011).
  `valid.simple` is not a table, so when a restore is in flight and one of
  the two "upgrade break" triggers fires, it raises instead of adding the
  mangled limb. Intended `valid['simplemangled'..limb]`.
- `valid.litpipe` (2092) and `valid.empty_light` (2639) index
  `svo.dict.lightelm`, `lightvalerian` and `lightskullcap`, which do not
  exist (only `lightpipes` does), so both raise every time they run.
  `svo.missing_tinderbox` checks `actions.light*_physical`, which can never
  be set.
- `valid.vodun_throttle = valid.kaido` (1348): there is no `valid.kaido`, so
  the `Vodun throttle` trigger raises "attempt to call a nil value". Intended
  `valid.kaido_choke`.
- `valid.usedwrathbalbalance` claims `stolebalance` with `'anathema'` rather
  than `'wrathbal'` (4367). Reachability depends on whether `bals.wrathbal`
  is ever initialised; checked under `Alias_functions.lua`.
- `valid.got_blind` tests `defs.blind` (a handler namespace) instead of
  `defc.blind`, so it can add hypochondria while blind is up as a defence.
- `valid.symp_asleep` and `valid.transfixily` test `affs.asleep` and
  `actions.asleep_aff`; the affliction is `sleep`, so those guards are dead
  (the memory already records this).
- Duplicate definitions: `svo.valid.relapsing_oculus` (1308 and 1313, second
  wins) and `svo.defs.got_dragonform` (a function at 289, then replaced at
  894 by `svo.dict.waitingfordragonform.waitingfor.oncompleted`).

## `Config_system.lua` (loader `config`)

- **OK** `wait_tbl` (0.7, 1.1, 1.9, 3.5, 3.5), 106 base options in
  `config_dict` (an `OrderedMap`), the field vocabulary, `tntf_tbl` entries
  and shortcuts (`ai`, `anti-illusion`, `a`, `antiillusion` to `aillusion`;
  `ss` to `serverside`), and `insert(1, ...)` placing class options first.
- **Resolved: the "up to 23" is reproducible.** It is the number of distinct
  option names across all 17 conditional `config_dict:insert(1, ...)`
  calls: kaido 5 (`transmute`, `transmuteamount`, `transsipprone`,
  `kaidodeaf`, `kaidoblind`), voicecraft 1, weaponmastery 1, zeal 1, venom 2
  (`shruggingfunc`, `shrugging`), devotion 1, woodlore 1, metamorphosis 3,
  shindo 2, the fitness group 2 (`fitness`, `fitnessfunc`), the rage group 2
  (`rage`, `ragefunc`), and `parry` or `guarding` 2. No class gets all 23.
- **WRONG** "**not** `tekura` | `parry`, `guarding`". Non-tekura classes get
  `parry`; tekura gets `guarding` instead (the `else` branch, line 1713).
- **WRONG** "Saving writes through `svo.pl.pretty`". The `saveconfig`
  handler writes `conf` with `svo.tablesave` (Mudlet's table pickle) to
  `<home>/svo/config/conf`; `pl.pretty` is used for priority exports only.
- **GAP, migrations.** The load-time fix-ups are more than the three the
  document names: `ai_minherbbal` 0.7 or 1.2 to 1.1, `ai_resetherbbal` 5 to
  2.5, `ai_resetsipbal` 5 to 7 **and then 7 to 10** (chained, so Setup's
  default of 7 is always turned into 10: the effective sip failsafe is 10 s),
  `Shallam` to `Targossas`, `recovery` to `efficiency`, `gagserverside`
  defaulted on, `ai_resetpurgativebal` 5 to 10, and `eventaffs` forced true.
  `conf.releasechannel` is forced to `'inclient'` on every load.
- **NEW, load order of configuration.** Setup applies defaults; this loader
  then merges `<home>/svo/config/conf` over them with `svo.update`, runs the
  migrations, and pre-initialises every still-undeclared option to `false`
  or `0`. Load-time side effects: bashing triggers on or off, the `riding`
  action switched between balanceful and balanceless by `freevault` (then a
  `dragonform` emit to rebuild shortlists), `burrowpause` connects
  `sk.check_burrow_pause` to `gmcproominfo`, a default custom prompt after
  10 to 15 s, single prompt, herbstat label, logging.
- **NEW, inconsistency.** `shipmode` connects `sk.check_shipmode` to
  `newroom` only in its `onenabled`, never at load, so after a restart or a
  class change the ship-mode failsafe is not wired even with the option on.
  `burrowpause` does it both ways.
- **NEW** `svo.config.set(what, option, echoback)`: booleans accept
  yes/no words, numbers are range-checked, strings pass `check`, custom
  options open `onmenu`; the `svo config changed` event is raised on a
  `tempTimer(0)`; it then continues the installer if one is running and runs
  the gnomes. `svo.tntf_set` raises the event immediately.
- `tn serverside` runs `setup_default_serverignore`, drops old "using
  server-side curing" ignores, `setupserverside()`, and sends `curing
  afflictions on`, `sipping on`, `defences on`, `focus on|off`, `batch on`,
  `config advancedcuring on`, `reporting on`, and `curing on` unless paused.
- Small defects: the `morphskill` option's `installstart` clears
  `svo.sp_config.morphskill` instead of `conf.morphskill`, so a reinstall
  never re-asks it; the `weapon` option's `onshow` is a string formatted at
  load and never updates.

## `Install_system.lua` (loader `install`)

- **GAP** the `vinstall` flow: `installstart` sends `Char.Skills.Get` for
  every `installdata` entry with a `gmcp` field (plus the survival and, for
  metamorphosis, the metamorphosis group) and `Char.Items.Inv`, and unblocks
  three GMCP handlers; it sends `config screenwidth 0` and the in-game
  `CONFIG PROMPT CUSTOM` string; runs every option's `installstart`; zeroes
  the pipe ids; sets `org` from GMCP city and dragonflex/dragonheal from level
  99. `checkskillgmcp` answers each probe (have it or not) and
  `installclear` arms a 5 s timeout that sets unanswered booleans false and
  then starts `ask_install_questions`, which asks the first option in
  `config_dict` order with `conf` nil and an `installcheck`, prefilling
  `vconfig <name> ` on the command line. Every `svo.config.set` advances it.
  At the end: block the probes, `saveconfig`, offer parry, precache and
  colours, set the default prompt, and ask for a restart.
- `checkinvgmcp` assigns pipe ids from inventory items named "pipe" via
  `svo.pipe_assignid` (which also sends `empty <id>`). Its location guard is
  `if not t.location == 'inv'`, which is always false, so it scans every
  item list. The `pipes` entry's `ii pipe` command is never sent.
- `vinstall fresh` (twice) calls `os.remove` on the `svo` directory, which
  cannot remove a non-empty directory, and resets defup/keepup to `basic` and
  `combat` only.

## `Priorities.lua` (loader `prio`)

- **NEW, the model.** Priorities live only on the dictionary handlers
  (`aspriority`, `spriority`); files exist only for export and import (the
  file's header says so). At `systemstart` `prio.import('current')` loads
  `<home>/svo/prios/current`, falling back to `installationfolder()/
  default_prios`; a `saveconfig` pre-emit exports `current`. The file format
  is Lua, `balance = { [n] = "action" }`, run in a `setfenv` sandbox.
- **WRONG** `prio.list(balance)` "returns the list". `prio.list(echoback)`
  lists the saved priority files; `prio.getlist(balance)` returns the table.
- **WRONG** `prio.sortlist(balance)` "re-sorts". It is `sortlist(actions,
  balance)` and sorts a list of action names by their priority (used by
  `svo.missing_enchant`).
- **WRONG** `prio.usedefault(balance)`. It is `usedefault(echoback)` and
  reloads every list from `default_prios`.
- **GAP** `prio.insert(action, balance, number, echoback)` moves an action
  and shifts the rest, raising `svo prio changed` once per moved action (with
  a fourth `'slowcuring'` argument for the sync list). `prio.import` clears
  each imported balance, sets the numbers, reruns `dict_setup` and
  `dict_validate`, and reports serverside differences with
  `sk.notifypriodiffs(before, after)`. `gethighest` returns number and action.

## `Parry.lua` (loader `parry`)

- **OK** the five strategies, `sp_limbs`, and the function list.
- **GAP, the flow.** `valid.limb_hit` unblocks `svo.sp_checksp` on
  `after_lifevision_processing`; it recomputes `sp_config.parry_shouldbe` for
  the strategy (a custom function strategy also reruns on every
  `svogotaff`/`svolostaff`), calls `check_sp_satisfied` to set
  `sys.sp_satisfied`, and blocks itself again. The dictionary's
  `doparry.physical` (balanceless) fires while not satisfied and sends
  `parry`/`guard`/`clawparry <limb>`. `full` needs `parry_actionlevel`
  numbers, whose install step is commented out, so it only works if set
  through `sp.setparrylevel` by hand.
- **NEW, defect.** `sp.setup()` assigns the file-local `sp_config` a new
  table without updating `svo.sp_config`, so after `vsetup sp` the parry
  commands (which read `svo.sp_config`) and the saved file (which writes the
  local) disagree until reload.
- Saved to `<home>/svo/config/sp_config`, loaded at loader time.

## `Pipes.lua` (loader `pipes`)

- **GAP** state is saved to its own file, `<home>/svo/pipes/conf`, on
  `saveconfig`, and loaded when the loader runs, with defaults added for
  fields introduced later; not "with the configuration".
- `pipes.expectations` is a rotating guess at which pipe goes out next;
  `svo.pipeout()` marks the first unlit and rotates.
- The PIPES list parser fills primary then secondary pipes; the empties pass
  compares status against `'Lit'` (capitalised) and reads a `status2` that is
  never set, so pipes assigned from empty slots are always marked unlit.
- `connected` marks non-artefact pipes unlit on login.

## `Rift.lua` (loader `rift`)

- **WRONG** "rebuilds eight functions ... `sk.can_eat_for`, `svo.sip`,
  `svo.apply`, `sk.synceat`, `sk.asynceat`, `sk.syncfill`, `sk.asyncfill`,
  and the local `siprandom`". On `curemethodchanged` it rebuilds five:
  `sk.can_eat_for`, `svo.sip`, `svo.apply`, `sk.synceat`, `sk.asynceat`.
  `sk.syncfill`/`sk.asyncfill` are ordinary functions that choose the herb at
  call time (the comment says pipes are filled too rarely to be worth
  recompiling), and `siprandom` is a fixed local.
- **NEW** `svo.sip` and `svo.apply` are rebuilt but do not vary: they always
  use `sipcure[1]`/`applycure[1]`, the concoctions name. So `curemethod`
  changes what is eaten and what fills pipes (and sileris, in the
  dictionary), never what is sipped or applied. With `conf.siprandom`,
  `svo.sip` picks a random vial id from the elistsorter's `svo.es_vialids`.
- **NEW** a second binding like `svo.eat`: `svo.fillpipe` is `sk.syncfill`
  in slow curing and `sk.asyncfill` otherwise, swapped on `changecuring`.
- `synceat` eats if the herb is in inventory, otherwise only outrifts it
  (the next sync action eats); `asynceat` eats and outrifts together.
  `rift.outr` tops up to the current defence mode's precache amount and arms
  `sys.blockoutr`.
- Persistence: `<home>/svo/rift+inv/rift`, `inv` (reset to zero on load,
  since you cannot hold herbs across a login), and `precachedata`, one table
  per defence mode; `rift.precache` is the current mode's.
- **NEW** `enablegmcp` subscribes to `IRE.Rift`, but no handler listens to
  `gmcp.IRE.*` except `IRE.Time`, so rift contents are tracked from text
  lines only (`riftline`, `riftremoved`, `riftadded`, `riftnada`,
  `riftate`, `invline`, pocketbelt).
- `rift.outr(what)` takes one argument, not `(what, count)`.

## `Alias_functions.lua` (loader `aliases`)

- **WRONG, the balance list (State section).** `svo.reset.bals` sets
  **13** unconditionally (the doc says "fourteen" and then lists 13) and
  **12** behind gates, not 11: the doc misses `wrathbal`, set when you have
  `excision`. The total of 25 is right by accident. The comment above it says
  it creates a new table; it does not, it sets fields in place, so a balance
  from an earlier class survives a class change. It then raises
  `svo got balance` for every key in `svo.bals`.
- **NEW, consequence.** Because `bals.wrathbal` is initialised, the
  `usedwrathbalbalance` defect (it names `'anathema'`) is reachable for an
  `excision` user. Setup's vitals handler (line 590) calls
  `valid.usedwrathbalbalance()` whenever GMCP says `wrathbal: No` while
  `bals.wrathbal` is true. That claims `stolebalance.happened` with
  `'anathema'`, whose `oncompleted` runs `svo['lostbal_anathema']()`, which
  exists only with the `anathema` skillset. So the call errors,
  `bals.wrathbal` stays true, and the same error repeats on every vitals
  update until the balance returns; the `@wrathbal` prompt tag never goes
  out. Pre-existing.
- **OK** the function list. 33 top-level functions plus `svo.transmute`
  (Kaido, defined inside a skillset gate at line 1166), so 34 matches.
- **GAP, what the toggles do.**
  - `svo.app(what, quiet)` is the pause toggle; `svo.dop` pauses the do queue.
  - `svo.dv()` sets `sys.manualdiag` so the dictionary's diag action fires.
    `svo.adf()` sets `me.manualdefcheck` and does `svo.doaction(dict.defcheck
    .physical)`; while it is set, `speed` and `sileris` stop being advisable
    so their own messages cannot collide with the DEF list.
  - `svo.aupdate()` only opens the documentation URL; it updates nothing.
    `svo.aconfigs()` does nothing.
  - `svo.inra()` sends `sk.inring` plus a GMCP `Char.Items.Inv`.
    `svo.get_herbs()` sends `ql` with `sk.retrieving_herbs` set.
  - `svo.vaff(aff)`: from a trigger it goes through `valid.proper_<aff>` or
    `valid.simple<aff>`; typed by hand it calls the `aff` action's
    `forced`/`oncompleted` directly, then `checkaeony` and `changecuring`.
    `svo.vrmaff` is the reverse through `gone`.
  - `svo.ashow()` (`vshow`) raises `svo onshow` so addons append lines.
- **GAP, the four resets.**
  - `reset.affs` removes everything except `lovers`.
  - `reset.general` kills every action, and clears `onpromptfuncs`,
    `sk.gmcp_cured`, and `removed_something`.
  - `reset.defs` keeps every defence with `stays_on_death` and clears parry.
    It is connected to `charname` and `gmcpcharname`, so it runs at every
    login.
  - `reset.bals`, above, runs on `systemstart`.

## `Defences.lua` (loader `defences`)

- **WRONG** "They set or clear `svo.defc`, raise `svo got def` or
  `svo lost def`, and update the timers." `defences.got`/`lost` are two
  lines each: flip `defc[def]` only if it changes, and raise the event. No
  timers.
- **WRONG** "`defences.gettime(def)` returns how long you have had it." It
  takes `(defence, max)` and returns `(max - ceil(elapsed/max)) .. 'm'` from
  `svo.dict[defence].stopwatch`, or `""`. Nothing in `src/` calls it, nor
  `defences.urlify`, `defences.complete_def`, or `defences.get_def_list`.
- **WRONG** "`defs.defup(def, onoff)` and `defs.keepup(def, onoff)`". Both
  are `(which, status, mode, echoback, reshow)`. A string status goes through
  `convert_string`; nil toggles; turning a defence on runs its
  `defs_data.onenable(mode, which, 'defup'|'keepup', echoback)` and aborts
  if that returns false. Both raise `svo defup changed`/`svo keepup changed`,
  then `sk.fix_affs_and_defs()` and `make_gnomes_work()`.
- **WRONG** "`sk.sanitize` and `sk.desanitize` escape and unescape names for
  storage". They swap spaces and underscores so a defence name can become a
  handler name (`svo.defs.got_<name>`), and back for display. Storage never
  sees them.
- **WRONG** "`defs['lost_shield']` ... named with brackets because the names
  contain characters an identifier cannot". All three are valid identifiers;
  the brackets are style. What makes them special is that they **override**
  the generated handler: `lost_shield` claims `shield.gone` and also recolours
  the line; `lost_riding` claims `riding.physical` with the named outcome
  `dismount`; `block_failed` claims `block.physical` with `failed`.
- **WRONG** "`svo.ignoreskill` and `svo.showhidelist()` manage which skillsets
  svof pretends you do not have". `sk.ignored_defences` only hides skillsets
  or single defences from the defence **display** lists (`show_defs`);
  `showhidelist` says so in its header. Setup flips `tekura`/`shikudo` in it
  on a Monk form switch. It changes no curing or defup behaviour.
- **WRONG, misleading** "`svo.detect_lifevision()` is here ... because
  lifevision is itself a defence". It is about the lifevision **mask** (and
  the Shadowcloak and the phylactery): it sends `Char.Items.Inv` and a blank
  line so the three `check*` inventory scanners run. It has nothing to do with
  the `svo.lifevision` ledger. Called by the `Detect_lifevision` trigger.
- **GAP, `defs_data` field vocabulary.** `type` (general, dragoncraft, or a
  skillset), `on`/`onr` (exact or regex "got" lines), `on_only` (a gain line
  that only counts if you asked for it: claims without force), `on_free`,
  `off`/`offr`/`offs` (exact, regex, substring loss lines), `off_free`,
  `def`/`defr` (the DEF list line), `nodef` (never on DEF, so it is an
  "additional" defence), `invisibledef` (never on DEF, but process_defs must
  not clear it), `custom_def_type` (a channel-style group reset by a
  `def<type>start` line), `specialskip`, `onenable`, `ondef` (value to show
  next to the name), `onshow`, `mana` (`'little'` or truthy, shown as m/M),
  `tooltip`, `staysindragon`, `availableindragon`, `stays_on_death`,
  `offline_defence` (persisted across logout).
- **NEW, how every defence trigger is made.** No defence has a Mudlet
  trigger item. A `systemstart` handler (line 3279) calls `defload()`, resets
  `defences.def_types`, then walks `defs_data` and creates a
  `tempExactMatchTrigger`, `tempRegexTrigger`, or `tempTrigger` per pattern,
  recording the ids in `svo.defencetemptriggers` so class change can kill
  them (`svo.classchange.lua:27`). Each fires one of three generated
  handlers:
  - `defs.got_<name>`: if the dictionary has an entry for the defence, it
    claims that entry's first non-`gone` balance action through
    `checkaction` (forced for `custom_def_type`, and for metamorphosis when
    you are using that balance) and adds it to the ledger, or with `force`
    finishes it immediately, bypassing lifevision. Otherwise it is
    `defences.got`.
  - `defs.lost_<name>`: claims `dict[def].gone` if it exists, else
    `defences.lost`.
  - `defs.def_<name>`: records the DEF-list line in `defences.def_def_list`
    (or in `nodef_list` for class defences while in dragonform), and deletes
    the line. For a `nodef` defence it only counts while a `defcheck` is in
    flight.
  It also blanks defup and keepup for every mode, seeds
  `sk.ignored_defences`, and merges the saved defup/keepup back over the
  blanks with `svo.update`.
- **GAP, the DEF check workflow.** `svo.adf()` → `defcheck.physical` sends
  `def` → `defs.defstart` (the header line) claims it, clears parry state →
  each line fires `defs.def_<name>` → `defs.defline` (the count line) adds
  `defcheck_physical` to the ledger → at the prompt its `oncompleted` clears
  `me.manualdefcheck` and calls `svo.process_defs()`. That clears every
  defence in `defc` not on the list (through `gone` if the dictionary has
  one), adds every listed defence you did not have (through the action's
  `oncompleted(true)` if there is one), and schedules `defs.defprompt`, which
  prints your defences and the "additional" ones and empties both lists.
- **GAP, the defup workflow.** `defs.switch(mode, echoback, nodefup)` sets
  `defs.mode`, `rift.precache`, and (unless `nodefup`) `sys.deffing`; starts
  `defences.defup_timer`; raises `svo switched defence mode` and
  `svo started defup`; and calls `make_gnomes_work` and `defupfinish`. Every
  defence action's `isadvisable` checks `(sys.deffing and
  defdefup[mode][def]) or (conf.keepup and defkeepup[mode][def])`.
  `svo.defupfinish()` (from `onprompt` and `switch`) asks
  `sk.have_defup_defs()`, which lists defup defences you lack that are not
  skipped, ignored (`svo.ignore`), dragon-incompatible, or `nodef`, sorted by
  `aspriority`, marking a defence `(?)` when svof has no balanceful or
  balanceless action for it. When nothing is left it clears `sys.deffing`,
  prints the time, raises `svo done defup`, and emits `donedefup`.
  `quietswitch` only changes mode and precache.
- **GAP, login.** `sk.loginonbasic` switches to `basic` with `nodefup` on
  the first `charname`/`gmcpcharname`, then disconnects from those two and
  stays on `relogin` only.
- **NEW, defect (masked).** The `relogin` handler at line 3234 collects
  `t[#t+1] = defc` instead of the name, so it calls `defences.lost(defc)`
  and clears nothing. It is masked because `reset.defs` runs on
  `gmcpcharname` at every login. Pre-existing (xml line 4428).
- **NEW, three runtime-registered defences.** `enablemindnet`,
  `enablelifevision`, and `enableshroud` each add a `defs_data` entry and (for
  lifevision and shroud) a `svo.dict` entry at runtime, create their own
  temp triggers **outside** `svo.defencetemptriggers`, snapshot priorities,
  rerun `dict_setup` and `dict_validate`, report priority changes, and emit
  `dragonform`. Each runs on a `systemstart` `tempTimer(0)` when its `conf`
  flag is set, or from a `gmcpcharitemslist` scanner that sets the flag,
  raises `svo config changed`, and disconnects itself. Defects, all
  pre-existing: the scanners' `if not t.location == 'inv'` guard never fires;
  the phylactery match has a double space (`"a  phylactery of sixth
  sense"`); `enableshroud` registers only `on[1]`/`on[2]`, so the Blood
  Maiden cloak line never counts; and after a class change their triggers
  are not killed, so each is created again.
- **GAP, persistence.** `saveconfig` writes `<home>/svo/defup+keepup/`
  `defup`, `keepup`, `ignored_defences`, and `offline_defences` (the
  `offline_defence` defences you have); `defload` reads them back and
  re-grants the offline ones.
- **Defects in the data, all pre-existing:** `lipread.specialskip` reads an
  undefined global `mindseye`, so it is always skipped; `rest.off` has a
  stray second string; Kaido `boosting.onenable` sets heartsfury instead of
  regeneration; the occultism simulacrum `offr` and an alchemy empower `on`
  line carry the placeholder `<fix me, insert character name here>`.

## `Custom_prompt.lua` (loader `customprompt`)

- **WRONG** "51 of them". There are **64** `cpp` functions: 55 named
  `compute_*`, `unknown_stats`, and 8 generated in two loops
  (`compute_<stat>_percent` and `compute_<stat>_colour` for health, mana,
  endurance, and willpower). The table misses the 8 generated ones plus
  `compute_age`, `compute_anathemabal`, `compute_manifestation`,
  `compute_wrathbal`, and `compute_wrath`. Many exist only for a skillset;
  where a skillset is absent, the tag is still defined as `"''"`.
- **WRONG** "`cp.makefunction(tbl)` then compiles the token list".
  `cp.makefunction()` takes no argument. It returns unless
  `conf.customprompt` is set **and** `sk.logged_in`; it calls
  `cp.generatetable(conf.customprompt)` itself, compiles
  `return table.concat({...})` with `loadstring`, and falls back to an empty
  display (with a `debugf`) if that fails. If the prompt uses `@gametarget`,
  `@gametargethp`, `@weaponmastery`, or `@servertimestamp`, it also sends
  `sys.ingamecustomprompt` (a `CONFIG PROMPT CUSTOM` line, two variants in
  Setup) so the game prompt carries those fields, and gags the confirmation
  with a one-shot trigger.
- **GAP, when it runs.** `makefunction` is connected to `gmcpcharname` (the
  comment says login, not `systemstart`, so the in-game prompt can be set),
  runs immediately if the system is already loaded, and runs again from
  `cp.adddefinition`. Until then `cp.display` returns `''`.
- **GAP, who renders it.** `cp.display()` is called by the
  `after_prompt_processing` custom prompt handler (`Controllers.lua:364`)
  and by `svo.showprompt()` (`Miscellaneous_functions.lua:204`, into the
  `svo.bottomprompt` window when that is in use).
- **NEW, defect.** Literal text between tags is emitted as `'...'` without
  escaping, so an apostrophe or backslash in `conf.customprompt` makes the
  compile fail and the prompt goes blank.
- **Minor.** `@essence` is defined only for `necromancy`, although
  `compute_essence` also exists for `oppression`.
- **OK, with a precision.** Every Mudlet `color_table` name becomes its own
  `^<name>` tag that emits `<name>`; the doc's "prompt tag argument" is
  imprecise. `systemstart` also copies `conf.customprompt` into
  `conf.oldcustomprompt` if that is unset or `'off'`.

## `Serverside.lua` (loader `serverside`)

- **WRONG, the core meaning of `svo.serverignore` (line 2354 and nearby).**
  `serverignore[action] = true` means **the server cures it and svof skips
  it**: `check_herb` and the rest skip an action when
  `conf.serverside and svo.serverignore[i]`, and
  `sk.shouldignoreserverside(action)` is true when `not serverignore[action]`
  (svof keeps it). So `setup_default_serverignore()`, which runs only when the
  table is empty, sets **every** serverside-capable action to `true` (hand it
  to the server) and then `impale`, `lovers`, and `selfishness` to `false`
  (svof keeps them; the comments say the server does not stack writhing,
  handle lust, or remove selfishness). The doc's "the things svof would rather
  cure itself" is the inverse.
- **WRONG** "`sk.notifypriodiffs()` reports when the compression changed the
  meaning ... tells you when that happened." It has nothing to do with the
  25 cap and prints nothing. `notifypriodiffs(before, after)` diffs two
  snapshots and raises `svo prio changed` for every action whose index moved.
  It is the event source for paths that change many priorities at once
  (`prio.import`, and the runtime `enablemindnet`/`enablelifevision`/
  `enableshroud`, which rerun `dict_setup`).
- **GAP** `sk.sendpriorityignore` sends `26` for an affliction but `reset`
  for a defence, and returns while `svo.logging_in`.
- **GAP, `sk.shouldignoreserverside(action)`** is true when the action is on
  `svo.ignore`, is kept by svof (`not serverignore`), is a defence that is
  off keepup (outside defup) or off defup (during defup), or its dictionary
  `onservereignore()` says so.
- **GAP, `sk.splitdefs(balance, list)`** does more than split: it drops
  `uncurable` and `irregular` actions, moves defences that are on
  defup/keepup and not ignored into their own list, moves ignored defences
  and ignored afflictions into two "disabled" lists (which then get
  `sendpriorityignore`), and drops every other defence (including
  `undeffable` ones). `sk.splitbals` is the slowcuring step, splitting
  `action_balance` names by balance.
- **GAP, the triggers for a sync.** `sk.priochangetimer` is a
  `tempTimer(0)` debounce set by `svo prio changed` and by
  `sk.handleserversideswitch`, which is connected to `svo ignore changed`,
  `svo keepup changed`, `svo serverignore changed`, `svo switched defence
  mode`, and `svo done defup` (plus a `_keepup` variant that only reacts for
  the current mode). Those connections are **blocked** at `svo system loaded`
  when serverside is off, and unblocked or blocked again on
  `vconfig serverside`.
- **GAP, `vconfig serverside` on.** Resets the cache, takes a blank
  before-state (every priority negative, so everything differs), sends
  `PRIORITY RESET`, forces a full sync, runs every dictionary
  `onprioswitch`, and then mirrors `healthaffsabove`, `mosshealth`,
  `mossmana`, keepup (`defences on/off`), focus, clot, insomnia, `clotat`,
  siphealth and sipmana (0 unless the server handles `healhealth`/
  `healmana`), curemethod (as `transmutation` and `fallback` on/off), and
  `manathreshold`.
- **GAP, the other mirrors.** `sync` switches between the `normal` and
  `slowcuring` curingsets. `paused` uses `svo.force_send` (not the queue) so
  `curing on/off` keeps its order. Focus is toggled from `svogotaff`,
  `after_prompt_processing`, and every config change, and turns off while
  you have cadmus unless `focuswithcadmus` and one of `me.cadmusaffs`. Clot
  turns off while `corrupted` and health is under `sys.corruptedhealthmin`.
- **GAP, login.** `svo.setupserverside()` runs on `charname` and
  `gmcpcharname`, sends `curingset new normal` and `curingset new
  slowcuring`, and opens a 5 seconds plus ping window (`svo.serversidesetup`)
  in which the curingset or alias limit messages count.
- **NEW, possible defect.** `sk.updateserversideprios` returns early while
  `svo.logging_in` or before `svo.systemloaded` **without clearing
  `sk.priochangetimer`**, and every scheduler only arms a new timer when that
  field is nil. So if a sync is scheduled during login (for example by
  `loginonbasic`'s `svo switched defence mode`) and fires before the
  "Password correct" line clears `logging_in`, no later change reaches the
  server until `vconfig serverside` is toggled. Whether it happens depends on
  the order the game sends `Char.Name` and that line; not verified live.

## Trace 3 (`vset`) against the code

- **WRONG, step 2.** The `vset` path takes no before-snapshot. The alias
  body is `svo.prio.insert(matches[2], matches[3], matches[4], true)`. The
  before-state is `sk.priosbeforechange`, which the **previous** sync left
  behind (blank at `svo system loaded` and on `vconfig serverside`).
- **WRONG, step 3.** `prio.insert` shuffles the list itself and sets
  `aspriority` (or `spriority` for slowcuring) on each moved action; it does
  not call `prio.sortlist`.
- **WRONG, step 4.** `prio.insert` raises `svo prio changed` **once per
  moved action**, not once. The first listener arms the debounce timer; the
  second runs that action's dictionary `onprioswitch` (health, for example,
  which has no server priority).
- **OK, steps 5 and 6**, with the stuck-timer caveat above; the send goes
  through `svo.sendcuringprio`, which batches into `sk.dosendprios` on its
  own `tempTimer(0)`. After sending, the sync stores a fresh before-state.
- **WRONG, step 7.** No compression report exists. Everything past 25 is
  silently pooled at 25.
- **NEW, defect.** `prio.insert` for `slowcuring` at an empty slot calls
  `insertat`, which indexes `svo.dict[<action_balance>]['slowcuring']`
  and errors; and an action that is not in the list errors at
  `t[oldnum] = nil` with a nil index.

## `svo (core)`: migration guard, updater, class management, utilities

### `svo.remove_legacy_modules.lua`

- **WRONG, all five helper descriptions.**
  - `installed(list)` takes a list and returns the subset still registered
    (`getModulePath`), not a yes/no for one name.
  - `backup(module)` does **not** save settings. It copies the module's
    **xml file** to `<path>.svof-backup`, only once (an existing backup is
    never overwritten), because Mudlet 4.16's own profile save can truncate
    synced module xmls. Settings live under `<home>/svo/` and are untouched.
  - `try_remove(list)` pcalls `uninstallModule` on every name and ignores the
    result, because a refusal returns false rather than raising.
  - `sweep(found, attempt)` sorts the bootstrap module (`svo (install me in
    module manager)`) last, removes, and retries every 2 seconds up to
    `MAX_ATTEMPTS = 4`, checking what is still installed each time.
  - `finish(found)` clears `svo.removing_legacy_modules` **first**, reports
    removed or not, and if the bootstrap's own uninstall handler cleared
    `svo.systemloaded`, reruns `svo_init_system` under pcall and checks
    `systemloaded` afterwards.
- **GAP** The entry point returns for a `sysInstall` of any other package,
  and while a sweep is already running. Everything waits `SAVE_DELAY = 3`
  seconds so Mudlet's post-install profile save finishes first; backups are
  taken after that delay too. The list is the 25 **old** module names, kept
  deliberately even where `src/` renamed the group.

### `svo.classchange.lua`

- **GAP** Step 2 also **deletes** every `defc` entry with no `defs_data`
  record, on every `Char.Status` message, class change or not.
- **WRONG** step 8, "Unpause serverside if the system is not paused". It
  calls `svo.app("off")`, svof's own unpause; the serverside `curing on`
  follows only through the `paused` config mirror when serverside is on.
- **GAP** also: `sk.gettingfullstats = false`, and `saveconfig` is emitted
  on the **old** bus before reinit (see Load and init).

### `Check for system updates/`

- **WRONG** "`svo_checkupdatestart` ... calls
  `svo.checkforupdates(nil, true)`". It calls
  `svo.checkforupdates("checking", true)`, so the automatic check (at most
  once an hour) announces "Checking for updates..." and the result.
- **GAP, the whole flow.** `svo system loaded` → `svo_checkupdatestart` →
  `checkforupdates(kind, automatic)` sets `svo.checkingupdates` and
  `svo.announceupdates`, arms a 60 s timeout, and calls `getHTTP` →
  `sysGetHttpDone` → `svo.update_http_done` (ours only per
  `update_response_is_ours`) parses JSON, records `pending_update_tag` and
  the `svof.mpackage` asset URL, and either says you are current, says the
  release has no package, installs straight away for `force`, or calls
  `showupdatereminder(latest)`. **Install** click → `svo_doupdate_click` →
  `install_update(version, url)` saves config, sets `svo.update_target`
  (`<home>/svof-update.mpackage`), and `downloadFile` → `sysDownloadDone` →
  `update_download_done` defers one turn with `tempTimer(0)` (to dodge a
  use-after-free while Mudlet walks its handler list) →
  `install_downloaded_package` checks for the end-of-central-directory
  record, uninstalls `svof` (up to 4 tries, 2 s apart, checking
  `getPackages()` each time), installs the file, confirms with
  `package_installed`, deletes the download, and asks for a restart.
  `sysDownloadError` → `update_download_error` matches the target against
  every argument and reports that nothing changed.
- **NEW** A release with **zero** assets counts as installable (the
  fallback URL is built from the raw tag); only a release that has assets
  but no `svof.mpackage` is refused up front.

### `svo_Class_Management.lua`, `svo.registerhit.lua`

- **WRONG** "`svo.enableclass(class)` and `svo.disableclass(class)` toggle
  a class's trigger group". No trigger group is touched. `enableclass`
  increments a counter in `svo.enabledskills[skill]` for each of the class's
  three skillsets in `svo.classes`, marks `svo.enabledclasses[class]`, and
  raises `svo enabled class`; `disableclass` reverses it. What "class
  tricks" change is whatever reads those tables: the three Vodun/Puppetry
  anti-illusion triggers (reject the line unless `vodun` or `puppetry` is
  enabled), the rebounding trigger, the blackout `aff` action (assume
  crippled limbs against `necromancy`, suspect asthma/anorexia against
  `curses`), `codepaste.checkdismemberkill` (only with `sentinel`), and the
  `tn`/`tf` aliases.
- **GAP, the detection flow.** 179 trigger lines call
  `svo.startedfighting(class, name)` → `valid.gothit` claims
  `gothit.happened` and records `tempmap[name or '?'] = class` in the
  ledger, so an illusion discards it → at the prompt its `oncompleted`
  raises `svo got hit by` → `svo.registerhit` counts it (only while the
  class is not yet enabled), enables at `conf.classattacksamount` hits within
  `conf.classattackswithin` seconds, and arms a disable timer.
- **WRONG (minor)** "a timer for `60 * conf.enableclassesfor` minutes". The
  `tempTimer` is `60 * enableclassesfor` **seconds**, so
  `enableclassesfor` is in minutes.

### `svo Utilities/`

- **WRONG** "They contain data, not functions" (the six strategy files).
  Each strategy is `{ desc = "...", function () ... end }`: a description for
  `vconfig2` and a **predicate at index 1**, which the dictionary runs
  under pcall when that strategy is enabled. They read `svo.affl`,
  `svo.me.locks.*` (filled by `Controllers.lua:801`), `svo.gettreeableaffs()`
  (`Empty_cure_handling.lua:92`), `svo.es_potions`, and
  `me.pipes.valerian.puffs`. Oddities, all harmless: the shrugging
  `any2affs`/`any3affs` count **tree**-curable afflictions; `rage.any2affs`
  says "one of them is rage-curable" but only counts afflictions.
- **WRONG** "`svo.inslowcuringmode()` reports whether `sys.sync` is set". It
  returns `affl.retardation or affl.aeon` from the public list.
- **WRONG** "`svo.ccnop` is its no-op counterpart". `ccnop` is `cc` without
  the pause check: it still reports while paused. Both skip slow curing.
  `docc` routes by `conf.ccto` (pt, clt, tell, ot, army, team, echo, or a
  clan name).
- **WRONG** "`svo.doubleRunToSend(cmd)` deals with doubled speedwalk
  commands". It sends its arguments only on the second call within 0.4 s: a
  double-press guard for keys.
- **GAP** `svo.preattack()` sends `stand` when prone outside slow curing.
  `svo.shipprompt()` only records `me.shippromptn`.
- **NEW** an anonymous `svo system loaded` handler registers a `@mem`
  prompt tag (Lua memory use). With `@exits`, `@EXITS`, `@affs`,
  `@paracelsus_affs_customtag`, and `@target` from the two tag files, that is
  six tags that exist only through `svo.adddefinition` at runtime, none in
  `cp.definitions`. All are registered with `registerAnonymousEventHandler`
  at script-body time.
- **WRONG** "`svo.autopause_on_def.lua` ... pauses the system when a
  configured defence goes up". Nothing is configured: it pauses on gaining
  `blackwind` or `astralform` (remembering if you were already paused) and
  unpauses on losing either unless you were.
- **WRONG** "`svo.isenemy.lua` ... defers to NameDB if it is present". It
  returns true when the global `target` starts with the name, else calls
  `ndb.isenemy(name)` unconditionally.
- **WRONG** "`svo.sitting.lua` and `svo.sleeping.lua` ... track the two
  postures". On losing `prone`/`sleep` they remove the `svo.ignore` entry
  that was set with the reason "you sat down"/"you wanted to sleep".
  `sitting` raises `svo ignore changed`; `sleeping` does not, so a
  serverside sync is not scheduled for sleep.
- **GAP** `svo_autoslickprio` is registered on three events, but the
  `svo got aff`/`svo lost aff` calls pass an affliction name, never
  `'herb'`, so it only ever acts on herb balance regain, including the swap
  back.
- **OK, precision** `stupidityCheckTable` has 21 entries but 20 keys (the
  "cannot settle down to sleep" line is listed twice). Its one caller is the
  `StupidityValid` symptom trigger.
- **NEW** `@affs.lua`'s abbreviation table mixes vocabularies: it has
  `asleep`, `impaled`, and similar GMCP-style names that svof never stores,
  so `sleep` and `impale` print unabbreviated. Bleeding shows only at or
  above `conf.bleedamount`.

### `svo_Time_Tracking.lua`, `svo UI Experiments/`, `Examples/`

- **NEW** `svo.sync_time` and `svo.tic_time` have **no callers** in
  `src/`. The local clock never starts.
- **WRONG** "`svo UI Experiments/` ... not wired into the main system".
  `Rift_label_dimensions.lua` creates `svo.riftlabel`, the herbstat window
  that `Rift.lua` (`update_riftlabel`), `Config_system.lua`
  (`conf.riftlabel`, `herbstatsize`), and the `vshow herbstat` alias use.
  The other two come alive through the `makechat` alias: with the Vyzor
  package installed it builds `svo.ui.chat` (a tabbed chat frame) and calls
  `svo_enableCommChannel()`, after which `svo_captureChats` copies channel
  lines into it on `gmcp.Comm.Channel.Start`. Without `makechat` they are
  inert.
- **WRONG** "Six demonstration files". Five, and **all five ship
  inactive** (`isActive: no`); two also return on their first line
  (`if true then return end`) until edited. `eventaffs`, which the comments
  ask you to enable, is a deprecated option forced on.
- **WRONG (Penlight table)** "`pretty.write` is how svof serialises its
  configuration": config is saved with `svo.tablesave` (see Config).

## `svo (core)/3rdparty/`

### Penlight

- **WRONG, "unmodified library code".** Every file ends with
  `package.loaded['pl.<name>'] = <name>` instead of `return <name>`, which
  is what lets them run as Mudlet script items; the item order in
  `scripts.json` is dependency order (utils, tablex, stringx, lexer, pretty,
  path, class, List, Map, OrderedMap, dir, config). `pl.operator` is not
  vendored, so any `tablex`/`List` call given an operator string such as
  `'=='` fails at `require`.
- **GAP, what svof actually uses.** Setup binds seven modules into
  `svo.pl`: `pretty`, `config`, `dir`, `path`, `string` (stringx),
  `OrderedMap`, `tablex`. Real use outside Penlight: `dir.makepath` (8
  directories under `<home>/svo/`), `pretty.write` (the priority export at
  `Priorities.lua:105`, and debug output), `tablex.keys`/`imap`/`find_if`/
  `reduce`/`map`/`index_map`, and `OrderedMap` for **four** tables:
  `svo.actions`, `svo.lifevision.l`, `svo.defs_data`, and
  `svo.config_dict` (the doc names two). `stringx.import` is never called.
- **NEW, semantics that matter to svof.** An OrderedMap stores entries as
  fields on the object, so `set(key, nil)` is the only removal that also
  drops the key from the order; a plain `map[key] = v` is invisible to
  `iter`. `set` re-appends a key whose current value is `false`. No svof key
  collides with a method name (checked for `defs_data` and `config_dict`).
  `svo.deepcopy` keeps metatables, so the `checkstun` ledger snapshot and
  restore stay OrderedMaps.
- **NEW** `utils.lua` defines globals on Lua 5.1: `table.pack`, `_G.pack`,
  and `package.searchpath`.

### luanotify (`notify/`)

- **NEW, modified from upstream.** `Signal:connect(fn, name)`,
  `add_pre_emit`, and `add_post_emit` take a name, and connecting a name
  that is already present **replaces** that handler: that is what makes the
  named `connect` calls in loaders safe to rerun on the same bus. Both files
  register through Lua 5.1's `module()`.
- **NEW, latent defect.** The replacement looks the name up in one queue
  (`handler_names`) and removes by that index from another (`handlers`).
  `DoubleQueue:push_back` ignores a value that is already present, and
  `disconnect` never removes the name, so every unnamed connect after the
  first on a signal pushes a handler without a matching `""` name, and the
  two queues drift apart. 11 of the 214 `connect` calls in `src/` pass no
  name. The drift is one step for Setup's two unnamed `systemstart`
  handlers, but it **grows during play** where an unnamed handler is
  connected and disconnected repeatedly: limbcounter does that on
  `before_prompt_processing` for every limb hit, peopletracker on `newarea`
  each time `clearlabels` is toggled, and elistsorter on `elistcaptured`
  per dispose. Once misaligned, reconnecting a name that is already present
  removes a **different** handler and leaves the old one connected. Within
  one init no name repeats on those signals (checked: the only duplicate
  name in `src/` is `sk.check_burrow_pause` on `gmcproominfo`, the same
  function, which dedupes), so it bites only when a loader reruns on a live
  bus, for example when a script is saved in the editor.
- **NEW** `pre_emit` functions run LIFO, not FIFO as their docstring says:
  both lists use `push_front`.
- **OK** `block`/`unblock` are counted per handler, and a handler blocked
  twice needs two unblocks.

## The addons

- **GAP, how each addon hooks into init.** Ten have a `svo.loader.<name>`
  called from `svo_init_system`'s addon list, so they rerun on every class
  change. NameDB is different: `ndb_load` is registered with
  `registerAnonymousEventHandler("svo system loaded", ndb_load, true)`,
  **one-shot**, and `ndb.init()` (the database) runs at script-body time.
  The module era did the same with `tempTimer(0, ...)`, so this is
  pre-existing.
- **NEW, consequence of the one-shot (pre-existing).** Everything
  `ndb_load` connects to `svo.signals` lives on the first bus only. After
  the first class change (dragonform included) the new bus has none of:
  the three `saveconfig` handlers (highlightignore list, city politics,
  `VACUUM`), and `svo.signals["namedb finished honors"]`, the signal NameDB
  creates for itself. So highlightignore and city-politics edits made after
  a class change are not saved; `ndb.loadsettings`, which runs on every
  `svo system loaded`, then reloads the stale city-politics file over the
  table at the next class change, reverting them. (Reasoned from the code,
  not tested.) Honors chaining survives only through the separate
  anonymous `svo got balance` handler.
- **WRONG** (elistsorter) "That is the only place outside `Setup.lua` that
  creates one [signal]". NameDB also requires `notify.signal` and creates
  `svo.signals["namedb finished honors"]` (`ndb_main_code.lua:912`).
- **GAP, the anonymous handlers.** Besides NameDB's two, script-body
  `registerAnonymousEventHandler` calls exist for the `@mem`, `@exits`,
  `@affs`/`@target`, and `@bl` prompt tags, `svo_count_show`'s
  `changelimbcount` option, and enchanter's `gmcp.Char.Items.List` →
  `svo.check_ourobori`. They are what the reinstall-leak item in CLAUDE.md
  refers to.

### limbcounter

- **OK** the class list (14) and trigger-group switching, with gaps:
  "svo Blademaster limbcounter" and "svo None limbcounter" groups do not
  exist, so those two classes enable nothing (silent no-op), and the
  Shikudo branch tests `me.path == "Shikudo"` while Setup stores
  `'shikudo'`, so Shikudo monks get no limbcounter (the unreachable branch
  also calls a misspelled `disablTrigger`).
- **NEW, defects, all pre-existing:**
  - `svo.lc_smash()` (fired by the `svolc Don't register 2` trigger) calls
    `signals.before_prompt_processing:disconnect(sk.svo.lc_checklimbcounter)`
    with no local `signals`, so it always raises.
  - `svo.lc_priestdamage` is initialised as a boolean and then redefined as
    the toggle function that overwrites itself with a boolean: the second
    call raises.
  - `get_other_prepped` compares a count with the function
    `svo.lc_prep_at`, so "also prepped" is never reported.
  - `lc_sethitsneeded` and `lc_synchits` read a global `lc_lasthit` (never
    set) instead of `svo.lc_lasthit`, so "sync" always says it is tracking
    nobody; `lc_show`'s empty check compares a table with `{}`.
  - `lc_countshow` only has hit tables for Runewarden; Infernal and Paladin
    index a nil table.
- **GAP, flow.** `svo.lc_hit` queues `{limb = damage}` in a local
  `hittable`, enables the two "Don't register" triggers, and connects
  `lc_checklimbcounter` to `before_prompt_processing`, which applies the
  damage, raises `svo limbcounter hit`, reports, and disconnects itself.
  Three prompt tags are registered at loader time with
  `svo.adddefinition`.

### burncounter

- **WRONG** "six operations, matching the six triggers": seven operations
  from seven triggers (the doc's own list has seven), plus
  `svobl Don't register`.
- **NEW, defects, pre-existing:** `svo.bl_ignore()` calls `table.remove`
  on a string (the queued action), so the "Don't register" trigger always
  raises; `bl_reset('all')` rebinds the local `bl_list`, leaving
  `svo.bl_list` (which the `@bl` tag reads) stale.
- **GAP** it uses `block`/`unblock` on one unnamed
  `after_prompt_processing` handler (connected once), not
  connect/disconnect.

### elistsorter, enchanter, peopletracker, priestreport, refiller, inker

- **WRONG** (elistsorter) "`svo.es_captured(isvlist)` ... restores
  `config pagelength`". `es_captured` prints the report and emits
  `elistcaptured`; the `svo_Capture_elist_stop` **trigger** restores the
  page length to `conf.pagelength` (at least 20). `es_dispose` sets 250.
- **WRONG** (enchanter) "`svo.reenchant` is defined twice ... The second
  definition wins." The first (line 871) is inside a `--[[ ]]` comment.
  Also the engine runs as a **balanceful function**:
  `svo.addbalanceful("enchantment step", enchantmentStep)`, which sends
  every balanceless step at once and stops at the next balanceful one.
  `enchant` is the local that queues an order, not "the send". It stops
  keeping selfishness and riding **up** and afterwards sets keepup to
  whether they **were up**, not to the old keepup setting. The trailing
  reload block is commented out, so saving the script does not rerun the
  loader.
- **WRONG** (peopletracker) "five options with ... `onmenu`": none has
  `onmenu`. **GAP** it both listens to `mmapper updated pdb` (redrawing at
  the prompt through `sk.onprompt_beforeaction_add`) and, from its own
  triggers and the `qwho` alias, raises it.
- **WRONG** (priestreport) `svo.trace(name)` takes no argument (it is the
  timer callback). **NEW, defect:** the loader forces
  `conf.reportdelay = 2` and `conf.bettertrace = true` on every run, so
  those two options never persist. The loader returns unless you are a
  Priest or an Apostate.
- **WRONG** (refiller) "`svo.rf_check_trans` ... checks whether you have
  Transmutation". It checks for **Transcendent Remedies** and
  **Transcendent Toxicology** (`rf_transrefiller`, `rf_transtoxicology`),
  which raise the batch from 10 to 12 and change the multiplier from 5 to
  4; its `break` stops at the first match, so having both reads only one.
  The vial-shuffling commands are aliases, not in this script.
- **NEW** (inker) `svo.ti_interrupted()` with `autoreink` off cancels
  (clearing `svo.ti_inking`) and then indexes it: raises. Inking pauses
  svof (`svo.app('on')`) and unpauses when done. The `autoreink` messages
  print a literal `&lt;0,250,0&gt;` (double-escaped in the original xml).

### NameDB

- **GAP, schema.** 33 columns; the doc's list misses `iff` (the manual
  enemy or ally override that `ndb.isenemy` checks first), `importance`,
  and `level`.
- **NEW, defect (pre-existing).** `ndb.loadhighlights()` calls
  `collectgarbage('stop')` and returns early when `conf.ndbpaused`,
  **without** restarting the collector. With name highlighting paused,
  every call (at load, and from every highlight option change) leaves
  Lua's garbage collector stopped until something else runs a full
  collect.
- **GAP** `ndb.getinfo` (the website API path) is commented out of
  `honors_next` ("Achaea disallowed use of website scraping"), but the
  `Honors` **trigger** still calls `ndb.getinfo(ndb.honorsname)` on every
  HONORS, so each honors also downloads
  `api.achaea.com/characters/<name>.json`, which `ndb.downloaded_file`
  (on `sysDownloadDone`) merges and follows with a second
  `NameDB finished honors`. `ndb.doexport`'s underscore-field pruning never runs
  (`not next(t) == nil`). `ndb.valid.classes` has four classes the
  plural table lacks. `Stats.lua` creates a **global** `stats` table and
  `Pluralization.lua` global helpers.

### mindnet, fishdist, logger, offering, and the trigger-only folders

- **OK** as described. fishdist uses a global `fdistance` and appends
  `@fishdist` to `conf.customprompt` on enable (and raises if no custom
  prompt is set). offering's `corpse_stuff` restores selfishness by
  queueing the `vkeep selfishness on` alias, which the do queue runs with
  `expandAlias`.

## Triggers (read through a flattened dump of all 2,799 items)

Method: `scratchpad/flatten.py` walks every `triggers.json`, prints each
item's path, own and effective active state, non-default flags, every
pattern with its type, and its script (inline or from the `.lua`). All
manifest keys are known ones (no unrecognised keys). Totals: 2,799 items =
258 folders + 2,541 triggers; 2,420 `.lua` files (7 of them folder
scripts), 64 inline scripts, 64 triggers with no script: the doc's counts
check out.

### The prompt chain (`General > Prompt`)

- **WRONG** "Under `Prompt > Capture flags` sit `Eq`, ..., `Prayer` and
  `Do stuffs.`". `Do stuffs.` is a sibling of `Capture flags`, not a child.
  `Prompt`'s four children are `Capture flags`, `Blackout`, `Do stuffs.`,
  and `Kai-Shin blackout`.
- **NEW, this is where `svo.paragraph_length` is counted.** `Prompt`'s only
  pattern is a Lua function: `if isPrompt() then return true else
  svo.paragraph_length = svo.paragraph_length + 1 return false end`. So
  every non-prompt line adds one, and the five `General > Cleanup` triggers
  (rebounding aura gone, breath exhaled, blank line, reflections gone,
  meditation broken) subtract one so those lines do not count.
  `svo.onprompt` resets it to 0 (`Controllers.lua:285`). Every
  `paragraph_length > 2` illusion test in the dictionary depends on this.
- **GAP, how balance and equilibrium are read.** `Capture flags` is a
  **filter** trigger (`.* ([a-zA-Z@]*)(?:\<.*\>)?(?: Vote)?-`): its script
  records `svo.had_balance`/`had_equilibrium` and calls
  `svo.valid.setup_prompt()`, which clears `bals.balance`,
  `bals.equilibrium`, and `svo.pflags` (or, on a blackout prompt `-`, sets
  both arm balances to `'unset'`). Its children then run against only the
  captured flag letters: `e` and `x` set the two balances, `b`, `d`, `k`,
  `c`, `@` set `pflags`, `E` sets `bals.prayer`. `Do stuffs.` then compares
  had/has, raises `svo lost balance` or `svo got balance` for **balance and
  equilibrium only** (skipped while `svo.innews`), times the gap, and calls
  `svo.onprompt()`.
- `Blackout` (`-` or ` Vote-`) and `Kai-Shin blackout` (`-<n>-`) call
  `svo.blackout()`.

### Cure containers

- **OK** the multiline containers (`Ate`, `Sip`, `Smoke`, `Apply elixir`,
  `Applied salve`, `Focus`) each open on the first line of a cure and have
  a `lua: return true` child first (`ate1`, `sip1`, `smoke1`, ...) and
  another near the end (`ate2`, ...), which is how the empty-cure flag pair
  brackets every result line. Result children call
  `svo.valid.<kind>_cured_<aff>`, `herb_cured_<aff>`,
  `svo.defs.gotherb_<def>`, and similar. Some children only call
  `setTriggerStayOpen("<container>", 1)` to keep the window open over an
  extra line (tick stole, emptied salve, mangled limb, hypothermia).
- **GAP** `Tree cures` is a **folder with patterns** ("You touch the tree
  of life tattoo." plus a spacer), active, acting as its own chain head;
  its comment "this folder is supposed to be off" is stale (copied from
  `General cures`).
- **GAP, blackout curing.** `General cures` ships inactive. `svo
  .check_generics()` (`Main_trigger_functions.lua:3388`) turns it on for
  blackout or a passive-cure paragraph via `enable_generic_trigs()` (3379), which
  also **disables** `Ate`, `Sip`, `Smoke` and the non-existent `Applied`
  and `Focus mind` (the known unresolved names), so during blackout
  `Applied salve` and `Focus` stay on alongside the generic set.
- Balance regain lines are single triggers in `General`: herb, moss, sip,
  salve, purgative (two lines), focus, smoke, dragonheal, and tree call
  `svo.valid.got<bal>()`; "You have recovered balance on all limbs." calls
  `svo.gotbalance()` and "You have recovered equilibrium." `svo.goteq()`.
  Class balance folders (Hydra, Monk, Prayer, Voice, Domination, Shrugging,
  Humour, Fitness, Rage, Word, Age) set `bals.*` directly or through
  `svo.valid.used/got<bal>balance`.
- **Server-side output**: `[Curing]: X` → `svo.curingcommand`,
  `[System]: Running queued ... command: X` → `svo.queuecommand`; a set of
  gag triggers hide serverside confirmations when `gagserverside`.
- **Login and editors**: `svo connect` matches the Achaea banner, calls
  `svo.connected()`, pauses (`svo.app("on", true)`) unless already paused,
  and sets `svo.innews`; the news, composer, and registration triggers set
  and clear `svo.innews` and pause and unpause around them.

### Small defects seen in trigger bodies (all pre-existing unless noted)

- `Symptoms > Full, injured, or restrained arms` tests
  `affs.unwknowncrippledarm` (typo) and, like `Damaged arms`,
  `missingleftarm`/`missingrightarm`, which svof never sets.
- `Prayer balance > svo lost prayer`'s last regex has `(w\+)` and
  `incleansing`, so it never matches.
- `General > prompt` (resets `Focus`) ships inactive and is dead since the
  fire-length fix, per its comment.

### NEW: trigger bodies that call handlers nothing defines

Method: `scratchpad/harness.lua` loads `Main_trigger_functions`,
`Simple_aff_trigger_functions`, `Diag_trigger_functions`, `Defences`, and
`Controllers` under a permissive stub (real Penlight, `haveskillset` true
for every skillset, the `systemstart` callbacks run once), then reads back
every key of `svo.valid` and `svo.defs`: 1,056 and 999 names, including
every loop-generated one. `scratchpad/callcheck.py` adds statically defined
names from all scripts and diffs them against every `svo.valid.X(` and
`svo.defs.X(` in trigger, alias, key, and button bodies (847 and 108 names
called). **24 call targets are defined nowhere**, and each appears in the
reference xmls only at its call site, so all are pre-existing. Mudlet
raises "attempt to call a nil value" when the line fires; no gate checks
this (`check_renamed_callsites.py` checks item names, not Lua handlers).

| Called | Fired by | Why it is missing |
|---|---|---|
| `valid.diag_calcifiedskull`, `diag_calcifiedtorso` | the two DIAGNOSE lines | not in the diag generator's list |
| `valid.diag_latched`, `generic_latched`, `tree_cured_latched`, `latched_woreoff`, `simplelatched` | diagnose, generic and tree cure, wore-off, Pervasion | `latched` is not modelled at `82e7f14` |
| `valid.tree_cured_paralysis` | `Tree cures > svo cure paralysis tree` (active) | tree list lacks paralysis |
| `valid.focus_cured_weakness` | `Focus > svo cured weakness` | focus list lacks weakness |
| `valid.curedconcussion` | `svo cure concussion` (General, active) | no handler (see the concussion memory) |
| `valid.simpleconcussion` | `Sculpting > Calcified Skull Concussion` | not in the simple list |
| `valid.simpletinderskin` | `Zeal > Tenderskin` | typo for `simpletenderskin` |
| `defs.curedblind` | `Tree cures > svo cured blind tree` (active), generic | no handler |
| `defs.cureddeaf` | `General cures > svo cured deaf` | no handler |
| `valid.sour_sparkle` | `General cures > svo sour sparkle` | no handler |
| `valid.healercure`, `emptyheal`, `nohealbalance`, `bedevilheal`, `healing_cured_insomnia` | the Healing triggers in `General` (active) | Healing was removed; triggers left behind (removed later on `gmcp-gated-empty-cures`) |
| `defs.got_spirit`, `got_boundspirit`, `got_fortifiedspirit` | `Healing + Elementalism channels > Spirit` | Spirit channel was Healing's |
| `valid.simplecheckwrithes` | two Qwindor bashing triggers (inactive) | no handler |
| `svo.lc_damagecheck` | `svo Priest limbcounter > Fragility` (enabled for Priests) | no handler; the toggle is `lc_priestdamage`, which overwrites itself |

A wider pass over every `svo.<name>(` call in item bodies (157 names)
found only that last one unresolved. Other defects of the same kind that a
name check cannot see:

- `svo Monk limbcounter > Shikudo > Hyperfocus` calls
  `svo.lc_shikudodamage(...)`, which is a string (the function is
  `lc_shikudodamagecheck`). Unreachable today because the Shikudo branch
  never enables.
- Misspelled Mudlet calls: `disableTriger("Shrine full-gone")` in the
  offering trigger (raises after it has already undone the queue) and
  `disablTrigger("Tekura")` in the unreachable Shikudo branch.
- Tekura limbcounter punches pass `svo.conf.larmdamage`, but the option is
  `armdamage`, so every punch counts as 1.

### More small trigger defects (pre-existing)

- Pattern-type mistakes that can never match: `Vodun & Puppetry >
  tonguetied` has a regex written as `exactMatch`; `Tekura > Hammerfist`
  starts `^(|w+)`; `Psionics > Transcendence empty` ends `$ - 0`; the
  last `svo lost prayer` regex (above).
- Non-multiline triggers that read `multimatches` (only filled for AND
  triggers): `Zeal > Judgement two/three`.
- `Tekura > Palmstrike` passes class `"Monk"`, which `svo.classes` does
  not have (lower case), so that hit never counts toward class detection.
- `Links To Click > Unread messages (old) > Stop` closes
  `"Unread messages"`, not the real name (the fire length of 100 closes it
  anyway).
- `fishdist > decay on pole` sets `fdistance = lineout` (a nil global)
  instead of the string.
- NameDB `Honors > Not Infamous` and `Infamous` index `temp_name_list`
  without the nil guard their siblings use.

### Per-skillset and addon trigger folders

- **OK** the doc's description: attack lines calling `svo.valid.*`, class
  detection through `svo.startedfighting(class, name)`, and warnings
  through `svo.givewarning`/`givewarning_multi`. Every `svo.valid`/
  `svo.defs` target they call resolves except the table above.
- **OK** `svo Bashing triggers` ships inactive; its scripts are almost all
  single `svo.valid.simple*`/`proper_*` calls (83 are
  `simpleprone`).
- **OK** limbcounter, NameDB list and honors capture, reboundingsileris,
  runeidentifier, stormhammer, and the `Scripting Examples` as described.
  The NameDB list triggers each follow header, capture, stop, then
  `db:merge_unique` and `raiseEvent("NameDB got new data")`, and the
  per-name `NameDB saw list name` event that re-highlights.

## Aliases, keys, buttons, resources

Read through the same flattener (`scratchpad/alias_dump.txt`,
`keys_dump.txt`, `buttons_dump.txt`) plus the raw button manifests.

- **WRONG, alias counts.** 169 aliases in 24 folders is right, but the split
  is **114** in `svo (aliases, triggers) > svo` and **55** in addons, not
  130 and 39. The doc's own addon table adds up to 55.
- **WRONG** "`vsl` ... only one counter is active at a time, so in practice
  only one fires". Neither alias is class-gated, so both fire for everyone:
  `lc_show()` and `bl_show()` both print.
- **GAP, what some aliases actually do.**
  - `vconfigs` calls `svo.aconfigs()`, which is empty.
  - `vupdate [force|checking]` calls `svo.checkforupdates(kind)` without
    `automatic`, so it is never throttled.
  - `vversion` still prints `conf.releasechannel`, the retired GitHub Pages
    channel.
  - `sit`/`lie` put `prone` on ignore with the reason "you sat down" (and
    raise `svo ignore changed`), clearing it after a second if you never
    went prone; `sleep` does the same for `sleep` without the event.
  - `b <dir>`/`ub` drive the `block` defence through keepup unless `block`
    is ignored; `vault`/`mount`/`board` remember `ridingskill` and
    `ridingsteed`.
  - `vecho <text>` feeds the text through the trigger engine
    (`feedTriggers`, `$` as a line break): the testing hook.
  - `makechat` builds a Vyzor chat window (see UI Experiments).
  - The `ndb` cheatsheet loads `<installationfolder>/ndb-help.lua` with
    `loadstring("return " .. s)`.
- **NEW, keys.** The single key, `Toggle bashing`, is bound to keyCode
  16777265 (Qt `Key_F2`) with no modifier. It starts
  `svo.dor("kill <target>")` or turns the repeating do off.
- **OK, buttons.** The root toolbar `svo` ships `isActive: no`; `Show affs`
  and the seven `Show prios` buttons call `svo.showaffs()`,
  `svo.printorder(<balance>)`, and `svo.printordersync()`. The manifests
  carry button-only fields (`isFlatButton`, `mButtonState`, `posX`/`posY`,
  `sizeX`/`sizeY`, `useCustomLayout`, `buttonColumn`, `buttonRotation`);
  several `sizeX`/`sizeY` values are uninitialised-looking (for example
  121309952 and 470220885), carried over from the original export.
- **OK, resources.** `default_prios` holds the ten lists (sip, physical,
  moss, smoke, slowcuring, purgative, salve, focus, misc, herb); slowcuring
  has 211 entries (indices up to 240, with gaps). 10,617 bytes with LF
  line endings (11,083 in a CRLF checkout). `ndb-help.lua` is 10,008 bytes,
  43 help entries, and parses as `return` plus its body.

## Mudlet event registrations (item `eventHandlerList`)

41 script items register Mudlet events through their manifest. The doc's
19-event `svo_events` list is **OK**. The full map:

- `svo_events`: CharVitals, CharName, RoomNum, RoomBrief,
  sysDataSendRequest, sysExitEvent, `mmapper updated pdb`, `svo lost
  balance`, `svo got balance`, `svo prio changed`, `svo system loaded`,
  `svo config changed`, `svo serverignore changed`, `svo ignore changed`,
  `svo defup changed`, `svo keepup changed`, `svo switched defence mode`,
  `svo done defup`, `NameDB finished honors`.
- `svo_gevents`: `gmcp.Char`, `gmcp.Room`, `gmcp.Char.Status`,
  `gmcp.IRE.Time` (Mudlet raises parent keys for child messages, so these
  four cover every subscribed GMCP message).
- `svo.savesettings`: sysExitEvent. `svo.remove_legacy_modules`:
  sysInstall, sysLoadEvent. `svo_init_system`: sysLoadEvent, sysInstall.
  `svo.classchange`: `gmcp.Char.Status`. `uninstall_all_modules`:
  sysUninstallPackage.
- Updater: `svo.update_http_done` (sysGetHttpDone),
  `update_http_error` (sysGetHttpError), `update_download_done`
  (sysDownloadDone), `update_download_error` (sysDownloadError),
  `svo_checkupdatestart` (`svo system loaded`).
- Class management: `svo.registerhit` and `ndb.setfromclass` on
  `svo got hit by`; `svo_show_classes` on `svo onshow`.
- Utilities: `svo_autoslickprio` (`svo got balance`, `svo got aff`,
  `svo lost aff`), `svo_onimportant_aff` (`svo got aff`),
  `svo.autopause_on_def`
  (`svo got def`, `svo lost def`), `svo.sitting`, `svo.sleeping`
  (`svo lost aff`), `commandTracker` (sysDataSendRequest),
  `put_vials_away` (`svo quit`).
- NameDB: `ndb.finished_honors`, `ndb.updatebyhonors`
  (`NameDB got new data`), `ndb.downloaded_file` (sysDownloadDone),
  `ndb.configs`/`ndb.loadsettings` (`svo system loaded`), `ndb.onshow`
  (`svo onshow`), `ndb.close` (sysExitEvent), `ndb.showqwi`
  (`NameDB finished all honors`), `ndb.addhighlightname` (six events).
- Other addons: `corpse_stuff` (`gmcp.Char.Items.List`),
  `svo_onshow_priestreport` (`svo onshow`), `svo.disable_seek` (`svo got
  dragonform`, `svo lost dragonform`, `svo system loaded`),
  `rf_check_trans` (`gmcp.Char.Skills`), `svo_captureChats`
  (`gmcp.Comm.Channel.Start`).
- The five inactive `Examples` scripts register `svo system loaded`,
  `svo got/lost aff`, `svo got/lost def`, and `svo done with prompt`, which
  never reach them while the items are inactive.

## Late findings, made while editing the reference

- **WRONG (count)** `raiseEvent` is called with **54** distinct names, not
  51. A pattern that requires a parenthesis misses `svo quit`,
  `svo got dragonform` and `svo lost dragonform` (`raiseEvent"x"` in
  `Setup.lua`). The document's grouped list had 49; the five missing were
  `svo before the prompt`, `svo disabled class`, `svo burncounter hit`,
  `svo burncounter reset` and `svo done refilling`. All 54 are literals.
- **WRONG** the namespace table's `sys` row ("people tracker labels"). `sys`
  is `svo.sys`, the runtime flags table; the peopletracker only hangs its
  label functions on it.
- **NEW** `empty.smoke_pear` is defined and referenced nowhere (the
  reference xml has the single definition too).
- **NEW** only two handlers define `onprioswitch`: `healhealth.sip` and
  `healmana.sip` (dictionary 484 and 531).
- **NEW** `svo.inra()` does not send `inr all` itself: it sets `sk.inring`
  and requests the inventory, and a `gmcpcharitemslist` handler sends it.
- **NEW** luanotify's `connect` is a no-op for a function already connected
  (the `handlers_block` check), which is why the duplicated
  `sk.check_burrow_pause` connection is harmless.
- **NEW, inferred** svof receives `Char.Afflictions.*` only through the
  `gmcp.Char` registration, so Mudlet must raise every level of a message's
  name with the full name as the argument. Then `Char.Status` reaches
  `svo_gevents` twice (through `gmcp.Char` and `gmcp.Char.Status`), and
  `gmcpcharstatus` is emitted twice per message. Not checked against
  Mudlet's source.
- `scratchpad/sigmap.py` (output `sigmap.txt`) maps every signal to its
  emitters and listeners; the reference's signal map is built from it.
  `svo defup changed` has no listener.

## Outcome

Every WRONG, GAP and NEW item above is applied to
`reference/svof-src-architecture.md` by exact-match edits, section by
section. New sections there: "Workflows" (startup, login, class change,
affliction gain, cure, empty cure, balance bookkeeping, illusion defences,
slow curing, defences, serverside sync, settings, persistence, updating, the
signal map, and the event registration map), the unresolved call-target
table, and a defect index. A phrase sweep for every corrected claim found
only the corrected text. The document has no em or en dashes.

<!-- END -->
