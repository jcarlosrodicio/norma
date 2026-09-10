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
bin/norma          the CLI: install | upgrade | doctor | version. POSIX sh, no deps
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
- **Bump `VERSION`** when vendored content changes, so `doctor` can tell a
  consumer it is behind.
- **English** for code, comments, commit messages, skills and templates. These
  documents are in English too.

## The loop applies here too

The procedure this repository installs elsewhere governs work here:
[`skills/run-task/SKILL.md`](skills/run-task/SKILL.md). The skills live in
`skills/` rather than `.agents/skills/` because this repository is their source.

`norma` does **not** install its own harness yet: there is no
`scripts/harness/verify` and no `.githooks/` here, so the gate is `test/run.sh`
run by hand and the stop-before-delivery rule is on you. Self-hosting is an open
question - see the end of `docs/01-architecture.md`.

## Consumers

Three repositories install this: `tally` (flutter), `grodar` (pnpm-turbo),
`aqorin` (node). Propagation rules - including when **not** to propagate - are in
`docs/02-flows.md`.
