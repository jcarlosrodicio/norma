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

HARNESS_CODE_PATHS="app routes database config tests resources"

harness_gates() {
  echo "harness: static gates"
  run ./vendor/bin/pint --test
  # Add larastan/phpstan here: ./vendor/bin/phpstan analyse
}

# artisan test takes --filter (a name pattern) and also plain paths.
harness_test_selected() { run php artisan test "$@"; }
harness_test_all() { run php artisan test; }
