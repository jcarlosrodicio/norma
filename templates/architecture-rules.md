# Harness: architecture rules (adoption map)

Which parts of `.agents/skills/architecture-guidelines/` apply in this repository,
which do not, and why. Read it together with the reference, before the first edit.

> TODO(harness): generated from a template. The installer cannot know your layers,
> your decisions or which sections you adopt - only you can. Fill this in and delete
> this note. An empty adoption map means the shared reference applies wholesale,
> which is almost never what you want.

## Which reference

- `references/backend.md` - services, APIs, CLIs, workers.
- `references/frontend.md` - client applications: web, mobile, desktop.

TODO(harness): say which applies here, to which directories, and which does not
apply at all.

## Precedence in this repository

1. The user's request in the current conversation.
2. This repository's own architecture documents and decision records.
   TODO(harness): name them.
3. This file.
4. The shared reference.
5. Existing code, last. A pattern in a random file is evidence of what somebody
   once did, not a decision.

Where code and documentation disagree, the documentation wins and the disagreement
is a finding to report.

## Already enforced by machine - do not argue with it

TODO(harness): which tool enforces the layer rule here - a dependency linter, a
boundary check, an architecture test suite - and where a new rule belongs. Where a
rule can be enforced by a tool, the tool is the rule and this file is only its
explanation. If nothing enforces it, say so plainly: then every rule below depends
on the agent behaving.

## Adopted, and what it adds

TODO(harness): the rules from the reference that this repository takes on, and
specifically the ones its own documents do not state yet. Be concrete; a list that
restates the reference adds nothing.

## Not applicable here, and why

TODO(harness): every section you are dropping, with its reason. This is the half
that stops a shared guideline from fighting the project - and the reason matters as
much as the decision, because the next reader will otherwise re-adopt it.
