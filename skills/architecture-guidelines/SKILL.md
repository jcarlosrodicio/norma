---
name: architecture-guidelines
description: Use before writing or reviewing any production code - the shared architectural criteria (layering, domain purity, naming, testing, migrations) that apply across projects. Read it during planning and implementation, and use it as a review dimension. Consult the backend reference for services, APIs and CLIs, and the frontend reference for client applications.
version: 1.0.0
---

# architecture-guidelines

The harness says *how* to work: enrich, plan, implement, verify, review, document.
This skill says *what good code looks like* while you do it. Without it every
project restates the same rules in its own words and a new project starts from
nothing.

## Precedence - read this first

When two sources disagree, the winner is fixed. Do not pick the convenient one:

1. **The user's request in the current conversation.**
2. **The project's own documents** - `AGENTS.md` and everything it indexes
   (`ARCHITECTURE.md`, `docs/`, ADRs). These are the source of truth for the
   repository you are in.
3. **`docs/harness/architecture-rules.md`** in the project - the adoption map. It
   declares which parts of this skill apply here, which do not, and why.
4. **The references in this skill** - shared criteria, for anything the project has
   not decided.
5. **The existing code** - last. A pattern in a random file is evidence of what
   somebody once did, not a decision.

Where code and documentation disagree, the documentation wins **and the
disagreement is a finding you report**.

## Which reference

- `references/backend.md` - services, APIs, CLIs, workers, anything with a data
  store and a delivery surface.
- `references/frontend.md` - client applications: web, mobile, desktop.

A repository with both (an API plus a dashboard) uses both, each on its own side of
the boundary. Read the one you need, not both by default.

## Way of working

Five rules that sit above any specific architecture:

1. **Think before you code.** State assumptions and doubts explicitly. If there are
   several readings, present them instead of silently choosing one. If a simpler
   solution exists, propose it.
2. **Prefer simplicity.** Write the minimum code that solves what was asked. No
   unrequested features, no single-use abstractions, no speculative
   "flexibility" or configuration, no handling of impossible cases.
3. **Surgical changes.** Touch only what the request needs. Do not "improve"
   adjacent code or refactor what is not broken. Respect the existing style. Report
   unrelated dead code; do not delete it. Clean up only what your own change left
   unused.
4. **Verifiable goals.** Turn every task into checkable success criteria. Bugs:
   reproduce with a test, then make it pass. Refactors: green before and after.
   Nothing is done until it is verified.
5. **Imitate the canonical example.** Every pattern in a project has one reference
   implementation, end to end. When in doubt, copy its structure, names and style
   instead of inventing. **Uniformity beats personal preference.**

## How this is used in the loop

- **Planning** (`openspec-new-change`, `openspec-ff-change`): the design must name
  the layer each new piece belongs to, and any rule it deliberately breaks.
- **Implementing** (`openspec-apply-change`): the applicable reference plus the
  project's adoption map are mandatory reading before the first edit, and the
  project's own architecture document overrides both.
- **Reviewing** (`adversarial-review`): architectural conformance is a review
  dimension. A layer violation is a finding with a file and a line, like any other.
- **Machine over prompt.** Where a rule can be enforced by a tool - a dependency
  linter, a boundary check, a static gate - the tool is the real rule and this file
  is only its explanation. Prefer adding the check to arguing with the agent.

## Exceptions

A deliberate exception is legitimate. A silent one is not. Record it where it
happens, with its reason, and do not extend it by analogy: the next case starts from
the rule again, not from the exception.
