# Harness: mandatory steps

Non-negotiable steps for every implementation task in this repository. When a task
list is created or updated, these steps must appear in it, in this order, and the
agent must execute them itself. Never ask the human to run the tests.

Read `AGENTS.md` first - it is the index for architecture, constraints and commands.

Architecture criteria: [`architecture-rules.md`](architecture-rules.md) is this
project's adoption map over the shared reference in
`.agents/skills/architecture-guidelines/`. This repository's own architecture
documents win over both.

> TODO(harness): this file was generated from a template. Replace every TODO with
> what is true for this repository, and delete this note. A generic loop that does
> not name your real commands, layers and conventions is a loop nobody follows.
>
> An agent can do this with you: point it at
> `.agents/skills/harness-setup/SKILL.md` (in Claude Code, `/harness-setup`). It
> reads the repository first and only asks what it cannot infer.

## Step 0 - Feature branch (always first)

Create and switch to a branch before any edit. TODO(harness): state the naming
convention (for example `phase-NN-<slug>`). Never work directly on the default
branch.

Then open the run context:

```
scripts/harness/run start <the branch slug>
```

A task run is not an agent session. This task may be implemented in one session,
reviewed in another and corrected in a third, and that command is what makes the
three one task. It is idempotent on the same branch and **refuses** while a run
from another branch is still open. Every later step records its evidence against
it, and step 8 closes it.

## Step 1 - Plan before code

The task list must exist and be reviewed before implementation starts. Keep entries
small and mark them as completed as you go - that file is the persistent state that
lets an interrupted session resume. TODO(harness): say where the roadmap lives and
how to confirm the work belongs to the current phase.

## Step 2 - Tests first

Write or update the failing test before the implementation. TODO(harness): list
where tests live per layer, and which runner each one uses.

## Step 3 - Implement

TODO(harness): the layer boundaries of this repository, and what may not depend on
what. Say which tool enforces them, if any.

Conform to [`architecture-rules.md`](architecture-rules.md), and imitate the
canonical example: copy the structure and names of the existing reference
implementation of the pattern instead of inventing one. A deliberate deviation is
stated in the report; a silent one is a defect.

## Step 4 - Verification gate (MANDATORY, agent executes)

One command, whatever agent you are:

```
scripts/harness/verify <test target> [more targets...]
scripts/harness/verify --full        # only for cross-cutting changes
scripts/harness/verify --docs-only   # the change touches no code
```

It runs the static gates declared in `scripts/harness/config.sh`, then the tests you
named, and records the result in `.harness/verified`. It **refuses to run without a
test target**, because naming the tests you selected is part of the step - a reviewer
must be able to tell whether you picked the right subset.

`--docs-only` exists because a change that touches no code cannot name the tests
involved in it, which would leave documentation, configuration and harness work
unable to pass the gate at all. It runs the static gates and **refuses the moment it
sees a code file**, so it cannot be used to skip tests. It judges the *staged*
change when something is staged - so a documentation commit is still possible in a
tree that carries unrelated work in progress - and the pre-commit hook refuses code
committed against a docs-only stamp, so the narrower scope is not a way in.

Run **only the tests involved in this task**, not the whole suite. The full suite
runs in CI on the pull request; repeating it locally on every task wastes time and
tokens for no new information. Involved means: the tests for the code you changed,
the tests for its direct callers, and any test that asserts a contract or invariant
you touched.

**That last clause is where selections go wrong**, because those tests do not import
your code and grep will not lead you to them. Concretely: adding a database
migration involves the test that enumerates the schema's tables and counts the
migrations; changing a published contract involves its snapshot test; adding a file
anywhere involves the guardrails that scan the whole tree for forbidden patterns.
Name them even though nothing in your diff mentions them - otherwise CI finds them
for you, which is the expensive way to learn it. When in doubt about a specific test, run it - the rule trims the suite,
it does not trim coverage of the change. `--full` is for genuinely cross-cutting
changes only, and you justify it in the report.

Record what you selected, why, and the passed/failed/skipped counts. Zero new static
findings: fix them, do not annotate them away.

When a run context is open, the gate also records the mode, the selection, the
outcome and the duration into the run's evidence log. You run nothing extra for
that, it never reaches the network, and it cannot make a verification fail.

This gate is not advisory. `.githooks/pre-commit` refuses the commit when the stamp
is missing, older than the staged files, or when you are on the default branch - so
it holds for every agent and for you. After a fresh clone, restore it with
`git config core.hooksPath .githooks`.

## Step 5 - Runtime verification (MANDATORY when behaviour changed)

Unit tests do not prove the thing works. The procedure is
[`.agents/skills/runtime-verification/SKILL.md`](../../.agents/skills/runtime-verification/SKILL.md):
it decides whether the change has a surface at all, exercises the happy path and
the failure path, and says in the report what it did **not** cover. Follow it
rather than restating it here - it is maintained upstream and arrives with every
upgrade.

What this file owns is the part no installer can know: **the commands**.

TODO(harness): how this project is exercised for real - the command that boots
it, the URL or the screen, the account or fixture to use, and how you see the
effect (the log, the row, the response). The skill looks here first; leaving this
marker in place means every run has to rediscover it.

### When the change migrates a data store (MANDATORY, no exceptions)

TODO(harness): if this project migrates a data store, the real commands for the
three checks the skill requires - bring the engine up, apply the migration twice,
and apply it to a store that already has data. If it has no migrated store, say
so here and why, so nobody goes looking.

## Step 6 - Report

Write the verification report into the change folder: commands executed, results,
what was verified by hand, and what was left uncovered.

The skills for steps 5 and 7 each end by recording a machine-readable event -
a surface and a verdict, a coverage count and a finding count. Those are **in
addition to** this report, never instead of it: the findings, the file, the line
and the triggering input live here, and nothing is reduced to a score.

## Step 7 - Adversarial review (MANDATORY)

Follow `.agents/skills/adversarial-review/SKILL.md`, preferably in a fresh session
and on a different model from the one that wrote the code. TODO(harness): name the
areas that also require `.agents/skills/code-auditing/SKILL.md` - authentication,
credentials, payments, personal data.

## Step 8 - Update documentation and close the change (MANDATORY, before delivery)

Follow `.agents/skills/update-docs/SKILL.md`. TODO(harness): which documents own
which topic, and where a new decision has to be registered.

Then close the change, in **this** branch. Both halves travel in the same pull
request as the code, because neither needs it merged to be true:

1. **Close the phase where the roadmap describes it.** TODO(harness): name the
   roadmap document and how a phase is marked done here. This is the update the
   diff cannot lead you to - nothing in the code mentions the roadmap - so it is
   the one that gets forgotten, and a phase left open after it shipped is how the
   next session builds it twice.
2. **Archive the OpenSpec change**, following
   `.agents/skills/openspec-archive-change/SKILL.md`: it syncs the delta specs into
   `openspec/specs/` and moves the change folder under `openspec/changes/archive/`.
   Ordinary file operations, both of them.

3. **Close the run**, after the archive, straight into its final path:

   ```
   scripts/harness/run close openspec/changes/archive/<date>-<change>/reports/norma-run.json
   ```

   `.harness/` is runtime state and disappears; that file is what survives this
   task. After the archive, not before - closing first means the archive moves the
   summary and every link to it points at a path that no longer exists. What it
   cannot carry is the confirmation run below, because that one happens after the
   summary is sealed; `.harness/verified` and the hook are what attest to it.
   TODO(harness): if this project keeps its reports somewhere other than an OpenSpec
   change folder, say where - and if it has no OpenSpec at all, say that
   `scripts/harness/run close` with no argument prints the summary for the report.

**Then run step 4 again.** Archiving rewrites and moves files and closing the run
writes one, so the stamp is now older than the change and the hook will refuse the
commit - correctly, because it cannot tell either of them from a code edit.

Leaving either half for after the merge costs a second branch, a second review and
a second gate run, and leaves the default branch carrying code whose specs were
never applied. If the change genuinely cannot be archived yet, say so in the report
and name what blocks it.

## Step 9 - Stop

Do not commit, push, open a pull request, publish or deploy. The loop ends here and
the human reviews. Only after explicit approval, follow
`.agents/skills/commit/SKILL.md`.

**One exception, and only when the human asked for it explicitly.** A phase handed
over to run unsupervised follows `.agents/skills/auto-run-task/SKILL.md`, and that
loop ends at an **open pull request** instead: the human's review point moves from
before the commit to the pull request itself. Nothing above this step relaxes - the
gate, the tests, the runtime verification, the adversarial review and the
documentation are exactly the same, and that procedure additionally requires every
decision taken without asking to be written down and linked from the pull request.
Merging, deploying and publishing stay with the human in both modes.
