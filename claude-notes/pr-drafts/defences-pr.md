Title: Give GMCP the final word on defences, and let players define and change them

Base: in-client-svof. Head: defences-single-source (57 commits). The elemental channels PR stacks on this one.

---

This is the defence half of making `svo.dict` the single source of truth. It separates "the game says you have this defence" from "svof's command for it finished", gives GMCP the final word on the defences it reports, as #858 did for afflictions, and builds `vcustomdef` on top: you can define defences svof doesn't know, change svof's own when the game has moved on, and share either as a file.

It also fixes 20 defects found along the way, most of them in the 2018 code.

## Why

A GMCP gain and a `DEF` listing reached svof through the same `got_<name>(true)` handler that svof's own command uses when it finishes. So a defence that came up at login, after a reload, or from serverside made svof book a command it never sent. It spent balances and pipe puffs and started waits that GMCP alone never finished. For example, a GMCP rebounding used a puff and smoke balance, then started a 9 second wait that timed out as lag, and rebounding stayed unset until the aura's text line arrived. With serverside on, one application of caloric spent salve balance twice.

Adding a defence also meant editing several places by hand, and players had no way to keep up when Achaea changed a class.

## The game's word

- **`defences.confirm` and `defences.unconfirm`** take the game's word. When svof's own command is in flight, it finishes once, with its bookkeeping. Otherwise the defence is set, and nothing is spent or started. A loss is taken at once, and an illusion verdict can't discard it.
- **GMCP's Add, Remove, and List** and a **`DEF` listing** call them.
- **Consequences move onto the records**, as `ongot` and `onlost`, so they happen whichever path set the defence: frost and temperance for Metamorphs, mindseye reclassifying blindness and deafness, astralform losing riding, viridian leaving its steed, and block's direction.
- **Once GMCP's List has arrived**, a line saying a defence is gone is dropped while GMCP still reports it, and a gain line GMCP doesn't back is dropped at the prompt. svof's own command stays in flight, so GMCP's Add or the outcome line still finishes it. These still count: a command the server sent, which the game doesn't let anyone illusion; blind and deaf, which the prompt flags decide; a GMCP name the game hasn't sent this session; and a second refusal of a separate command within 30 seconds, the loop breaker from #858. `vconfig gmcpdefechoes` shows each decision.
- **A gain line** claims whichever of svof's commands for the defence is in flight. It used to pick one balance with `pairs()`, and missed deathsight's skill.
- **The generated handlers** are remade on every systemstart, so the last class's stop answering after a class change.
- **tempest and susurrating** are read from GMCP, from your login log.

## Registering defences

- `defences.wire` makes one record's triggers, handlers, list places, and ignore entries.
- `defences.register` and `unregister` put a defence into play after systemstart and take it out cleanly.
- The phylactery's mindnet, the lifevision mask, and the Shadowcloak's shroud register through them. Their hand-made copies had drifted: their triggers piled up at every class change (shroud's went 5, 10, 15), mindnet was never lost from its line, and a phylactery lying in the room registered mindnet.
- A registered defence's command is adopted when serverside sends it or you type it.

## `vcustomdef`

`vcustomdef` lists your definitions and changes, with links. Its forms:

- `vcustomdef <name>` starts a definition. For a defence the game has, svof asks `DEFENCE SHOW <name>` and fills in the GMCP name, gain, loss, and `DEF` lines. "Profession: No" makes it every class's, and "Yes" asks which class, with a link for each.
- `vcustomdef game` reads the game's `DEFENCE LIST`, every defence GMCP reports, and lists the ones svof doesn't know as links.
- `vcustomdef svof` lists this class's own defences by skillset, each a link to change it. `vcustomdef svof all` adds every other class's, offered as a copy.
- Fields: class, skillset, command, balance, GMCP name, gain, loss, and `DEF` lines, and patterns for lines that vary (`gotpattern`, `lostpattern`, `defpattern`). `def none` says `DEF` doesn't list the defence.
- `test`, `install`, `delete`, `reset`, `export [file]`, and `import <file>`.

The rules:

- **Definitions** are saved in `svo/custom/defs`, which updates leave alone, and registered at every load. A class definition goes under one of that class's skillsets, or a skillset you type when svof's list is out of date.
- **Changes to svof's own** replace its exact lines, patterns, GMCP name, skillset, and, for a defence whose action only sends its command, the command. svof's logic stays. Changes are saved in `svo/custom/edits`. When an update changes svof's own version, svof says so, with links to keep yours or use svof's. The first install asks you to confirm.
- **GMCP names** are taken only when the game confirms them: by `DEFENCE SHOW`, by `DEFENCE LIST`, or by GMCP this session. A definition with a GMCP name is serverside's to raise while serverside is on.
- **Clashes are refused** on install and at every load: a shared line, GMCP name, or command, a pattern matching another defence's line, the name of svof's own defence in another class (offered as a copy instead), and the name of svof's own action in another class that isn't a defence, such as fitness.
- **`DEFENCE SHOW` and `DEFENCE LIST` replies** are matched to what svof asked, in order, and hidden. A late reply, after svof stopped waiting or asked something else, fills nothing and stays hidden for up to two minutes. A `DEFENCE SHOW` you type is left alone.
- **Marks:** `*` after a defence you defined and `+` after one you changed, in the defence lists, both priority lists, `vshow server`, and `vshow hidelist`, with a key.
- **`vconfig customdefinitions off`** starts svof without any of them, for a definition that breaks your curing.

## Hiding, and priorities

- **`vshow hidelist`** links each defence and skillset to hide or show it. `vshow hide` and `vshow unhide` do the same from the command line, and `vshow hidelist all` lists every class's skillsets.
- **Hiding a defence** takes it off defup and keepup in every mode, with an undo link. `vconfig showhiddendefs` lists hidden ones anyway.
- **Hide choices** are kept through a class change and back. Defect 28: they were forgotten.
- **Defence groups** are listed in the class's own order, not the order `pairs()` happens to give.
- **Priorities are kept for what svof leaves out this session:** your definitions with `customdefinitions` off, and every other class's own actions across a class change. Before, they came back at the bottom of the list. `tools/defence_catalog.lua` generates `src/resources/prio_catalog.lua`, the list of actions only some classes have.

## Defects fixed

Most are in the 2018 xmls:

- rest was never lost when a full rest ended, because its second line had no key.
- spinning was never lost from its line, because its regex was under an exact-match key.
- croonmirror was never lost, because its regex started with a stray quote.
- Fortifying air last never granted fortifyall, because of a typo in the name.
- Kaido's boosting added heartsfury instead of regeneration.
- An Apostate's demon armour strip was dropped.
- mindseye marked you deaf, and blind with blind on keepup, every time, from operator precedence.
- frost and temperance never lost themselves.
- bonding's gone sat inside its physical.
- `dict_setup` added `gone` while `pairs()` walked the entry, so Lua 5.4 and later skipped a balance in about half of the runs.
- `vconfig havemindnet` registered lifevision.
- caloric and frost sent their svof names to serverside, not insulation and temperance (confirmed by the owner).
- The phylactery was matched only with two spaces in its name.
- The three item defences' copies had drifted, as described earlier.
- A Monk's stale `lost_boosting` survived a class change.
- The generated handlers' `pairs()` pick of a balance missed deathsight's skill.
- Hide choices were forgotten on a class change.
- `sk.notifypriodiffs` raised for an action that was deleted.
- Saved priorities dropped other classes' actions on a class change (defect 29).
- The general group's hide was a no-op in the main list.

## Tests

- **`tools/svof_world.lua`** loads the shipped `src/` into plain Lua through the real `svo_init_system`, for any class, with Mudlet stubbed and recorded.
- **`tools/test_defences.lua`**, gate 1.95: 1259 checks, 0 failures, on Lua 5.5 and on Mudlet's own `lua51.dll`. Each feature's commit switched off its parts in turn, and each switched-off part fails a check.
- **`tools/check_defences.py`**, gate 1.96, checks the game lines in every defence record. Seven known findings are recorded, so a new one fails.
- **`tools/defence_catalog.lua`**, gate 1.97, fails when `defence_catalog.lua` or `prio_catalog.lua` is out of date. `check_package.py` requires both in the package.
- **`check_valid_callsites.py`** checks the `svo.defs` call sites too: 11 known dead calls.
- **`verify_merged --baseline`**: 481 accepted differences, all matching. `check_package`, the source tree, renamed call site, and dictionary field checks pass, the derived lists show their usual 35, and all 12 Lua suites pass.

## In game

Tested on a Magi in Mudlet 5.0.1, on 2026-10-18 and 2026-10-19, in 13 sessions, with svof paused except in short defup trials:

- Defining from `DEFENCE LIST` and `DEFENCE SHOW` (279 defences, 68 that svof doesn't know), every class and profession defences, GMCP names, serverside, and a GMCP gain at login.
- Changing svof's own: efreeti's command, skillset, and two new gain lines, raised live once instead of every 0.7 seconds.
- Hiding and showing defences and skillsets, including another class's, through a relaunch.
- Priorities with `vset`, `vswap`, `vexportprio`, and `vimportprio`, defup raising the higher priority first, and priorities kept through a session with definitions off.
- Export and import round trips, and every refusal and clash.
- A late `DEFENCE SHOW` reply hidden and kept out of the definition asked for after it, and a typed `DEFENCE SHOW` left alone.
- A class change to Monk with `vcleargaps` and back, using svof's own class change code, which left the Magi's own priorities in their order. The first run of this found the run of a class's own actions turning over, which `3daf75b` fixes.

## Not covered

- A capture with real `DEF` resyncs and real defence traffic over GMCP. The timing the gain gate relies on, GMCP's Add before the gain's text, is measured for afflictions and for your serverside login.
- svof's own defences that Achaea has changed since 2018, such as efreeti and waterweird. They're on the task list, as one batch.
- Changing class in game, as opposed to through svof's class change code.
