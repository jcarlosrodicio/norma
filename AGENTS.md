# norma

`norma` installs and maintains the task harness in a repository: one loop, one
verification gate, one skill library, identical whichever agent is driving,
enforced by git rather than by any single agent's hook system.

This file is the index for every agent working here. It is short on purpose: it
points at the document that owns each topic instead of repeating it.

## Required reading before any change

1. [`docs/01-architecture.md`](docs/01-architecture.md) - the pieces, and the
   **ownership boundary** the whole design rests on. Mandatory before touching
   anything under `core/` or `bin/`; getting it wrong means an upgrade destroys a
   consumer's decisions, or the consumers drift apart.
2. [`docs/02-flows.md`](docs/02-flows.md) - what `install`, `upgrade` and `doctor`
   do step by step, plus **every refusal** the gate and the hook can produce and
   the reason each one exists. Never soften a refusal without reading why it is
   there.
3. Then the document that owns your area:
   [`docs/03-skills.md`](docs/03-skills.md) for `skills/`,
   [`docs/04-testing.md`](docs/04-testing.md) for `test/`.

The documents under `docs/` are the source of truth. Where code and documentation
disagree, the documentation wins and the disagreement is a finding to report.

## Project shape

```
bin/norma          the CLI: start | install | upgrade | doctor | home | version
core/verify        the verification gate, vendored into projects unchanged
core/pre-commit    the git hook that makes the gate binding
profiles/*.sh      prefab config.sh per stack: flutter, node, pnpm-turbo, python
skills/            the canonical skill library, vendored into projects as real dirs
templates/         the documents a project owns after the first write
test/run.sh        the whole test suite, one place
VERSION            the vendored-content version, stamped into each project
```

## Non-negotiables

- **POSIX sh only** in `bin/` and `core/`. No bashisms, no arrays, no `[[`. It has
  to install into a Flutter repo and a Python one with nothing on the machine.
  Check with `sh -n` before running anything.
- **Never widen what the harness owns.** The ownership table in
  `docs/01-architecture.md` is the contract. A file the project owns is written
  once and never touched again.
- **Every behaviour change to `core/` or `bin/` lands with a test.** The gate and
  the hook are the pieces that do the enforcing; they had no coverage at all until
  late, which was the worst gap in this repository.
- **`test/run.sh` passes before you commit**, and its count goes in the commit
  message. It is fast - a couple of seconds - so there is no excuse.
- **Bump `VERSION`** when vendored content changes - `core/`, `skills/`,
  `profiles/`, `templates/` - so `doctor` can tell a consumer it is behind.
- **`--docs-only` is for `docs/`, `README.md` and `AGENTS.md`.** Everything else
  here is shipped or tested, and the gate refuses.
- **English** for code, comments, commit messages, skills and templates. These
  documents are in English too.

## The loop applies here, enforced

The full procedure for any change is
[`skills/run-task/SKILL.md`](skills/run-task/SKILL.md) - the same one this
repository installs elsewhere, chaining orient, enrich, branch, plan, implement,
verify, review, document and hand over, and stopping at the three points where a
human decides. `.agents/skills/run-task/SKILL.md` resolves to it too, so an agent
that only knows the vendored path finds it.

`norma` installs its own harness, so the gate and the hook are real here:

```
scripts/harness/verify <what you were verifying>
scripts/harness/verify --docs-only     # docs/, README.md, AGENTS.md only
```

`.githooks/pre-commit` refuses `master`, a missing or stale stamp, and code
committed against a docs-only stamp - so a branch per change is the rule here as
it is everywhere else. After a fresh clone: `git config core.hooksPath .githooks`.

The binding checklist is [`docs/harness/mandatory-steps.md`](docs/harness/mandatory-steps.md),
and [`docs/harness/architecture-rules.md`](docs/harness/architecture-rules.md) is
the adoption map - which, honestly, adopts neither shared reference and says why.

`.agents/skills/<name>` symlinks to `../../skills/<name>` rather than being a
copy: this repository is the source of those skills, so vendoring them into
itself would duplicate content that could then drift. The links stay inside the
repository, which is what `doctor` requires.

## Consumers

Three repositories install this: `tally` (flutter), `grodar` (pnpm-turbo),
`aqorin` (node). Propagation rules - including when **not** to propagate - are in
`docs/02-flows.md`.
