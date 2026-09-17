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

HARNESS_CODE_PATHS="src app lib buildSrc"

harness_gates() {
  echo "harness: static gates"
  run ./gradlew --quiet compileKotlin compileJava 2>/dev/null || run ./gradlew --quiet classes
  # Add ktlintCheck, detekt or checkstyleMain here once the project has them.
}

# Gradle filters by test class pattern, not by path. On Android the task is
# testDebugUnitTest rather than test.
harness_test_selected() { for t in "$@"; do run ./gradlew --quiet test --tests "$t"; done; }
harness_test_all() { run ./gradlew --quiet check; }
