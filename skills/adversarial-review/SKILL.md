---
name: adversarial-review
description: Use after an implementation passes its own tests and verification, before committing or archiving a change - an independent red-team pass that assumes the work is wrong and tries to break it. Also use when the user asks for a devil's advocate, red-team or independent review.
version: 1.0.0
---

# adversarial-review

An independent review pass with one job: find what the implementation got wrong.
Automated verification proves the code does what the spec said. This proves the
spec and the code were not both wrong in the same direction.

## Mindset

- **Zero trust.** Passing tests are evidence the tests pass, nothing more.
- **Assume the tests were written to pass.** A test suite authored alongside the
  implementation tends to encode the same misunderstanding.
- **Attack, do not admire.** Do not summarise what the change does well.
- **Report only what you can point at.** Every finding names a file and line and a
  concrete input or sequence that breaks it. No "consider maybe".

## Context boundary

Work from the change artifacts and the diff. Do not read the implementation
author's reasoning, planning notes or self-reported test summaries before forming
your own view - they anchor you to the same assumptions. Read them last, if at all.

Run this in a fresh session, and prefer a different model from the one that wrote
the code.

## What to attack

1. **Incorrect assumptions.** Every place the code assumes a value exists, is
   non-empty, is unique, is ordered, is in a given state, or arrives once.
2. **State preconditions.** Operations allowed on entities whose state should
   forbid them - editing something still being generated, mutating an archived
   record, acting on a soft-deleted row.
3. **Authorisation.** Can one user read, mutate or enumerate another user's data?
   Check every new read path, not just the writes.
4. **Input handling.** Empty, whitespace-only, maximum-length, wrong-type,
   wrong-encoding, unicode edge cases, injection payloads in any field that
   reaches a query, a shell, a template or a log.
5. **Concurrency and idempotency.** Two callers at once; a retried request; a
   partial failure halfway through a multi-step write.
6. **Error paths.** What the caller actually sees when it fails. An unhandled
   exception surfacing as a blank screen is a defect, not an edge case.
7. **Spec drift.** Requirements in the change artifacts with no implementation, and
   implementation with no requirement behind it.
8. **Consistency.** Response shapes, naming and error formats that diverge from the
   documented conventions in `AGENTS.md` and the standards it indexes.
9. **Architectural conformance.** Check the code against
   `docs/harness/architecture-rules.md` and the reference it points at in
   `.agents/skills/architecture-guidelines/`. What to look for: a dependency
   pointing outward instead of toward the domain; business rules in a component,
   a controller or an adapter; a loose primitive where a typed value belongs; an
   external payload deserialised straight into a domain type without a DTO and an
   explicit mapper; an error from a transport or an SDK leaking upward instead of
   being translated; a screen state expressed as combinable booleans; the same
   datum held as truth in two places. Report only what the project actually
   adopted - the adoption map says which rules apply here, and a rule listed as not
   applicable is not a finding.

For a dedicated security pass following OWASP Top 10 and NIST, use the
`code-auditing` skill instead - this skill covers correctness broadly.

## Output

Group findings by severity: **Blocking**, **Should fix**, **Nit**.

Each finding:

- `file:line`
- what breaks;
- the exact input, state or sequence that triggers it;
- why the existing tests miss it.

Close with a single explicit verdict: **safe to commit** or **not safe to commit**.
If you found nothing blocking, say so plainly - do not invent findings to look
thorough.
