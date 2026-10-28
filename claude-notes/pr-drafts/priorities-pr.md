Title: Fix vset and vswapslow in slow curing, and refuse names they can't set

Base: in-client-svof. Head: prio-insert-gap (5 commits).

---

`vset` into an empty slow curing number raised a Lua error, `vswapslow` always asked which balances to use and then swapped anyway, and both took names that aren't cures. This fixes them, makes both say why they refuse a name, and fixes two bugs in the "svo prio changed" event that every priority change raises.

## What changes

**`vset` in slow curing.** Setting an entry such as `paranoia_focus` to a free number indexed `svo.dict` by the whole name and raised, so `vset <action>_<balance> slowcuring <number>` failed on every gap. It now splits the name the way the shuffle onto a taken number already did.

**Names `vset` can't set.** `svo.prio.insert` refuses these before anything changes, returns false with the reason, and with echoback `vset` says "Can't set that priority: <reason>.":

- an unknown action, or an action without the balance you named
- a balance with no priority list, such as `aff`, `gone`, or `waitingfor`
- a slow curing name whose table isn't a cure, such as `paranoia_aff`

Each of these raised a Lua error before. `paranoia_aff` was worse: onto a free number it went into the slow curing list, and export and import kept it there every session.

**`vswapslow`.** It checked the second balance before reading it, so it always printed "What balances do you want to use for swapping?" and carried on. It also took any name and raised on a typo. It now refuses a name the slow curing list doesn't have, with the reason, and both lines after a swap name the two in the order the swap left. The coloured line used to name them the other way round. A swap onto a free number stores a number, not the alias's string, which the priority lists couldn't sort.

**The "svo prio changed" event.**

- `svo.basictableindexdiff` listed a moved value once from each table, so every moved entry was handled twice and the event was raised twice for it. It lists each value once.
- `sk.notifypriodiffs` hid the loop's `balance` with a local of the same name, so every slow curing event carried `nil` for the new number. svof's own handlers ignore the number, so only players' scripts that listen for the event saw it.

## Tests

`tools/test_prio_insert.lua` is new, as CI gate 1.98. It extracts the real code from the source files, the way `test_slow_curing.lua` does: the priorities loader, `prio_slowswap`, `printordersync`, the priority snapshots, and the `vset` and `vswapslow` aliases. Controls put each piece of old code back and show the old failure.

- `test_prio_insert`: 418 checks, 0 failures on Lua 5.5, the 5.1 shim, and Mudlet's own `lua51.dll`. 23 mutations of `Priorities.lua` and 30 of the swap and the event code are each caught.
- `verify_merged --baseline`: 476 accepted differences, all matching. Controllers differs from the 2018 xmls for the first time, and the Priorities, Serverside, and Miscellaneous functions digests change.
- `check_package`, the call site, source tree, and dictionary field checks pass, the derived lists show their usual 35, and all 12 Lua suites pass.

## In game

Tested live on a Magi in Mudlet 5.0.1, with svof paused throughout:

- `vswapslow lethargy_herb thirdeye_herb` swapped them, said "lethargy is now > thirdeye.", and raised two events, each with its new number. Swapping back restored both.
- `vswapslow paranoia_aff ...` and an unknown name were refused with the reason.
- `vset lethargy_herb slowcuring 3`, a free number, moved it there without an error, and `vset` back to its old number restored it.
- `vset paranoia_aff slowcuring 5` and `vset nosuchthing physical 5` were refused with the reason.

## Merging with the defences PR

This and the defences PR both touch two files. Whichever merges second needs:

- `Serverside.lua`, in `sk.notifypriodiffs`: keep the defences PR's `if valid then` guard around the event, with this PR's `syncbalance` name.
- `.github/workflows/build.yml`: keep both new CI steps.

`tools/test_prio_insert.lua` already stubs the defence marks and `decho` that the defences PR's `printordersync` draws with, so it passes with the defences PR merged too.
