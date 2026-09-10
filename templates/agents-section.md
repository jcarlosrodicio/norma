## Harness

<!-- Managed by the norma installer. Edit the harness upstream, not this block. -->

- **Full procedure for any implementation task:**
  [`.agents/skills/run-task/SKILL.md`](.agents/skills/run-task/SKILL.md). It chains
  the whole loop in order - orient, enrich, branch, plan, implement, verify,
  adversarial review, document, hand over - and marks the points where you must stop
  and wait for the human. Read and follow that file; in Claude Code it is also
  invocable as `/run-task`.
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
- The agent executes verification itself. Never ask the human to run the tests.
- Project skills are real directories in `.agents/skills` (vendored, so they survive
  a clone) and are exposed to Claude Code through relative symlinks in
  `.claude/skills`.
- The loop stops before delivery: no commit, push, pull request, publish or deploy
  until the human approves.
