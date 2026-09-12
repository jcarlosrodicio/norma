# 01 · Architecture

## What norma is

A tool that installs a **task harness** into any git repository and keeps it
up to date. The harness is everything around the model: the loop a task follows,
the verification gate that must pass before delivery, the architectural criteria,
and the skills that describe each stage.

The harness itself is agnostic to the agent by construction. Instructions are
referenced **by file path**, never by an agent's slash-command syntax, and the
enforcement rides on the two things every agent and every human passes through:
**git** and **an executable script**. Claude Code hooks, Codex config and Pi
packages are all things one agent reads and the others ignore, so none of them can
carry an obligation.

## Scope

**In scope.** The mechanical half of a harness: the gate, the git hook, the skill
library, prefab stack adapters, document templates, and the CLI that starts,
installs, upgrades and diagnoses them.

That CLI covers a project's whole life in one direction: `start` before there is a
repository, `install` once there is, `upgrade` as norma moves, `doctor` whenever
something feels off. The first of those writes no harness at all - it writes the
note that sends an agent to `start-project`, because a project that does not exist
yet needs a conversation before it needs a gate.

**Out of scope, deliberately.**

- **A boundary or dependency checker of its own.** Every stack already has one -
  dependency-cruiser, an import linter, an architecture test suite - and it is
  better than anything generic. The harness *calls* what the repository already
  has; `doctor` lists what it finds so nobody adds a second mechanism. This is not
  theory: a checker was once written here and deleted three commits later because
  the target repository already had a stronger one.
- **Test selection.** The harness demands that a selection be named and recorded.
  It does not compute it.
- **Per-agent configuration.** MCP servers, skill visibility, model choice,
  per-agent hooks: all outside. They belong to the agent and to the project.
- **Anything that encodes a project decision.** See the ownership boundary below.

## The ownership boundary

This is the load-bearing decision. Get it wrong and either an upgrade destroys a
project's decisions, or the consumers drift apart until the harness means nothing.

| norma owns it - replaced on `upgrade` | The project owns it - never touched |
|---|---|
| `scripts/harness/verify` | `scripts/harness/config.sh` |
| `.githooks/pre-commit` | `docs/harness/mandatory-steps.md` |
| `.agents/skills/<vendored>` | `docs/harness/architecture-rules.md` |
| `scripts/harness/VERSION` | `openspec/config.yaml` |
| `AGENTS.md` between the harness markers | `AGENTS.md` outside them, or with no markers at all |

The rule behind the table: **norma owns what is identical everywhere; the project
owns everything that expresses a decision.** An installer cannot know your layers,
your phase conventions, or which shared architectural rules you adopt, and
pretending otherwise is how a harness turns into a framework that fights the
project.

Templates are therefore written **once**, arrive full of `TODO(harness)` markers,
and become the project's own from that moment. `doctor` keeps warning while the
markers are unfilled, and `skills/harness-setup` is the procedure that fills them
by interviewing the human.

## The pieces

### `core/verify` - the gate

Byte-identical in every project. Everything stack-specific lives in
`scripts/harness/config.sh`, which the gate **sources**. There is no generated
file, so there is nothing to regenerate and nothing that can drift out of sync
with the upstream copy.

The contract the config must satisfy, checked at startup - the gate refuses to run
if any part is missing:

```sh
HARNESS_CODE_PATHS="lib test"                            # top-level dirs that hold code
harness_gates()         { echo "..."; run <static gates>; }
harness_test_selected() { run <runner> "$@"; }           # ONLY these targets
harness_test_all()      { run <runner>; }                # --full
```

`run` is provided by the gate: it routes through [rtk](https://github.com/rtk-ai/rtk)
when installed, cutting the output that reaches an agent's context, and calls the
command directly when not.

A successful run writes `.harness/verified` - the **stamp** - containing the
timestamp, the branch and the exact selection. The stamp is runtime state: it is
gitignored, and it is the only channel between the gate and the hook.

### `core/pre-commit` - the enforcement

Four rules, in order. Each exists because of a specific failure:

1. **Not the default branch.** Work belongs on a branch, and a phase-named one
   where the project has phases.
2. **A stamp must exist.** No verification on record, no commit.
3. **The stamp must be newer than every staged file.** Editing code after
   verifying it invalidates the run. The refusal prints the previous selection
   from the stamp as a command ready to paste, because the agent that trips this
   has usually lost track of what it verified.
4. **A `docs-only` stamp may not cover code.** Rule 3 compares mtimes and cannot
   catch code edited *before* a docs-only run, so staged code plus a docs-only
   stamp is refused outright, reading `HARNESS_CODE_PATHS` from the config.

The one hole is `git commit --no-verify`, which no git hook can close. CI running
the full suite on the pull request is the backstop, and the loop template says so
explicitly rather than pretending otherwise.

### `profiles/*.sh` - stack adapters

Sixteen prefab `config.sh` files: `django`, `dotnet`, `elixir`, `flutter`, `go`,
`gradle`, `java-maven`, `laravel`, `next`, `node`, `pnpm-turbo`, `python`, `ruby`,
`rust`, `swift`, `terraform`.

Detection walks the manifests most specific first - a file only one stack ever
writes (`mix.exs`, `Package.swift`, `pom.xml`, `artisan`) before one several share
(`package.json`) - and `--profile` wins, which is what a repository carrying two
manifests needs: a Tauri app, a .NET service with a JS frontend. Two tests keep
this honest: every name detection can emit must have a profile file behind it,
and every profile must be valid sh satisfying the contract the gate checks at
startup - otherwise `install` hands a project a config that refuses to run.

**What a profile is not: tested support.** The commands inside were never run
against a real toolchain of that stack, and this repository has no way to run
them. What is verified is the shape, not the behaviour. A profile is therefore a
draft of the project's own `config.sh`, and the project owns it from the first
write.

The interesting content of a profile is often its comments, because they carry
what the contract cannot express: that `cargo test`, `dotnet test`, Gradle and
`swift test` filter by test *name* rather than by path, so a named selection is a
filter and the report has to say what it actually selected; that Android's task is
`testDebugUnitTest`; that Django's runner takes dotted labels; that Go code at the
repository root is invisible to the directory-prefix check of
`HARNESS_CODE_PATHS`; that a Terraform plan against a real workspace needs
credentials and therefore belongs in runtime verification rather than in a gate. A profile is a starting point, not a
constraint: it lands as the project's own file and is never overwritten.

### `skills/` - the canonical library

See [`03-skills.md`](03-skills.md).

### `templates/` - the documents a project inherits and then owns

`agents-section.md` (the block injected into `AGENTS.md`), `mandatory-steps.md`
(the loop), `architecture-rules.md` (the adoption map over the shared
architectural reference), `openspec-config.yaml`.

## Decisions, and why - do not undo these without reading the reason

**Vendored, not symlinked.** Skills are copied into `.agents/skills/<name>/` as
real directories. A symlink into `$HOME` looks tidier and is a trap: it gets
committed, and then it does not resolve on another machine or in CI. This was a
real bug in a consumer repository before the copy rule existed. `doctor` fails on
any symlink that escapes the repository. The cost is that improvements need
`harness upgrade`, which is what `VERSION` is for.

**One skill is deliberately not vendored.** `start-project` runs before the
repository exists, so there is nowhere to vendor it to; it is reached through
`$(norma home)/skills/start-project/SKILL.md`. Adding it to `VENDORED_SKILLS`
would ship the founding interview into every project that has already been
founded. The test suite asserts its absence from an install, so the omission
cannot be silently "fixed".

**A generic gate that sources a config, rather than a generated gate.** The three
consumer repositories had hand-written gates differing in exactly four values.
Generating a file per project would have re-created the same drift with extra
machinery.

**The project owns its `AGENTS.md` harness section - unless it keeps the
markers.** The installer writes the block only when the file does not exist or
says nothing about the harness. All three consumers had customised that section
within days; owning the whole file would have overwritten real content on the
first upgrade.

The markers are what resolves that. `<!-- harness:begin -->` is the project
*asking* for the block to be managed, and the block itself says so - "Edit the
harness upstream, not this block." So an upgrade rewrites what is between them,
and touches nothing else in the file: no markers, or content outside them, and it
is the project's. A project that wants the section for itself deletes the markers,
which is exactly what the three customised consumers had effectively done by never
receiving them.

For a while the code did neither: only `install` ever rewrote the block, so a
marked section that promised to be managed went stale on every upgrade. The cost
was not cosmetic - a skill added upstream reached Claude Code through
`.claude/skills` and stayed **invisible to every agent that reads `AGENTS.md` by
path**, which is the portability the whole harness is built on.

**`doctor` detects rather than imposes.** It reports what the repository already
enforces, what drifted, what templates are unfilled, and which user-level tools
are missing. It changes nothing. That posture came out of writing a duplicate
boundary checker for a repository that already had a better one.

**Machine over prompt.** Where a rule can be enforced by a tool, the tool is the
rule and the document is only its explanation. This is why the enforcement is a
git hook and not a paragraph asking the agent to behave.

**Self-hosting: decided, yes.** `norma` installs its own harness. The gate parses
every shell file and runs the whole suite; the hook is real, so a branch per
change applies here too. Before this, the loop imposed on three repositories ran
here on nothing but discipline - and discipline is exactly what the harness exists
to replace.

Two adaptations the contract could not express on its own:

- **The suite is indivisible.** `harness_test_selected` runs everything whatever
  you name, and says so rather than pretending to filter. The selection still
  reaches the stamp, because a reviewer reads it to know what you thought you were
  covering.
- **The skills are symlinked, not vendored.** `.agents/skills/<name>` points at
  `../../skills/<name>`: this repository is their source, and a copy inside it
  would be a second version that drifts. The link stays inside the repository, so
  `doctor` is satisfied and a clone resolves it.

**shellcheck is not in the gates**, deliberately. It is not installed here, and
wiring in a linter nobody has means the gate changes behaviour the day somebody
installs it. Adopting it means paying its findings in the same change.
