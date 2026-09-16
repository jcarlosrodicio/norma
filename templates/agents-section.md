## Harness

<!-- Managed by the norma installer. Edit the harness upstream, not this block. -->

- **Full procedure for any implementation task:**
  [`.agents/skills/run-task/SKILL.md`](.agents/skills/run-task/SKILL.md). It chains
  the whole loop in order - orient, enrich, branch, plan, implement, verify,
  adversarial review, document, hand over - and marks the points where you must stop
  and wait for the human. Read and follow that file; in Claude Code it is also
  invocable as `/run-task`.
- **Unsupervised runs:** when the human hands over a whole roadmap phase and is not
  there to answer questions, the procedure is
  [`.agents/skills/auto-run-task/SKILL.md`](.agents/skills/auto-run-task/SKILL.md)
  (`/auto-run-task`). Same stages and same gate; it decides the ambiguities itself,
  records every decision, and ends at an open pull request instead of stopping
  before the commit. Use it only when the human asked for it.
- Mandatory per-task loop: [`docs/harness/mandatory-steps.md`](docs/harness/mandatory-steps.md).
  It is not advisory - every task list must contain its steps, in order.
- **Architecture criteria:** [`docs/harness/architecture-rules.md`](docs/harness/architecture-rules.md)
  is this project's adoption map over the shared reference in
  [`.agents/skills/architecture-guidelines/`](.agents/skills/architecture-guidelines/SKILL.md) -
  what good code looks like here, and which shared rules this project does not adopt.
  This repository's own architecture documents win over both.
- **Verification gate, one command for any agent:** `scripts/harness/verify <test
  targets>`. It runs the static gates plus only the tests **involved in the task**
  (the full run is CI's job on the pull request) and records the result. It refuses
  to run without a target: naming what you selected is part of the step.
  `--docs-only` is for a change that touches no code, and refuses the moment it sees
  a code file. Everything stack-specific lives in `scripts/harness/config.sh`.
- `.githooks/pre-commit` enforces it - no stamp, a stale stamp, or the default
  branch and the commit is refused, whatever agent you are. After a fresh clone:
  `git config core.hooksPath .githooks`.
- **Run context:** `scripts/harness/run start <branch slug>` right after creating the
  branch, `scripts/harness/run close <report path>` when closing the change. A task
  run is not an agent session - the implementation, the independent review and the
  corrections are deliberately different sessions, and this is what makes them one
  task. The gate and the review steps record their evidence against it; the summary
  it produces is committed with the change.
- The agent executes verification itself. Never ask the human to run the tests.
- Project skills are real directories in `.agents/skills` (vendored, so they survive
  a clone) and are exposed to Claude Code through relative symlinks in
  `.claude/skills`.
- The loop stops before delivery: no commit, push, pull request, publish or deploy
  until the human approves. An unsupervised run under `auto-run-task` is the single
  exception, and it still stops at the open pull request - merging, deploying and
  publishing are never the agent's.
