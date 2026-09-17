---
name: run-task
description: Use to run a complete implementation task end to end - a roadmap phase item, a feature, a fix or a refactor - from a vague request to code that is verified and waiting for human review. Invoke it whenever the user asks for work to be built rather than just discussed, and follow it in order without skipping stages. It stops three times for the human; use auto-run-task instead when they hand over a whole phase and want it delivered to a pull request without being asked anything.
version: 1.0.0
---

# run-task

The whole loop in one procedure. Follow it **in order**. Every stage produces the
input for the next, so skipping one leaves the following stage guessing.

It stops three times for the human: after enriching, after planning, and before
delivery. Those stops are the point of this procedure. When the human is not there
to answer them - they handed over a phase and left - the procedure is
`.agents/skills/auto-run-task/SKILL.md`, which runs these same stages and replaces
each stop with a decision it records instead of a question it asks.

## Portability

This procedure references other instructions **by file path**, never by an
agent-specific shortcut, so it runs identically whichever agent executes it. Read the
referenced `SKILL.md` and follow it.

If you are Claude Code, `/opsx:new`, `/opsx:ff`, `/opsx:apply` and `/opsx:verify` are
shortcuts to the same files; using them is equivalent. Any other agent reads the path.

The project's own rules always win over this file: `AGENTS.md` is the index, and
`docs/harness/mandatory-steps.md` is the binding checklist for the project you are in.

## 0. Orient

1. Read `AGENTS.md`. Follow it to the architecture and standards documents that the
   task touches. Do not explore the codebase freely first - documented patterns beat
   whatever a random file happens to do.
2. Read `docs/harness/mandatory-steps.md`. It is not advisory.
3. Read `docs/harness/architecture-rules.md` - the project's adoption map - and the
   reference it points at in `.agents/skills/architecture-guidelines/`. That is the
   criteria layer: what good code looks like here, and which shared rules this
   project does not adopt. The project's own architecture document wins over both.
4. Make sure the search index is serving so it reflects recent changes:
   `tgrep status`, and if it reports no PID, `tgrep serve .` in the background.

## 1. Enrich

Follow `.agents/skills/enrich-task/SKILL.md`.

Turn the request into an implementable specification. It ends with the open questions
the request left ambiguous.

**STOP.** Put those questions to the user and wait. Do not answer them yourself and
do not continue on assumptions - a wrong assumption here is paid for in every later
stage. Skip this stage only if the request already carries acceptance criteria,
affected files and non-functional requirements.

## 2. Branch

Create and switch to a feature branch before any edit, named after the roadmap phase
the work belongs to. Never work on the default branch - `.githooks/pre-commit`
refuses commits there anyway.

Then open the run context, which is what makes everything that follows one task
rather than a pile of unrelated sessions:

```
scripts/harness/run start <the branch slug>
```

**A task run is not an agent session.** This task is implemented in one session,
reviewed in another - deliberately on a different model - and corrected in a third,
and the identity that has to survive all three is the task's. That is what this
records, in a file in the worktree rather than in an environment variable, because
the reviewer is launched fresh and never inherits your environment.

It is idempotent on the same branch, so a resumed session just runs it again. It
**refuses** when a run from another branch is still open: close that one first,
or the evidence of this task lands under somebody else's identity. Starting here
and not earlier is deliberate - orienting and enriching happen before the branch
exists, sometimes on the default branch and sometimes for a task that is then
abandoned, and a run minted there would be an orphan. The cost is declared: what
you did before the branch is not correlated.

### Before the first edit

That refusal is the only one of these git can make for you. Read `git status` and
the diff against the base branch before writing anything:

- **Work in the tree that is not part of this task.** Stop and ask what to do with
  it - keep, stash, discard - and do not build on top of it. The diff your reviewer
  reads would not be this change, and the gate would vouch for somebody else's code
  as if you had tested it.
- **Commits on this branch that are not part of this task.** Ask whether to branch
  off the base instead of stacking on them.
- **A branch behind the base branch.** Update it first. Otherwise you spend the loop
  on something already fixed upstream, and the conflict arrives at delivery, which
  is the worst moment for it.

Only start from a clean, up-to-date tree. Skipping this is cheap to do and expensive
to discover.

## 3. Plan

Follow `.agents/skills/openspec-new-change/SKILL.md`, then
`.agents/skills/openspec-ff-change/SKILL.md`.

That produces the proposal, the spec and `tasks.md`. `tasks.md` is the persistent
state: mark entries as you complete them so an interrupted session can resume.

**STOP.** Show the user the task list before writing code. This is the cheapest
moment to catch a misunderstanding, and the last one before it becomes code.

## 4. Implement

Follow `.agents/skills/openspec-apply-change/SKILL.md`, respecting every step in
`docs/harness/mandatory-steps.md`: tests before implementation, the project's layer
boundaries, and the mandatory verification steps in their stated order.

**`.env.example` is yours to write; `.env` is the human's.** When you add a variable,
update the example in the same change - an example that lags the code is how the next
person gets a broken setup on their first try. Never write the real `.env`: it holds
live credentials, it is not in the repository, and overwriting it costs them
something you cannot restore. The same asymmetry holds for any local-only
configuration the repository ships an example of.

Write code that conforms to the architecture criteria you read in stage 0. Where a
rule is enforced by a tool - a dependency linter, a boundary check - the tool is the
rule. Where you must deviate, say so in the report with its reason; a silent
exception is a defect. And imitate the canonical example: the project's existing
reference implementation of the pattern beats your own preference.

## 5. Verify

```
scripts/harness/verify <the test targets involved in this task>
```

One command, any agent. It runs the static gates plus only the tests involved in the
task, and records the result - in `.harness/verified` for the hook, and, when a run
context is open, as an entry in the run's evidence log carrying the mode, the
selection, the outcome and the duration. You do not run anything extra for that; the
gate does it, offline, and a failure to record can never fail a verification. It
refuses to run without a target: naming what you selected is part of the step. `--full` is for genuinely cross-cutting changes only,
and you justify it in the report. `--docs-only` is for a change that touches no code
at all - it runs the static gates and refuses the moment it sees a code file, so it
is not a way around the tests.

Then follow `.agents/skills/openspec-verify-change/SKILL.md` to contrast the work
against the artifacts - completeness, correctness, coherence with the recorded
decisions.

Last, follow `.agents/skills/runtime-verification/SKILL.md`. The gate proves the code
does what its tests say; that step proves the thing works, which is a different
failure and the one the tests cannot see. It decides whether the change has a surface
at all, exercises the happy path and the failure path, and writes the report where
this project keeps them.

### When it comes back red

Any of the three can come back red - the gate, the contrast against the artifacts,
the runtime verification - and stage 6 sends you back here too. Before you change
anything, **name which of these four it is and quote the line that decided it**.
The reflex is to edit, re-run and hope; that is how a session spends an hour making
the wrong thing green.

- **The code is wrong.** The check is right and the change does not do what it
  claims. Fix the code - this is the **only one of the four** that justifies
  editing the implementation.
- **The check is wrong.** It asserts something the specification never asked for,
  or it encodes the behaviour this change deliberately replaces. Fix it against
  the spec, quoting in the report what backs the new assertion - and fix it by
  changing what it asserts, **never by deleting it**, skipping it, or loosening it
  until it passes. That move is indistinguishable from hiding a defect, including
  to you.
- **The harness is pointed at the wrong thing.** The selection missed the tests
  that cover the change, or the stamp is older than the file you just edited.
  Nothing is wrong with the code: correct what you named and run it again. A gate
  that refuses for a reason your change does not explain - `config.sh` naming a
  command this machine does not have - is a different thing: that file is the
  **project's**, never yours to edit your way past, so it goes in the report, and
  unsupervised it is an escalation rather than a fix.
- **Something is missing.** There is no fixture, no seam, no way to reach the thing
  under test at all. That is **work, not a retry** - it goes back to stage 3 and
  into `tasks.md`, because a capability invented at the retry point is one nobody
  planned and nobody reviewed.

**Never re-run unchanged**, expecting a different answer. A retry that changed
nothing asks the same question twice; if you cannot say what you changed since the
last run, you have not classified the failure yet. The one exception is a failure
you have classified as a **flake** - a timeout, a network blip, nothing in the diff
that explains it - and calling something a flake is a claim you back with the log
line, not a shrug. The same check flaking twice is a finding for the report, not a
third run.

**A failure you have seen before stops being a retry and becomes infrastructure.**
Not the second attempt at one failure - the same failure arriving again, in a later
task or a later session. A case the tests never covered becomes a test; a rule that
keeps being broken becomes a gate or a refusal; a decision that keeps being
re-litigated becomes a line in the documents, with its reason beside it. A loop
that skips this pays the same price for the same failure forever.

## 6. Review

Follow `.agents/skills/adversarial-review/SKILL.md`.

Best run in a fresh session with a different model from the one that wrote the code.
Architectural conformance is one of the review dimensions: a layer violation, a
primitive where a typed value belongs, or an external shape leaking past its mapper
is a finding with a file and a line, like any other.

For changes touching authentication, credentials, permissions, payments or personal
data, also follow `.agents/skills/code-auditing/SKILL.md`.

The review leaves its report **in the change**, next to the verification report.
That is what makes it survive the session that wrote it - and the corrections are
often another session, which can only read files.

Fix what it finds, then re-run stage 5. A finding you argue with instead of checking
is a finding you did not understand yet.

**Re-run the runtime verification too, not only the gate**, whenever a fix changed
behaviour rather than shape. The gate re-runs because the hook forces it; nothing
forces this one, so a review that changed what the user sees used to leave a report
describing code that no longer existed. Re-exercise the affected flow and say in the
report that you did.

## 7. Document

Follow `.agents/skills/update-docs/SKILL.md`. Mandatory, and always before delivery.
Documentation that lags the code poisons every future session.

## 8. Close the change

The work is finished; the record of it is not. Two things remain, and both belong
in **this** change rather than in a branch after the merge:

1. **Close the phase where the roadmap describes it.** Stage 7 covers the documents
   the code invalidated; this is the one no diff can point you at, because nothing
   in the code mentions the roadmap. The phase entry, its status column, the phase
   document that still reads as pending - a roadmap that lags reality is how the
   next session picks up work that is already built.
2. **Archive the OpenSpec change.** Follow
   `.agents/skills/openspec-archive-change/SKILL.md`. It syncs the delta specs into
   `openspec/specs/` and moves the change folder under `openspec/changes/archive/`.
   Both are ordinary file operations in this repository: **nothing about either
   needs the pull request to be merged**, which is the assumption that used to push
   them into a second branch.

Archiving **moves the change folder**, reports and all, so everything you wrote
into `openspec/changes/<change>/reports/` now lives under
`openspec/changes/archive/<date>-<change>/`. Point at the new path in anything that
links it, and do not go looking for the old one afterwards.

3. **Close the run**, after the archive and writing straight into its final path:

   ```
   scripts/harness/run close openspec/changes/archive/<date>-<change>/reports/norma-run.json
   ```

   It writes the durable evidence summary - the verifications with their
   selections, the runtime verification verdicts, the review coverage and
   findings, and the agent sessions that worked on this task - and then removes
   the context, so the next task cannot inherit it. `.harness/` is runtime state
   and disappears; this file is what survives the task. Where the project has no
   `openspec/`, `scripts/harness/run close` with no argument prints the summary
   and you put it in the report.

   **After the archive, not before.** Closing first means the archive then moves
   the summary, and every link to it is written against a path that no longer
   exists - the same trap the reports have.

   One thing it cannot carry, and saying so is part of reporting honestly: **the
   final confirmation run below**. Any file written after a verification
   invalidates the stamp, this summary included, so the last gate run of the task
   happens after the summary is sealed. What attests to that one is
   `.harness/verified` and the hook that refuses the commit without it.

Then **re-run stage 5**. Archiving moves and rewrites files and closing the run
writes one, so the stamp is now older than the change and the hook will refuse the
commit - correctly, since it cannot tell either of them from a code edit.

Doing this afterwards instead costs a second branch, a second review and a second
gate run, and leaves the default branch carrying code whose specs were never
applied for as long as it takes somebody to remember. If the change genuinely
cannot be archived yet - the spec sync depends on something still in flight - say
so in the hand-over and name what is blocking it. That is a finding, not a routine
deferral.

## 9. Hand over

**STOP HERE.** Report to the user:

- what was built, in one paragraph;
- the tests you selected and why, with the counts;
- what the runtime verification exercised, its verdict, and the **paths** to any
  evidence it captured - the committed report carries the file names, so this
  message is the only place the human learns where the files actually are;
- what the adversarial review found and what you did about it;
- which documents you updated, and where the phase was closed;
- that the change is archived and the specs synced, or what blocks it;
- the **run id** and where its evidence summary landed, so the human can find this
  task's sessions in whatever collects their telemetry;
- anything you left out, and why.

Do not commit, push, open a pull request, publish, merge or deploy. When the user
approves, and only then, follow `.agents/skills/commit/SKILL.md`.

## Reporting honestly

Say plainly when a stage was skipped and why. A stage reported as done without the
command output behind it is worse than a stage reported as skipped: it spends the
user's trust on nothing.
