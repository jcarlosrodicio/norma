# Stack adapter for scripts/harness/verify. This is the ONE file per project that
# the harness does not own: edit it freely, it is never overwritten by an upgrade.
#
# Contract:
#   HARNESS_CODE_PATHS      space-separated top-level dirs that hold code. A
#                           --docs-only run refuses the moment it sees a change
#                           under one of them.
#   harness_gates()         static gates. Fast, and they must fail loudly.
#   harness_test_selected()  run ONLY the targets passed as "$@".
#   harness_test_all()      the full suite (--full, for cross-cutting changes).
#
# Use `run` for every command: it routes through rtk when installed, cutting the
# output that reaches an agent's context, and calls the command directly when not.

HARNESS_CODE_PATHS="app src pages components lib"

harness_gates() {
  echo "harness: static gates"
  run npx tsc --noEmit
  run npx next lint
}

harness_test_selected() { run npx vitest run "$@"; }
harness_test_all() { run npx vitest run; }
