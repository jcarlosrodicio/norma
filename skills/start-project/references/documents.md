# The founding document set

Skeletons for what `start-project` writes. Headings are a starting point, not a
form to fill: drop a section that has nothing in it rather than writing "N/A"
under it, and add one the project genuinely needs. Write them in the human's
language.

Two rules hold across all of them: **one topic, one owner** - no fact is stated in
two documents - and every document ends with its own open questions.

---

## `docs/00-product.md`

```md
# 00 · Product

One sentence: what this does and for whom.

## The problem
What the people it is for do today, and why that is not good enough.

## Who it is for
The real person. If there are several kinds, say which one the first version serves.

## What it must do well
The one job. Then the three to five use cases, as sentences with an actor.

## What success looks like
Concrete, in three months. A number, a behaviour or an event.

## Out of scope
Verbatim from the human. These are what stop the roadmap from growing a tail.

## Constraints
Dates, budget, regulation, offline, an existing system it must live beside.

## Decisions taken by default
What nobody decided, what was assumed instead, and the phase where it is revisited.

## Open questions
```

---

## `docs/01-architecture.md`

```md
# 01 · Architecture

## The shape
One paragraph and, if it helps, a text diagram. What talks to what.

## Stack
Language, framework, persistence, and **one line of reason each**.

## Domain
The entities, their lifecycle, and where truth lives for each: owned here, or a
copy of something owned elsewhere.

## Layers and boundaries
The directories, and the direction dependencies may point. What may not import
what.

## What enforces this
The dependency linter, the architecture test, the import rule - or the honest
statement that nothing does, and that every rule therefore depends on the agent.

## External systems
Direction, protocol, what happens when each is down.

## Access
Actors, how they authenticate, what each may do. Sensitive data, named.

## Scale
The honest numbers, and what would have to change if they were 100x.

## Rejected alternatives
What was considered and why it lost. This is what stops phase 14 from proposing it
again.

## Open questions
```

---

## `docs/02-design.md`

Skipped only when nothing has an interface. A CLI has one: its output.

```md
# 02 · Design brief

> Gathered with / without vision. (If without: the references below arrived as
> links or descriptions, and nobody in this conversation looked at an image.)

## Platforms
Form factors, and which is designed first.

## Identity
Existing brand, or from nothing. Colours, typeface, logo, what it must sit beside.

## References
Each one with **what** is liked about it: density, typography, calm, speed.

## What it must not look like

## Feel
Three adjectives, and one thing it must never feel like.

## Density and pace
Lived in for hours, or touched for thirty seconds.

## Themes
Light, dark or both. Both is a constraint on every colour decision from phase one.

## Motion
None, restrained, expressive.

## Accessibility
The target - contrast, keyboard, screen reader - and whether it is a requirement or
an intention.

## Languages
Locales at launch, and whether text can grow 40% in translation.

## Screens
Each one with the single thing a person came there to do.

## The states nobody designs
Empty, loading, error, offline, permission denied, and the first run before any
data exists.

## Design system
Adopted or built, and which. Adopting is the default for a first version.

## Open questions
```

---

## `docs/03-delivery.md`

```md
# 03 · Delivery

## Where it runs
Host, store or platform - and whether that is decided now or at a named phase.

## Environments
Local, preview, production. Which of them actually exist.

## Local stack
Docker or not. If there are migrations and Docker, bringing the stack up locally is
part of verifying a change, not an afterthought.

## Continuous integration
What runs on a pull request. The harness runs only the tests involved in a task
locally, so CI is where the full suite lives. If there is no CI, say so: the hole is
real.

## Secrets
What they are, where they live, who has them, and which phases are blocked until
they exist.

## Data and migrations
What has to be imported, and the rollback story.

## Observability
How you find out it broke.

## Release
Cadence, versioning, and who the first real user is.

## Open questions
```

---

## `AGENTS.md` - the project half

The installer appends its own harness block below this, between markers, and
re-running it never touches what you wrote. Without this half, an agent opening
the repository finds a perfect description of how to verify a change and no idea
what the project is.

```md
# <Project>

One sentence. This is the first thing any agent working here reads: it points at
the document that owns each topic instead of repeating it.

## Required reading before touching anything
1. `docs/00-product.md` - what this is and for whom. The **out of scope** list
   lives there.
2. `docs/01-architecture.md` - stack, domain, layers, and which way dependencies
   may point.
3. `docs/02-design.md` - the design brief, before writing a single screen. Name
   the constraints that are requirements rather than preferences.
4. `docs/03-delivery.md` - environments, CI, secrets, and what verifying a change
   includes here.

## Where the work is
`docs/roadmap.md` is the phase index: size, dependencies, what runs in parallel,
status. Each phase has its card in `docs/roadmap/phase-NN-*.md`. A task that does
not come from a phase card is a task to discuss before starting.

**Current phase: N.** Branch per phase: `phase-NN-<slug>`.

Where the code and these documents disagree, the documents win and the
disagreement is a finding to report.
```

---

## `docs/roadmap.md` - the index

```md
# Roadmap

One line on what the roadmap covers: the finished product, or a first usable
version.

Every phase is a **vertical slice** that leaves the system working and verifiable.
Sizes: **XS** < 2h · **S** 2-4h · **M** 4-6h · **L** 6-8h. There is no XL - a phase
that does not fit in L is two phases, and it is split before it starts.

## Ordering principles
Three to five lines specific to this project: what goes early and why, what is
deliberately late, which risk drove the order.

## Milestones

| Milestone | After phase | What becomes possible |
| --- | --- | --- |

## Phases

A phase counts as done when its change is archived in `openspec/changes/archive/`.
This column is the only place it is tracked.

| # | Phase | Size | Depends on | Parallel with | Milestone | Status |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | [Skeleton](roadmap/phase-00-skeleton.md) | S | — | — | | |

**Current phase: 0.**

Status values: empty (not started) · In progress · Done · **Blocked: <what it is
waiting for>**.
```

---

## `docs/roadmap/phase-NN-<slug>.md` - one card per phase

Written **after** the human has reviewed the index. Forty cards written before that
conversation are forty cards to rewrite.

Phase 0 carries one acceptance criterion the others inherit rather than repeat:
**the gate runs green**. It is the first moment in the project's life when
`scripts/harness/verify` can actually execute the commands in `config.sh`, because
phase 0 is what puts the toolchain there.

```md
# Phase NN · <name>

**Size** M · **Depends on** 3, 5 · **Parallel with** 8 · **Branch**
`phase-NN-<slug>`

## Goal
One sentence. If it needs two, this is two phases.

## Why now
What it unblocks, or which risk it retires.

## Preconditions
What must already be true. Including anything the human must provide - and if that
is not there yet, this phase is blocked and the index says so.

## The work
The actual steps, in order. Concrete enough that an agent does not have to invent
the approach, short enough that it is not a design document.

## Touches
The modules and directories this phase owns. This is what makes the parallel claim
checkable.

## Domain and data
New entities, changed ones, migrations.

## Interface
Endpoints, commands, screens - whichever this project has.

## Tests
What must exist and pass, by layer. Name the targets, because the gate is run with
the targets involved in the task.

## Acceptance criteria
Checkable statements. Not "works well".

## How it is proved
The command whose output shows it, or the screen you open. Every phase has one.

## Out of scope
What a reader of this card would reasonably assume is included, and is not.

## Risks
And what you would do instead if each one lands.

## Security pass
Only when the phase touches authentication, credentials, payments or personal
data: say so here, so the review stage knows it also follows
`.agents/skills/code-auditing/SKILL.md`.

## Result
What can be done after this phase that could not be done before.
```
