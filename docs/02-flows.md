# 02 · Flows

## `norma install [--profile <name>] [--dry-run]`

Run inside the target repository. `--dry-run` prints the plan and writes nothing;
use it first on a repository that already has content.

1. Require a git repository, and resolve the profile - detected or `--profile`.
2. Vendor `core/verify` → `scripts/harness/verify` (0755).
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

Re-vendors only what the harness owns: the gate, the hook, the skills, the
version stamp. It never touches `config.sh`, the documents, `openspec/config.yaml`
or `AGENTS.md`.

If an owned file was edited locally and upstream has not changed, it reports and
keeps the local edit instead of clobbering it; `--force` replaces it.

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
orient → enrich → branch → plan → implement → verify → review → document → hand over
         ^stop            ^stop                                            ^stop
```

`docs/harness/mandatory-steps.md` in each project is the binding checklist, with
that project's real commands.

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

### The hook

| Refusal | Why |
|---|---|
| On the default branch | Work belongs on a branch; the project's convention names it. |
| No stamp | Nothing was verified. |
| Stamp older than a staged file | Code was edited after being verified. The refusal prints the previous selection, ready to paste. |
| `docs-only` stamp with staged code | Rule 3 cannot catch code edited *before* that run, and a docs-only run vouches for no test at all. |

Soften none of these without reading the reason and replacing it with something
stronger.
