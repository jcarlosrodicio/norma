# Harness: mandatory steps

Non-negotiable steps for every change in this repository. The agent executes them
itself; never ask the human to run the tests.

Read [`../../AGENTS.md`](../../AGENTS.md) first - it is the index - and then the
document that owns your area.

## Step 0 - Feature branch (always first)

Create and switch to a branch before any edit. This repository has no phases, so
name it after the change: `hook-stale-stamp-hint`, `profile-rust`. Never work on
`master`; `.githooks/pre-commit` refuses it.

Then open the run context, with the branch name as the slug:

```
scripts/harness/run start <branch name>
```

It is idempotent on the same branch and refuses while a run from another branch is
still open. Step 4 records its own result against it, step 5 and step 7 record
theirs, and step 8 closes it.

## Step 1 - Plan before code

Say what you are changing and what you are not. A change to `core/` or `bin/`
that also rewrites a skill and a template is three changes; land them separately.

## Step 2 - Tests first

Every behaviour change to `core/` or `bin/` arrives with a test in
[`../../test/run.sh`](../../test/run.sh). Conventions and helpers:
[`../04-testing.md`](../04-testing.md). Write the failing test first - the suite
runs in two seconds, so there is no reason not to.

## Step 3 - Implement

POSIX sh only in `bin/` and `core/`: no bashisms, no arrays, no `[[`. Respect the
ownership boundary in [`../01-architecture.md`](../01-architecture.md) - widening
what the harness owns is the one change that can destroy a consumer's decisions.

Bump `VERSION` when vendored content changes: `core/`, `skills/`, `profiles/`,
`templates/`. `doctor` uses it to tell a consumer it is behind.

## Step 4 - Verification gate (MANDATORY, agent executes)

```
scripts/harness/verify <what you were verifying>
scripts/harness/verify --docs-only     # docs/, README.md, AGENTS.md only
```

It parses every shell file, then runs the whole suite. The selection is recorded
in the stamp even though the suite is indivisible: a reviewer reads it to know
what you thought you were covering. With a run open it is recorded in the run's
evidence log too, with the outcome and the duration - the gate does that itself,
offline, and it cannot fail a verification.

`--docs-only` refuses the moment the change touches `bin/`, `core/`, `profiles/`,
`skills/`, `templates/`, `test/` or `scripts/`, and the hook refuses code
committed against a docs-only stamp.

shellcheck is deliberately not in the gates - it is not installed here, and
wiring in a linter nobody has means the gate changes behaviour the day somebody
installs it. Adopting it means paying its findings in the same change.

## Step 5 - Verify against a real repository (MANDATORY when install, upgrade or the vendored files changed)

The suite runs against throwaway repositories with a stub adapter. That is not
the same as a real project. When `bin/norma` or anything vendored changes, drive
it through one:

```
cd <a scratch clone, or a temporary git repo>
norma install --dry-run      # read the plan
norma install
norma doctor
```

Never against a repository that carries work in progress. Running the gate there
overwrites its stamp, and your stamp would vouch for code you never tested.
See "When not to propagate" in [`../02-flows.md`](../02-flows.md).

## Step 6 - Report

What changed, the test count, what you verified by hand, and what you left out.

Step 5 and step 7 each end by recording a machine-readable event against the run -
a surface and a verdict, a coverage count and a finding count. That is in addition
to this report and never instead of it.

## Step 7 - Adversarial review (MANDATORY for changes to the gate or the hook)

Follow [`../../skills/adversarial-review/SKILL.md`](../../skills/adversarial-review/SKILL.md).
Those two files are the enforcement: a hole in them is silent, and every refusal
they make exists because something got through once.

This repository has no change folder, so the report goes **in the pull request
body**. Wherever it goes, it cannot stay only in the reviewing session: that
session ends, and whoever applies the fixes is often another one.

## Step 8 - Update documentation and close the change (MANDATORY, before delivery)

Follow [`../../skills/update-docs/SKILL.md`](../../skills/update-docs/SKILL.md).
A new refusal goes in the table in `docs/02-flows.md` **with its reason**; a new
decision goes in `docs/01-architecture.md`; a new skill goes in
`docs/03-skills.md` and in `VENDORED_SKILLS`.

Stage 8 of the loop also closes the change - the roadmap phase and the OpenSpec
archive - and **here both halves are no-ops, which is a statement rather than an
omission**: this repository is the harness, its unit of work is a change rather
than a phase, and it has no `openspec/` directory at all. Say so in the report
instead of reporting a stage done. The day either becomes true, this paragraph is
what has to change first.

Its third half is not a no-op. **Close the run:**

```
scripts/harness/run close
```

With no argument it prints the summary instead of writing a file, which is the
right shape here precisely because there is no change folder to put one in: it
goes into the report of step 6.

**Close it last, after the final run of step 4.** Everything it removes lives
under the gitignored `.harness/`, so nothing it does can invalidate a stamp - and
closing after the last verification is the one ordering where the summary carries
that verification too. A project that writes the summary into a change folder
cannot have this: there the file itself invalidates the stamp, so it closes before
the confirming run and the summary is one verification short. Here it is not, and
that is worth keeping.

A run left open is a run the next change inherits, so closing is not optional.

## Step 9 - Stop

Do not commit, push or merge. The human reviews. Only after explicit approval,
follow [`../../skills/commit/SKILL.md`](../../skills/commit/SKILL.md).

**One exception, and only when the human asked for it explicitly.** A phase handed
over to run unsupervised follows
[`../../skills/auto-run-task/SKILL.md`](../../skills/auto-run-task/SKILL.md): the
loop ends at an open pull request instead, with every decision taken without asking
written down and linked from it. Steps 0 to 8 do not relax at all. Merging and
propagating stay with the human in both modes - step 10 below is never the agent's
to trigger.

## Step 10 - Propagate, only when asked

Consumers pick up a release with `norma upgrade`, one commit each. Read "When not
to propagate" first: check the branch and `git status` of the target, stage
explicit paths, and never `git add -A`.
