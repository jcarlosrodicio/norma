---
name: update-docs
description: Use as the last step of any change that altered behaviour, contracts, schema or architecture, before committing - updates the technical documentation the project treats as its source of truth so the next session starts from accurate context.
version: 1.0.0
---

# update-docs

The repository is the source of truth for the harness. Documentation that lags the
code silently poisons every future session, so this step is mandatory, not
optional, and it runs before the commit.

## Process

1. Read `AGENTS.md` - it is the index that says which documents exist and what each
   one owns.
2. From the diff, decide which of them the change invalidated. Typical triggers:
   - new or changed API contract -> the API spec document;
   - schema, migration or model change -> the data-model document;
   - new dependency direction, boundary or composition change -> the architecture
     document and, if a rule was bent, an ADR;
   - new command, script or environment variable -> the development/setup guide;
   - behaviour a future reader would find surprising -> the relevant spec or ADR.
3. Update those documents. Match the existing structure and heading style; do not
   restructure a document as a side effect.
4. Add nothing that duplicates the code. Documentation carries intent, contracts
   and decisions - not a paraphrase of the implementation.
5. If the change made an existing statement false, fix the statement. Stale text is
   worse than missing text.

## Do not

- Do not create new documents when an existing one owns the topic.
- Do not write a changelog entry of what you just did unless the project keeps one.
- Do not leave a documentation TODO instead of the update.

## Report

List the documents updated and, in one line each, what changed. If nothing needed
updating, say which documents you checked and why they were unaffected - that is a
valid outcome, an unchecked assumption is not.
