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

This gate is not advisory. `.githooks/pre-commit` refuses the commit when the stamp
is missing, older than the staged files, or when you are on the default branch - so
it holds for every agent and for you. After a fresh clone, restore it with
`git config core.hooksPath .githooks`.

## Step 5 - Runtime verification (MANDATORY when behaviour changed)

Unit tests do not prove the thing works. TODO(harness): how this project is
exercised for real - a simulator, an HTTP call, the packed CLI, a browser flow -
including the failure path. Capture what you observed in the report.

Skip only when the change cannot surface at runtime, and say why.

### When the change migrates a data store (MANDATORY, no exceptions)

An in-memory or throwaway store is not the store. A migration verified only
against an embedded engine, a WASM build or a container the test framework
creates and destroys has been verified against a *fresh, empty* schema - which is
the one case that never happens in production.

So bring up the real thing and drive the change through it. If the project ships a
container definition for its own dependencies, that is what it is for:

```
docker compose -f <compose file> up -d      # or the project's own script
<the migrate command>
<the command, endpoint or screen that exercises the change>
```

Three things to check, and record them in the report:

1. **Apply it twice.** The second run must be a no-op, not an error and not a
   duplicate.
2. **Migrate a store that already has data**, not one you just created. A fresh
   schema proves nothing about a populated one, and a column that cannot be added
   to existing rows is exactly the failure this step exists to catch.
3. **Name the engine and version you ran against.** "It worked locally" without
   saying what "locally" was is not evidence - especially when the tests ran on a
   different engine than production uses.

TODO(harness): the project's real commands for the three steps above, or a
statement that this project has no migrated store and why.

## Step 6 - Report

Write the verification report into the change folder: commands executed, results,
what was verified by hand, and what was left uncovered.

## Step 7 - Adversarial review (MANDATORY)

Follow `.agents/skills/adversarial-review/SKILL.md`, preferably in a fresh session
and on a different model from the one that wrote the code. TODO(harness): name the
areas that also require `.agents/skills/code-auditing/SKILL.md` - authentication,
credentials, payments, personal data.

## Step 8 - Update documentation (MANDATORY, always last before delivery)

Follow `.agents/skills/update-docs/SKILL.md`. TODO(harness): which documents own
which topic, and where a new decision has to be registered.

## Step 9 - Stop

Do not commit, push, open a pull request, publish or deploy. The loop ends here and
the human reviews. Only after explicit approval, follow
`.agents/skills/commit/SKILL.md`.
