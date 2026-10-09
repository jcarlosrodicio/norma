# Notices

norma is licensed under the [MIT License](LICENSE). Parts of it come from other
projects, listed here with their licenses. This repository is not affiliated with
any of them.

## Vendored content

- **`skills/writing-skills/`** - from
  [`obra/superpowers`](https://github.com/obra/superpowers), MIT License,
  Copyright (c) 2025 Jesse Vincent. Edited locally where a statement would be wrong
  inside a vendored copy. The license travels with the skill as
  [`skills/writing-skills/LICENSE`](skills/writing-skills/LICENSE), so every project
  it is vendored into keeps the notice.
- **`skills/using-git-worktrees/`** - from
  [`obra/superpowers`](https://github.com/obra/superpowers), MIT License,
  Copyright (c) 2025 Jesse Vincent, in a copy modified by LIDR.co (the `author`
  field in its front matter). Its license travels with it as
  [`skills/using-git-worktrees/LICENSE`](skills/using-git-worktrees/LICENSE).

## Adapted ideas

- **`skills/adversarial-review/`** - the coverage contract of stage 1 and the two
  grounds of stage 4 are adapted from
  [`alibaba/open-code-review`](https://github.com/alibaba/open-code-review),
  Apache License 2.0. No code is copied; the skill says so where it uses them.

## Referenced, not vendored

- Anthropic's
  [skill authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)
  are linked from `writing-skills`, not copied.
- [OpenSpec](https://github.com/Fission-AI/OpenSpec),
  [rtk](https://github.com/rtk-ai/rtk), `tgrep` and `codegraph` are tools on the
  user's `PATH` that `doctor` looks for; the gate routes commands through rtk when
  it is installed. norma ships none of them.
