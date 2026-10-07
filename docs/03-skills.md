# 03 · Skills

`skills/` is the canonical library. It is vendored into every project as real
directories under `.agents/skills/`, exposed to Claude Code through
repository-relative symlinks in `.claude/skills/`, and referenced everywhere **by
path** so any agent can follow it without a skill system of its own.

## The library

| Skill | What it is for |
|---|---|
| `run-task` | The whole loop in one procedure, and the single entry point. References every stage by file path, classifies a failure before retrying it, opens the run context on the branch stage and closes it with the change, and marks the three stops. |
| `auto-run-task` | The same loop with nobody watching: it replaces each of the three stops with a decision it records, and ends at an open pull request. A delta over `run-task`, not a copy of it. |
| `harness-setup` | The interview that fills what `install` cannot infer. Detects first, asks in five rounds, never invents a decision. |
| `enrich-task` | Turns a vague request or a roadmap line into an implementable specification, ending in the open questions the request left ambiguous. |
| `architecture-guidelines` | The shared architectural criteria - `references/backend.md` and `references/frontend.md` - plus the precedence order. A project's adoption map narrows it. |
| `runtime-verification` | The procedure behind step 5 of the loop: decide whether the change has a surface, exercise the happy path and the failure path, capture the evidence the surface actually needs, and report what it does **not** cover. Ends by recording a surface and one of three verdicts against the run. norma owns the method; the project owns the commands. |
| `adversarial-review` | An independent pass that assumes the work is wrong. Zero trust, attack rather than admire, every finding with a file and a line. Accounts for every file in the diff, fact-checks its own findings before reporting them, treats a bar lowered to get to green - a test made easier, a checker silenced, a threshold moved - as blocking unless the change justifies it, and records its coverage, its counts and its verdict against the run - the findings themselves stay in a dated report that travels with the change, because the session that applies them is often another one. |
| `code-auditing` | The security pass - OWASP Top 10, NIST - for changes touching credentials, permissions, payments or personal data. |
| `update-docs` | Mandatory before delivery. Documentation that lags the code poisons every later session - the roadmap phase included, which is the update no diff points at. |
| `commit` | Atomic commits, explicit paths, message written from the actual diff. Never `git add -A`. |
| `using-git-worktrees` | Isolated workspaces when work must not disturb the current tree. |
| `start-project` | The interview that turns "I want to build X" into documents, a roadmap of phases and an installed harness. **Not vendored** - see below. |
| `writing-skills` | How to write a skill. Third-party; the source of `render-graphs.js` and the reason linters must exclude `.agents`. |

Twelve vendored, plus one that is not. That is the ceiling, and it has moved
once - which is worth saying here rather than quietly editing a number. The
workshop this harness came from is explicit about the danger: thirty skills and
seventeen agents is a symptom, not a feature. A skill earns its place by being
invoked, not by existing.

`runtime-verification` earned it on exactly that test. It is invoked by every
task that changes behaviour - more often than `code-auditing`, vendored since the
start - and before it existed, the stage it covers was the only stage of the loop
with no procedure of its own. `run-task` spent one line on it and everything else
lived in `docs/harness/mandatory-steps.md`, which the **project** owns. A
procedure kept there never receives an upgrade, so each consumer drifted its own
way and no improvement could reach any of them. The split it introduces is the
one the gate already makes: norma owns the method, the project owns the commands.
The migration checks moved out of the template for that reason, and the template
keeps its `TODO(harness)` markers, which are the commands.

## The autonomous variant is a delta, not a copy

`auto-run-task` runs the same eight stages as `run-task` and says so instead of
restating them: it names the stage, points at `run-task` for its content, and
describes only what changes. Copying the stages would have produced a second
version of the loop that drifts from the first the moment either is edited - the
same reason this repository symlinks its own skills instead of vendoring them into
itself.

What it does own, because `run-task` has no equivalent, is the part that makes an
unsupervised run reviewable:

- **The decision contract.** What the agent may settle by itself - anything
  reversible and inside the phase - and the seven reasons it must stop anyway.
  Crisp on both sides on purpose: a vague list produces either an agent that asks
  about everything, which is useless, or one that asks about nothing, which is
  dangerous.
- **The hard limits.** Never `--no-verify`, never edit the gate or the hook to
  pass, never silence a failing test, never force-push, never merge, deploy,
  publish or touch a credential. The one about the failing test is the load-bearing
  one: with nobody watching, *make it green* is the dominant failure mode, and
  every other rule is downstream of refusing it.
- **The autonomy log** - `openspec/changes/<change>/reports/autonomy.md`, linked
  from the pull request. Every question enriching raised and the answer the agent
  chose, the plan self-review, every rule bent, every retry, everything deferred.
  This is the whole compensation for the removed stops: the human stops deciding
  three times before the code and decides once after it, and they can only do that
  if the decisions are written down.

The three stops become: triage the open questions instead of asking them, review
the plan against the roadmap instead of showing it, and deliver to a pull request
instead of handing over. The end of the run is the pull request, never a merge -
taking that away would leave the human with no review point at all, which is the
one thing this mode cannot afford.

## The one skill that is not vendored

`start-project` runs **before the project exists**: there is no repository, no
`.agents/`, and nothing to vendor into. It is reached through the installation
instead - `$(norma home)/skills/start-project/SKILL.md` - which is what
`norma home` is for, and what `norma start` writes into the empty directory so the
human never has to type it.

Leaving it out of `VENDORED_SKILLS` is a decision, not an oversight, and the test
suite asserts that `install` does not ship it. Once it has finished, the project
has a roadmap and a harness, and the skill that matters from then on is
`run-task`. A copy of the founding interview sitting in `.agents/skills/` would
only be one more thing an agent can misfire on.

It is written as a **conversation with a checklist behind it**, not as rounds: what
is fixed is what it must end up knowing before a phase table can exist, and the
route there belongs to the human. That is also why it names no agent - a shell and
the ability to write files is all it assumes.

It ends by installing the harness and handing over to `harness-setup`, carrying
the answers it already has, and it makes the founding commit the way
[`02-flows.md`](02-flows.md) describes. The two must not re-interview the human:
the design conversation and the roadmap it builds already settle the stack, its
commands, the branch and phase conventions and where the tests live - which is
most of rounds 1 and 2 of `harness-setup`. (This paragraph used to name "rounds 3
and 4 of `start-project`", contradicting the one above it: that skill has no
rounds, and never had.)

## The description field is the whole trigger

The `description` in the frontmatter is the only thing a model reads when deciding
whether to fire a skill. Write it as **when to use this**, not what it contains:
the conditions, the phrasings a user would actually type, and the boundary against
neighbouring skills. `writing-skills/SKILL.md` covers this properly - read it
before adding or renaming anything.

## Adding or changing a skill

1. Write or edit it under `skills/<name>/SKILL.md`.
2. If it is a new skill, add its directory name to `VENDORED_SKILLS` in
   `bin/norma`. Nothing installs it otherwise, and the count check in `doctor`
   reads the same list. Leaving it out is legitimate only for a skill that runs
   outside a project at all - `start-project` is the only one so far - and then
   say so in this document, because otherwise it reads as a missing line.
3. Reference other instructions **by path** (`.agents/skills/<name>/SKILL.md`),
   never by an agent's shortcut. A path is what makes it portable; mention the
   shortcut only as an aside, the way `run-task` does.
4. Bump `VERSION` - skills are vendored content.
5. `test/run.sh`. The installer test asserts that `run-task` and `harness-setup`
   land as real files; extend it if the new skill deserves the same guarantee.

Third-party skills - `writing-skills`, `code-auditing`, `using-git-worktrees` -
came from outside. Keep local edits minimal and confined to statements that would
otherwise be wrong inside a vendored copy, such as where skills live.
