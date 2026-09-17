# Stack adapter for scripts/harness/verify. This is the ONE file per project that
# the harness does not own: edit it freely, it is never overwritten by an upgrade.
#
# Contract:
#   HARNESS_CODE_PATHS      space-separated paths that hold code - a top-level
#                           directory, or a single file at the root. A
#                           --docs-only run refuses the moment it sees a change
#                           under one of them.
#   harness_gates()         static gates. Fast, and they must fail loudly.
#   harness_test_selected()  run ONLY the targets passed as "$@".
#   harness_test_all()      the full suite (--full, for cross-cutting changes).
#
# Use `run` for every command: it executes it and hands back its exit status,
# which is what the gate decides on. Filtering the output here is fine; changing
# the status is not, and a wrapper that swallowed one is why this is spelled out.

HARNESS_CODE_PATHS="packages apps"

harness_gates() {
  echo "harness: static gates"
  run pnpm lint
  run pnpm typecheck
  run pnpm depcruise
}

harness_test_selected() { run pnpm vitest run "$@"; }
harness_test_all() { run pnpm test; }
