---
name: enrich-task
description: Use before planning any feature, fix or refactor when the request is a short roadmap line, a phase item, a screenshot or a one-paragraph idea - turns it into an implementation-ready spec with acceptance criteria, edge cases and open questions. Run this before openspec new/ff.
version: 1.0.0
---

# enrich-task

Turns a vague request into a spec detailed enough for autonomous implementation.
This is the first step of the harness loop, before any OpenSpec artifact exists.

## When NOT to use

Skip it when the request already carries acceptance criteria, affected files and
non-functional requirements. Enriching an already-complete spec wastes tokens.

## Inputs

The task arrives as one of:

- a line or bullet from the project roadmap (`docs/*roadmap*.md`, `docs/17-roadmap.md`, phase docs);
- a phase name matching a branch convention such as `phase-NN-<slug>`;
- free text, a screenshot, or a link the user pastes in chat.

There is no ticket tracker in these projects. Never ask for a Jira id and never
try to fetch one. If the input names a phase, read that phase's section in the
roadmap and treat it as the source of truth for scope.

## Process

1. **Read the project context first.** `AGENTS.md` is the index. Follow it to the
   architecture, standards and data-model documents that the task touches. Do not
   explore the codebase freely before reading the index - the documented patterns
   win over whatever a random file happens to do.
2. **Act as a product expert with technical depth.** Understand the problem before
   describing the solution.
3. **Analyse the existing code** for what can be reused: existing endpoints, models,
   widgets, use cases, response shapes. Name them explicitly. Reusing an existing
   contract beats inventing a parallel one.
4. **Decide whether the task is already complete enough.** It is complete only if it
   states: full behaviour description, every field to add or change, the module and
   file boundaries it may touch, definition of done, documentation and test
   updates, and non-functional requirements (security, performance, observability,
   data integrity).
5. **Write the enriched version** covering, in this order:
   - business summary and scope boundary (say explicitly what is out of scope);
   - reuse analysis from step 3;
   - functional requirements;
   - non-functional requirements;
   - affected files and modules, consistent with the documented architecture;
   - acceptance criteria and definition of done;
   - test cases, including the hostile ones: empty input, oversized input, wrong
     encoding, injection attempts, concurrent writes, entities in a state that
     forbids the operation.
6. **Challenge the request.** End with open questions about what the input left
   ambiguous - cardinality (one vs many), ownership, permissions, what happens to
   existing rows, behaviour on partial failure. Ask them; do not silently pick an
   answer.

## Output

Return markdown with exactly two top-level sections:

- `## Original`
- `## Enhanced`

Do not write files unless the user asks. The enriched text is the input for
`openspec new` / `openspec ff`, which is what creates artifacts.

## Notes

- Prefer Opus with high reasoning for this step: it is planning, not typing.
- If the roadmap phase is larger than one change, say so and propose the split
  instead of enriching an oversized task.
