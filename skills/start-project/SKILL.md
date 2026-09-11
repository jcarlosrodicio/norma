---
name: start-project
description: Use to start a new project from nothing - it interviews the human about the product, the domain, the stack, the delivery path and the design, writes the founding documents, turns them into a roadmap of phases no longer than a day of work each, and only then installs the harness so the first phase can be built with the loop. Use it when the request is "I want to build X" and there is no repository yet, or an empty one. Not for a repository that already has code - that is harness-setup.
version: 1.0.0
---

# start-project

A project starts twice. Once when somebody decides to build it, and once - weeks
later - when it turns out nobody wrote down what it was for, so every later decision
is re-argued from memory. This procedure closes the gap between the two: it
interviews the human until the project is actually specified, writes that down as
documents the repository owns, turns it into a roadmap of phases that can each be
built and verified in a day, and hands the result to the harness so the first phase
runs through the normal loop.

The interview is the work. The documents are a by-product of having asked well.

## Where this runs from

This is the one skill that runs **outside** a project, because the project does not
exist yet. It lives in the norma installation, not in `.agents/skills/`:

```
norma home          # prints the installation directory
$(norma home)/skills/start-project/SKILL.md
```

Any agent reads that path. In Claude Code it becomes `/start-project` once linked:
`ln -s "$(norma home)/skills/start-project" ~/.claude/skills/start-project`.

It is deliberately **not** vendored into projects. By the time it has finished, the
project has a roadmap and a harness, and the skill that matters from then on is
`run-task`.

## What it produces

- `docs/00-product.md` - the problem, who has it, what is in and out of scope.
- `docs/01-architecture.md` - the stack, the layers, the boundaries, and why.
- `docs/02-design.md` - the design brief. Skipped, explicitly, if there is no UI.
- `docs/03-delivery.md` - where it runs, how it ships, what it needs to run.
- `docs/roadmap.md` plus one card per phase in `docs/roadmap/phase-NN-<slug>.md`.
- The harness installed, configured, and green.

`references/documents.md` next to this file carries the skeleton of each one. Write
them in **the human's language** - these are the project's documents, not norma's.

## Three rules for the interview

1. **Ask only what changes the plan.** Every question must be one whose answer moves
   a phase, a boundary or a technology. Questions asked to look thorough are how an
   interview loses the human halfway through.
2. **Propose, do not interrogate.** Attach your proposed answer to every question -
   "this reads like a modular monolith with one database, agree?" A blank form gets
   blank answers; a proposal gets a correction, which is the same information at a
   tenth of the effort.
3. **Never decide silently.** If something stays unanswered you have two honest
   moves: record it as an open question in the document that owns the topic, or take
   a default and **write that it was a default**, with the phase where it gets
   revisited. What you may not do is bury a decision in prose as though it had been
   made.

And one rule about pace: **stop after every round and wait**. A wrong answer in
round 1 is copied into every document and every phase that follows.

## 0. Declare what you can do, then read what exists

Before the first question, say two things in two lines.

**Whether you can see.** The design round asks for visual references, and how it is
run depends on it. Check whether this session can actually receive images - not
whether the model family can in principle. If it cannot:

> I cannot see images in this session, so send design references as **links** I can
> fetch, or describe them in words - products you like and what specifically you like
> about them. I will write the brief from that, and mark it as gathered without
> vision so whoever picks up the design knows.

Say it once, plainly, at the start, and record the same line in `docs/02-design.md`.
Never pretend to have looked at a screenshot: a design brief written from an image
nobody saw is worse than one that admits it is text-only.

**Whether you can fetch.** If you cannot open URLs either, say so now - then
references have to arrive as descriptions.

Then look before asking. If a directory exists, read it: a README, a napkin
document, notes, an old prototype, an export of some existing system. Ask the human
what to read if it is not obvious. Come to round 1 with a summary of what you already
know; it is the cheapest way to prove the interview is worth their time.

## 1. Round one - the product

1. In one sentence: what does this do, and for whom? Push until the sentence names a
   real person and a real problem, not a category.
2. What do those people do **today** instead? The answer sizes the project: replacing
   a spreadsheet is a different project from replacing nothing.
3. What is the one job it must do well? If everything else worked badly and this
   worked, would it still be worth having?
4. What does success look like, concretely, in three months? A number, a behaviour,
   or an event - not "adoption".
5. What is explicitly **out** of scope? Write these down verbatim; the non-goals are
   what stops the roadmap from growing a tail.
6. Hard constraints: a date, a budget, a language, offline operation, a regulation,
   data that may not leave a country, an existing system it must live beside.
7. Who decides? For a personal project the human decides everything, and that is
   worth stating - it changes how much the roadmap can assume.

**STOP.** Play the answers back in five lines and get them corrected.

## 2. Round two - the domain

1. The main things the system holds - entities - and the lifecycle of each: created
   how, changed by whom, ends when.
2. The three to five use cases that make up the product. Get them as sentences with
   an actor: "a coach publishes a routine", not "routine management".
3. Where truth lives. For each entity: does this system own it, or is it a copy of
   something owned elsewhere? A copy that pretends to be the original is the most
   expensive mistake on this list.
4. External systems it must talk to, in which direction, and what happens when one is
   down.
5. Who the actors are, how they authenticate, and what each is allowed to do.
6. Sensitive data: personal, health, payment, credentials. Name it now - it decides
   whether `code-auditing` is mandatory on some phases, and it changes the delivery
   round.
7. Scale, honestly: how many users, how much data, how fast must it answer. The
   honest answer for most new projects is "small, and I will know when it is not",
   and writing *that* down is what stops premature distribution.

**STOP.** Sketch the entities and their relations back to them, in text.

## 3. Round three - the stack and the architecture

Come with a recommendation, derived from rounds 1-2, and defend it in one line each.
The available profiles are the menu the harness can install:
`ls "$(norma home)/profiles"`.

1. Language and framework. Weigh what the human already knows above novelty: the
   project has to be maintained by whoever is in this conversation.
2. Persistence, and the reason. "Postgres because the data is relational and I want
   one boring dependency" is a reason; "Postgres" is not.
3. The architecture style - layered, hexagonal, modular monolith, services - and the
   **default is the simplest thing that satisfies round 2**. Distribution is a cost
   paid to solve a problem nobody has yet.
4. The layer boundaries, by directory, and which direction dependencies may point.
   This becomes the adoption map in `docs/harness/architecture-rules.md`, and it is
   worth ten minutes now: the criteria in
   `$(norma home)/skills/architecture-guidelines/` say what good looks like, and the
   project's own document says which parts it adopts.
5. What will **enforce** those boundaries - a dependency linter, an architecture test,
   an import rule. If the answer is nothing, say plainly that from then on every rule
   depends on the agent behaving.
6. Repository shape: one repository or several, one package or a workspace.
7. The testing strategy: what is unit-tested, what is integration-tested, what needs
   a real dependency (a container, a device, a browser), and what the static gates
   will be. This is round 1 of `harness-setup` answered in advance.

**STOP.**

## 4. Round four - delivery

1. Where does it run - a host, a store, a serverless platform, a machine under a desk
   - and does that decision have to be made now or at a later phase?
2. Environments: local, preview, production. Which of them actually exist.
3. Does it use Docker locally? If it does, and the project has migrations, then
   bringing the stack up locally is part of verifying a change - not an afterthought.
4. Continuous integration: what runs on a pull request. The harness runs only the
   tests involved in a task locally, so CI is where the full suite lives. If there is
   no CI, that hole is real and belongs in the documents.
5. Secrets: what they are, where they live, who has them. Any phase that needs a
   credential the human must obtain is a **blocked** phase until they do - mark it.
6. Migrations and data: is there data to import, and is there a rollback story.
7. Observability: how you will know it broke.
8. Who the first real user is, and when. This is usually the single best ordering
   constraint the roadmap has.

**STOP.**

## 5. Round five - design

Skip this round only if the project genuinely has no interface a person looks at - a
library, a daemon. Say that you are skipping it and why. A CLI **does** have a
design: its output is its interface.

Repeat the vision caveat from stage 0 if it applies, then ask:

1. Platforms and form factors, and which one is designed first. Mobile-first and
   desktop-first produce different layouts; picking later means doing it twice.
2. Is there an existing brand - colours, a logo, a typeface, an existing product this
   must sit beside - or does it start from nothing?
3. Three or four references they like, with **what** they like about each: the
   density, the typography, the calm, the speed. References without a reason are
   decoration; the reason is the brief.
4. What it must **not** look like. This is usually the sharpest answer of the round.
5. Three adjectives for how it should feel, and one thing it should never feel like.
6. Density and pace: is this a tool someone lives in for hours, or something they
   touch for thirty seconds?
7. Light, dark, or both - and if both, that is a constraint on every colour decision
   from phase one, not a later theme.
8. Motion: none, restrained, expressive.
9. Accessibility: the target - contrast, keyboard, screen reader - and whether it is
   a requirement or an intention.
10. Languages and locales at launch, and whether text can grow by 40% in translation.
11. The screens, listed. For each, the one thing a person came to do.
12. The states nobody remembers to design: empty, loading, error, offline,
    permission-denied, and the very first run before any data exists.
13. Adopt a design system or build one? Adopting - Material, Cupertino, shadcn, a
    corporate kit - is the default for a first version, and saying so out loud stops
    the roadmap from hiding a design system inside a feature phase.

**STOP.** Write `docs/02-design.md` from the answers before the roadmap: the design
decisions change what a phase contains.

## 6. Write the documents

Now write the founding set, following `references/documents.md`. Rules:

- Every document states its own **open questions** at the end. An empty section is a
  claim, so only write "none" when it is true.
- Anything you took as a default is labelled as a default, with where it gets
  revisited.
- No document repeats another. If the architecture is described in two places, one of
  them will be wrong within a month.
- Say what you decided **against** and why. The alternatives that were rejected are
  what stops phase 14 from re-proposing them.

## 7. Build the roadmap

The roadmap is the contract between this conversation and every agent that comes
after it. It goes in `docs/roadmap.md` - an index - plus one card per phase under
`docs/roadmap/`.

**A phase is a vertical slice that leaves the system working, and that fits in a
day.** Sizes: XS under 2h, S 2-4h, M 4-6h, L 6-8h. There is no XL: a phase that does
not fit in L is two phases, and if you cannot state a phase's goal in one sentence,
that is the same signal.

The rules that make it usable:

1. **Every phase ends with something you can run.** A command whose output proves it,
   a screen you can open, a test that could not pass before. A phase whose only
   output is a document or a folder structure is not a phase.
2. **Phase 0 is the skeleton**: the repository, the toolchain, the test runner, the
   thinnest path that goes end to end - and, where it is cheap, the deployment path.
   The point is to meet the integration problems while the project is still empty.
3. **Order by risk, not by comfort.** Whatever would kill the project if it turned
   out not to work goes early: the external API with undocumented limits, the
   platform approval, the performance assumption. Building the easy parts first feels
   productive and buys nothing.
4. **Dependencies are explicit**, by phase number. A phase may only depend on phases
   before it.
5. **Parallel is a claim, not a wish.** Two phases run in parallel only when their
   dependencies are already done *and* they touch disjoint files. Otherwise it is a
   merge conflict with an optimistic label. Mark it in the `Parallel with` column, and
   say in the card which module each one owns.
6. **A phase that needs something from the human** - a credential, an account, a
   design decision, a legal answer - is marked **blocked**, with what unblocks it.
   These are the phases that stall a project, and they are visible from the index.
7. **Milestones**: after which phase can somebody actually do something? Name two to
   five of those, with what becomes possible. It is what turns a list of phases into a
   plan somebody can believe.
8. **One phase, one branch, one change, one pull request.** `phase-NN-<slug>` is the
   branch, and the change proposal under `openspec/changes/` is where its tasks live.
9. **Status is a column**, and the index is the only place it is tracked. A phase is
   done when its change is archived - not when the code looks finished.
10. **Sensitive phases are labelled.** Anything touching authentication, credentials,
    payments or personal data also runs `code-auditing`, and the card says so.

Ask the human whether the roadmap runs to a **finished product** or to a **first
usable version**; the milestones differ, and it is the last big scoping decision.

## 8. Review the roadmap with the human

**STOP, and make this one count.** Present the index - phases, sizes, dependencies,
milestones - and ask three questions:

- Is anything here that you did not ask for?
- Is anything missing that you assumed?
- Is the order right, given what you are most afraid of?

Correct, and only then write the phase cards. Writing forty cards before this
conversation is forty cards to rewrite.

## 9. Create the repository and install the harness

Order matters here, because of the hook.

```sh
git init                       # if it is not a repository yet
# write the documents, then:
git add docs README.md         # explicit paths, never -A
git commit -m "docs: what this project is, and the phases it will be built in"
```

That is the only commit in this project's life with no gate behind it, and it is
documents only. Make it **before** installing, because `norma install` arms the
pre-commit hook and the hook refuses the default branch - correctly.

Then, on a branch:

```sh
git switch -c phase-00-harness
norma install --profile <the one chosen in round 3>
```

Pass `--profile` explicitly. A new repository often has no manifest yet, so detection
has nothing to read.

Now follow `.agents/skills/harness-setup/SKILL.md` - it is vendored into the project
by the install. **Do not re-run its interview from zero.** Rounds 3 and 4 of this
procedure already answered most of round 1 and 2 of that one; bring those answers,
show them as proposals, and ask only what is genuinely still open. An agent that asks
the same questions twice teaches the human that answering was pointless.

Finish with:

```sh
norma doctor
scripts/harness/verify --docs-only
```

`doctor` must be clean. If the gates cannot run because the toolchain is not
installed yet - no dependencies, no test runner - that is not something to paper
over: say it, and make it the first task of phase 0.

## 10. Hand over

**STOP HERE.** Do not start phase 0. Report:

- the project in one paragraph, as you now understand it;
- the documents you wrote, and the open questions each one still carries;
- the roadmap in numbers: how many phases, the milestones, which are blocked and on
  what;
- what you took as a default rather than being told, and where each gets revisited;
- whether the design brief was gathered with or without vision;
- what `doctor` says;
- and the one command that starts the work:

> The harness branch is ready for you to review and merge. After that, phase 0 goes
> through the normal loop: point an agent at `.agents/skills/run-task/SKILL.md` with
> `docs/roadmap/phase-00-<slug>.md`.

## Reporting honestly

An interview is easy to fake: the documents look the same whether the answers came
from the human or from you filling gaps. They are not the same, and the difference
surfaces at phase 7 when a decision nobody made turns out to be wrong. Say which
answers were yours. It costs one line and it is the only thing that makes the rest of
the document trustworthy.
