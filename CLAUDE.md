# svof - working notes

Branch `svof-muddler`. svof used to ship as 25 hand-edited Mudlet XML files,
installed as 24 modules plus a bootstrap module, with load order set by
`modules_list` and `setModulePriority`. It is now **one `svof.mpackage`**
built by muddler from per-item `.lua` + `.json` sources. The module system is
gone.

## Ground rules

**`src/` is the source of truth.** The 25 `svo (*.xml)` files at the repo root
are kept *only* as the reference that the build is verified against. Never
edit them, and never regenerate `src/` from them - `merge_svof.py` was a
one-time conversion and rerunning it discards everything written since. It has
a `--force` guard for exactly this reason. Respect it.

**Diff every file a bulk edit touches, before committing.** Scripted
multi-file edits have destroyed real code here three times: blanking the addon
group scripts also removed `ndb = ndb or {}`, `svo.buildwhosummary()` and
`svo.bl_prompttag()`; a `modules_version` regex rewrote `svo.version` in files
with no trailing newline; regenerating `src/` wiped 43 hand-written runtime
files. Each was caught by tooling, not by reading. Assume the same of the next
one.

**Verify with the tools, quote the numbers.** Do not claim a build is good
without running both checks and saying what they printed.

## Build and verify

```
java -jar muddle-all.jar                    # must be the fork, see below
python tools/verify_merged.py build/svof.xml --baseline tools/verify_baseline.json
python tools/check_package.py --luac "$(which luac)"
python tools/check_lua_syntax.py
python tools/check_renamed_callsites.py
python tools/check_src_tree.py
lua tools/test_gmcp_reconciler.lua
```

`check_package.py` opens the `.mpackage` users install, which nothing else
does - every other gate verifies `build/svof.xml`, its sibling. It checks the
archive is a readable zip, carries every file above a size floor, holds an
`svof.xml` byte-identical to the one the object-diff just blessed, and that its
`config.lua` parses. That last one matters: muddler writes the whole README
into `description = [[...]]` unescaped, so one `]]` in a README example closes
the string early, `Host::getPackageConfig` returns empty without printing
anything, and every package field silently comes back blank. `mfile` sets a
real `description` now, which keeps the README out of that string entirely.

`check_src_tree.py` catches the two ways an edit to `src/` produces nothing: a
`.lua` with no entry in the sibling json (muddler builds from the json and says
nothing about orphans), and two item names resolving to one filename, since the
lookup is `name:gsub(" ","_")..".lua"` and that is not injective. Also flags a
filename differing from its item name only in case, which resolves on Windows
and not on the Linux runner.

`check_renamed_callsites.py` exists because Mudlet does not raise on an
unknown item name - `enableTrigger"gone name"` and
`setTriggerStayOpen("gone name", 0)` are silent no-ops. Two of the 56
filename renames kept their old call sites through review and only showed up
when someone ran the package in a real Mudlet and watched what stopped
happening.

`verify_merged.py` compares the built package object by object against all 25
originals: structure, names, scripts, patterns, pattern types, alias regexes,
event handlers, behavioural flags, and top-level load order.

It splits problems in two. **Structural** ones - missing, duplicated,
misplaced or reordered items - are always fatal. **Content** ones are script
and flag differences, and the deliberate ones live in
`tools/verify_baseline.json` with a digest each - the count is in that file and
printed by the gate, not repeated in prose that cannot track it. So `--baseline` fails on
anything new *and* on any change to a difference that was already accepted.
Without `--baseline` it lists everything and exits non-zero, which is fine for
looking but useless as a gate.

When a difference is intended, regenerate the baseline in the same commit that
causes it:

```
python tools/verify_merged.py build/svof.xml --write-baseline tools/verify_baseline.json
```

Expected, as of version 65:

- load order preserved for Trigger, Alias, Script and Key
- accepted differences on `svof-muddler` all match `tools/verify_baseline.json`,
  exit 0 - the gate prints the count and the file holds it, so it isn't
  repeated here. The two most recent first-time divergences were
  `svo_checkupdatestart` (the update check is throttled now) and
  `svo count show` (its option registers on `svo system loaded`). The count
  rises whenever a file diverges for the first time, and that rise belongs in
  the same commit that causes it.

## Round 3 review and the 2026-08-23 rebase

The repo owner's third review pass (2026-08-22/23) found four more live
blockers and nine total gate blind spots across three rounds - see the git log
on `svof-muddler` for the individual commits and the PR #845 thread for the
full back-and-forth. Worth remembering past the commit messages:

- **The migration guard could truncate the user's module xmls on Mudlet 4.16.**
  `Host::installPackage` calls `saveProfile()` *before* raising `sysInstall`,
  and that save's background writer serialises whatever the trigger/alias/
  script lists hold at the moment it runs - so a sweep that empties those
  lists a few milliseconds after `sysInstall` (the old `tempTimer(0, ...)`)
  raced the writer and lost. Fixed by delaying past the save (3s) and taking a
  `.svof-backup` copy first. Not reproducible locally (only 4.22 available
  here) - taken on the reviewer's traced mechanism and repro, not verified
  independently.
- **`installPackage`/`uninstallPackage` return values cannot be trusted.**
  `uninstallPackage` returns nothing at all before Mudlet 4.20, and both calls
  return misleadingly (`installPackage` returns `{true, ""}` and defers while a
  profile save is in flight) during the ~100-200ms window after any package
  op. The only reliable check is `getPackages()` after the fact -
  `svo.package_installed()` now does this and both the migration guard and the
  updater use it instead of trusting a return value.
- **A truncated download passes a two-byte `"PK"` check.** A zip's local file
  header looks the same whether the rest of the archive arrived or not; only
  the end-of-central-directory record proves the whole file landed.
  `svo.update_looks_like_package()` checks for that now.
- **muddler writes the whole README into `description = [[...]]` unescaped.**
  One `]]` anywhere in it - an example like `svo.echof([[hello]])`, say -
  closes the long string early, `Host::getPackageConfig` returns an empty
  table on the resulting parse error and prints nothing, and every package
  field (including `svo.version`'s source) comes back blank. `mfile` now
  carries a real `description` so the README never enters that string. New
  gate: `tools/check_package.py` opens the actual `.mpackage`, which nothing
  else does - everything else verifies `build/svof.xml`, its sibling.
- **`tools/check_src_tree.py` is new**: catches an orphaned `.lua` (no entry
  in the sibling json - muddler says nothing and ships nothing) and two item
  names resolving to one filename (`name:gsub(" ","_")..".lua"` is not
  injective).

**Live coverage, not just static gates.** `C:\work\svof-live-testing`
(`make_load_test.py`, `make_update_test_r3.py`) now installs the actual built
package into a real Mudlet 4.22.0 and asserts it loads (24 checks) and that the
whole update path behaves (25 checks, including a control that reproduces the
truncated-download bug so the test can't silently stop meaning anything). This
is the class of bug no object-diff gate can see by construction - it's what
caught the missing buttons and the wrong colour numbers in earlier rounds.
Getting it into CI needs a headless Mudlet on the runner; still open.

**My own mistake this round, worth remembering:** the replay runner
(`run_replay.sh`) called `Mudlet.exe <path>` in a retry loop with no check for
whether an instance was already running. `Mudlet.exe <path>` with nothing
running *launches* Mudlet, which - having no profile loaded - opens a
profile-picker dialog and waits for a human. Every failed retry launched
another one, so the user ended up manually dismissing a stream of these. Fixed
by guarding every forward on a live-instance check and having the runner wait
for the profile to actually finish loading (`--profile <name>` loads directly,
no Connect needed; the mirror log prints
`errors_<profile>| *** starting new session ***` when it's ready) before
forwarding anything. A second, related trap: the "throwaway" test profile
wasn't actually thrown away between runs, so a stale test package re-ran its
body on the next profile load and overwrote the results file with the wrong
verdict. Full mechanics in the `mudlet-live-testing-via-package-injection`
memory - read it before touching that tooling again.

**This round's live testing covered install/load/update mechanics, not
curing.** Nothing new was learned here about how curing itself behaves in
play - that knowledge is from the two captured Achaea fights in an earlier
session and lives in the `svof-curing-live-behaviour` memory /
`svof-live-testing/HANDOFF.md`. The "wanted: a capture with real `DEF`
resyncs" gap from that work is still open and still needed for live coverage
of the defence List reconciler (G8).

**Rebasing a stack where every commit touches a derived baseline: every
commit conflicts, and that's expected, not a problem.** Do not hand-merge
`tools/verify_baseline.json` - it's a file of digests, there is no meaningful
manual resolution. Resolve each conflict by rebuilding from the tree at that
point and regenerating with `--write-baseline`, then continue. The only
conflicts worth reading by hand are in `build.yml`. Two traps hit this round:
`--onto <new> <oldbase>` needs the *previous tip of the layer below*, not
`<tip>~N` guessed from a commit count - guessing wrong replays the wrong
commit range and produces a bogus conflict in unrelated source (`Setup.lua`,
here); and a freshly-regenerated baseline will look byte-different from the
committed one on Windows purely from CRLF, so any "did the rebase lose
anything" check has to compare at the JSON id/digest level, never with `diff`
on the raw file.

To prove a rebase didn't drop content, diff each layer's own contribution
before and after, excluding the derived baseline and the blob-hash header
lines (`^index `) - real edits show up as real diff lines regardless of the
base commit's tree:

```
git diff <oldbase> <oldtip> -- . ':(exclude)tools/verify_baseline.json' | grep -v '^index '
git diff <newbase> <newtip> -- . ':(exclude)tools/verify_baseline.json' | grep -v '^index '
```

All four branches rebased clean and are green on Linux CI: accepted differences
match `tools/verify_baseline.json` on every layer, with #848 carrying one more
than the rest from its own first-time divergence. `test_gmcp_reconciler.lua`
green on #847, and green along with `test_lifevision_validate.lua` on #848.
Both suites print their own check count - don't repeat it here, it has gone
stale every time it has been written down.
Pre-rebase tips are kept as local `prerebase/*` branches in case anything
needs comparing against them.

**Comment rot around the baseline count happened three separate times** (33,
then 50, then stale-79-vs-81) before the count was removed from prose entirely
- `build.yml` now says the baseline file holds it and the gate prints it,
rather than repeating a number that a rebase or a rewording will immediately
make wrong again. Don't reintroduce a hardcoded count anywhere near that gate.

See the "CI" section below for the CRLF-on-Windows-vs-LF-on-Linux class of
bug that bit twice in checks added for the second review pass (the
duplicated-resource-file check, then the reference-xml hash pin) - the same
lesson this rebase reapplied rather than a new one.

- `check_lua_syntax.py`: 2800 chunks parsed, **0 errors** under real 5.1 -
  the ones you see locally are entirely 5.5 artifacts, confirmed by CI.
  CI installs Lua 5.1.5 and passes `--strict-version`, so it fails rather than
  check against the wrong grammar. Locally it reports them if your `luac` is
  5.2+, and prints a loud banner saying so: `goto` as an identifier, a `\/`
  escape, and two Penlight const assignments are all legal 5.1. Never
  "fix" code to satisfy a newer luac. The one exception so far was a real
  bug as well: the Blademaster slash lookback's `\w+`, legal 5.1 but read
  there as the letter `w`, so the pattern never matched.

**The gate had nine blind spots across three review rounds and all are closed -
do not reintroduce them.** Round three found five more, every one of which let
a package that cannot work verify clean: item trees in the wrong
`<XxxPackage>` wrapper (both tools took any wrapper's children, so 2317
triggers moved into `ScriptPackage` verified fine and none could ever fire);
an absent `isActive`, which read as "yes" here and as *inactive* to Mudlet;
the 51 synthetic module wrappers, which nothing compared to anything, so a
body plus `isActive="no"` in one passed; a kind with no expected items, which
made `src/timers/` an unguarded entry point; and `--write-baseline` writing
the file and *then* saying it refused, turning 79 entries into 62 on a run
that exited 1.

The four from earlier rounds. A differing item count used to `continue` past the whole subtree,
which meant the only two trees that differ that way (the bootstrap folders,
holding the updater, the migration guard and `svo_init_system`) were the
one part nothing checked. And package-only items were digested by *path*,
so their bodies could change forever without the digest moving. The test
for both: put `error("sabotage")` in `svo.remove_legacy_modules` keeping
the item count, rebuild, and the gate must FAIL. It used to pass.

Third: the reference xmls are in the same working tree, so a change applied
to BOTH sides was invisible - `send('quit')` in the reference xml and in
`src/` verified clean. Their hashes are pinned in
`tools/reference_xmls.json`, checked before any comparison; regenerate with
`--write-reference` only when you meant it.

Fourth: `_norm_colour` re-spelled `ANSI_COLORS_F{16}_B{2}` as `FG16BG2` and
called them equal. They are different colours - the legacy numbers are palette
indices that `XMLimport::remapColorsToAnsiNumber` rewrites on load - and that
normalisation let all 6 colour triggers ship converted to colours the game
never sends. The table now lives in `xml2muddler.LEGACY_TO_ANSI` and the gate
imports it, so the converter and the gate cannot disagree.

`describe()` must also keep checking `isPerlSlashGOption` - dropping perl
`/g` from all 7 triggers that had it verified clean before it did, and that
silently under-counted rift parsing.

`isColorTriggerFg`/`isColorTriggerBg` are deliberately NOT compared: XMLexport
writes them from derived state and XMLimport never reads them back, so they
are export-only. Measured with the pairing `verify_merged.py` actually uses:
5082 comparisons, 12 differences once `flag()` has normalised the spelling -
all derived, none behavioural. The "5570" figure quoted in early rounds was
never measured this way and the tools/verify.py comment that used to repeat it
now says so instead of repeating a number. Boolean attributes are normalised
through `verify.flag()` because Mudlet writes "no" where muddler writes "".

A number that moves is a real signal. Investigate before explaining it away.

`test_gmcp_reconciler.lua` is a logic-level test for the six GMCP
affliction/defence handlers in `Setup.lua`. It extracts that block from the
real source by anchor text and runs it under a stub `svo`/`sk`/`conf`/`gmcp`/
`signals` environment - the code under test is a substring of the shipped
file, not a reimplementation, so it cannot silently drift from what actually
ships. It proves the reconciler's logic (name parsing, the svoatoss/svodtoss
removal gate, the unknownany guard, once-per-event call counts), and nothing
about Mudlet integration or actual play. Run it with a real Lua - it doesn't
need 5.1 specifically, since none of the constructs here are version-
sensitive, but CI runs it under the same 5.1.5 the syntax gate uses anyway.

## The stack

The conversion and the fixes are **separate PRs**, stacked, at the repo
owner's request: fixes landing on the conversion branch make the conversion
untestable. Trunk is `in-client-svof`, and all branches live in `svof/svof`
(you have push there) because `gh stack` does not support cross-fork stacks.

```
in-client-svof
└── svof-muddler              #845  conversion only
    └── gmcp-handler-fixes    #846  G3/G4/G7 G5 G6 G9
        └── gmcp-list-reconcilers  #847  G2/G8 G1 + test
            └── gmcp-illusion-interaction  #848
```

Accepted differences match `tools/verify_baseline.json` on every layer; #848
carries one more than the rest, from its own first-time divergence.

All four green on Linux CI as of the 2026-08-23 rebase (see above). #845 is out
of draft; #846-848 are still drafts and need `gh pr ready <n>` when they're
wanted for review.

Stack #849. Manage with `gh stack view` / `gh stack submit --auto --remote
origin` (the `--remote` is required - two remotes are configured). Editing a
lower layer means rebasing every layer above it before resubmitting.

The two TEMPORARY debug-echo commits are deliberately **not** in the stack.
They live on `debug-echoes-for-testing`, along with the pre-split history on
`backup-svof-muddler-with-fixes`.

## CI

`.github/workflows/build.yml` builds muddler from the fork, builds the
package, and runs the gates plus the reference xml check. The **build job
runs anywhere** so the conversion is verified on the PR proposing it. The
**release job is still fork-only** - verifying anywhere is safe, cutting an
svof release from an unplay-tested conversion is not.

**The tests must run under Lua 5.1, and your local lua is 5.5.** Both
extract-the-real-block tests were written with `load(src, name, "t", env)`,
which is 5.2+; 5.1 wants `loadstring` plus `setfenv`. They passed locally and
failed on CI. They now branch on `setfenv`. To exercise the 5.1 branch
locally, shim it:

```
lua -e 'loadstring=function(s,n) return load(s,n) end; setfenv=function(f,e) debug.setupvalue(f,1,e) return f end' <test>
```

Releases never happen from a push. The `release` job runs only from a manual
`workflow_dispatch` with the release box ticked, tags `v<version>` from
`mfile`, and refuses if that release already exists.

The muddler cache is keyed on the **resolved commit**, not the branch name.
Keying it on the branch meant the first jar built from `svof-fixes` was reused
forever, so moving a muddler fix forward had no effect - which is exactly how
the first CI run built with the commit before the ordering fix and shipped a
reordered package. Every run logs which muddler commit built the package.

**Build on Linux before believing a build.** A local Windows build and a CI
build are never byte-identical, for two harmless reasons: line endings (CRLF
locally, LF in CI - the size delta is exactly the CR count) and `<path>`
separators (`\` vs `/`, 2718 of them). `<path>` is muddler's own bookkeeping
for finding the `.lua` at build time; Mudlet's own exports contain none of it.
Content is identical once both are normalised, so never treat a hash mismatch
between the two as a defect.

That difference is not the point, though. The point is that filesystem
enumeration order differs between the two, and that is a real source of
silently reordered packages. Verifying only on Windows hid one.

**The same class of bug bit twice more, in checks added for the second review
pass.** The duplicated-resource-file check (`cmp` between `default_prios` at
the repo root and its `src/resources/` copy) and the reference-xml hash pin
(`reference_hashes()` in `verify_merged.py`) both compared/hashed raw checked-
out bytes. Both passed locally and both failed on CI - the resource check on
one file, the hash pin on all 25 at once - because Windows' `core.autocrlf`
rewrites LF-stored files to CRLF on checkout and Linux doesn't. Fixed by
normalising line endings before comparing/hashing in both, and reverified
against the actual git blob content (`git show HEAD:<path>`, not the working
tree) before trusting either fix. **Any new check that reads a file's raw
bytes needs that same verification before it can be trusted** - a passing
local run proves nothing about what Linux CI will see.

## Toolchain

The build **requires the fork** `TheLastDarkthorne/muddler`, branch
`svof-fixes`. Upstream muddler cannot build svof correctly: it drops nested
group attributes, zeroes `multilineDelta`, cannot represent a raw keyCode,
crashes on colour patterns, and mis-orders groups by directory read order. The
result looks fine and is silently wrong.

All of it is reported upstream now: four fixes in muddler PR #57, directory
read order in #59, buttons in #60 (issue #58). Until those merge the fork is
still required. `MUDDLER_REF` is pinned to the commit `45616f1`, not to the
branch, so the tool that built yesterday's package builds today's.

Buttons: upstream muddler ships a `Button` class that **nothing constructs**.
`App.groovy` builds five packages and yields five; there is no sixth. A
project with a populated `src/buttons/` builds clean and button-free -
"Scanning for buttons" never prints. The fork adds `ActionPackage` and
completes `Button` (its constructor set none of its declared fields). This
is why svof's 8-button toolbar vanished in the conversion, and it was *not*
`xml2muddler.py`'s fault - worth remembering before blaming this repo's
converter for a missing item type.

**DeMuddler is not in the build path** and must not be added to it. It was
evaluated for the initial import and abandoned after three silent data-loss
bugs, all reported. The import was done once with `tools/xml2muddler.py`.

## How svof initialises

Each script defines `svo.loader.X = function() ... end`. `svo_init_system`
runs on `sysLoadEvent` and `sysInstall` and calls 22 required subsystems then
10 addons in explicit dependency order, so init does not depend on item order.
It bails early if Penlight is not loaded or any subsystem is missing. It
emits `svo.signals.systemstart`, then raises `svo system loaded`.

Anything needing the core must register on `svo system loaded`, the way
`@exits.lua` and `@affs.lua` do. **`tempTimer(0, ...)` is not safe for this.**
As separate modules it was enough to get behind the core; in one package a
script can run before `svo_init_system` does. That assumption broke ndb main
code and the burncounter prompt tag.

Related: paths. `svo.installationfolder()` used to derive from
`getModulePath`; it now returns `<profile>/svof`, which is where Mudlet
unpacks the package. Files the system reads at runtime must live in
`src/resources/` - muddler copies that to the package root.

## Still open

- No sustained play testing yet - whether tracking and curing hold up under
  pressure over a long session is still unknown. What is already covered:
  two captured Achaea fights analysed for curing behaviour (54/54
  afflictions cured, zero Lua/regex errors - see the
  `svof-curing-live-behaviour` memory) and 49 live checks on the
  install/load/update path (below).
- The muddler directory-read-order bug is filed as PR #59. It is worse than
  the fork's first fix assumed: sorting shallowest-first with a stable sort left ties in
  filesystem order, which is alphabetical on NTFS and arbitrary on ext4, so
  the same sources built a differently ordered package on a Linux runner. Ties
  are now broken by path. That platform-dependence is the strongest part of
  the eventual report, and it has a clean repro: same commit, clean on
  Windows, reordered on Linux.
- The 25 reference xmls cannot be retired while `verify_merged.py` depends on
  them. Their hashes are pinned, which makes editing one deliberate but not
  impossible - pinning to a git revision would be stronger.
- 9 item names (12 recorded file/kind/name entries) that do not exist,
  recorded in `tools/known_unresolved_names.json`. All are absent from the
  2018 xmls too, so they are pre-existing silent no-ops, not conversion
  damage - but `enableTrigger('Applied')` and `enableTrigger("Focus mind")`
  sit beside three siblings that do resolve, and `"svolc Don't Register"`
  differs from the real item only in case. Fixing them is a behaviour change
  and wants its own commit.
- The root `default_prios` and `ndb-help.lua` are vestigial; only the
  `src/resources/` copies ship. CI fails if they drift, but retiring the root
  copies is the real fix.
- **Loading the built package is covered now**, but only locally, not in CI.
  `C:\work\svof-live-testing\tools\make_load_test.py` + `run_replay.sh`
  install `build/svof.mpackage` into a throwaway Mudlet 4.22.0 profile and
  assert the system came up: 24 checks covering `svo.systemloaded`, conf and
  config_dict sizes, both data files readable at `installationfolder()`, the
  package metadata reaching Lua, one svo folder per kind, and no module
  machinery left. `make_update_test_r3.py` does the same for the whole update
  path, 25 checks including a control that reproduces the bug being fixed.
  Getting these into CI needs a headless Mudlet on the runner and is still
  open.
- **`svo.update_repo` points at the testing fork** (`TheLastDarkthorne/svof`),
  matching where the README and `doc/index.rst` send people to download from
  - but neither location has a release carrying `svof.mpackage` yet, so the
  in-client updater is honest (it now says so rather than 404ing) but inert.
  Flagged explicitly to the repo owner as his call: both move back to
  `svof/svof` together whenever the release job's fork-only gate does, and
  someone has to cut the first package release somewhere before either path
  is real.

## Existing users stay on the old version - deliberately

Decided by the repo owner on 2026-08-23, while the conversion is still being
tested. **Merging the stack must not reach a single existing user, and does
not.** Do not "fix" this.

The old system's updater has two halves pointing at two different places, and
the merge touches neither:

- **version check** polls gh-pages, not the repo:
  `http://svof.github.io/svof/<releasechannel>/current_version.txt`.
  `stable` holds `34` (the per-class `*.Svof.v34.zip` downloads), `inclient`
  - the default - holds `65`, and the modules on `in-client-svof` already
  carry `svo.version = "65"` (in `svo (setup, misc, empty, funnies, dor).xml`).
  Both populations compare equal and are told "you're all good".
- **download** pulls raw xml from the branch root,
  `github.com/svof/svof/raw/in-client-svof/svo (…).xml`. Those 25 files are
  the verification references and the whole stack leaves them byte-identical
  (`git diff in-client-svof <tip> -- "svo (*.xml)"` is empty), so even a
  forced re-download gets what it gets today.

The new updater is a **completely disjoint** mechanism: GitHub Releases API ->
`svof.mpackage` asset. The release job never writes `current_version.txt`.
There is no bridge, and that is the intent for now.

**The one way to break this: bumping `inclient/current_version.txt` past 65
while the branch xmls stay frozen at 65.** Old clients would download, land
back on 65, re-check, see the higher number and download again - an update
loop that never delivers anything. The two halves have to move together, or
the old channel has to be retired deliberately. Neither should happen until
the package is play-tested and someone has actually cut a release.

Nothing user-owned is at risk either way: user data lives under
`<profile>/svo/` (config, prios, defup+keepup, rift+inv, pipes, namedb) and
the conversion only moved `installationfolder()` to `<profile>/svof/`, which
holds read-only shipped content (`default_prios`, `ndb-help.lua`).
- **The anonymous-handler leak on same-session reinstall was found but
  deliberately not fixed in #845.** `registerAnonymousEventHandler` keeps its
  own registry that uninstall never touches, so reinstalling in one session
  leaks handlers - 9 call sites across 7 converted files would need ids
  recorded and cleaned up. Bodies are idempotent, so there's no observable
  effect today; fixing it is a real behaviour change with a wide blast radius
  for no current user-visible gain, which reads as stacked-fix work rather
  than conversion work. Asked the repo owner whether he'd rather it land here
  anyway - answer pending as of the last reply on #845.
- **The actual goal**, deferred from the start: make `svo.dict` the single
  source of truth, so adding an affliction stops needing ~10 edits across
  files. Everything above is groundwork for this.

## Conventions

- In public issues, refer to svof by name and link only - no description of
  what it is.
