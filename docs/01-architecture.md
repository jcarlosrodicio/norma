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
| `scripts/harness/run` | `.harness/` (runtime state, gitignored, nobody's to keep) |
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
HARNESS_CODE_PATHS="lib test main.go"                     # paths that hold code: a dir, or a file at the root
harness_gates()         { echo "..."; run <static gates>; }
harness_test_selected() { run <runner> "$@"; }           # ONLY these targets
harness_test_all()      { run <runner>; }                # --full
```

`run` is provided by the gate: it executes the command and hands back its exit
status, which is the only thing the verdict may depend on. It used to route
through [rtk](https://github.com/rtk-ai/rtk) when installed, to cut the output
reaching an agent's context - until a measurement in a consumer showed that
wrapper exiting 0 where the command exited 1, so a verification passed with a
broken typecheck. A project may still filter output inside its own `config.sh`;
what it may not do is return a status that is not the command's.

A successful run writes `.harness/verified` - the **stamp** - containing the
timestamp, the branch and the exact selection. The stamp is runtime state: it is
gitignored, and it is the only channel between the gate and the hook.

#### The floor guard

Once the tests are green, the gate reads the change for the moves that make a
check pass without making the code work, prints them, and records them against the
run. It refuses nothing.

| kind | what it looks for | where |
|---|---|---|
| `skip` | a skip or focus marker added: `.skip(`, `.only(`, `xit(`, `@pytest.mark.skip`, `t.Skip(`, `#[ignore]`, `@Disabled`... | test files |
| `suppression` | a suppression comment added: `@ts-ignore`, `eslint-disable`, `# noqa`, `// ignore:`, `#[allow(`, `istanbul ignore`... | `HARNESS_CODE_PATHS`, Markdown excluded |
| `stub` | "not implemented", `NotImplementedError`, `todo!()`, a one-line empty `catch`, `except: pass` | the same, test files excluded |
| `deleted_test` | a test file removed - empty and binary ones included - or renamed to a name that no longer reads as a test, which stops it running just the same | test files |
| `assertions` | more assertion lines removed than added, net, in a test file that stayed | test files |
| `gate_config` | `scripts/harness/config.sh` modified - the one place a gate can be removed | that file |

A **test file** is recognised by name - a `test/`, `tests/`, `spec/` or
`__tests__/` directory, `*_test.*`, `*.test.*`, `*.spec.*`, `test_*.py`,
`*Test.java` and its siblings - because nothing in the config contract says where
tests live, and adding a field for it would ask every consumer for a decision to
save a heuristic a few misses.

Four decisions, each one load-bearing:

- **It warns; it does not refuse.** A test can change legitimately when the
  specification did, and a heuristic that blocks on a false positive is how a
  team learns `--no-verify`. The events it records are what will say whether it
  is precise enough to block. Measured on 2026-10-07, before it shipped, against 28 merged pull
  requests of three consumer repositories: three of them reported anything, five
  findings in all, and every one a real move - three `eslint-disable-next-line`,
  a modified `config.sh`, and a test file that lost 54 assertions net when they
  moved into a helper the name heuristic does not count as a test. Real is not
  the same as wrong: that last one is a refactor, and only a reader can tell.
  When it does block, a lowering will be accepted with
  `verify --accept-weakening "<reason>"`, recorded in the stamp and the run - a
  reason cannot live on the line, because a deleted file has no line to carry it.
- **Against the branch point, not the last commit.** The base is the merge base
  with `origin/HEAD`, `origin/main`, `origin/master`, `main` or `master`, first
  that exists, and the change is everything since it: committed, staged,
  unstaged and untracked. What the default branch already had is not this
  change's doing. With no base at all it says *could not check* and records
  `outcome=unchecked` - never a clean result it did not earn.
- **The patterns live in the gate, not in the profiles.** A profile becomes the
  project's `config.sh` on the first write and never receives an upgrade, so
  patterns kept there would never reach a project installed before them. In the
  gate they arrive with `norma upgrade`, like every other fix to it.
- **Its patterns cannot match their own source.** Each one is written `ski[p]`
  where `skip` would do. norma keeps the gate inside a code path, and so may any
  project; a guard that reports itself is a guard people learn to skim.

What it misses, known and accepted while it only warns:

- **Tests the name heuristic does not see** - Rust unit tests inside `src/*.rs`,
  Python's `tests.py` and `conftest.py` - so a skip marker there goes unread, and
  assertions moved into a helper count as removed.
- **Markers with no pattern yet** - Dart's `@Skip(`, Playwright's `test.fixme(`,
  `@unittest.expectedFailure`. Adding one is a line in the gate and a test.
- **The assertion count is lexical.** Any line in a test file mentioning
  `assert` counts, a comment included, so the net figure is a prompt to look,
  not a measurement.
- **A file name holding a tab, a quote or a newline** stays quoted in the diff
  and matches nothing. Spaces and non-ASCII names are read: the diff's prefixes
  and `core.quotepath` are pinned, so a user's git config cannot reshape it.
- **Cost grows with the change.** One `git diff` for the branch plus one per
  untracked file, after the tests. It cannot change the verdict; on a tree with
  thousands of unignored files it can make the gate slower.

`scripts/harness/verify --floor` runs the guard alone: no gates, no tests, no
stamp and no record, exiting 0 clean, 1 with findings and 2 when it could not
check. It exists for the adversarial review, which may not read the author's
run log but can ask the diff the same question.

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

### `core/run` - the task's identity

Byte-identical in every project, and it encodes no stack-specific decision at
all: there is no config to source, because there is nothing here a project could
legitimately disagree with.

It exists because of one fact the rest of the harness had no way to express:
**a task run is not an agent session.** The loop deliberately splits a task
across sessions - the adversarial review asks for a fresh session on a different
model, a correction comes back afterwards, an unsupervised run fans out into
subagents - and before this, nothing tied those together. The verification stamp
describes one gate run. The change folder describes the artifacts. Neither says
"these four sessions were one task", which is exactly what somebody looking at
the telemetry those sessions emit needs to know.

```sh
scripts/harness/run start <change slug> [--kind production|benchmark]
scripts/harness/run status
scripts/harness/run event <type> [key=value...]
scripts/harness/run close [<output file>]
```

`start` writes `.harness/run.json`: a run id, the kind, the change, the branch,
the repository name, the timestamp and the norma version. No secrets, no prompts,
no model output, no absolute path from this machine - the summary it eventually
produces is committed, and a machine path in a committed file is a rule this
harness already has. `event` appends a line to `.harness/run-events.jsonl`.
`close` writes the summary - the run plus every event, verbatim - and removes
both files.

Four decisions inside it, each one load-bearing:

- **A file in the worktree, not an environment variable.** The agent process is
  usually running before the task begins, and the independent reviewer is
  launched fresh and inherits nothing. An exported variable cannot describe a
  task that started after the shell did, which is the normal case rather than the
  edge one.
- **`.harness/`, which is already gitignored and already per worktree.** Two
  concurrent worktrees get separate contexts with no mechanism at all, because
  git gave each one its own working directory. Nothing had to be invented for
  concurrency, and the run id carries a random suffix only so two runs started in
  the same second are still distinct.
- **No run context is a normal state.** `event` is a silent no-op without one and
  exits 0. That is what lets the gate call it unconditionally, and what makes
  this whole feature invisible to a project that upgrades and never uses it.
- **It gates nothing.** A stale context - one started on another branch, or a
  week ago - is reported by `status` and by `doctor`, and marks the events it
  collects, but refuses nothing. Verification must not gain a way to fail that
  has nothing to do with the code, and `start` refusing a second branch is the
  one refusal, made at the only moment where it costs nobody a red gate.

The gate records its own result through it - mode, selection, outcome, exit code,
duration - and that record is armed only once the gate is about to do real work,
so the refusals above it record nothing: no target named and no config are the
harness being pointed at the wrong thing, not a verification that happened. The
record reaches no network, and a `run` that is missing, broken or non-executable
costs a record and never a verification.

Three fields carry the duration, and a reader needs to know which one to believe:

| field | what it is |
| --- | --- |
| `duration_ms` | the measurement. Present whenever the machine offers a clock finer than a second, absent when it does not - never zero to stand in for a missing one. |
| `duration_clock` | where that measurement came from: `monotonic`, `realtime_ns` or `realtime_s`. |
| `duration_s` | whole seconds, truncated, kept at the type and meaning it has always had so consumers written before `duration_ms` existed do not change behaviour. **A new reader takes `duration_ms`**: a `0` here means "under a second", not "instant". |

`duration_s` is `duration_ms` divided by a thousand, in integers, so the two
never disagree. When the clock stepped backwards between the two reads - a wall
clock can, a monotonic one cannot - neither field is emitted, because an interval
that ran backwards did not measure a fast verification, it measured nothing.

The clock is probed once per verification, in this order, and the order is a
decision rather than a preference for the best clock:

| order | source | `duration_clock` |
| --- | --- | --- |
| 1 | `date +%s%N`, when the answer really carries nanoseconds | `realtime_ns` |
| 2 | `perl` + `Time::HiRes` CLOCK_MONOTONIC | `monotonic` |
| 3 | `date +%s` | `realtime_s` |

Monotonic is the better clock and it is second, because reaching it means
spawning an interpreter on every verification, and a `perl` that is present but
wedged hangs the gate with no portable way to bound it: `timeout` is not POSIX
and macOS does not ship it. Reproduced during review - a `perl` stub that sleeps
leaves `verify` running indefinitely on a Mac. Trying the command this script
already depends on first means the common machine never spawns perl at all, and
the clock step monotonic would have caught is refused below instead of being
measured wrong. A test asserts perl is not spawned when `date` answers; it is
the assertion that encodes this decision, and the only one that goes red if the
order is swapped back.

Being all digits is not enough to accept `date +%s%N`. **BusyBox does not
implement `%N` and drops it silently** - `date +%s%N` in alpine answers
`1789726082`, the same as `date +%s`, exit 0 - so the gate measures the answer
against `date +%s` and wants exactly nine more characters. Without that check it
would trim six characters off bare epoch seconds and publish `1789` as
milliseconds, and a two-second verification would record zero. Every Alpine
container in a CI would have reported that, quietly.

This is the defect that named the change: with only `date +%s`, every
verification shorter than a second recorded `duration_s=0`, and a zero produced
by truncation reads exactly like a zero somebody measured.

Two limits, both found by review and neither closed:

- **A wedged `perl` still hangs the gate** on a machine whose `date` cannot do
  nanoseconds, where perl is the only remaining precise source. `timeout` guards
  it where it exists. A gate that runs the project's own test command has the
  same exposure to that command, which is why this is a limit and not a refusal.
- **The nanosecond path assumes 64-bit shell arithmetic.** The reading itself is
  trimmed as a string rather than divided, so the 19-digit value never reaches
  `$(( ))`, but the subtraction of two millisecond counts is around 1.7×10¹² and
  a 32-bit shell would not hold it. Every platform this installs on today is
  64-bit; the day one is not, the symptom is a wrong duration rather than a
  failed verification.

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
repository root has to be named as a file in `HARNESS_CODE_PATHS`, because a
directory entry cannot reach it; that a Terraform plan against a real workspace needs
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

**A template owns the commands, never the method.** `templates/mandatory-steps.md`
is written once and becomes the project's, which is right for what it decides and
wrong for what it explains: a procedure parked there never receives an upgrade
again. That is what happened to runtime verification - the loop's step 5 carried
the whole method, so three consumers each drifted their own way and no
improvement could reach any of them. The method moved into
`skills/runtime-verification/`, vendored like the gate; the template kept its
`TODO(harness)` markers, which are the commands. When a template paragraph
explains *how* rather than deciding *what*, it belongs upstream.

**`doctor` detects rather than imposes.** It reports what the repository already
enforces, what drifted, what templates are unfilled, and which user-level tools
are missing. It changes nothing. That posture came out of writing a duplicate
boundary checker for a repository that already had a better one.

**Machine over prompt.** Where a rule can be enforced by a tool, the tool is the
rule and the document is only its explanation. This is why the enforcement is a
git hook and not a paragraph asking the agent to behave.

**Self-hosting: decided, yes.** `norma` installs its own harness. The gate parses
every shell file and runs the whole suite; the hook is real, so a branch per
change applies here too. Before this, the loop imposed on the consumer repositories ran
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

  **The installer knows this about itself**, rather than leaving it as a
  convention nobody enforces. When the repository it is acting on *is* norma,
  vendoring a skill means creating that link, repairing one that points at a skill
  which moved, and refusing to replace a real directory someone put there.

  It asks that in two ways, because one is not enough. Paths, resolved physically,
  since the CLI reaches its home through `cd ..` while git reports the real one.
  Then shape - `bin/norma`, `core/verify`, `skills/` - which catches what paths
  cannot: **a git worktree or second checkout of norma driven by the installed
  CLI**. The paths differ there and the repository is still norma, and this harness
  is the one telling everyone to work in worktrees, so that tree gets made. It does not merely tolerate the links: it
  creates them, because otherwise self-hosting is maintained by hand and every
  skill added upstream needs two symlinks made by whoever remembers.

  Until that existed, `norma upgrade` run in this tree silently turned all eleven
  links into copies - undoing the decision above, in the one repository where no
  consumer would ever notice, and leaving the stale stamp that made it visible.

**Evidence is recorded by whatever produced it, and never reduced to a score.**
The run's evidence log is written by the gate for its own verification, by the
runtime verification for its own verdict, by the review for its own coverage and
findings - never by an agent summarising all three afterwards. That is the same
rule as "a stage reported as done without the command output behind it", moved to
a place a machine reads. And the ordering it implies is deterministic evidence
first, independent review second, self-report last, which is why the review event
carries counts and a verdict while the findings themselves stay in the report,
with their file, their line and the input that triggers them. A number cannot be
argued with, which is precisely what makes it useless as a review.

**shellcheck is not in the gates**, deliberately. It is not installed here, and
wiring in a linter nobody has means the gate changes behaviour the day somebody
installs it. Adopting it means paying its findings in the same change.
