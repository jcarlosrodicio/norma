# 03 · Skills

`skills/` is the canonical library. It is vendored into every project as real
directories under `.agents/skills/`, exposed to Claude Code through
repository-relative symlinks in `.claude/skills/`, and referenced everywhere **by
path** so any agent can follow it without a skill system of its own.

## The library

| Skill | What it is for |
|---|---|
| `run-task` | The whole loop in one procedure, and the single entry point. References every stage by file path and marks the three stops. |
| `harness-setup` | The interview that fills what `install` cannot infer. Detects first, asks in four rounds, never invents a decision. |
| `enrich-task` | Turns a vague request or a roadmap line into an implementable specification, ending in the open questions the request left ambiguous. |
| `architecture-guidelines` | The shared architectural criteria - `references/backend.md` and `references/frontend.md` - plus the precedence order. A project's adoption map narrows it. |
| `adversarial-review` | An independent pass that assumes the work is wrong. Zero trust, attack rather than admire, every finding with a file and a line. |
| `code-auditing` | The security pass - OWASP Top 10, NIST - for changes touching credentials, permissions, payments or personal data. |
| `update-docs` | Mandatory before delivery. Documentation that lags the code poisons every later session. |
| `commit` | Atomic commits, explicit paths, message written from the actual diff. Never `git add -A`. |
| `using-git-worktrees` | Isolated workspaces when work must not disturb the current tree. |
| `start-project` | The interview that turns "I want to build X" into documents, a roadmap of phases and an installed harness. **Not vendored** - see below. |
| `writing-skills` | How to write a skill. Third-party; the source of `render-graphs.js` and the reason linters must exclude `.agents`. |

Ten vendored, plus one that is not. That is the ceiling. The workshop this harness came from
is explicit about it: thirty skills and seventeen agents is a symptom, not a
feature. A skill earns its place by being invoked, not by existing.

## The one skill that is not vendored

`start-project` runs **before the project exists**: there is no repository, no
`.agents/`, and nothing to vendor into. It is reached through the installation
instead - `$(norma home)/skills/start-project/SKILL.md` - and that is what
`norma home` is for.

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
[`02-flows.md`](02-flows.md) describes. The two must not re-interview the human: rounds 3 and
4 of `start-project` cover most of rounds 1 and 2 of `harness-setup`.

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
