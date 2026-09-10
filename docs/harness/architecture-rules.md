# Harness: architecture rules (adoption map)

Which parts of [`../../skills/architecture-guidelines/`](../../skills/architecture-guidelines/SKILL.md)
apply here.

## Which reference

**Neither.** `references/backend.md` describes services with a domain model, a
data store and a delivery surface; `references/frontend.md` describes client
applications. norma is a few hundred lines of POSIX sh with no domain, no
persistence and no UI. Adopting either wholesale would mean inventing layers to
have something to separate.

## What does apply

From [`SKILL.md`](../../skills/architecture-guidelines/SKILL.md), the way of
working - think first, prefer simplicity, surgical changes, verifiable goals,
imitate the canonical example - applies as written and is not restated here.

Beyond that, four rules govern this repository, and they live in
[`../../AGENTS.md`](../../AGENTS.md) because they are non-negotiable rather than
architectural:

1. POSIX sh in `bin/` and `core/`.
2. Never widen what the harness owns - the table in
   [`../01-architecture.md`](../01-architecture.md).
3. No behaviour change to `core/` or `bin/` without a test.
4. Bump `VERSION` when vendored content changes.

## Precedence

1. The user's request in the current conversation.
2. `AGENTS.md` and the documents under `docs/`, which are the source of truth.
3. This file.
4. The shared reference.
5. Existing code, last.

## What enforces it

`sh -n` over every shell file, plus the suite, both inside
`scripts/harness/verify`. Nothing enforces rules 1 to 4 mechanically beyond the
parse check: they depend on review. That is worth saying plainly rather than
implying a guarantee that does not exist - and if a check for any of them becomes
possible, it belongs in the gate rather than in this document.
