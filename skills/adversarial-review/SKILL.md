---
name: adversarial-review
description: Use after an implementation passes its own tests and verification, before committing or archiving a change - an independent red-team pass that assumes the work is wrong and tries to break it. Also use when the user asks for a devil's advocate, red-team or independent review.
version: 1.1.0
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

`.harness/run-events.jsonl` is one of those: it holds what the author's runs
already concluded. `scripts/harness/run status` is not - it carries an identity and
no judgement, which is why the step below can use it without breaking this boundary.

Run this in a fresh session, and prefer a different model from the one that wrote
the code.

## 1. Map the change

Before attacking anything, list every file the change touches. That list is the
checklist for the whole pass. Identify an entry by `(path, status)`, not by path
alone - a path appears twice when a deletion is followed by a recreation.

Every entry ends in one of two states: **reviewed**, or **skipped with a concrete
reason** - "generated file, no hand-written logic", "lockfile, the diff is machine
output". "Looked minor" is not a reason, and neither is running out of attention.

Reviewing one file does not cover its counterpart. An implementation file does not
cover its header, its interface, its test or its configuration, and the smaller
member of a pair is exactly where a forgotten update hides.

The counts go in the output. A review that silently covered two thirds of the diff
reads exactly like one that covered all of it, and the verdict it ends on is worth
nothing - which is what this checklist exists to make visible.

## 2. Plan the attack

Go through the mapped files once and write down, for each risk point:

- the severity you expect - blocking, should fix, nit;
- what is at stake, concretely: where it is, what breaks, who notices;
- what you have to read to confirm it or kill it, named - this function's callers,
  that migration, the test that claims to cover it.

Then go and confirm them. The plan holds hypotheses, not findings: an entry you
could not confirm is dropped, and saying that costs nothing. Planning first is also
what keeps the pass from spending its whole attention on the first file and
arriving at the last one with none left.

If the change carries no identifiable risk, write that instead of padding the list.

## 3. What to attack

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

Cross-file findings are part of the job: an inconsistency between two files in the
change, an update applied to one caller and not the other, a contract broken on one
side. Read whatever context you need, but file every finding against a file that
the change actually touches.

For a dedicated security pass following OWASP Top 10 and NIST, use the
`code-auditing` skill instead - this skill covers correctness broadly.

## 4. Fact-check your own findings

A finding is not evidence because you produced it. Go through the list once more
with the opposite job: not "is this worth reporting" but "does the diff prove this
wrong".

The two mistakes available here are not equally expensive. **Reporting a wrong
finding costs somebody a few minutes. Dropping a correct one destroys it in
silence** - it reaches nobody, and nobody learns it was dropped. So when the
evidence falls short of proof, it stays. "Suspicious", "I cannot verify this", "low
value" and "the code looks fine to me now" all mean it stays.

Drop a finding on exactly two grounds:

- **A - it describes code that is not there.** The symbol, statement or construct it
  names appears nowhere in the file it was filed against. The same construct in a
  sibling file does not rescue it.
- **B - a diff line contradicts it literally.** It calls an identifier unused and
  the diff uses it; it says a check is missing and the diff contains it; it says a
  value is hardcoded and the diff reads it from a variable. The contradiction has to
  be readable straight off the diff - needing a chain of reasoning to reach it means
  there is none.

**Never drop a finding** whose subject is memory safety, concurrency, a declaration
that disagrees with its definition, a behavioural or compatibility change, or a
parameter the function accepts and never uses - whatever you concluded about it.
Those are the categories where a wrongly dropped finding is most expensive and your
own confidence is worth least, including your confidence that the language or the
runtime does not behave the way the finding claims.

None of these is a ground: you disagree with the fix it proposes; you consider the
flagged code acceptable as written; you cannot confirm it; it quotes the wrong line
while describing something the diff does contain. Judge the claim, not the citation.

This step shares an author with the findings it judges, which makes it weaker than
it looks - it still removes what the diff flatly refutes. When the pass runs in a
fresh session with a different model, as the context boundary asks, so does this
step, and then it is worth considerably more.

## Output

Open with the coverage line: files in the change, files reviewed, files skipped,
and the reason for each skip.

Then group findings by severity: **Blocking**, **Should fix**, **Nit**.

Each finding:

- `file:line`
- what breaks;
- the exact input, state or sequence that triggers it;
- why the existing tests miss it.

Close with a single explicit verdict: **safe to commit** or **not safe to commit**.
If you found nothing blocking, say so plainly - do not invent findings to look
thorough.

Then record the same thing where a machine can read it, **in addition to** the
report above and never instead of it:

```
scripts/harness/run event review review=adversarial \
  files_in_change=<n> files_reviewed=<n> files_skipped=<n> \
  blocking=<n> should_fix=<n> nit=<n> verdict=<safe_to_commit|not_safe_to_commit>
```

Counts and a verdict, not a score: the findings themselves stay in the report,
where the file, the line and the triggering input live. A review collapsed into a
number is a review nobody can act on. Without a run context the command writes
nothing and exits 0, so it is safe to run anywhere. Run it again after the fixes,
adding `unresolved=<n>`, because the review the human reads is the one that ran
last.

---

The coverage contract of stage 1 and the two grounds of stage 4 are adapted from
[`alibaba/open-code-review`](https://github.com/alibaba/open-code-review)
(Apache-2.0), which runs them as separate passes around its review agent.
