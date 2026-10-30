---
name: architecture-guidelines
description: Use before writing or reviewing any production code - the shared architectural criteria (layering, domain purity, naming, testing, migrations) that apply across projects. Read it during planning and implementation, and use it as a review dimension. Consult the backend reference for services, APIs and CLIs, and the frontend reference for client applications.
metadata:
  version: "1.1.0"
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

## Which tests to write

Every test is paid for on every task: the gate runs it, CI runs it, and a suite
that grows "just in case" ends up as the slowest stage of the loop. Projects
running this loop have had to cut theirs by a third and by more than half for that
reason. The question for every new test is **what real bug would reach users that
no existing test catches?** If the answer is none, or a cosmetic one, do not write
it.

- **Search before you write.** Find the test that already covers the behaviour -
  search for the function, the error code, the message - and extend it. A new test
  is for what nothing asserts yet.
- **One test per rule, at the cheapest layer that proves it** - usually a unit test
  in the module that owns the behaviour. Do not prove the same rule again at
  another layer. A slower test - integration, UI, end to end - covers the wiring
  once per path, and only when the details are already unit-tested.
- **One representative case plus the edges that genuinely differ** - a boundary,
  an error path. No table of near-identical inputs, and no variant per button, per
  wording or per runtime when the code path is shared.
- **Do not test** constructors, getters, equality, copies or one-line delegation;
  that a constant, a type or an export exists; what the type system or a static
  gate already enforces; the language, a library or the framework; copy, colours,
  layout or the shape of a view tree; the contents of documentation; or the
  implementation mirrored line by line. Never write a test that asserts other test
  files exist: it freezes the suite and makes pruning it impossible.
- **Tests live with the module they test.** A task, a phase or a bug does not get
  its own test file. Prefer extending an existing file over creating one: many
  runners load, compile or spawn each file on its own, and that per-file cost can
  dominate the run.
- **A bug fix adds at most one regression test**, and only when no existing test
  can be tightened to catch it.
- **Slow tests are the exception.** Real processes, real network and real timers
  only when nothing faster can prove the behaviour. Never a fixed sleep: fake the
  clock, or poll with a timeout.
- **Always kept:** security, secrecy, credentials, permissions, refusals, money,
  data-transforming migrations and data loss each need a test at their enforcement
  point. A test there is removed only when the change names the test that still
  proves the same thing; a removal that cannot name one is a gap.
- **See it fail once.** A regression test, and any test written after the code,
  is decoration until it has gone red: break the production code the way the bug
  would, confirm it fails **for the reason it names**, restore, confirm green.
  Check the break actually took - a stash or a checkout with a wrong pathspec
  reverts nothing, silently, and the tell is that the red counts equal the green
  ones. The report says how the test was seen failing.
- **A test can fail for the wrong reason, or for none.** These pass while the
  behaviour is broken:
  - **Circular evidence.** The expected value comes from the helper under test,
    or is copied from production. Derive it independently.
  - **The mock does the work.** A mock or a fixture supplies what production
    should produce - the acknowledgement, the ordering, the stored row - or the
    assertion reads a store the real path never writes. Mock at the edges only.
  - **The wrong guard goes red.** A negative case rejected by another check, or
    never reaching the branch it names. Assert the reason, not only the refusal.
  - **A declaration posing as behaviour.** An import, a flag, a call shape or an
    export asserted where the behaviour it promises goes unchecked.
  - **A count without the value.** On a dedup, normalise or idempotency path,
    `length == 1` passes with normalisation broken; assert what was stored.

The project's own test policy in `AGENTS.md`, where it has one, wins over this
list: it is the one that knows which paths are critical there.

## How this is used in the loop

- **Planning** (`openspec-new-change`, `openspec-ff-change`): the design must name
  the layer each new piece belongs to, and any rule it deliberately breaks.
- **Implementing** (`openspec-apply-change`): the applicable reference plus the
  project's adoption map are mandatory reading before the first edit, and the
  project's own architecture document overrides both. Tests follow "Which tests to
  write" above.
- **Reviewing** (`adversarial-review`): architectural conformance is a review
  dimension. A layer violation is a finding with a file and a line, like any other,
  and so is a test that only re-proves what another one already proves.
- **Machine over prompt.** Where a rule can be enforced by a tool - a dependency
  linter, a boundary check, a static gate - the tool is the real rule and this file
  is only its explanation. Prefer adding the check to arguing with the agent.

## Exceptions

A deliberate exception is legitimate. A silent one is not. Record it where it
happens, with its reason, and do not extend it by analogy: the next case starts from
the rule again, not from the exception.
