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
| `writing-skills` | How to write a skill. Third-party; the source of `render-graphs.js` and the reason linters must exclude `.agents`. |

Ten skills, and that is close to the ceiling. The workshop this harness came from
is explicit about it: thirty skills and seventeen agents is a symptom, not a
feature. A skill earns its place by being invoked, not by existing.

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
   reads the same list.
3. Reference other instructions **by path** (`.agents/skills/<name>/SKILL.md`),
   never by an agent's shortcut. A path is what makes it portable; mention the
   shortcut only as an aside, the way `run-task` does.
4. Bump `VERSION` - skills are vendored content.
5. `test/run.sh`. The installer test asserts that `run-task` and `harness-setup`
   land as real files; extend it if the new skill deserves the same guarantee.

Third-party skills - `writing-skills`, `code-auditing`, `using-git-worktrees` -
came from outside. Keep local edits minimal and confined to statements that would
otherwise be wrong inside a vendored copy, such as where skills live.
