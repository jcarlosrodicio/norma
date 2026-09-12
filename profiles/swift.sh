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
# Use `run` for every command: it routes through rtk when installed, cutting the
# output that reaches an agent's context, and calls the command directly when not.

HARNESS_CODE_PATHS="Sources Tests"

harness_gates() {
  echo "harness: static gates"
  run swift build
  # Add swiftformat --lint or swiftlint here once the project has them.
}

# swift test filters by name: --filter TargetTests.CaseName. An app project built
# with xcodebuild needs -only-testing:Target/Class instead, and a destination.
harness_test_selected() { for t in "$@"; do run swift test --filter "$t"; done; }
harness_test_all() { run swift test; }
