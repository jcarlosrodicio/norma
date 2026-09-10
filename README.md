# norma

The task harness, extracted so it can be installed into any repository. One loop,
one verification gate, one set of skills - identical whichever agent is driving,
because everything is referenced **by file path** and enforced by **git**, not by
any single agent's hook system.

```sh
git clone <this repo> ~/Nasito/Desarrollo/norma
ln -s ~/Nasito/Desarrollo/norma/bin/norma ~/.local/bin/norma

cd ~/some/project
norma install --dry-run    # see what it would do
norma install              # do it
norma doctor               # what is still missing, and what you must fill in
```

`install` detects the stack from its manifest, or takes `--profile`. Sixteen are
shipped:

| | |
|---|---|
| **JS/TS** | `node` · `pnpm-turbo` · `next` |
| **Mobile** | `flutter` · `swift` |
| **Systems** | `go` · `rust` |
| **JVM** | `java-maven` · `gradle` (Java/Kotlin/Android) |
| **Python** | `python` · `django` |
| **Web frameworks** | `laravel` · `ruby` (Rails) · `elixir` (Phoenix) |
| **Other** | `dotnet` · `terraform` |

**A profile is a starting point, not tested support.** Each one is verified as
valid POSIX sh that satisfies the config contract - there is a test per profile -
but the commands inside were not run against a real toolchain of that stack. It
lands as `scripts/harness/config.sh`, which the project owns from that moment:
read it, make it true for your repository, and delete what does not apply. The
comments flag the traps worth knowing - that `cargo test` filters by name rather
than path, that Gradle wants `testDebugUnitTest` on Android, that Go code at the
repository root is invisible to the code-path check.

## Finishing it: `/harness-setup`

`install` leaves templates full of `TODO(harness)` on purpose - those are the
decisions it cannot infer. The `harness-setup` skill fills them **by interviewing
you**: it reads the repository first (scripts, CI, whatever already enforces your
architecture, the branch and roadmap conventions), comes back with proposals rather
than a blank form, asks in four rounds, and then writes `config.sh`,
`mandatory-steps.md` and `architecture-rules.md` from your answers. It also installs
the harness first if it is not there yet.

It is vendored into every project as `.agents/skills/harness-setup/SKILL.md`, so any
agent can follow it by path; in Claude Code it is `/harness-setup`. Anything you do
not answer stays in the document as an explicit open question - it never guesses a
convention, because a guessed convention that everybody then follows is worse than
an admitted gap.

## Who owns what

This is the whole design. Get it wrong and either upgrades destroy your decisions,
or your projects drift apart.

| The harness owns it - replaced on `upgrade` | The project owns it - never touched |
|---|---|
| `scripts/harness/verify` | `scripts/harness/config.sh` |
| `.githooks/pre-commit` | `docs/harness/mandatory-steps.md` |
| `.agents/skills/<vendored>` | `docs/harness/architecture-rules.md` |
| `scripts/harness/VERSION` | `openspec/config.yaml` |
| | `AGENTS.md` |

The gate is **byte-identical in every project**. Everything stack-specific lives in
`config.sh`, which the gate sources - so there is no generated file to drift, and
nothing to re-generate when the harness changes.

Templates are written **once** and then belong to you. `mandatory-steps.md` and
`architecture-rules.md` arrive full of `TODO(harness)` markers on purpose: the
installer cannot know your layers, your phases or which shared rules you adopt.
`doctor` keeps reminding you while they are unfilled.

## The config.sh contract

```sh
HARNESS_CODE_PATHS="lib test"      # a --docs-only run refuses on a change here

harness_gates() {                  # static gates: fast, and they fail loudly
  echo "harness: static gates"
  run fvm flutter analyze
}

harness_test_selected() { run fvm flutter test "$@"; }   # ONLY these targets
harness_test_all() { run fvm flutter test; }             # --full
```

`run` routes through [rtk](https://github.com/rtk-ai/rtk) when installed, cutting
the output that reaches an agent's context, and calls the command directly when not.

**Wire what the repository already enforces into `harness_gates`** - a dependency
linter, a boundary check, an architecture test suite. Do not add a second mechanism
that competes with it; `doctor` lists what it finds so you don't.

## Vendored, not linked

Skills are copied into `.agents/skills/<name>/` as real directories, and exposed to
Claude Code through repository-relative symlinks in `.claude/skills/`. A symlink into
`$HOME` looks tidier and is a trap: it is committed, and then it does not resolve on
another machine or in CI. `doctor` fails on any symlink that escapes the repository.

The cost of vendoring is that improvements do not arrive on their own: run
`norma upgrade`, which compares against `scripts/harness/VERSION` and reports any
owned file you edited locally instead of clobbering it.

## Tests

```sh
test/run.sh
```

56 tests over the gate's real behaviour - its refusals above all - and over
`install`, `upgrade` and `doctor`, each in a throwaway git repository with a stub
stack adapter. They live here, once, because the gate is the same file everywhere:
before this repository existed the same eight tests were duplicated across three
projects in two languages.

## Working on norma itself

[`AGENTS.md`](AGENTS.md) is the index for that, and it is what an agent should read
first: the ownership boundary in [`docs/01-architecture.md`](docs/01-architecture.md),
the flows and every refusal in [`docs/02-flows.md`](docs/02-flows.md), the skill
library in [`docs/03-skills.md`](docs/03-skills.md), and the suite in
[`docs/04-testing.md`](docs/04-testing.md). `CLAUDE.md` is a symlink to `AGENTS.md`,
because Claude Code autoloads only the latter.

## Not per project

Some things are user-level and `install` deliberately does not touch them; `doctor`
reports on them:

- **OpenSpec's workflow set** lives in `~/.config/openspec/config.json`. It is global
  configuration, not per project.
- `tgrep`, `rtk` and `codegraph` are tools on your `PATH`.
