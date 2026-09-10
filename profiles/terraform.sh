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

HARNESS_CODE_PATHS="modules environments"

harness_gates() {
  echo "harness: static gates"
  run terraform fmt -check -recursive
  run terraform validate
  # Add tflint or checkov here once the project has them.
}

# `terraform test` takes a directory of .tftest.hcl files. A plan against a real
# workspace is Step 5 runtime verification, not a gate: it needs credentials.
harness_test_selected() { for t in "$@"; do run terraform test -test-directory "$t"; done; }
harness_test_all() { run terraform test; }
