# norma

<p align="center">
  <a href="https://github.com/jcarlosrodicio/norma/actions/workflows/ci.yml"><img src="https://github.com/jcarlosrodicio/norma/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/jcarlosrodicio/norma" alt="License"></a>
  <a href="https://github.com/sponsors/jcarlosrodicio"><img src="https://img.shields.io/badge/Sponsor-GitHub%20Sponsors-ea4aaa?logo=githubsponsors&logoColor=white" alt="Sponsor on GitHub"></a>
</p>

**One task loop, one verification gate, one skill library - for every coding agent,
enforced by git.**

norma installs and maintains a task harness in a repository. Whatever agent is
driving - Claude Code, Codex, OpenCode, Cursor or the next one - it follows the same
procedure, read **by file path** from the repository, and it cannot commit until the
same gate has passed. The enforcement lives in a git hook, not in any one agent's
hook system, so switching agents changes nothing.

**MIT · POSIX sh · Agent-agnostic · No runtime dependencies**

> [!NOTE]
> norma is not an agent, an orchestrator or a hosted service. It is the set of
> files and the one hook that make several agents work the same way in your
> repository, and the CLI that keeps those files current.

## Why this exists

A repository worked on by coding agents tends to grow its process by accident:

- A prompt here, a rule file there, a slash command only one agent understands.
- "Run the tests" as an instruction rather than a check - followed when remembered.
- A different procedure per agent, so the result depends on who was driving.
- The same gate and the same tests hand-built again in every repository, drifting
  apart a little more with each copy.

norma is that process extracted once, made portable, and made binding:

- **One loop** for any change - orient, enrich, branch, plan, implement, verify,
  review, document, hand over - with three explicit stops where a human decides.
- **One gate**, byte-identical in every project, that runs what the project says
  its checks are and writes a stamp the hook demands before a commit.
- **One skill library**, vendored as plain files, so any agent can follow it
  without a skill system of its own.
- **One CLI** to install it, upgrade it without touching your decisions, and
  diagnose what is missing.

## What you get

| Capability | What it gives you |
|---|---|
| The loop | `run-task`: a whole change from a vague request to verified code waiting for review, stopping three times for the human |
| Unattended phases | `auto-run-task`: the same loop with nobody watching, each stop replaced by a decision it writes down, ending at an open pull request |
| A binding gate | `scripts/harness/verify` runs your static checks and the tests for what changed, and stamps the result |
| A hook that enforces it | `.githooks/pre-commit` refuses the default branch, a missing or stale stamp, and code committed against a docs-only stamp |
| Independent review | `adversarial-review`: a red-team pass that assumes the work is wrong, fact-checks its findings and treats a lowered bar as blocking |
| Runtime verification | `runtime-verification`: proof that the change works in the running system, not just that the tests pass |
| Task runs | `scripts/harness/run`: one identity across the several sessions a task takes, with the evidence each stage recorded |
| Guided setup | `harness-setup`: an interview that fills the decisions the installer cannot infer |
| Projects from nothing | `norma start` and `start-project`: from "I want to build X" to founding documents, a roadmap and an installed harness |
| Sixteen stack profiles | A starting `config.sh` for Node, pnpm/Turbo, Next, Flutter, Swift, Go, Rust, Maven, Gradle, Python, Django, Laravel, Rails, Phoenix, .NET and Terraform |
| Safe upgrades | `norma upgrade` replaces only what the harness owns and reports local edits instead of clobbering them |

## Who this is for

- You use more than one coding agent, or expect to, and want them to work the same way.
- You want "the tests passed" to be something git checks, not something an agent says.
- You maintain several repositories and are tired of hand-copying the same process.
- You want the process in plain files you can read, diff and change.

## Who this is not for

- You want an agent runtime, a multi-agent orchestrator or a hosted platform.
- You want every request fully automated with no human review.
- Your repository cannot run its checks from a shell.

## How it works

```
orient → enrich → branch → plan → implement → verify → review → document → close → deliver
         ^stop             ^stop                                                   ^stop
```

Every stage is a document in `.agents/skills/`, referenced by path, so an agent that
knows nothing about skills can still follow it. The **verify** stage is the gate:

```sh
scripts/harness/verify <what you were verifying>   # static gates + the selected tests
scripts/harness/verify --full                      # everything, as CI runs it
scripts/harness/verify --docs-only                 # refuses if code changed
```

It runs the commands your project declares in `scripts/harness/config.sh` and, on
success, writes a stamp of what it verified. The pre-commit hook refuses a commit
whose stamp is missing, stale or docs-only against code - so a step that was skipped
shows up as a refused commit, not as a review comment three days later. Run the same
gate in CI to close the one hole the hook cannot, `git commit --no-verify`.

Every refusal and the reason it exists are listed in
[`docs/02-flows.md`](docs/02-flows.md).

## Quick start

### Requirements

- `git` and a POSIX `sh`. Nothing else is needed to install, upgrade or run the gate.
- [OpenSpec](https://github.com/Fission-AI/OpenSpec) for the full loop: the plan,
  apply and archive stages of `run-task` follow its skills.
- Optional: [rtk](https://github.com/rtk-ai/rtk), which the gate uses to trim the
  output that reaches an agent's context when it is installed. `doctor` also looks
  for `tgrep` and `codegraph`.

### Install norma

With Homebrew, on macOS or Linux:

```sh
brew install jcarlosrodicio/tap/norma
```

Or with the install script, which needs only git:

```sh
curl -fsSL https://raw.githubusercontent.com/jcarlosrodicio/norma/master/install.sh | sh
```

It clones the latest release into `~/.local/share/norma` and links `norma` from
`~/.local/bin`. `NORMA_VERSION=0.21.0` pins a release, and `NORMA_HOME` and
`NORMA_BIN_DIR` move either location. Run it again to move to another release. It
refuses rather than overwrite a `norma` that is already there.

Or by hand, from a release tag:

```sh
git clone --branch 0.21.0 https://github.com/jcarlosrodicio/norma.git ~/.local/share/norma
ln -s ~/.local/share/norma/bin/norma ~/.local/bin/norma
```

All three install a tagged release, never `master`. `norma home` prints where it
lives. Updating norma itself is `brew upgrade norma`, the script run again, or
`git checkout` of a newer tag; bringing a project up to it is `norma upgrade`.

### Add the harness to a repository

```sh
cd ~/some/project
norma install --dry-run    # see what it would do
norma install              # do it
norma doctor               # what is still missing, and what you must fill in
```

Then ask your agent to follow `.agents/skills/harness-setup/SKILL.md` (in Claude Code,
`/harness-setup`) to fill in the decisions `install` cannot infer. From then on, any
change starts with `.agents/skills/run-task/SKILL.md`.

### Or start a project that does not exist yet

```sh
norma start my-project     # creates the directory and leaves the note
cd my-project              # open your agent here and say what you want to build
```

### Stack profiles

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

## Starting from nothing: `norma start`

```sh
norma start my-project     # creates the directory and leaves the note
cd my-project              # open your agent here and say what you want to build
```

That is the whole entry point. `start` writes an `AGENTS.md` pointing at the
procedure below, and every agent reads that file on the way in - so there is
nothing to paste, and no path to remember.

For a project that does not exist yet, the harness is the **last** step, not the
first. `start-project` is the interview that comes before it: what this is and for
whom, the domain, the stack and the boundaries, how it ships, and - for anything
with an interface - a design brief, so the first screen is not invented by whoever
happens to build it. Out of that it writes the founding documents and a roadmap of
**vertical slices of at most a day each**, with sizes, explicit dependencies, an
honest parallel column, milestones and a status column. Then it creates the
repository, installs the harness and hands over to `harness-setup` carrying the
answers it already has.

It is a **conversation, not a questionnaire**: what it fixes is the set of things
it must end up knowing - the point, the shape, the materials, the way out, the face
- and the route there is the human's. It plays back more than it asks, digs only
where an answer would change a phase, and marks out loud which decisions were
theirs and which were defaults it took.

It is the one skill **not vendored** into projects - it runs before there is a
project - so it is found through the installation, by any agent, by path:

```sh
$(norma home)/skills/start-project/SKILL.md
```

`norma start` is that path written into a file the agent already reads; the path
itself still works on its own. No skill system, no slash commands, no tools beyond
a shell. If your agent has a skill directory, link it there and it gets a name as
well - nothing depends on that:

```sh
ln -s "$(norma home)/skills/start-project" ~/.claude/skills/start-project
```

If the agent running it cannot see images, it says so up front and switches the
design conversation to links and descriptions, and the brief records that it was
gathered without vision. A brief written from a screenshot nobody looked at is
worse than one that admits what it is.

## Finishing it: `/harness-setup`

`install` leaves templates full of `TODO(harness)` on purpose - those are the
decisions it cannot infer. The `harness-setup` skill fills them **by interviewing
you**: it reads the repository first (scripts, CI, whatever already enforces your
architecture, the branch and roadmap conventions), comes back with proposals rather
than a blank form, asks in five rounds, and then writes `config.sh`,
`mandatory-steps.md` and `architecture-rules.md` from your answers. It also installs
the harness first if it is not there yet.

It is vendored into every project as `.agents/skills/harness-setup/SKILL.md`, so any
agent can follow it by path; in Claude Code it is `/harness-setup`. Anything you do
not answer stays in the document as an explicit open question - it never guesses a
convention, because a guessed convention that everybody then follows is worse than
an admitted gap.

## Running a whole phase unattended: `/auto-run-task`

`run-task` is the loop, and it stops three times for you: after enriching, after
planning, and before delivery. `auto-run-task` is the same loop for when you are not
there to answer - you hand over a roadmap phase and leave.

```
orient → enrich → branch → plan → implement → verify → review → document → close → deliver
         ^decide ^run      ^self-review                                     ^run    ^commit, push, PR, CI
                  start                                                      close
```

Each stop becomes something the agent does and **writes down**: the open questions
are decided from the roadmap and the architecture documents, the plan is checked
against the phase instead of shown to you, and the run ends at an **open pull
request** with a green CI - never a merge, a deploy or a publish. Every decision it
took instead of asking lands in `reports/autonomy.md`, linked from that pull request,
so you review once, afterwards, and can stop at the first decision you disagree with.

It stops anyway for seven reasons - among them a question that changes *what* gets
built rather than how, anything destructive, anything needing a credential, and the
same failure surviving two attempts. Then it commits, pushes, does **not** open the
pull request, and asks you everything at once.

Nothing about the gate relaxes: no `--no-verify`, no edit to `verify` or the hook to
make a run pass, and no failing test silenced instead of fixed - with nobody
watching, *make it green* is the failure mode this mode exists to refuse.

A project that already had the harness needs one edit before using it: `Step 9` of
its own `docs/harness/mandatory-steps.md` has to name the exception, or the binding
checklist forbids the delivery. New installs get it from the template.

## One task, several sessions

The loop deliberately splits a task across sessions: the adversarial review asks
for a fresh one on a different model, the correction comes back afterwards, an
unsupervised run fans out into subagents. **A task run is not an agent session**,
and nothing in the harness used to say so - the verification stamp describes one
gate run, the change folder describes the artifacts, and neither says "these four
sessions were one task".

```sh
scripts/harness/run start phase-16-whatever   # right after creating the branch
scripts/harness/run close <report path>       # with the change, after the archive
```

`start` writes `.harness/run.json` - a run id, the change, the branch, the
timestamp. A file in the worktree rather than an environment variable, because the
reviewer is launched fresh and inherits nothing, and because git already gives
every worktree its own, so two of them running at once need no mechanism at all.
It refuses while a run from another branch is open: a different branch is a
different task, and letting the old one attach itself silently would make every
later correlation a lie.

Then the pieces that produce evidence record their own: the gate records the mode,
the selection, the outcome and the duration of every verification; the runtime
verification records a surface and one of its three verdicts; the review records
its coverage, its counts and its verdict. `close` seals that into a JSON summary
the change carries, and removes the context so the next task cannot inherit it.

Three things it deliberately is not. It is **not a score** - the findings stay in
the report with their file, their line and the input that triggers them, because a
number cannot be argued with. It **gates nothing** - a stale run is reported by
`doctor`, never refused by the gate, since verification must not gain a way to fail
that has nothing to do with the code. And it is **entirely optional**: without a
context every command writes nothing and exits 0, so a project that upgrades and
never runs `start` sees no change at all.

Nothing here reaches the network. Whatever collects your agents' telemetry can join
on that run id afterwards; the harness's job ends at writing it down.

## Who owns what

This is the whole design. Get it wrong and either upgrades destroy your decisions,
or your projects drift apart.

| The harness owns it - replaced on `upgrade` | The project owns it - never touched |
|---|---|
| `scripts/harness/verify` | `scripts/harness/config.sh` |
| `scripts/harness/run` | `.harness/` - runtime state, gitignored, nobody's to keep |
| `.githooks/pre-commit` | `docs/harness/mandatory-steps.md` |
| `.agents/skills/<vendored>` | `docs/harness/architecture-rules.md` |
| `scripts/harness/VERSION` | `openspec/config.yaml` |
| `AGENTS.md` between the harness markers | `AGENTS.md` outside them, or with no markers at all |

**About that last row.** `<!-- harness:begin -->` / `<!-- harness:end -->` are how a
project asks for the block to be kept current; `upgrade` then rewrites what is
between them and **nothing else** - your architecture notes above it and your
release process below it survive verbatim. No markers, no rewrite: the file is
yours whole, which is what the three oldest consumers ended up with. Delete both
markers any time to take the section back.

The markers must be an exact matching pair, each alone on its line. They are not
processed hopefully: a begin with no end, or an end with one trailing space, and
`norma` refuses the whole file and tells you why - because the rewrite would
otherwise delete everything below the marker.

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

**With one exception, and it is norma itself.** This repository is where `skills/`
lives, so a copy of it under `.agents/` would be a second version that drifts. The
installer recognises its own home and links there instead - creating the links a
newly added skill needs, repairing one that points at a skill that moved, and
refusing to overwrite a real directory someone put in the way. Every other
repository gets copies, which is what makes them survive a clone.

## Not per project

Some things are user-level and `install` deliberately does not touch them; `doctor`
reports on them:

- **OpenSpec's workflow set** lives in `~/.config/openspec/config.json`. It is global
  configuration, not per project.
- `tgrep`, `rtk` and `codegraph` are tools on your `PATH`.

## Engineering quality

```sh
test/run.sh
```

485 tests over the gate's real behaviour - its refusals above all - over the run
context and what the gate records through it, over every
profile and the detection that picks one, over the shape of the skill library, and
over `install`, `upgrade` and `doctor`, each in a throwaway git repository with a
stub stack adapter. They live here, once, because the gate is the same file everywhere:
before this repository existed the same eight tests were duplicated across three
projects in two languages.

The suite runs in a couple of seconds, under dash in CI, and norma installs its own
harness: every change to this repository passes the same gate and the same hook it
installs elsewhere.

## Documentation

- [`docs/01-architecture.md`](docs/01-architecture.md) - the pieces, and the
  ownership boundary the whole design rests on.
- [`docs/02-flows.md`](docs/02-flows.md) - what `install`, `upgrade` and `doctor` do
  step by step, and every refusal with its reason.
- [`docs/03-skills.md`](docs/03-skills.md) - the skill library and how to add to it.
- [`docs/04-testing.md`](docs/04-testing.md) - the suite and its conventions.

## Compatibility and scope

- `bin/` and `core/` are POSIX sh with no bashisms; CI runs the suite under dash, and
  it is developed on macOS.
- The gate works with any stack whose checks run from a shell; the profiles are
  starting points, not tested support (see above).
- Agent-agnostic by construction: everything is a file referenced by path. Claude
  Code additionally gets the skills as `/slash` commands through `.claude/skills/`.
- Native Windows is not supported; WSL is untested.

## Contributing

Contributions are welcome. Found a bug or have an idea?
[Open an issue](https://github.com/jcarlosrodicio/norma/issues).

[`AGENTS.md`](AGENTS.md) is the index for working on norma itself, for humans and
agents alike, and [`CONTRIBUTING.md`](CONTRIBUTING.md) has the rules and the
checklist. `CLAUDE.md` is a symlink to `AGENTS.md`, because Claude Code autoloads
only the latter.

## License

Licensed under the [MIT License](LICENSE). Some skills come from other projects;
[NOTICE.md](NOTICE.md) lists them with their licenses.

## Disclaimer

norma is not affiliated with Anthropic, OpenAI, OpenSpec or any agent vendor it
works with.
