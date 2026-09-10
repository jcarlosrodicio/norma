---
name: commit
description: Use when the user asks to commit, to create a pull request, or when a change is verified and ready to land - produces atomic commits that stage only the files belonging to the change, with a message and PR body written from the actual diff.
version: 1.0.0
---

# commit

## Rules

- **Atomic.** One commit per logical change. Never `git add -A` or `git add .`;
  stage the specific paths this change touched.
- **Never commit unrelated work.** Run `git status` first. If the tree contains
  modifications outside the change, list them to the user and stage only what
  belongs. Do not stash or revert someone else's work-in-progress.
- **Never commit secrets or local config.** Check the diff for keys, tokens, `.env`
  values and absolute paths from this machine before staging.
- **English, imperative mood**, as required by the project language standard.
- **Do not commit unless asked.** The harness loop stops before delivery so the
  human reviews first.

## Branch

Work on a feature branch, never directly on the default branch. These projects use
phase-based naming - follow whatever the repository already does (for example
`phase-NN-<slug>`), and if no convention is visible, ask instead of inventing one.

## Message format

```
<type>: <what changed, imperative, under 72 chars>

<why it changed - the problem, not a restatement of the diff>

<what to know when reading it later: decisions taken, trade-offs,
what was deliberately left out>
```

Types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `perf`.

Write the body from the diff you actually staged. Do not describe files you did not
change, and do not claim tests pass unless you ran them in this session.

## Pull request

When a PR is requested, the body carries:

- **What** - the behaviour change, in product terms.
- **Why** - the problem or the roadmap phase it belongs to.
- **How** - the approach and the decisions worth questioning.
- **Verification** - the commands actually run and their results, plus what was
  not covered.
- **Risk** - what could break, and the rollback.

Link the change artifacts (OpenSpec change folder, spec or ADR) rather than
duplicating their content.

## Before finishing

Report the commit hash and the exact paths staged, so the human can check nothing
extra travelled with it.
