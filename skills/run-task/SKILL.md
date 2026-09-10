---
name: run-task
description: Use to run a complete implementation task end to end - a roadmap phase item, a feature, a fix or a refactor - from a vague request to code that is verified and waiting for human review. Invoke it whenever the user asks for work to be built rather than just discussed, and follow it in order without skipping stages.
version: 1.0.0
---

# run-task

The whole loop in one procedure. Follow it **in order**. Every stage produces the
input for the next, so skipping one leaves the following stage guessing.

## Portability

This procedure references other instructions **by file path**, never by an
agent-specific shortcut, so it runs identically whichever agent executes it. Read the
referenced `SKILL.md` and follow it.

If you are Claude Code, `/opsx:new`, `/opsx:ff`, `/opsx:apply` and `/opsx:verify` are
shortcuts to the same files; using them is equivalent. Any other agent reads the path.

The project's own rules always win over this file: `AGENTS.md` is the index, and
`docs/harness/mandatory-steps.md` is the binding checklist for the project you are in.

## 0. Orient

1. Read `AGENTS.md`. Follow it to the architecture and standards documents that the
   task touches. Do not explore the codebase freely first - documented patterns beat
   whatever a random file happens to do.
2. Read `docs/harness/mandatory-steps.md`. It is not advisory.
3. Read `docs/harness/architecture-rules.md` - the project's adoption map - and the
   reference it points at in `.agents/skills/architecture-guidelines/`. That is the
   criteria layer: what good code looks like here, and which shared rules this
   project does not adopt. The project's own architecture document wins over both.
4. Make sure the search index is serving so it reflects recent changes:
   `tgrep status`, and if it reports no PID, `tgrep serve .` in the background.

## 1. Enrich

Follow `.agents/skills/enrich-task/SKILL.md`.

Turn the request into an implementable specification. It ends with the open questions
the request left ambiguous.

**STOP.** Put those questions to the user and wait. Do not answer them yourself and
do not continue on assumptions - a wrong assumption here is paid for in every later
stage. Skip this stage only if the request already carries acceptance criteria,
affected files and non-functional requirements.

## 2. Branch

Create and switch to a feature branch before any edit, named after the roadmap phase
the work belongs to. Never work on the default branch - `.githooks/pre-commit`
refuses commits there anyway.

## 3. Plan

Follow `.agents/skills/openspec-new-change/SKILL.md`, then
`.agents/skills/openspec-ff-change/SKILL.md`.

That produces the proposal, the spec and `tasks.md`. `tasks.md` is the persistent
state: mark entries as you complete them so an interrupted session can resume.

**STOP.** Show the user the task list before writing code. This is the cheapest
moment to catch a misunderstanding, and the last one before it becomes code.

## 4. Implement

Follow `.agents/skills/openspec-apply-change/SKILL.md`, respecting every step in
`docs/harness/mandatory-steps.md`: tests before implementation, the project's layer
boundaries, and the mandatory verification steps in their stated order.

Write code that conforms to the architecture criteria you read in stage 0. Where a
rule is enforced by a tool - a dependency linter, a boundary check - the tool is the
rule. Where you must deviate, say so in the report with its reason; a silent
exception is a defect. And imitate the canonical example: the project's existing
reference implementation of the pattern beats your own preference.

## 5. Verify

```
scripts/harness/verify <the test targets involved in this task>
```

One command, any agent. It runs the static gates plus only the tests involved in the
task, and records the result. It refuses to run without a target: naming what you
selected is part of the step. `--full` is for genuinely cross-cutting changes only,
and you justify it in the report. `--docs-only` is for a change that touches no code
at all - it runs the static gates and refuses the moment it sees a code file, so it
is not a way around the tests.

Then follow `.agents/skills/openspec-verify-change/SKILL.md` to contrast the work
against the artifacts - completeness, correctness, coherence with the recorded
decisions.

Do the runtime verification the project requires (simulator, HTTP calls, end-to-end),
and write the report into `openspec/changes/<change>/reports/`.

## 6. Review

Follow `.agents/skills/adversarial-review/SKILL.md`.

Best run in a fresh session with a different model from the one that wrote the code.
Architectural conformance is one of the review dimensions: a layer violation, a
primitive where a typed value belongs, or an external shape leaking past its mapper
is a finding with a file and a line, like any other.

For changes touching authentication, credentials, permissions, payments or personal
data, also follow `.agents/skills/code-auditing/SKILL.md`.

Fix what it finds, then re-run stage 5. A finding you argue with instead of checking
is a finding you did not understand yet.

## 7. Document

Follow `.agents/skills/update-docs/SKILL.md`. Mandatory, and always before delivery.
Documentation that lags the code poisons every future session.

## 8. Hand over

**STOP HERE.** Report to the user:

- what was built, in one paragraph;
- the tests you selected and why, with the counts;
- what the adversarial review found and what you did about it;
- which documents you updated;
- anything you left out, and why.

Do not commit, push, open a pull request, publish, merge or deploy. When the user
approves, and only then, follow `.agents/skills/commit/SKILL.md`.

## Reporting honestly

Say plainly when a stage was skipped and why. A stage reported as done without the
command output behind it is worse than a stage reported as skipped: it spends the
user's trust on nothing.
