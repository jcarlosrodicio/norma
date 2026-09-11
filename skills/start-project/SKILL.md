---
name: start-project
description: Use to start a project that does not exist yet - it talks with the human until it understands what they want to build, well enough to write the founding documents and a roadmap of phases of at most a day each, and then creates the repository and installs the harness so the first phase runs through the normal loop. Use it when the request is "I want to build X" and there is no repository, or an empty one. Not for a repository that already has code - that is harness-setup.
version: 2.0.0
---

# start-project

Somebody wants to build something. Right now it exists as a few sentences and a lot of
assumptions they have not noticed they are making. Your job is to understand it - well
enough to write down what it is, what it is not, and the order in which it gets built -
and then to hand that to the harness so the building can start.

**The understanding is the work.** The documents and the roadmap are what is left over
once you have understood; they are not a form to fill in.

## How this is run

This is the one skill that runs **outside** a project, because the project does not
exist yet. It lives in the norma installation, and there are two ways it reaches you.

Usually the human ran `norma start <directory>` before opening you, and the `AGENTS.md`
sitting in the directory - between `<!-- norma:start -->` markers - is what pointed you
here. **That file is a note, not the project's index**: when you write the real
`AGENTS.md`, replace it whole. If it is still there when the founding commit is made,
the first thing anyone reads about this project is an instruction to start it.

Otherwise the path is the interface:

```
norma home                                    # prints the installation directory
$(norma home)/skills/start-project/SKILL.md   # this file
```

Any agent follows it by reading that path. It assumes nothing about you: no skill
system, no slash commands, no tools beyond a shell and the ability to write files. If
your runtime happens to have a skill directory you can link it there and invoke it by
name, but the path is what makes it work everywhere.

It is deliberately **not** vendored into projects. By the time it has finished, the
project has a roadmap and a harness, and the skill that matters from then on is
`run-task`.

## Before the first question: say what you cannot do

Two lines, once, at the start. Not a disclaimer - a working agreement.

**Can you see images?** Check whether *this session* can actually receive them, not
whether your model could in principle. If it cannot, say so where it matters, which is
the design conversation:

> No puedo ver imágenes en esta sesión. Mándame las referencias como **enlaces** que
> pueda abrir, o descríbemelas: qué producto te gusta y qué te gusta de él. Escribiré el
> brief con eso y dejaré anotado que se recogió sin ver imágenes, para que quien diseñe
> de verdad lo sepa.

And write that same line into the design document. Never discuss a screenshot you did
not see: a brief written from an image nobody looked at is worse than one that admits
what it is.

**Can you open URLs? Run commands? Write files?** Say which of those you cannot do, and
agree on the workaround before you need it - for example, that the human pastes the
contents of a page, or runs the commands at the end themselves.

## The shape of this: a conversation

There is no fixed script, and there are no rounds to get through. There is a set of
things you must **end up knowing** - the next section - and a conversation that gets you
there. How you get there is the human's business as much as yours.

What that means in practice:

- **Follow their thread.** People do not answer in your order. They will answer three
  questions in one paragraph, open two you had not thought of, and mention in passing
  the constraint that reorganises the whole roadmap. Go where they went, and come back.
- **Ask a few at a time, in their language**, and always with your proposed answer
  attached. "Esto suena a un monolito con una sola base de datos, ¿no?" gets a
  correction; "¿qué arquitectura quieres?" gets a shrug. A blank form gets blank answers.
- **Play back more than you ask.** Summarising what you understood and being corrected
  is faster, and far more accurate, than another question. Do it often.
- **Never ask what you can read or work out.** If there is a directory, a README, a
  prototype, an export, notes - read them first and come back with what you already know.
  Asking someone to type what they already wrote is how an interview gets abandoned.
- **Dig where it changes the plan.** A detail that moves a phase, a boundary or a
  technology is worth three more questions. One that does not is worth none. The test is
  always: would the roadmap look different?
- **"No lo sé" is a real answer.** Treat it as information, not as a gap to fill. Either
  it becomes an open question in the document that owns the topic, or you take a default
  **and say out loud that you are taking it**, with the phase where it gets revisited.
  What you may never do is decide it silently and bury it in prose.
- **Notice what they keep coming back to.** The thing somebody mentions three times is
  the thing the product is actually about, whatever they said when you asked directly.

And one rule about pace: **do not run ahead**. Understanding, then documents, then the
roadmap, then the repository - each built on the previous one being right.

## What you must know before you can write a roadmap

This is the contract, not the questionnaire. The order is yours; the coverage is not.
Each group says why it exists - because a thing you cannot justify asking is a thing you
should not be asking.

**A · The point.** One sentence saying what this does and for whom, naming a real person
and a real problem. What those people do today instead. The one job it must do well.
What success looks like in three months, concretely. And what is explicitly **out** -
write the non-goals verbatim, they are what stops the roadmap growing a tail.

**B · The shape of the thing.** The entities it holds and the lifecycle of each: created
how, changed by whom, ends when. For each, whether this system owns the truth or holds a
copy of something owned elsewhere - a copy that pretends to be the original is the most
expensive mistake on this list. The three to five use cases, as sentences with an actor.
Who the actors are, how they identify themselves, what each may do. What is sensitive:
personal, health, payment, credentials. And the scale, honestly - for most new projects
the true answer is "small, and I will know when it is not", and writing *that* down is
what prevents a distributed system nobody needed.

*Without this you cannot cut a phase, because you do not know where the seams are.*

**C · The materials.** Language and framework - weighing what the human already knows
above novelty, because they are the one maintaining it. Persistence, with a reason.
The architecture style, where the default is the simplest thing that satisfies B.
The layer boundaries by directory and which way dependencies may point. **What will
enforce those boundaries** - a dependency linter, an architecture test, an import rule -
or the plain statement that nothing will, and that every rule then depends on whoever is
typing. The testing strategy: what is unit-tested, what needs a real dependency, and what
the static gates will be. Repository shape.

*Without this you cannot size a phase, and C is also most of what `harness-setup` will
ask later - gather it once.*

**D · The way out.** Where it runs, and whether that is decided now or at a named phase.
Which environments actually exist. Whether there is a local stack, Docker, migrations -
if there are both, then bringing the stack up locally is part of verifying a change.
What runs in CI, because the harness runs only the tests involved in a task locally and
CI is where the full suite lives; if there is no CI, that hole is real and belongs in the
documents. The secrets: what they are, who has them, **and which do not exist yet** -
every one of those is a blocked phase. What data has to be imported. Who the first real
user is and when, which is usually the best ordering constraint the roadmap has.

*Without this the deployment phase lands at the end, which is where deployments go to
fail.*

**E · The face.** Skip only if nothing has an interface a person looks at. A CLI has one:
its output is its interface. See the next section.

**F · The frame.** Does the roadmap run to a **finished product** or to a **first usable
version**? Is there a date? Who decides - for a personal project, saying "I decide
everything" out loud changes how much the roadmap may assume.

### The test for whether you know enough

Try to write the phase table. Not the cards - the table: number, name, size, what it
depends on. The first phase you cannot size, or whose dependency you cannot name, is
pointing straight at the question you still have to ask. Go and ask that one.

## The design conversation

Not a checklist to read aloud. Get them talking about products they like and products
they hate, and steer until you know these things - because each one changes what a phase
contains:

- **Platforms and which is designed first.** Mobile-first and desktop-first produce
  different layouts; deciding later means doing it twice.
- **Whether there is an existing identity** - colours, typeface, logo, something it must
  sit beside - or whether it starts from nothing.
- **Three or four references, each with what they like about it**: the density, the
  typography, the calm, the speed. A reference without a reason is decoration; the reason
  is the brief.
- **What it must not look like.** Usually the sharpest answer you will get all day.
- **How it should feel**, in three adjectives, and one thing it must never feel like.
- **Density and pace**: lived in for hours, or touched for thirty seconds standing up?
- **Light, dark, or both.** Both is a constraint on every colour decision from the first
  screen, not a theme to add later.
- **Motion**: none, restrained, expressive.
- **Accessibility**: the target, and whether it is a requirement or an intention. If the
  users are elderly, or the thing is used outdoors, or one-handed, that is a product
  requirement and it belongs in document 00 as well.
- **Languages**, and whether text can grow 40% in translation.
- **The screens**, each with the one thing a person came there to do.
- **The states nobody designs**: empty, loading, error, offline, permission denied, and
  the very first run before any data exists. Ask about these explicitly - nobody
  volunteers them, and they are a third of the work.
- **Adopt a design system or build one.** Adopting is the default for a first version,
  and saying it out loud stops a design system from hiding inside a feature phase.

## The three moments you stop and wait

Everything else is a conversation. These three are checkpoints, and you do not pass them
alone.

1. **When you think you understand.** Play the whole thing back in half a page - the
   point, the shape, the materials, the way out - *before* writing any document. This is
   the cheapest moment in the project to be wrong.
2. **When the roadmap table exists**, before writing a single phase card. Show the table
   and ask three questions: is there anything here you did not ask for, is anything
   missing that you assumed, and is the order right given what you are most afraid of?
   Forty cards written before this conversation are forty cards to rewrite.
3. **Before creating the repository.** Show what you are about to do to their disk.

## Write the documents

Follow `references/documents.md`, which carries the skeleton of each one. Write them in
**the human's language** - these are the project's documents, not norma's.

- `docs/00-product.md`, `docs/01-architecture.md`, `docs/02-design.md` (skipped
  explicitly if there is no interface), `docs/03-delivery.md`.
- `AGENTS.md` with the **project's own index** - see below. The installer will add its
  harness block underneath, and the two halves are both needed.
- `docs/roadmap.md` and, after checkpoint 2, one card per phase in `docs/roadmap/`.

Rules that hold across all of them: one topic, one owner - no fact stated twice, because
one copy will be wrong within a month. Every document ends with its own open questions,
and "none" is only written when it is true. Anything you took as a default is labelled as
a default. And say what was decided **against** and why: rejected alternatives are what
stops phase 14 from proposing them again.

## Build the roadmap

The roadmap is the contract between this conversation and every agent that comes after
it. **A phase is a vertical slice that leaves the system working, and that fits in a
day.** Sizes: XS under 2h, S 2-4h, M 4-6h, L 6-8h. There is no XL - a phase that does not
fit in L is two phases, and if you cannot state its goal in one sentence, that is the
same signal.

1. **Every phase ends with something you can run**: a command whose output proves it, a
   screen you can open, a test that could not have passed before. A phase whose only
   output is a document or a folder structure is not a phase.
2. **Phase 0 is the skeleton**, and it goes all the way: the toolchain, the test runner,
   the boundary rule with a test that proves it bites, and - where it is at all cheap -
   **the path to production, with a hello world on it**. A deployment discovered at phase
   9 is a deployment that fails at phase 9.
3. **Order by risk, not by comfort.** Whatever would kill the project if it turned out
   not to work goes early: the external API with undocumented limits, the rule that could
   be subtly wrong for months, the platform approval. Building the easy parts first feels
   productive and buys nothing.
4. **Dependencies are explicit**, by phase number, and only ever backwards.
5. **Parallel is a claim, not a wish.** Two phases run in parallel only when their
   dependencies are already satisfied *and* they touch disjoint files. Say in each card
   which directories it owns - that is what makes the claim checkable. Otherwise it is a
   merge conflict with an optimistic label.
6. **A phase waiting on the human** - a credential, an account, a legal answer - is
   marked **blocked**, with what unblocks it, and it goes early and isolated so its delay
   costs one phase instead of five.
7. **Milestones**: after which phase can somebody actually *do* something? Two to five,
   each saying what becomes possible. That is what turns a list into a plan somebody
   believes.
8. **One phase, one branch, one change, one pull request.** `phase-NN-<slug>`.
9. **Status is a column**, and the index is the only place it is tracked. A phase is done
   when its change is archived, not when the code looks finished.
10. **Phases touching authentication, credentials, payments or personal data say so**,
    and their card requires the security pass as well as the review.

## Create the repository and install the harness

Order matters, and it is not the obvious one. The hook that `norma install` arms refuses
any commit without a passing verification - and a project whose toolchain is phase 0's
job cannot pass anything yet. So **the founding commit precedes the rules**: everything
written so far, documents and harness together, in one commit made with the hook
deliberately out of the way. It is the only commit in this project's life that gets that.

```sh
git init                                   # if it is not a repository yet
# write the documents and AGENTS.md first, then:
norma install --profile <the one you chose>
```

Pass `--profile` explicitly: a new repository usually has no manifest yet, so detection
has nothing to read. `ls "$(norma home)/profiles"` is the menu.

Then follow `.agents/skills/harness-setup/SKILL.md`, which the install vendored into the
project - but **do not re-run its interview from zero**. Group C above already answered
most of it. Bring those answers as proposals, and ask only what is genuinely still open;
an agent that asks the same question twice teaches the human that answering was
pointless. Write `scripts/harness/config.sh` with the commands that will be true **at the
end of phase 0**, not the ones that work on an empty directory.

Now the founding commit:

```sh
git add docs AGENTS.md CLAUDE.md README.md scripts .githooks .agents openspec .gitignore
git -c core.hooksPath=.git/hooks commit -m "docs: qué es esto, y las fases en que se construye"
```

`-c` overrides the hook for that one command only: nothing is unset, nothing has to be
re-armed, and the next commit is already refused if it has no verification. Do not use
`--no-verify` and do not unset `core.hooksPath` - a repository left silently unarmed is
the failure this whole harness exists to prevent.

Then prove the state:

```sh
norma doctor
```

**`doctor` is the proof at this point, not the gate.** Running `scripts/harness/verify`
now would try to execute gates against a toolchain that does not exist yet, and it would
be right to fail. The first real gate run happens at the end of phase 0 - which is why
"the gate runs green" is an acceptance criterion of phase 0's card.

### `AGENTS.md` has two halves

If `norma start` created this directory, the file already holds its bootstrap note.
Overwrite it - do not append below it.

The installer writes the harness half. **You write the project half, above it**: what
this is, the four documents in reading order, where the roadmap lives, and which phase is
current. Without it an agent that opens this repository finds a perfect description of
how to verify a change and no idea what the project is. Re-running `install` preserves
what you wrote - it only ever replaces its own block, between its markers.

## Hand over

**STOP HERE.** Do not start phase 0; it goes through the normal loop like everything
else. Report:

- the project in one paragraph, as you now understand it;
- the documents you wrote, and the open questions each still carries;
- the roadmap in numbers: how many phases, the milestones, which are blocked and on what;
- **which answers were the human's and which were yours** - defaults you took, and where
  each gets revisited;
- whether the design brief was gathered with or without vision;
- what `doctor` says;
- and the one instruction that starts the work:

> El arnés está instalado y el repositorio tiene su primer commit. La fase 0 va por el
> bucle normal: dile a un agente que siga `.agents/skills/run-task/SKILL.md` con
> `docs/roadmap/phase-00-<slug>.md`.

## Reporting honestly

An interview is easy to fake: the documents read the same whether the answers came from
the human or from you filling the gaps quietly. They are not the same, and the difference
surfaces at phase 7, when a decision nobody made turns out to be wrong. Say which parts
were yours. It costs one line, and it is what makes the rest of the document worth
trusting.
