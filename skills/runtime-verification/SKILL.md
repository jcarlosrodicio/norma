---
name: runtime-verification
description: Use after the verification gate passes and before the adversarial review, whenever a change could show up at runtime - a screen, an endpoint, a command, a job, a migration. It is the step that proves the thing works rather than that the tests pass, so use it whenever the human asks for QA, to try it for real, to check a flow by hand, or to confirm a change actually behaves in the running system. It does not replace scripts/harness/verify, which proves something else.
version: 1.0.0
---

# runtime-verification

## This is not the gate

`scripts/harness/verify` proves the code does what its tests say. This proves the
thing works. Those are different failures and the first does not cover the
second: a suite written alongside the implementation tends to encode the same
misunderstanding, and no unit test has ever noticed that the screen renders
blank, that the endpoint answers 200 with an empty body, or that the migration
cannot be applied to a table that already has rows.

Stage 5 of the loop runs both. This file is the second half.

## 1. Decide the surface first

Three outcomes, and picking the wrong one wastes the whole step:

- **No observable surface** - an internal refactor, a type change, a build
  script. Skip it, and say in the report why the change cannot surface.
- **A command, an endpoint, a job, a store.** Run the command. Call the endpoint.
  Look at what it wrote and at what it logged. There is no interface to open, and
  opening one proves nothing.
- **A user-facing surface.** Drive the real application, not a unit test of it.

Do not open a browser or a simulator for a change with no screen. That is the
most common way this step turns into theatre.

## 2. Find out how this project is exercised

In this order, stopping at the first that answers:

1. `docs/harness/mandatory-steps.md`, the step that covers **runtime
   verification** - the project's own declaration of how it is run for real.
   That is **Step 5** in the template, but the project owns this file: it may
   have renumbered the step, renamed it, or written the whole document in another
   language. Find the step by what it covers, not by its label.
2. `AGENTS.md` and the documents it indexes.
3. The repository itself: the scripts in its manifest, a container definition, an
   end-to-end suite, a seed command.

If none of them says - or that step still carries its `TODO(harness)` marker - that
is **a finding for the report**, not permission to skip the step. Do the best
version you can reach, then say in the report both what you did and that this
project has never declared how it is exercised. The next session should not have
to rediscover it.

## 3. Exercise it

- **The happy path and the failure path.** What the user or the caller sees when
  it fails is part of the change: an unhandled exception surfacing as a blank
  screen or a bare 500 is a defect, not an edge case.
- **The real effect, not the layer you can see.** The row written, the message
  published, the file created, the entry logged, the cache invalidated.
- **Steps somebody else could repeat.** Record what you actually did, in the
  order you did it, with the inputs you used.

### When the change migrates a data store

An in-memory or throwaway store is not the store. A migration verified only
against an embedded engine, a container the test framework creates and destroys,
or a schema built from scratch has been verified against the one case that never
happens in production: an empty database.

So bring up the real engine and drive the change through it. Three checks, and
all three go in the report:

1. **Apply it twice.** The second run is a no-op - not an error, and not a
   duplicate.
2. **Migrate a store that already has data.** A column that cannot be added to
   existing rows is exactly the failure this catches, and a fresh schema proves
   nothing about a populated one.
3. **Name the engine and version** you ran against. "It worked locally" without
   saying what locally was is not evidence - least of all when the tests run on a
   different engine from the one production uses.

## 4. Capture what proves it

Evidence is what you would have to put in front of somebody to convince them, in
the cheapest form that carries it. That is decided by the surface, not by habit:

- **A screen** - one still per state that matters. Before and after where the
  change is visual; the empty state, the error state and the loaded one where
  those are the change. Name files for what they show, not `screenshot-1.png`.
- **A command** - its real output, verbatim, and the **exit code**. A terminal
  screenshot of text is worse than the text: it cannot be searched, diffed or
  quoted back.
- **An endpoint** - the request you sent and the status and body that came back.
- **A store** - the query and the rows, before and after where it matters.

**One change can touch more than one surface** - an endpoint and the screen
that calls it, a command and the rows it writes. Then it needs evidence for
each: capture per surface, not one artifact per change.

**Not video.** It was considered and dropped: it is heavy, a reviewer has to watch
it in real time to find the second that matters, and it cannot be diffed or
quoted. A sequence of stills carries almost everything a flow needs, and the
report carries the rest in words. If a bug genuinely only exists in motion, say so
and describe it - that is a finding, not a format problem.

**Keep it outside the repository** - your scratch or temporary directory:
**never inside the repository**, and never committed. A repository that collects
a screenshot per change grows forever and nobody ever deletes one.

## 5. Where to run it

Screen dumps, long logs and page snapshots fill a context window fast, and the
context you still need for the review and the documentation is the expensive one.

- If your agent can launch a subagent or a fresh context, do this work there and
  bring back the report **and the evidence paths**. The report deliberately
  carries file names only, so a delegated run that returns just the report has
  dropped the one thing the delivery needs: **hand the paths back** to the caller
  explicitly. Preferred, with that caveat.
- If it cannot, do it in session.

Either way **say which of the two it was**, the same way the adversarial pass
does. The evidence from the previous step is on disk precisely so it can be
referred to rather than pasted: a report that inlines a page dump is a report
nobody finishes reading.

## 6. The report

Write it where this project keeps its verification reports:
`openspec/changes/<change>/reports/` where the project uses OpenSpec, and
otherwise wherever the reporting step of `docs/harness/mandatory-steps.md` says -
**Step 6** in the template, under whatever label that project gave it. Some
repositories have no `openspec/` directory at all.

It carries:

- **What you ran** - the commands verbatim, the endpoint, the screen, the account
  or fixture you used.
- **The evidence** - what each file shows, in words, and its file name:
  **not the path**. This report is committed; an absolute path from this machine means
  nothing to anyone else and is exactly what the no-machine-paths rule below
  forbids. The paths themselves go in the hand-over message, or into the pull
  request when there is one.
- **What you observed** - including the failure path.
- **Not covered** - what this run does not prove. The honest list, not the
  flattering one. A reviewer reads this to know where to look.
- **Verdict** - one line, explicit, and one of three: *works as specified*,
  *does not*, or *could not be verified* - the last naming what was missing.
  Three rather than two because the third is common and collapsing it into
  *does not* is a lie in the expensive direction: a reviewer reads that as a
  broken change and goes looking for a defect that was never there. A blocked
  run is not a failed one, and saying so is the whole point of this step.

Subject to the same rule as every committed file: no credentials, no tokens, no
`.env` values, and no absolute paths from this machine.

Then record the verdict where a machine can read it, **in addition to** the report
and never instead of it:

```
scripts/harness/run event runtime_verification surface=<screen|command|endpoint|store|none> \
  verdict=<works_as_specified|does_not|could_not_be_verified> evidence_count=<n>
```

The three verdicts are the three above, unchanged - collapsing *could not be
verified* into *does not* is the same lie here as it is in the report, and a
machine reading it later cannot tell them apart afterwards. Without a run context
the command writes nothing and exits 0. **One event per surface** when the change
touched more than one, for the same reason the evidence is captured per surface.
No paths, no output, no page dumps: this is a count and a verdict, and the report
is where the words go.

## When it cannot be run at all

A credential you do not have, a paid or external service, a device that is not
here, a dependency this machine cannot install. Say so plainly in the report and
name what is missing. Under `.agents/skills/auto-run-task/SKILL.md` that is
escalation reason 3 - it needs something only the human has - and it stops the
run rather than passing quietly.

Never report this step as done on the strength of the unit tests. That is the one
failure this file exists to prevent.
