# Claude Code working folder

Local only, git-ignored, and not part of svof. Nothing here ships, nothing here
is read at runtime, and no gate looks at it. It exists so the working state of a
session lives beside the code instead of only in a chat.

Created 2026-09-21 at the repo owner's request.

## What is here

| path | what it holds |
|---|---|
| `TASKS.md` | the task list. Read it at the start of a session and update it as work lands |
| `reference/` | three Cowork documents about svof, copied 2026-09-21. Reference material to consult, not work to do |
| `single-source-implementation-plan.md` | the phased plan for making `svo.dict` the single source, and for the `vconfig customaff` surface on top of it. Written 2026-09-22, four owner decisions folded in the same day |
| `verification-2026-09-21.md` | the evidence behind that date's verification pass over `src/` |

## Refer to `reference/` when you need it

The three documents in `reference/` are the spec, the refactor plan, and the
architecture map for `src/`, written by Cowork sessions that read the source in
full. They are copies, taken 2026-09-21 from
`C:\work\svof-cowork-export\from-cowork\`.

| file | what it is | how far to trust it |
|---|---|---|
| `svof-system-spec.md` | the system reference, 22 sections: the dictionary, the curing loop, the action system, defences, priorities, GMCP, and serverside. Section 21 logs every analysis error made against this codebase | verified against this checkout on 2026-09-21: 223 of 229 gated claims pass, and every structural figure reproduces |
| `svof-single-source-guide.md` | the plan to make `svo.dict` the single source of truth, in eight steps, each reversible alone | same verification run. Its Step 5b carries a wrong exception list, corrected in the file named below |
| `svof-src-architecture.md` | a file-by-file, function-by-function map of `src/`: load order, the signal bus, the prompt cycle, the trigger and alias trees, and three end-to-end traces | **counts unverified.** No harness covers them. Use it to find things, then read the code |

**Use these to locate and to orient, never as the basis for a claim about
behaviour.** Point at the section a task needs rather than reading a whole
document, and read the actual source before changing anything. The architecture
map is the largest of the three and the least checked.

Three things to know before quoting a figure from any of them:

- **The harnesses that re-derive their numbers are a different set of tools**,
  in `C:\work\svof-cowork-export\from-cowork\tools\`. They are not this repo's
  gates in `tools/`, nothing in svof imports them, and none runs in CI. Run each
  from its own directory with the repo root as the argument. On this machine the
  interpreter is `python`, not `python3`.
- **Where a harness and a document disagree, the harness is right.** The
  documents were written at a moment in time; the harnesses read the tree now.
- **The known disagreements are already written down**, in
  `C:\work\svof-cowork-export\svof-from-cowork-corrections.md`. Read that
  alongside the spec and the guide, because it holds corrections that have not
  been applied to either.

## Keep this folder and memory in step

The memory store at
`C:\Users\djsli\.claude\projects\C--work-svof\memory\` holds the durable facts:
what was agreed, what the game does, and why a piece of work is shaped the way
it is. `TASKS.md` holds what is open right now and where each item stands.

When something lands or changes, update both. A task that turns out to rest on a
fact worth keeping gets a memory; a memory that describes work still to do gets
a line in `TASKS.md` pointing at it.
