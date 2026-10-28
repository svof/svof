Title: Open the elemental channels with simultaneity only when none is open

Base: defences-single-source (the defences PR). Head: elemental-channels (1 commit).

---

Stacked on the defences PR.

Simultaneity opens every elemental channel at once and costs 1000 mana however many it opens, but svof could send it to reopen a single lost channel. svof now sends it only when no channel is open, and opens one or two lost channels on their own.

## What changes

- **Wanting simultaneity** on defup or keepup means wanting every channel your class has: air, fire, water, and earth for a Magi, and air, water, and earth for a Sylvan.
- **svof sends simultaneity** only when no channel is open: at the start of defup, or once all are lost.
- **A channel or two lost**, or defup with some already open, opens those alone. So does a lack of mana, or an ignored simultaneity.
- **The game's word.** `Char.Vitals` lists the open channels in its charstats ("Channels: F W A E ", or "Channels: None"). svof confirms and loses channels by it, and simultaneity is up while every channel is, by any path.

Serverside doesn't handle channels, so this is svof's alone.

## Tests

- `tools/test_defences.lua` section 22: keepup and defup with none, one, two, and all channels lost, the mana floor, an ignored simultaneity, charstats with and without Channels, and a Sylvan's three. The suite has 1297 checks, 0 failures, on top of the defences PR.
- `verify_merged --baseline`: 481 accepted differences, all matching. The dictionary, Defences, and Setup digests change.
- All other gates and Lua suites pass, and both catalogs are current.

Not tested in game yet.
