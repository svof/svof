Title: Keep svof's idea of which pipes are lit in step with the game

Base: in-client-svof. Head: pipe-relight (1 commit).

---

With `vconfig relight` on, svof rarely kept your pipes lit. Five separate causes, all in the 2018 code, kept svof's idea of which pipes are lit apart from the game's. This fixes all five.

## What changes

- **Serverside.** With serverside on, `lightpipes` never ran, although `vconfig relight` says svof relights. Lighting takes no balance, so it runs with serverside on too, and it ignores svof's puff counts, which drift under serverside.
- **Which pipe went out.** svof guessed the pipe from the order it last lit them, and only ever marked the first pipe of a herb as out. The game names what the pipe holds ("Your pipe, containing a skullcap flower, has gone cold and dark."), so svof now marks that herb's pipes out.
- **Pipes lit by someone else.** svof believed `LIGHT PIPES` only when it sent the command, so pipes that the server or you lit stayed unlit to svof. Any answer to it marks them lit.
- **A missing tinderbox.** `litpipe` and `empty_light` looked up `lightvalerian`, `lightelm`, and `lightskullcap`, which were removed before 2018, and raised errors. `missing_tinderbox` never found them, so svof kept asking. A missing tinderbox now stops `lightpipes` and puts it on ignore.
- **Natural fire.** The light pipes trigger also takes the natural-fire line, so svof reads the answer when you light that way.

The game lines come from play logs.

## Tests

- `verify_merged --baseline`: 478 accepted differences, all matching. Three items differ from the 2018 xmls for the first time.
- `check_package`, the call site, source tree, and dictionary field checks pass, the derived lists show their usual 35, and all 11 Lua suites pass.

No new test suite covers this change, and it has not been tested in game yet.
