---
name: harness-setup
description: Use to install or finish setting up the task harness in a repository - it detects the stack, interviews the human for every decision the installer cannot infer, and writes the gate config, the mandatory loop, the architecture adoption map and the index. Use it on a repository with no harness, and on one where docs/harness still contains TODO(harness) markers.
version: 1.0.0
---

# harness-setup

`harness install` puts the mechanical half in place: the gate, the hook, the skills,
and templates full of `TODO(harness)` markers. Those markers are the half that
encodes decisions - your layers, your commands, your conventions - and no installer
can infer them. This procedure fills them by asking.

A harness left half-installed is worse than none: the loop points at documents that
say `TODO`, and every agent that reads them learns that the rules are decoration.

## Portability

This procedure references files **by path**, never by an agent-specific shortcut, so
it runs identically whichever agent executes it. If you are Claude Code it is also
invocable as `/harness-setup`; any other agent reads this file.

## The two rules

1. **Detect first, then ask.** Never ask what you can read. Come to the human with
   *proposals* - "your gates look like `pnpm lint && pnpm typecheck`, right?" - not
   with a blank form. An interview that makes them type what is already in
   `package.json` will be abandoned halfway.
2. **Never invent a decision.** If they do not answer something, write the question
   into the document as an explicit open question, marked as unanswered. A guessed
   convention that everybody then follows is worse than an admitted gap.

## 0. Locate the harness

```
harness doctor
```

- Command not found: the harness repository is not installed on this machine. Ask
  the human for its location, then tell them the two commands (clone it, and
  `ln -s <repo>/bin/harness ~/.local/bin/harness`). Do not clone anything yourself
  without being asked.
- It reports no harness in this repository: run `harness install --dry-run`, show
  the human what it would do, and run `harness install` once they agree.
- It reports TODOs or missing pieces: that list is your worklist.

## 1. Read the repository before asking anything

Build a findings sheet. Look for:

- **Build and test commands** - the package manifest's scripts, the CI workflow (it
  is the most honest statement of what must pass), the README's contributing notes.
- **What already enforces the architecture** - a dependency linter, a boundary
  check, an architecture test suite, a lint config with import rules. This is the
  single most important thing to find: it goes into `harness_gates`, and it means
  you must **not** add a second mechanism that competes with it.
- **The layer layout** - the directory structure, and any document that describes
  it. Prefer the document.
- **Branch and roadmap conventions** - `git branch -a` for the naming pattern in
  use, plus any roadmap or phase documents.
- **Where decisions live** - an ADR directory, a decision log, a spec registry.
- **The default branch name**, so the hook's refusal matches reality.

Report the sheet to the human in a few lines before the first question. It shows
them what you already know and what you are about to ask about.

## 2. Interview, in rounds

Ask in **four rounds**, in this order. Each round is a handful of questions with
your proposed answer attached. **STOP after each round and wait**: a wrong answer in
round 1 is copied into every document you write later.

Keep every question concrete. "What are your layers?" gets a vague answer; "I see
`packages/domain`, `packages/application`, `packages/adapters` - does application
depend only on domain and ports?" gets a decision.

### Round 1 - the gate (`scripts/harness/config.sh`)

1. The static gates, in order, and which of them are fast enough to run on every
   verification.
2. Whether the architecture check you found in step 1 belongs in the gates. If the
   repository has one and it only runs in CI, say so plainly: with the
   "only the tests involved" rule, CI becomes the *only* place it ever runs.
3. The command that runs **one** named test target, and the one that runs
   everything.
4. The top-level directories that count as code, for `HARNESS_CODE_PATHS`.

### Round 2 - the loop (`docs/harness/mandatory-steps.md`)

1. The default branch name, and the branch naming convention.
2. Where the roadmap lives, and whether work is organised in phases.
3. Where tests live per layer, and which runner or flag each needs.
4. How this project is exercised **for real** - a simulator, an HTTP call, the
   packed CLI, a browser flow - and when that is mandatory.
5. Which areas are sensitive enough to also require `code-auditing`:
   authentication, credentials, payments, personal data.
6. Which documents own which topic, and where a new decision is registered.
7. Whether CI runs the full suite on the pull request. That is the backstop for
   `git commit --no-verify`, the one hole the hook cannot close - if CI does not do
   it, say so, because then the hole is real.

### Round 3 - the architecture criteria (`docs/harness/architecture-rules.md`)

1. Which reference applies - `references/backend.md`, `references/frontend.md`, or
   both on different directories.
2. The precedence order: name this repository's own architecture documents, because
   they win over the shared reference.
3. Which sections the project **adopts**, and specifically which rules its own
   documents do not state yet. Those are the ones worth writing down.
4. Which sections are **not applicable, and why**. This is the half that stops a
   shared guideline from fighting the project, and the reason matters as much as the
   decision - without it, the next reader re-adopts what you dropped.
5. Anything the reference asks for that this project deliberately does the other
   way. Record it as a deliberate exception, not as debt.

### Round 4 - the index and the extras

1. If `AGENTS.md` does not exist or does not mention the harness, propose the
   section; if it already documents the harness, leave it alone and say so.
2. Confirm `CLAUDE.md` is a symlink to `AGENTS.md`. Without it, Claude Code loads
   nothing and the whole harness is dead letter.
3. Whether the linter or formatter excludes `.agents/**`. Vendored skills carry
   third-party files, and a linter will report them as the project's own.
4. Optional per-agent extras the human may want: an indexed search server, a
   token-cutting proxy, a code graph, MCP servers. Ask, do not install.

## 3. Write

Now write the answers into the files, replacing every `TODO(harness)` you touched:

- `scripts/harness/config.sh` - the contract is `HARNESS_CODE_PATHS`,
  `harness_gates`, `harness_test_selected`, `harness_test_all`. Use `run` for every
  command. Keep the comment block at the top.
- `docs/harness/mandatory-steps.md` - stack-specific, in the project's language and
  with its real commands. Never leave a generic step that names no command.
- `docs/harness/architecture-rules.md` - the adoption map, including the
  not-applicable section with reasons.
- `openspec/config.yaml` - the `context` block, if the project uses OpenSpec.
- `AGENTS.md` - only if round 4 said so.

Anything unanswered stays in the file as a marked open question. Do not quietly
drop it, and do not answer it yourself.

## 4. Verify, then report

Prove the harness works rather than asserting it:

```
harness doctor
scripts/harness/verify --docs-only
```

`doctor` must be clean, and the gate must actually run the project's real gates and
record a stamp. If the gates fail, that is a finding about the repository, not about
the harness - report it, do not paper over it by weakening the gates.

Then confirm the two refusals hold, because they are what makes the loop binding:

```
scripts/harness/verify              # must refuse: no test target
```

Report to the human:

- which files you wrote, and which questions they answered;
- what `doctor` says now;
- what remains open, and what will not work until they answer it;
- what you deliberately did not do - anything you were asked not to install, and
  any decision you left as an open question.

Finally: **stop**. Do not commit. Setting up the harness is a change like any other,
and the harness itself says the human reviews before delivery.
