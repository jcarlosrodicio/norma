# Stack adapter for scripts/harness/verify. This is the ONE file per project that
# the harness does not own: edit it freely, it is never overwritten by an upgrade.
#
# norma is written in POSIX sh and has no build, so no profile fits: this one is
# hand-written. `run` routes through rtk when installed and calls the command
# directly when not.

# Everything that ships or is tested. `docs/`, `README.md`, `AGENTS.md` and
# `VERSION` are outside, so a documentation commit can use --docs-only.
HARNESS_CODE_PATHS="bin core profiles skills templates test scripts"

SHELL_FILES="bin/norma core/verify core/pre-commit test/run.sh test/fixtures/config.sh scripts/harness/config.sh"

harness_gates() {
  echo "harness: static gates"
  for f in $SHELL_FILES profiles/*.sh; do
    sh -n "$f" || return 1
  done
  echo "harness: $(printf '%s\n' $SHELL_FILES profiles/*.sh | wc -l | tr -d ' ') shell files parse"
  # shellcheck is deliberately NOT wired in: it is not installed here, and adding
  # a linter nobody has means the gate changes behaviour the day somebody does.
  # If you adopt it, pay its findings in the same change.
}

harness_test_selected() {
  # The suite is one file and takes two seconds, so there is nothing to select.
  # Name what you were verifying anyway: the stamp records it and a reviewer
  # reads it.
  if [ $# -gt 0 ]; then
    echo "harness: selection '$*' noted - this suite is indivisible and runs whole"
  fi
  run ./test/run.sh
}

harness_test_all() { run ./test/run.sh; }
