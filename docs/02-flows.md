# 02 · Flows

## `norma start [<directory>]`

The front door of a project that does not exist yet. It needs no repository and
no harness, creates the directory if it is not there, and writes one file: an
`AGENTS.md` holding the absolute path of `skills/start-project/SKILL.md`, plus the
`CLAUDE.md` symlink. Then the human opens an agent there and says what they want to
build - every agent reads `AGENTS.md` (or `CLAUDE.md`) on the way in, so nothing has
to be typed or pasted.

It has been exercised end to end twice - a web application and a CLI - from the
empty directory to a repository with its documents, its roadmap, the harness
installed and `doctor` clean. What that found is in `start-project` itself: the
founding commit below, and the fact that the note must be **overwritten** rather
than appended to, or the first thing anyone reads about the project is an
instruction to start it.

It refuses when `AGENTS.md` already exists: that is a project that has started, and
its route is `install` plus `harness-setup`. The note is temporary and carries
`<!-- norma:start -->` markers so the procedure can recognise and replace it with
the project's real index.

## `norma install [--profile <name>] [--dry-run]`

Run inside the target repository. `--dry-run` prints the plan and writes nothing;
use it first on a repository that already has content.

1. Require a git repository, and resolve the profile - detected or `--profile`.
2. Vendor `core/verify` → `scripts/harness/verify` (0755) and `core/run` →
   `scripts/harness/run` (0755).
3. Write `profiles/<p>.sh` → `scripts/harness/config.sh` **only if absent**.
4. Vendor `core/pre-commit` → `.githooks/pre-commit` (0755), and
   `git config core.hooksPath .githooks`.
5. Stamp `VERSION` → `scripts/harness/VERSION`.
6. Vendor each skill → `.agents/skills/<name>/` as a real directory, and create
   `.claude/skills/<name>` → `../../.agents/skills/<name>` (repository-relative,
   so a worktree resolves it).
7. Write the templates - `docs/harness/mandatory-steps.md`,
   `docs/harness/architecture-rules.md`, `openspec/config.yaml` - **only if
   absent**.
8. `AGENTS.md`: create it with the harness block if missing; inject the block
   between markers if the markers are there; **leave it alone** if the file
   already documents the harness under any heading.
9. `CLAUDE.md` → `AGENTS.md` if absent. Without it Claude Code loads nothing and
   the whole harness is dead letter, because it autoloads only `CLAUDE.md`.
10. Ensure `.gitignore` carries `.harness/`, `.tgrep/`, `.codegraph/`.

Installing twice changes nothing - there is a test for it.

## `norma upgrade [--force]`

Re-vendors only what the harness owns: the gate, the run context, the hook, the
skills, the version stamp, and the `AGENTS.md` block **when the markers are
there**. It never
touches `config.sh`, the documents or `openspec/config.yaml`.

Three details that are each there for a reason:

- **The `AGENTS.md` block is refreshed only between `<!-- harness:begin -->` and
  `<!-- harness:end -->`.** Those markers are the project's opt-in; without them
  the file is untouched, down to not appending a block to one that lost it. The
  block announces itself as managed, so leaving it stale - which is what happened
  while only `install` rewrote it - made a new skill invisible to every agent that
  reads `AGENTS.md` by path, however correctly it had been vendored.

  Everything outside the pair survives verbatim: the architecture notes above it,
  the release process below it, the project's own conventions. **Unless the pair
  is not a pair**, which is why that is now a refusal - see below.
- **In norma's own repository, vendoring means linking.** `skills/` there is the
  source, so a copy under `.agents/` would be a second version of it. The
  installer detects that it is acting on its own home and creates, repairs and
  leaves the symlinks alone accordingly - see the self-hosting note in
  [`01-architecture.md`](01-architecture.md). Everywhere else, a copy is exactly
  what you want, and nothing changes.
- **`.claude/skills/<name>` is repaired, not merely created.** The old check asked
  whether something was there, never whether it pointed at the right place, so a
  link left dangling or aimed elsewhere survived every upgrade. A real directory at
  that path is still left alone: that is how `openspec` ships its own skills, and
  deleting them is not the harness's business.
- **The version stamp is written last**, and that order is load-bearing rather than
  incidental. The local-edit guard below decides by comparing the repository's
  stamp against the upstream version, so stamping first would answer its own
  question and clobber every local edit silently.

If an owned file was edited locally and upstream has not changed, it reports and
keeps the local edit instead of clobbering it; `--force` replaces it. When upstream
*has* changed, the upgrade replaces it - deliberately, and so far without saying
that a local edit went with it.

### The refusal that guards the block

`AGENTS.md` is rewritten only when the markers are **exactly one of each, each on
its own line, matching to the byte, begin before end**. Anything else - a begin
with no end, an end carrying one trailing space, a duplicated marker, the two in
the wrong order - and the whole file is left alone with a message saying what is
wrong and how to fix it.

That is not defensiveness. The rewrite copies everything up to the begin marker,
inserts the block, and resumes at the end marker; with nothing to resume at, it
**deletes the rest of the file** - the release process, the house conventions,
whatever lived below. It did exactly that until this refusal existed, and a single
trailing space was enough to trigger it. The failure was silent and the damage was
somebody else's content, which is the worst combination a tool can offer.

`--dry-run` prints the whole plan, the links included. A plan that announced a
skill but not the link an agent reaches it through was worse than no plan: it read
as complete.

### When not to propagate

Learned the hard way. **Do not upgrade a repository that carries unrelated work in
progress.** Three specific traps:

- Rewriting `.githooks/pre-commit` adds a file to somebody's pending change.
- Switching branches to reach `master` drags their uncommitted work with it,
  because uncommitted changes follow `HEAD` and belong to no branch.
- Worst: **running the gate there overwrites their stamp.** Your stamp would be
  newer than their files, so their commit would pass with *your* verification
  vouching for code you never tested. A false green is worse than a refusal.

So: check `git status` and the current branch first, use explicit paths - never
`git add -A` - and if the tree is not yours, wait. Propagation is never urgent.

## `norma home`

Prints the installation directory and requires nothing - no repository, no
harness. It exists for the one skill that runs before the project does:
`$(norma home)/skills/start-project/SKILL.md`. Everything else is reached through
the vendored copy inside the repository.

## `norma doctor`

Changes nothing; exits non-zero when something is blocking. It reports:

- the gate present, and whether it matches upstream or was edited locally;
- `scripts/harness/run` present and executable, and **a run left open on another
  branch** - the gate does not refuse for that, deliberately, so this is the only
  place a human hears that the next task is about to collect its evidence under
  somebody else's identity;
- the config contract complete, and whether it still has `TODO`;
- the hook present and `core.hooksPath` armed;
- `CLAUDE.md` → `AGENTS.md`, and that `AGENTS.md` points at `run-task` and the gate;
- the templates, warning while `TODO(harness)` remains and naming
  `harness-setup` as the way to fill them;
- vendored skills present, and **any symlink that escapes the repository**;
- whether a linter or formatter config excludes `.agents` - vendored skills ship
  third-party files a linter will otherwise report as the project's own;
- **what the repository already enforces** - dependency linters, architecture test
  suites - so you wire it into `harness_gates` instead of duplicating it;
- machine-level prerequisites: `openspec`, `tgrep`, `rtk`, `codegraph`, and
  whether OpenSpec has an explicit workflow set. That set is **global**
  configuration in `~/.config/openspec/config.json`, not per project.

## The loop the harness imposes on a consumer

`skills/run-task/SKILL.md` chains it and marks the three points where it stops for
the human: after enriching, after planning, and before delivery.

```
orient → enrich → branch → plan → implement → verify → review → document → close → hand over
         ^stop   ^run     ^stop                                            ^run    ^stop
                  start                                                     close
```

`docs/harness/mandatory-steps.md` in each project is the binding checklist, with
that project's real commands.

**`close` is the stage that was missing.** The loop used to end at `document`, so
closing the phase in the roadmap and archiving the OpenSpec change happened - when
it happened - in a second branch after the merge. Both are ordinary file
operations that never needed the pull request merged, and splitting them cost a
branch, a review and a gate run each time, while the default branch carried code
whose delta specs had not been applied. The stage re-runs `verify` afterwards,
because an archive rewrites files and the hook rightly refuses a stamp older than
them.

### The same loop with nobody watching

`skills/auto-run-task/SKILL.md` runs those same stages when the human handed over a
whole phase and left. The stops do not disappear - each becomes something the agent
does and records:

```
orient → enrich → branch → plan → implement → verify → review → document → close → deliver
         ^decide ^run      ^self-review                                     ^run    ^commit, push, PR, CI
                  start                                                      close
```

The run context matters more here than under supervision, not less: a phase run
unsupervised is implemented, reviewed and corrected across sessions nobody
watched, and that identity is what says they were one phase. The pull request
carries the run id and links the summary beside the autonomy log - the log says
what was decided, the summary says what was verified and by whom.

Three things bound it, and none of them may be softened:

- **It stops anyway for seven reasons** - the answer changes *what* is built rather
  than how; the phase needs something outside itself; it needs a credential or a
  new dependency; the step is destructive; the harness itself is what is blocking;
  the same failure survived two attempts; the roadmap and the repository disagree.
  When it stops it commits, pushes, does **not** open the pull request, and asks
  every question at once.

  **Its own model provider is not one of the seven**, and that had to be written
  down: a real run hit a concurrency cap, reported it as "my budget is exhausted",
  and used the budget it had invented to deliver a phase with half the tasks
  undone - on a plan that was billed for none of it. A rate limit is retried; if it
  persists the run is **interrupted, not finished**, and says so with the task in
  `tasks.md` where it stopped. Nothing here asks for parallel subagents either, and
  when a run chooses them the ceiling is the provider's concurrency limit minus
  two: one for the agent asking, one spare for whatever else shares the key.
- **It ends at an open pull request**, never at a merge, a deploy or a publish. That
  pull request is the human's only review point, so removing it would leave the run
  reviewed by nobody. A red CI is not a finished run, and the failure is classified
  before it is touched: caused by this change, fixed and pushed again, twice at
  most; a flake, re-run without spending either attempt; already red on the base
  branch, escalated rather than fixed, because that repair would smuggle work from
  outside the phase into this pull request. Treating the three alike is how an
  unsupervised run burns its attempts on a flake, or "fixes" somebody else's
  breakage inside a phase pull request.
- **Every decision it took instead of asking is written down**, in
  `openspec/changes/<change>/reports/autonomy.md` and linked from the pull request -
  at the path the archive left it, `changes/archive/<date>-<change>/`, because
  `close` moves the folder before `deliver` writes that link. A dead link to the log
  is the same as no log.

`close` also has prompts that only a human can answer, and unsupervised nobody
does: `openspec-archive-change` stops on incomplete artifacts, unchecked tasks, and
whether to sync the delta specs. `auto-run-task` answers all three rather than
leaving them to chance - sync always, and unchecked tasks at that point mean the
phase is not finished rather than a prompt to click through. "Archive without
syncing" is the plausible wrong pick: it leaves the specs describing a system that
no longer exists, and looking finished.

The gate, the hook and the tests behave identically in this mode - an unsupervised
agent is exactly the case they were built for. What `auto-run-task` adds on top is a
refusal to game them: never `--no-verify`, never an edit to `verify` or the hook to
make a run pass, and never a failing test silenced instead of fixed.

Projects that run it need one edit to the file norma does not own: `Step 9 - Stop`
in their `docs/harness/mandatory-steps.md` has to name the exception, or the binding
checklist forbids the delivery the procedure requires. The template carries it for
new installs; an existing project edits its own copy.

## The one commit that precedes the rules

A project created by `start-project` cannot satisfy the hook on its first commit:
the gates in `config.sh` name a toolchain that phase 0 has not installed yet, so
`verify` cannot pass and there is no stamp to be had. The founding commit -
documents plus the harness, together - is therefore made with the hook overridden
for that single command:

```sh
git -c core.hooksPath=.git/hooks commit -m "..."
```

Not `--no-verify`, and not by unsetting `core.hooksPath`: both leave a repository
that is silently unarmed afterwards, which is the failure the hook exists to
prevent. The override applies to one command, nothing has to be re-armed, and the
next commit is already refused. The suite asserts all of that, including that
`install` arms through `core.hooksPath` rather than by writing into `.git/hooks` -
the day that changed, the documented bootstrap would break.

## Every refusal, and why it exists

### The gate

| Refusal | Exit | Why |
|---|---|---|
| No test target named | 2 | Naming the selection is part of the step: a reviewer must be able to judge whether the subset was right. |
| `--docs-only` with code in the change | 2 | The mode exists for documentation, configuration and harness work. It must not become a way past the tests. |
| `config.sh` missing, or missing a contract function or `HARNESS_CODE_PATHS` | 2 | A gate that silently runs nothing is worse than no gate. |

`--docs-only` judges the **staged** change when something is staged - that is the
commit being prepared, so an unrelated dirty tree does not block a documentation
commit - and the whole change when nothing is staged.

The **floor guard** that runs after the tests is not on this list on purpose: it
reports a lowered bar and refuses nothing, for the reasons in
[`01-architecture.md`](01-architecture.md). Making it a refusal is a decision
that waits for its own records to show it is precise enough.

**None of the three reaches the run's evidence log**, and the gate is written so
that it cannot: the recording is armed only once the gate is about to do real
work. These are the harness being pointed at the wrong thing, not a verification
that happened, and a log that counted them would report a task as having verified
three times when it verified once.

### The hook

| Refusal | Why |
|---|---|
| On the default branch | Work belongs on a branch; the project's convention names it. |
| No stamp | Nothing was verified. |
| Stamp older than a staged file | Code was edited after being verified. The refusal prints the previous selection, ready to paste. |
| `docs-only` stamp with staged code | Rule 3 cannot catch code edited *before* that run, and a docs-only run vouches for no test at all. |

### The run context

| Refusal | Exit | Why |
|---|---|---|
| `start` while a run from another branch is open | 2 | A different branch is a different task. Letting the old context attach itself silently would make every later correlation a lie, and a lie a machine believes. |
| A change slug with anything but letters, digits, `.`, `_` and `-` | 2 | It reaches a JSON file and a path. |
| `--kind` outside `production` and `benchmark` | 2 | The distinction is the contract; a third value is a typo. |
| An event key that is not lowercase, or a field that is not `key=value` | 2 | The log is read by machines, and a malformed line is found weeks later by whoever needed it. |

Everything else here refuses nothing on purpose. `status` without a context is not
a failure, `event` without one writes nothing and exits 0, `close` with nothing to
close says so and exits 0. The absence of a run is a **normal, supported state**:
it is what a project that upgrades and never adopts this sees, and what any agent
working outside a repository sees.

Soften none of these without reading the reason and replacing it with something
stronger.
