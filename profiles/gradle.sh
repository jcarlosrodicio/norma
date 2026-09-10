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
