# Harness: mandatory steps

Non-negotiable steps for every change in this repository. The agent executes them
itself; never ask the human to run the tests.

Read [`../../AGENTS.md`](../../AGENTS.md) first - it is the index - and then the
document that owns your area.

## Step 0 - Feature branch (always first)

Create and switch to a branch before any edit. This repository has no phases, so
name it after the change: `hook-stale-stamp-hint`, `profile-rust`. Never work on
`master`; `.githooks/pre-commit` refuses it.

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
what you thought you were covering.

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

## Step 7 - Adversarial review (MANDATORY for changes to the gate or the hook)

Follow [`../../skills/adversarial-review/SKILL.md`](../../skills/adversarial-review/SKILL.md).
Those two files are the enforcement: a hole in them is silent, and every refusal
they make exists because something got through once.

## Step 8 - Update documentation (MANDATORY, always last before delivery)

Follow [`../../skills/update-docs/SKILL.md`](../../skills/update-docs/SKILL.md).
A new refusal goes in the table in `docs/02-flows.md` **with its reason**; a new
decision goes in `docs/01-architecture.md`; a new skill goes in
`docs/03-skills.md` and in `VENDORED_SKILLS`.

## Step 9 - Stop

Do not commit, push or merge. The human reviews. Only after explicit approval,
follow [`../../skills/commit/SKILL.md`](../../skills/commit/SKILL.md).

## Step 10 - Propagate, only when asked

Consumers pick up a release with `norma upgrade`, one commit each. Read "When not
to propagate" first: check the branch and `git status` of the target, stage
explicit paths, and never `git add -A`.
