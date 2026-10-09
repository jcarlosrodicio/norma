## What and why

<!-- What changes, and what you deliberately left out. -->

## Verification

<!-- The gate's result, with the count: scripts/harness/verify ... -> N passed, 0 failed -->

## Checklist

See [CONTRIBUTING.md](../CONTRIBUTING.md).

- [ ] One logical change; a change to `core/` that also rewrites a skill is two.
- [ ] `scripts/harness/verify` passes, and the count is in the commit message.
- [ ] A behaviour change to `bin/` or `core/` arrives with a test in `test/run.sh`.
- [ ] A new refusal is in the table in `docs/02-flows.md`, with its reason.
- [ ] `VERSION` is bumped if vendored content changed (`core/`, `skills/`, `profiles/`, `templates/`).
- [ ] Documentation matches the behaviour.
