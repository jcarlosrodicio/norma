# Contributing

Thanks for considering a contribution. norma is small on purpose, and it enforces
its own loop on itself, so a change here goes through the same gate and the same
hook it installs everywhere else.

## Before you start

Read [`AGENTS.md`](AGENTS.md) - it is the index for humans and agents alike - and
then the document that owns your area. Two of them are mandatory before touching
`bin/` or `core/`:

- [`docs/01-architecture.md`](docs/01-architecture.md): the **ownership boundary**.
  A file the project owns is written once and never touched again; widening what the
  harness owns is the one change that can destroy a consumer's decisions.
- [`docs/02-flows.md`](docs/02-flows.md): every refusal the gate and the hook make,
  and why each one exists. Never soften a refusal without reading its reason.

## Setup

```sh
git clone https://github.com/jcarlosrodicio/norma.git
cd norma
git config core.hooksPath .githooks
```

## The rules

- **POSIX sh only** in `bin/` and `core/`: no bashisms, no arrays, no `[[`. Check
  with `sh -n`; CI runs the suite under dash.
- **A branch per change.** The hook refuses commits on `master`.
- **Every behaviour change to `bin/` or `core/` lands with a test** in
  [`test/run.sh`](test/run.sh). Conventions are in
  [`docs/04-testing.md`](docs/04-testing.md).
- **Bump `VERSION`** when vendored content changes - `core/`, `skills/`,
  `profiles/`, `templates/`.
- **English** for code, comments, commit messages, skills and templates.
- **No third-party content without a license that allows redistribution**, and an
  entry in [`NOTICE.md`](NOTICE.md) when it arrives.

## Before opening a pull request

```sh
scripts/harness/verify <what you were verifying>
scripts/harness/verify --docs-only     # docs/, README.md, AGENTS.md only
```

The gate parses every shell file and runs the whole suite in a couple of seconds.
The hook refuses a commit without a fresh stamp from it. Put the test count in the
commit message.

Do not commit credentials, local paths or anything from `.harness/`, which is
runtime state.

## Pull request checklist

- [ ] One logical change; a change to `core/` that also rewrites a skill is two.
- [ ] `scripts/harness/verify` passes, and the count is in the commit message.
- [ ] A new refusal is in the table in `docs/02-flows.md`, with its reason.
- [ ] `VERSION` is bumped if vendored content changed.
- [ ] Documentation matches the behaviour.
