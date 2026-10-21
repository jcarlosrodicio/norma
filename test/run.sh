#!/bin/sh
# The harness test suite. One place: the gate is the same file in every project,
# so its behaviour is tested here instead of being re-tested per repository.
#
#   test/run.sh
#
# Every test runs against a throwaway git repository with a stub stack adapter,
# so nothing here depends on a toolchain being installed.
set -e

HOME_DIR=$(cd "$(dirname "$0")/.." && pwd)
NORMA=$HOME_DIR/bin/norma
pass=0
fail=0

ok() { pass=$((pass + 1)); printf '  ok    %s\n' "$1"; }
no() { fail=$((fail + 1)); printf '  FAIL  %s\n        %s\n' "$1" "$2"; }

assert_eq() {
  if [ "$2" = "$3" ]; then ok "$1"; else no "$1" "expected '$3', got '$2'"; fi
}
assert_has() {
  case $2 in
    *"$3"*) ok "$1" ;;
    *) no "$1" "output does not contain '$3'" ;;
  esac
}
assert_no() {
  case $2 in
    *"$3"*) no "$1" "output should not contain '$3'" ;;
    *) ok "$1" ;;
  esac
}
assert_file() { if [ -e "$2" ]; then ok "$1"; else no "$1" "$2 does not exist"; fi; }
assert_nofile() { if [ -e "$2" ]; then no "$1" "$2 should not exist"; else ok "$1"; fi; }

# Creates a throwaway repository and MOVES INTO IT, setting $R.
# It must not run in a command substitution: the cd would happen in a subshell
# and every later command would land in the harness repository instead.
new_repo() {
  cd "$HOME_DIR"
  R=$(mktemp -d)
  cd "$R"
  # `-b master` explicitly, not the machine default. Half a dozen assertions in
  # this suite name `master` as the default branch, and the first CI run said so:
  # the runner had `init.defaultBranch=main` and the hook refused naming `main`,
  # correctly. It was the suite that took the git config of whoever runs it for
  # granted.
  git init -q -b master
  git config user.email t@example.com
  git config user.name Test
  git config commit.gpgsign false
  echo seed > README.md
  git add .
  git commit -qm seed
}

done_repo() {
  cd "$HOME_DIR"
  if [ -n "$R" ]; then rm -rf "$R"; fi
  R=""
}

with_gate() {
  mkdir -p scripts/harness
  cp "$HOME_DIR/core/verify" scripts/harness/verify
  chmod +x scripts/harness/verify
  cp "$HOME_DIR/test/fixtures/config.sh" scripts/harness/config.sh
}

with_run() {
  mkdir -p scripts/harness
  cp "$HOME_DIR/core/run" scripts/harness/run
  chmod +x scripts/harness/run
}

# run the run context, capturing stdout+stderr and the exit code
ctx() {
  set +e
  OUT=$(sh scripts/harness/run "$@" 2>&1)
  RC=$?
  set -e
}

# run the gate, capturing stdout+stderr and the exit code
gate() {
  set +e
  OUT=$(sh scripts/harness/verify "$@" 2>&1)
  RC=$?
  set -e
}

# ---------------------------------------------------------------- the gate ----
echo "the verification gate"

new_repo; with_gate
gate
assert_eq "refuses to run without a test target" "$RC" 2
assert_has "explains what to name" "$OUT" "name the tests that touch this task"
assert_nofile "a refused run leaves no stamp" .harness/verified
done_repo

new_repo; with_gate
mkdir -p src && echo 'x' > src/probe.ts
gate --docs-only
assert_eq "--docs-only refuses an untracked code file" "$RC" 2
assert_has "names the offending file" "$OUT" "src/probe.ts"
assert_nofile "and leaves no stamp" .harness/verified
done_repo

new_repo; with_gate
mkdir -p spec && echo 'x' > spec/probe.ts
gate --docs-only
assert_eq "--docs-only refuses every declared code path" "$RC" 2
done_repo

# HARNESS_CODE_PATHS was matched as a directory prefix only, so a code file living
# at the repository root could never be one - the Go profile carried that as a
# known wart, and a consumer's compose file walked into it: a change that can take
# the whole lab down passed --docs-only without running a test.
new_repo; with_gate
printf 'HARNESS_CODE_PATHS="src spec compose.lab.yaml"\n' >> scripts/harness/config.sh
echo 'services: {}' > compose.lab.yaml
gate --docs-only
assert_eq "a declared file at the root is code too" "$RC" 2
assert_has "and it is named" "$OUT" "compose.lab.yaml"
done_repo

# The same entry must not start matching things that merely look like it: the dot
# is a literal, not a wildcard.
new_repo; with_gate
printf 'HARNESS_CODE_PATHS="src spec compose.lab.yaml"\n' >> scripts/harness/config.sh
echo 'x' > composeXlabYyaml
gate --docs-only
assert_eq "but a name that only resembles it is not" "$RC" 0
done_repo

# A directory entry keeps behaving as a prefix, which is what every profile ships.
new_repo; with_gate
mkdir -p srcery && echo 'x' > srcery/thing.ts
gate --docs-only
assert_eq "and a directory whose name merely starts with one is not code" "$RC" 0
done_repo

# An entry is a path, not a pattern, so every regex metacharacter in it is a
# literal. Unescaped, `app+` failed both ways at once: the real app+/ was not
# code, and an unrelated apppp/ was.
new_repo; with_gate
printf 'HARNESS_CODE_PATHS="app+"\n' >> scripts/harness/config.sh
mkdir -p apppp && echo 'x' > apppp/thing.ts
gate --docs-only
assert_eq "a '+' in an entry is a literal, not a quantifier" "$RC" 0
mkdir -p 'app+' && echo 'x' > 'app+/thing.ts'
gate --docs-only
assert_eq "and the directory it actually names is code" "$RC" 2
assert_has "named as written" "$OUT" "app+/thing.ts"
done_repo

# Pinning the reading, because a review called it a regression and it is not: an
# entry names a path that holds code, and a path is a file or a directory. Both
# cannot exist at once, so a bare file of that name is only reachable when the
# directory the entry meant is absent - a config pointing at nothing. Refusing
# there is the safe direction: it costs a test run, it never lets code through.
new_repo; with_gate
echo 'not really code' > spec
gate --docs-only
assert_eq "a declared name that turns out to be a file is code as well" "$RC" 2
done_repo

new_repo; with_gate
mkdir -p src && echo 'x' > src/staged.ts && git add src/staged.ts
gate --docs-only
assert_eq "staging a code file does not hide it" "$RC" 2
assert_has "and it is named" "$OUT" "src/staged.ts"
done_repo

new_repo; with_gate
mkdir -p docs && echo '# d' > docs/note.md
gate --docs-only
assert_eq "--docs-only passes when no code is involved" "$RC" 0
assert_has "runs the static gates" "$OUT" "STUB gates"
assert_no "and selects no tests" "$OUT" "STUB selected"
assert_file "stamping the run" .harness/verified
assert_has "the stamp says docs-only" "$(cat .harness/verified)" "docs-only"
done_repo

new_repo; with_gate
git switch -q -c phase-42-example
echo '# log' > CHANGELOG.md
gate --docs-only
assert_has "the stamp records the branch" "$(cat .harness/verified)" "phase-42-example"
done_repo

new_repo; with_gate
gate spec/thing.test.ts another/target
assert_eq "a named target runs" "$RC" 0
assert_has "the selection reaches the runner verbatim" "$OUT" "STUB selected: spec/thing.test.ts another/target"
assert_has "the stamp records the selection" "$(cat .harness/verified)" "spec/thing.test.ts another/target"
done_repo

new_repo; with_gate
gate --full
assert_eq "--full runs" "$RC" 0
assert_has "--full announces itself so the report justifies it" "$OUT" "FULL SUITE"
assert_has "and runs the whole suite" "$OUT" "STUB all"
done_repo

new_repo; with_gate
mkdir -p docs src
echo '# d' > docs/note.md
echo 'x' > src/wip.ts
git add docs/note.md
gate --docs-only
assert_eq "--docs-only judges the staged change, not an unrelated dirty tree" "$RC" 0
assert_has "and says so" "$OUT" "docs-only change"
done_repo

new_repo; with_gate
mkdir -p docs src
echo '# d' > docs/note.md
echo 'x' > src/wip.ts
git add docs/note.md src/wip.ts
gate --docs-only
assert_eq "but refuses the moment the code itself is staged" "$RC" 2
assert_has "naming it" "$OUT" "src/wip.ts"
done_repo

# The verdict is the command's exit status, and nothing in between may change it.
# Measured on 17-sep-2026 in a consumer: `rtk pnpm typecheck` exited 0 where
# `pnpm typecheck` exited 1, so verification passed with the typecheck broken, the
# hook let the commit through and the failure showed up in CI a minute later. A
# wrapper that trims the output has no say in whether something passed. A fake
# `rtk` that always exits 0 simulates it here: if the gate consulted it, this test
# would go green with the command failing.
new_repo; with_gate
cat > scripts/harness/config.sh <<'CFG'
HARNESS_CODE_PATHS="src spec"
harness_gates() { run sh -c 'exit 1'; }
harness_test_selected() { echo "STUB selected: $*"; }
harness_test_all() { echo "STUB all"; }
CFG
mkdir -p "$R/fake-bin"
printf '#!/bin/sh\nexit 0\n' > "$R/fake-bin/rtk"
chmod +x "$R/fake-bin/rtk"
OLD_PATH=$PATH
PATH="$R/fake-bin:$PATH"
gate src
PATH=$OLD_PATH
assert_eq "a failing gate command fails the run although the wrapper reports success" "$RC" 1
assert_nofile "and a failed gate leaves no stamp" .harness/verified
done_repo

# ------------------------------------------------------- the gate contract ----
echo ""
echo "the config.sh contract"

new_repo
mkdir -p scripts/harness
cp "$HOME_DIR/core/verify" scripts/harness/verify
gate --docs-only
assert_eq "no config.sh is a hard failure" "$RC" 2
assert_has "and it says how to fix it" "$OUT" "norma install"
done_repo

new_repo; with_gate
grep -v '^harness_gates' scripts/harness/config.sh > c && mv c scripts/harness/config.sh
gate --docs-only
assert_eq "a config without harness_gates is a hard failure" "$RC" 2
assert_has "naming what is missing" "$OUT" "harness_gates"
done_repo

new_repo; with_gate
grep -v '^HARNESS_CODE_PATHS' scripts/harness/config.sh > c && mv c scripts/harness/config.sh
gate --docs-only
assert_eq "a config without HARNESS_CODE_PATHS is a hard failure" "$RC" 2
done_repo

# --------------------------------------------------------- the run context ----
echo ""
echo "the run context"

new_repo; with_run
ctx status
assert_eq "status without a context is not a failure" "$RC" 0
assert_has "and says so plainly" "$OUT" "normal state"
ctx event verify outcome=pass
assert_eq "an event without a context is a silent no-op" "$RC" 0
assert_nofile "writing nothing at all" "$R/.harness/run-events.jsonl"
done_repo

new_repo; with_run
git switch -qc phase-16-demo
ctx start phase-16-demo
assert_eq "start creates a run" "$RC" 0
assert_file "as a file in the worktree, not an environment variable" "$R/.harness/run.json"
assert_has "printing the identity it minted" "$OUT" "nr_"
first=$(sed -n 's/^  "run_id": "\(.*\)",$/\1/p' .harness/run.json)
ctx start phase-16-demo
assert_eq "starting again on the same branch reuses it" "$RC" 0
assert_eq "rather than minting a second identity for one task" \
  "$(sed -n 's/^  "run_id": "\(.*\)",$/\1/p' .harness/run.json)" "$first"
done_repo

new_repo; with_run
git switch -qc branch-a
sh scripts/harness/run start task-a >/dev/null
git switch -qc branch-b
ctx start task-b
assert_eq "an active run from another branch refuses the new one" "$RC" 2
assert_has "naming the branch it belongs to" "$OUT" "branch-a"
assert_has "and how to end it" "$OUT" "run close"
done_repo

new_repo; with_run
git switch -qc branch-a
sh scripts/harness/run start task-a >/dev/null
git switch -qc branch-b
sh scripts/harness/run event verify outcome=pass
assert_has "an event collected against a drifted context is marked stale" \
  "$(cat .harness/run-events.jsonl)" '"stale": true'
done_repo

new_repo; with_run
git switch -qc phase-16-demo
sh scripts/harness/run start phase-16-demo >/dev/null
ctx start 'not a slug'
assert_eq "a slug with a space is refused" "$RC" 2
ctx start ok --kind sideways
assert_eq "a kind outside the two is refused" "$RC" 2
assert_has "naming both of them" "$OUT" "benchmark"
ctx event verify Mode=full
assert_eq "an event key that is not lowercase is refused" "$RC" 2
ctx event verify lonely
assert_eq "an event field that is not key=value is refused" "$RC" 2
done_repo

new_repo; with_run
git switch -qc phase-16-demo
sh scripts/harness/run start phase-16-demo >/dev/null
sh scripts/harness/run event review 'verdict=he said "no"' blocking=2
assert_has "a quote in a value is escaped rather than breaking the line" \
  "$(cat .harness/run-events.jsonl)" '\"no\"'
assert_has "an integer stays an integer" "$(cat .harness/run-events.jsonl)" '"blocking": 2'
assert_eq "one event is one line" "$(wc -l < .harness/run-events.jsonl | tr -d ' ')" "1"
# Digits and dashes are not an integer, and reading them as one emitted a bare
# 2026-09-16 into the log: not JSON at all, in the one field the whole
# correlation hangs on.
sh scripts/harness/run event agent_session runtime=codex session_id=2026-09-16 turns=-3
assert_has "an id of digits and dashes is quoted, not emitted as a number" \
  "$(tail -1 .harness/run-events.jsonl)" '"session_id": "2026-09-16"'
assert_has "while a negative integer is still a number" \
  "$(tail -1 .harness/run-events.jsonl)" '"turns": -3'
assert_has "and a lone dash is a string" \
  "$(sh scripts/harness/run event review verdict=- && tail -1 .harness/run-events.jsonl)" '"verdict": "-"'
done_repo

# git allows a double quote in a branch name, and the branch reaches both the
# context and every event written against it.
new_repo; with_run
git switch -qc 'quote"branch'
ctx start awkward-branch
assert_eq "a branch name carrying a quote does not break the context" "$RC" 0
assert_has "it is escaped where it is stored" "$(cat .harness/run.json)" 'quote\"branch'
sh scripts/harness/run event verify outcome=pass
assert_no "and the event it stamps is not marked stale by its own branch" \
  "$(cat .harness/run-events.jsonl)" '"stale": true'
done_repo

new_repo; with_run
ctx
assert_eq "no subcommand prints the usage" "$RC" 2
assert_has "naming start" "$OUT" "run start"
assert_has "and close" "$OUT" "run close"
assert_has "starting at the first command, with no blank line from the comment block" \
  "$(printf '%s' "$OUT" | head -1)" "run start"
done_repo

new_repo; with_run
git switch -qc phase-16-demo
sh scripts/harness/run start phase-16-demo >/dev/null
sh scripts/harness/run event agent_session runtime=claude-code session_id=abc turns=7
ctx close reports/norma-run.json
assert_eq "close writes the durable summary" "$RC" 0
assert_file "at the path it was given, creating the directory" "$R/reports/norma-run.json"
assert_has "carrying the run" "$(cat reports/norma-run.json)" "norma.run.summary/1"
assert_has "and the session that has to be correlated with it" \
  "$(cat reports/norma-run.json)" "claude-code"
assert_nofile "and removes the context, so no task inherits another's run" "$R/.harness/run.json"
assert_nofile "including its events" "$R/.harness/run-events.jsonl"
ctx close
assert_eq "closing nothing is not a failure" "$RC" 0
done_repo

new_repo; with_run
git switch -qc phase-16-demo
sh scripts/harness/run start phase-16-demo >/dev/null
ctx close
assert_eq "a run with no events still closes" "$RC" 0
assert_has "with an empty event list rather than a broken one" "$OUT" '"events": []'
done_repo

# ------------------------------------------ the gate records what it decided ----
echo ""
echo "the gate and the run context"

new_repo; with_gate
gate unit
assert_eq "the gate passes with no run context at all" "$RC" 0
assert_file "and still writes its stamp" "$R/.harness/verified"
done_repo

new_repo; with_gate; with_run
git switch -qc phase-16-demo
sh scripts/harness/run start phase-16-demo >/dev/null
gate unit
assert_eq "the gate passes with a run context" "$RC" 0
assert_has "recording the mode" "$(cat .harness/run-events.jsonl)" '"mode": "selected"'
assert_has "and the selection a reviewer has to judge" \
  "$(cat .harness/run-events.jsonl)" '"selection": "unit"'
assert_has "and that it passed" "$(cat .harness/run-events.jsonl)" '"outcome": "pass"'
gate --full
assert_has "--full is recorded as what it is" "$(cat .harness/run-events.jsonl)" '"mode": "full"'
gate --docs-only
assert_has "so is --docs-only" "$(cat .harness/run-events.jsonl)" '"mode": "docs-only"'
done_repo

new_repo; with_gate; with_run
git switch -qc phase-16-demo
sh scripts/harness/run start phase-16-demo >/dev/null
gate
assert_eq "a gate refused for naming no target still exits 2" "$RC" 2
assert_eq "and records nothing: nothing was verified" \
  "$(wc -l < .harness/run-events.jsonl | tr -d ' ')" "0"
done_repo

new_repo; with_gate; with_run
git switch -qc phase-16-demo
cat > scripts/harness/config.sh <<'STUB'
HARNESS_CODE_PATHS="src"
harness_gates() { echo gates; }
harness_test_selected() { return 3; }
harness_test_all() { return 0; }
STUB
sh scripts/harness/run start phase-16-demo >/dev/null
gate unit
assert_eq "a failing suite still fails the gate with its own code" "$RC" 3
assert_has "and the failure is recorded as a failure" \
  "$(cat .harness/run-events.jsonl)" '"outcome": "fail"'
assert_has "with the code that caused it" "$(cat .harness/run-events.jsonl)" '"exit_code": 3'
assert_nofile "and no stamp is written" "$R/.harness/verified"
done_repo

new_repo; with_gate; with_run
git switch -qc phase-16-demo
sh scripts/harness/run start phase-16-demo >/dev/null
printf '#!/bin/sh\nexit 9\n' > scripts/harness/run
gate unit
assert_eq "a broken 'run' costs a record, never a verification" "$RC" 0
assert_file "the stamp is written regardless" "$R/.harness/verified"
done_repo

# ------------------------------------------------- the gate's own clock -------
echo ""
echo "how long a verification took"

# A PATH entry that forces the gate onto one clock source, so these tests do not
# depend on what the machine running them happens to have. Each stub answers the
# probe the gate makes, and nothing else.
stub_clock() {
  mkdir -p "$R/stubbin"
  TICKS="$R/stubbin/ticks"; export TICKS
  # Three reads per gate run, not two: the probe that picks the source spends
  # one before the interval even starts. The first two answer the same value so
  # the measured interval is the third minus the second.
  cat > "$R/stubbin/tick" <<'TICK'
#!/bin/sh
n=0
[ -f "$TICKS" ] && n=$(cat "$TICKS")
n=$((n + 1))
echo "$n" > "$TICKS"
echo "$n"
TICK
  chmod +x "$R/stubbin/tick"
  # A BSD date with no %N prints the letter, which is why the probe reads the
  # answer for digits instead of checking the platform. Every source below perl
  # needs this, because `date` is now tried first.
  cat > "$R/stubbin/no_ns_date" <<'DATE'
#!/bin/sh
case ${1:-} in
  +%s%N) echo 1700000000N ;;
  *) exec /bin/date "$@" ;;
esac
DATE
  case $1 in
    realtime_ns)
      # perl leaves a mark if it is ever run. It must not be: `date` answered.
      cat > "$R/stubbin/perl" <<'PERL'
#!/bin/sh
touch "$(dirname "$0")/perl-was-run"
exit 1
PERL
      chmod +x "$R/stubbin/perl"
      cat > "$R/stubbin/date" <<'DATE'
#!/bin/sh
case ${1:-} in
  +%s%N)
    case $(sh "$(dirname "$0")/tick") in
      1|2) echo 1700000000000000000 ;;
      *) echo 1700000000347000000 ;;
    esac
    ;;
  *) exec /bin/date "$@" ;;
esac
DATE
      chmod +x "$R/stubbin/date"
      ;;
    monotonic)
      cp "$R/stubbin/no_ns_date" "$R/stubbin/date"; chmod +x "$R/stubbin/date"
      # 1000 ms, then 1347 ms: 347 ms elapsed, and it cannot go backwards.
      cat > "$R/stubbin/perl" <<'PERL'
#!/bin/sh
case $(sh "$(dirname "$0")/tick") in
  1|2) echo 1000 ;;
  *) echo 1347 ;;
esac
PERL
      chmod +x "$R/stubbin/perl"
      ;;
    realtime_s)
      cp "$R/stubbin/no_ns_date" "$R/stubbin/date"; chmod +x "$R/stubbin/date"
      printf '#!/bin/sh\nexit 1\n' > "$R/stubbin/perl"
      chmod +x "$R/stubbin/perl"
      ;;
    perl_dies)
      cp "$R/stubbin/no_ns_date" "$R/stubbin/date"; chmod +x "$R/stubbin/date"
      # Answers the probe, then fails. `clock_ms` runs inside `record_from`,
      # where `set -e` is armed, so before this was guarded a clock that broke
      # between the probe and the first read killed the whole verification.
      cat > "$R/stubbin/perl" <<'PERL'
#!/bin/sh
case $(sh "$(dirname "$0")/tick") in
  1) echo 1000 ;;
  *) exit 1 ;;
esac
PERL
      chmod +x "$R/stubbin/perl"
      ;;
    busybox)
      printf '#!/bin/sh\nexit 1\n' > "$R/stubbin/perl"
      chmod +x "$R/stubbin/perl"
      # BusyBox does not implement %N and drops it without complaining: the
      # answer is bare epoch seconds, all digits, exit 0. Verified in alpine.
      # Trimming six characters off that yields 1789, which the gate would
      # publish as milliseconds while a two-second run measured zero.
      cat > "$R/stubbin/date" <<'DATE'
#!/bin/sh
case ${1:-} in
  +%s%N|+%s) echo 1789726082 ;;
  *) exec /bin/date "$@" ;;
esac
DATE
      chmod +x "$R/stubbin/date"
      ;;
    date_dies)
      printf '#!/bin/sh\nexit 1\n' > "$R/stubbin/perl"
      chmod +x "$R/stubbin/perl"
      # Answers the probe, then fails outright. `clock_ms` runs inside
      # `record_from` before any `set +e`, so a bare `ns=$(date ...)` hands
      # date's status to a live `set -e` and ends the verification.
      cat > "$R/stubbin/date" <<'DATE'
#!/bin/sh
case ${1:-} in
  +%s%N)
    case $(sh "$(dirname "$0")/tick") in
      1) echo 1700000000000000000 ;;
      *) exit 1 ;;
    esac
    ;;
  *) exec /bin/date "$@" ;;
esac
DATE
      chmod +x "$R/stubbin/date"
      ;;
    backwards)
      printf '#!/bin/sh\nexit 1\n' > "$R/stubbin/perl"
      chmod +x "$R/stubbin/perl"
      # The wall clock steps back between the two reads, which is what NTP does.
      cat > "$R/stubbin/date" <<'DATE'
#!/bin/sh
case ${1:-} in
  +%s%N)
    case $(sh "$(dirname "$0")/tick") in
      1|2) echo 1700000005000000000 ;;
      *) echo 1700000000000000000 ;;
    esac
    ;;
  *) exec /bin/date "$@" ;;
esac
DATE
      chmod +x "$R/stubbin/date"
      ;;
    near_epoch)
      printf '#!/bin/sh\nexit 1\n' > "$R/stubbin/perl"
      chmod +x "$R/stubbin/perl"
      # A clock inside the first second of 1970 - no RTC battery, no NTP yet -
      # makes `date +%s%N` start with a zero, and `$(( 0985000000 / 1000000 ))`
      # is a fatal "value too great for base", not a non-zero status.
      cat > "$R/stubbin/date" <<'DATE'
#!/bin/sh
case ${1:-} in
  +%s%N)
    case $(sh "$(dirname "$0")/tick") in
      1|2) echo 0985000000 ;;
      *) echo 1332000000 ;;
    esac
    ;;
  # The seconds have to agree with the nanoseconds: the gate measures one
  # against the other to catch a %N that was never expanded.
  +%s) echo 0 ;;
  *) exec /bin/date "$@" ;;
esac
DATE
      chmod +x "$R/stubbin/date"
      ;;
  esac
}

# the gate, on a stubbed clock
staged_gate() {
  set +e
  OUT=$(PATH="$R/stubbin:$PATH" sh scripts/harness/verify "$@" 2>&1)
  RC=$?
  set -e
}

new_repo; with_gate; with_run
git switch -qc clock-demo
sh scripts/harness/run start clock-demo >/dev/null
gate unit
EVENT=$(cat .harness/run-events.jsonl)
assert_has "the record says which clock measured it" "$EVENT" '"duration_clock"'
assert_eq "and it is one of the three the gate knows" \
  "$(printf '%s' "$EVENT" | sed -n 's/.*"duration_clock": "\([a-z_]*\)".*/\1/p' \
     | grep -cE '^(monotonic|realtime_ns|realtime_s)$')" "1"
done_repo

new_repo; with_gate; with_run
git switch -qc clock-demo
stub_clock realtime_ns
sh scripts/harness/run start clock-demo >/dev/null
staged_gate unit
assert_eq "a date that does nanoseconds is what the gate reaches for first" \
  "$(sed -n 's/.*"duration_clock": "\([a-z_]*\)".*/\1/p' .harness/run-events.jsonl)" "realtime_ns"
assert_has "and a verification under a second leaves a usable measurement" \
  "$(cat .harness/run-events.jsonl)" '"duration_ms": 347'
assert_has "with the legacy field truncated to whole seconds, as it always was" \
  "$(cat .harness/run-events.jsonl)" '"duration_s": 0'
assert_no "and no quotes around either: they are numbers, not strings" \
  "$(cat .harness/run-events.jsonl)" '"duration_ms": "'
assert_nofile "and perl is never spawned, which is the point of that order" \
  "$R/stubbin/perl-was-run"
done_repo

new_repo; with_gate; with_run
git switch -qc clock-demo
stub_clock monotonic
sh scripts/harness/run start clock-demo >/dev/null
staged_gate unit
assert_eq "a date without %N is what sends the gate to the monotonic clock" \
  "$(sed -n 's/.*"duration_clock": "\([a-z_]*\)".*/\1/p' .harness/run-events.jsonl)" "monotonic"
assert_has "which measures the same sub-second run" \
  "$(cat .harness/run-events.jsonl)" '"duration_ms": 347'
done_repo

new_repo; with_gate; with_run
git switch -qc clock-demo
stub_clock realtime_s
sh scripts/harness/run start clock-demo >/dev/null
staged_gate unit
assert_eq "with neither, only whole seconds are left" \
  "$(sed -n 's/.*"duration_clock": "\([a-z_]*\)".*/\1/p' .harness/run-events.jsonl)" "realtime_s"
assert_no "and then there is no precise duration to report" \
  "$(cat .harness/run-events.jsonl)" '"duration_ms"'
assert_has "the legacy field survives, which is what consumers already read" \
  "$(cat .harness/run-events.jsonl)" '"duration_s"'
done_repo

new_repo; with_gate; with_run
git switch -qc clock-demo
stub_clock backwards
sh scripts/harness/run start clock-demo >/dev/null
staged_gate unit
assert_eq "a wall clock that stepped back is not a fast verification" "$RC" 0
assert_no "so no precise duration is invented" \
  "$(cat .harness/run-events.jsonl)" '"duration_ms"'
assert_no "and no coarse one either: a negative interval measures nothing" \
  "$(cat .harness/run-events.jsonl)" '"duration_s"'
assert_has "the verification itself is recorded, as it must be" \
  "$(cat .harness/run-events.jsonl)" '"outcome": "pass"'
done_repo

new_repo; with_gate; with_run
git switch -qc clock-demo
stub_clock perl_dies
sh scripts/harness/run start clock-demo >/dev/null
staged_gate unit
assert_eq "a clock that breaks after the probe costs a measurement, not the gate" "$RC" 0
assert_file "and the stamp is written" "$R/.harness/verified"
assert_has "the verification is still recorded" \
  "$(cat .harness/run-events.jsonl)" '"outcome": "pass"'
assert_no "without a precise duration nobody measured" \
  "$(cat .harness/run-events.jsonl)" '"duration_ms"'
done_repo

new_repo; with_gate; with_run
git switch -qc clock-demo
stub_clock near_epoch
sh scripts/harness/run start clock-demo >/dev/null
staged_gate unit
assert_eq "a clock still in 1970 does not crash the gate on an octal numeral" "$RC" 0
assert_has "and its interval is measured all the same" \
  "$(cat .harness/run-events.jsonl)" '"duration_ms": 347'
assert_no "with no shell diagnostic leaking into the output" "$OUT" "value too great"
assert_no "nor dash's wording for the same thing" "$OUT" "Illegal number"
done_repo

new_repo; with_gate; with_run
git switch -qc clock-demo
stub_clock busybox
sh scripts/harness/run start clock-demo >/dev/null
staged_gate unit
assert_eq "a date that swallowed %N is not mistaken for a nanosecond clock" \
  "$(sed -n 's/.*"duration_clock": "\([a-z_]*\)".*/\1/p' .harness/run-events.jsonl)" "realtime_s"
assert_no "so it never publishes epoch seconds as milliseconds" \
  "$(cat .harness/run-events.jsonl)" '"duration_ms"'
done_repo

new_repo; with_gate; with_run
git switch -qc clock-demo
stub_clock date_dies
sh scripts/harness/run start clock-demo >/dev/null
staged_gate unit
assert_eq "a date that fails after the probe costs a measurement, not the gate" "$RC" 0
assert_file "and the stamp is written" "$R/.harness/verified"
assert_has "the verification is still recorded" \
  "$(cat .harness/run-events.jsonl)" '"outcome": "pass"'
assert_no "without a precise duration nobody measured" \
  "$(cat .harness/run-events.jsonl)" '"duration_ms"'
done_repo


new_repo; with_gate; with_run
git switch -qc clock-demo
stub_clock realtime_ns
sh scripts/harness/run start clock-demo >/dev/null
printf '#!/bin/sh\nexit 9\n' > scripts/harness/run
staged_gate unit
assert_eq "measuring the duration still cannot cost a verification" "$RC" 0
assert_file "and the stamp is written regardless" "$R/.harness/verified"
done_repo

# ------------------------------------------------- the floor guard ------------
echo ""
echo "the floor guard"

# The markers below are assembled from pieces on purpose. This file is a test
# file inside a code path, so writing them out literally would make this very
# suite trip the guard it is testing on every change that touches it.
SK=skip; ON=only; TSI="@ts-""ignore"; NOQ="# no""qa"; NI="not ""implemented"

# A repository whose harness is committed on master, on a branch with a run open:
# the shape of a real project mid-task, so nothing the guard sees is setup noise.
floor_repo() {
  new_repo; with_gate; with_run
  mkdir -p src spec
  printf 'export const a = 1;\n' > src/a.ts
  printf 'it("adds", () => {\n  expect(add(1, 1)).toBe(2);\n  expect(add(2, 2)).toBe(4);\n});\n' > spec/a.test.ts
  printf 'it("subtracts", () => {\n  expect(sub(2, 1)).toBe(1);\n});\n' > spec/b.test.ts
  git add . && git commit -qm harness
  git switch -qc phase-17-floor
  sh scripts/harness/run start phase-17-floor >/dev/null
}

floor_repo
printf 'export const b = 2;\n' > src/b.ts
gate unit
assert_eq "a change that lowers nothing passes" "$RC" 0
assert_no "and the guard says nothing" "$OUT" "harness: floor"
assert_has "the guard records that it looked" "$(cat .harness/run-events.jsonl)" '"outcome": "clean"'
done_repo

floor_repo
printf 'it.%s("adds", () => {});\n' "$SK" >> spec/a.test.ts
gate unit
assert_eq "a skipped test does not fail the gate - the guard only warns" "$RC" 0
assert_file "and the stamp is written" "$R/.harness/verified"
assert_has "it names the file and the line" "$OUT" "spec/a.test.ts:5"
assert_has "and what the move was" "$OUT" "skip or focus marker"
assert_has "it records the move against the run" "$(cat .harness/run-events.jsonl)" '"outcome": "weakened"'
assert_has "counted by kind" "$(cat .harness/run-events.jsonl)" '"skip": 1'
done_repo

floor_repo
printf 'it.%s("x", () => {});\n' "$SK" > "spec/with space.test.ts"
gate unit
assert_has "an untracked file whose name holds a space is still read" "$OUT" "spec/with space.test.ts:1"
done_repo

floor_repo
printf 'describe.%s("all", () => {});\n' "$ON" > spec/c.test.ts
gate unit
assert_has "a focus marker silences every other test, and a new file is read too" \
  "$OUT" "spec/c.test.ts:1"
done_repo

floor_repo
printf '// %s\nexport const b: number = "x";\n' "$TSI" > src/b.ts
printf 'Never write %s in this project.\n' "$TSI" >> README.md
gate unit
assert_has "a suppression in code is reported" "$OUT" "src/b.ts:1"
assert_has "as a silenced checker" "$OUT" "checker suppressed"
assert_no "the same words in a document are not code" "$OUT" "README.md"
done_repo

floor_repo
printf 'x = 1  %s\n' "$NOQ" > src/c.py
printf 'export function b() { throw new Error("%s"); }\n' "$NI" > src/b.ts
gate unit
assert_has "a python suppression is one too" "$OUT" "src/c.py:1"
assert_has "a stub standing in for the work is reported" "$OUT" "src/b.ts:1"
assert_has "as unfinished" "$OUT" "unfinished work"
done_repo

floor_repo
git rm -q spec/b.test.ts
gate unit
assert_has "a deleted test file is reported" "$OUT" "spec/b.test.ts"
assert_has "as what it is" "$OUT" "test file deleted"
done_repo

floor_repo
printf 'it("adds", () => {\n  expect(add(1, 1)).toBe(2);\n});\n' > spec/a.test.ts
gate unit
assert_has "an assertion removed from a test that stayed is reported" "$OUT" "spec/a.test.ts"
assert_has "with the net count" "$OUT" "1 assertion(s) removed"
done_repo

floor_repo
printf 'it("adds", () => {\n  expect(add(1, 1)).toEqual(2);\n  expect(add(2, 2)).toEqual(4);\n});\n' > spec/a.test.ts
gate unit
assert_no "an assertion rewritten, not removed, is not a lowered bar" "$OUT" "harness: floor"
done_repo

floor_repo
printf 'harness_gates() { :; }\n' >> scripts/harness/config.sh
gate unit
assert_has "a change to the gate's own config is reported" "$OUT" "scripts/harness/config.sh"
assert_has "as the one place a gate can be removed" "$OUT" "gate's own config changed"
done_repo

floor_repo
printf 'it.%s("pre-existing", () => {});\n' "$SK" > spec/old.test.ts
git switch -q master && git add spec/old.test.ts && git commit -qm old && git switch -q phase-17-floor
git merge -q --ff-only master
printf 'export const b = 2;\n' > src/b.ts
gate unit
assert_no "what the base branch already had is not this change's doing" "$OUT" "spec/old.test.ts"
done_repo

# A line added to a hunk that starts with `++` shows as `+++` in the diff, which
# is the shape of a file header. The parser must not take it for one.
floor_repo
printf '++n;\nit.%s("x", () => {});\n' "$SK" >> spec/a.test.ts
gate unit
assert_has "a +++ inside a hunk is content, not a header" "$OUT" "spec/a.test.ts:6"
done_repo

# The guard's own patterns live in core/verify. Written out plainly, they would
# match themselves the day a project puts the gate inside a code path - norma does.
floor_repo
cp "$HOME_DIR/core/verify" src/verify.sh
gate unit
assert_no "the gate does not trip on its own patterns" "$OUT" "src/verify.sh"
done_repo

floor_repo
printf 'it.%s("adds", () => {});\n' "$SK" >> spec/a.test.ts
gate --floor
assert_eq "--floor alone exits 1 when the bar was lowered" "$RC" 1
assert_has "printing the same report" "$OUT" "spec/a.test.ts:5"
assert_no "it runs no test" "$OUT" "STUB"
assert_nofile "it writes no stamp" "$R/.harness/verified"
assert_eq "and records nothing - the reviewer reads it, the author's run does not" \
  "$(wc -l < .harness/run-events.jsonl | tr -d ' ')" "0"
done_repo

floor_repo
gate --floor
assert_eq "--floor exits 0 on a clean change" "$RC" 0
done_repo

floor_repo
git branch -qm master trunk
printf 'it.%s("adds", () => {});\n' "$SK" >> spec/a.test.ts
gate --floor
assert_eq "--floor exits 2 when there is no base to compare with" "$RC" 2
assert_has "and says so instead of reading as clean" "$OUT" "could not check"
gate unit
assert_eq "the gate still passes when the guard cannot look" "$RC" 0
assert_has "but it says so" "$OUT" "could not check"
assert_has "and records it" "$(cat .harness/run-events.jsonl)" '"outcome": "unchecked"'
done_repo

# Found by review: a user's git config reshapes the diff the parser reads. With
# mnemonic prefixes every path arrived as `w/src/...` and no code path matched;
# with the default quotepath a non-ASCII name arrived quoted and matched nothing.
floor_repo
git config diff.mnemonicPrefix true
printf '// %s\n' "$TSI" >> src/a.ts
gate --floor
assert_has "a user's diff prefixes do not hide a suppression" "$OUT" "src/a.ts:2"
done_repo

floor_repo
printf '// %s\n' "$TSI" > "src/$(printf '\303\251').ts"
git add . && git commit -qm accent
gate --floor
assert_has "a non-ASCII file name is read, not quoted past the patterns" "$OUT" "src/$(printf '\303\251').ts:1"
done_repo

# A rename out of the test names stops the test running exactly as a deletion
# does, and a pure rename carries no ---/+++ lines at all.
floor_repo
git mv spec/b.test.ts src/b.txt
gate --floor
assert_has "a test renamed out of the test names reads as deleted" "$OUT" "spec/b.test.ts"
done_repo

floor_repo
: > spec/empty.test.ts
git add . && git commit -qm empty
git switch -q master && git merge -q --ff-only phase-17-floor && git switch -q phase-17-floor
git rm -q spec/empty.test.ts
gate --floor
assert_has "deleting an empty test file is still a deletion" "$OUT" "spec/empty.test.ts"
done_repo

floor_repo
git branch -qm master trunk
gate --floor
assert_has "with no base it names that as the reason" "$OUT" "no base branch"
done_repo

# The reviewer may not read the author's run log, so the one exception has to be
# written where the reviewer looks, and the author has to be told to answer it.
assert_has "the review is allowed the guard's list, and only that" \
  "$(cat "$HOME_DIR/skills/adversarial-review/SKILL.md")" 'Neither is `scripts/harness/verify --floor`'
assert_has "run-task tells the author each floor line needs a reason" \
  "$(cat "$HOME_DIR/skills/run-task/SKILL.md")" "**floor guard**"

floor_repo
printf 'it.%s("adds", () => {});\n' "$SK" >> spec/a.test.ts
gate --docs-only
assert_no "--docs-only refuses before the guard ever runs" "$OUT" "harness: floor"
done_repo

# ---------------------------------------------------------- the hook ----------
echo ""
echo "the pre-commit hook"

new_repo
mkdir -p .githooks && cp "$HOME_DIR/core/pre-commit" .githooks/pre-commit
chmod +x .githooks/pre-commit
git switch -q -c feature-branch
mkdir -p .harness src
printf '2026-01-01 10:00:00 | feature-branch | spec/thing.test.ts another/one\n' > .harness/verified
touch -t 202601011000 .harness/verified
echo 'x' > src/late.ts
git add src/late.ts
set +e
OUT=$(.githooks/pre-commit 2>&1); RC=$?
set -e
assert_eq "refuses a commit whose stamp predates the staged files" "$RC" 1
assert_has "and hands back the previous selection, ready to paste" "$OUT" "scripts/harness/verify spec/thing.test.ts another/one"
assert_no "so no placeholder is left for somebody to remember" "$OUT" "<the tests"
done_repo

new_repo
mkdir -p .githooks && cp "$HOME_DIR/core/pre-commit" .githooks/pre-commit
chmod +x .githooks/pre-commit
git switch -q -c feature-branch
mkdir -p .harness src
printf '2026-01-01 10:00:00 | feature-branch | docs-only\n' > .harness/verified
touch -t 202601011000 .harness/verified
echo 'x' > src/late.ts
git add src/late.ts
set +e
OUT=$(.githooks/pre-commit 2>&1); RC=$?
set -e
assert_eq "still refuses when the stale run was docs-only" "$RC" 1
assert_has "and then asks for a real test selection" "$OUT" "<the tests that touch this task>"
done_repo

new_repo
mkdir -p .githooks scripts/harness && cp "$HOME_DIR/core/pre-commit" .githooks/pre-commit
chmod +x .githooks/pre-commit
cp "$HOME_DIR/test/fixtures/config.sh" scripts/harness/config.sh
git switch -q -c feature-branch
mkdir -p .harness src
echo 'x' > src/late.ts
git add src/late.ts
printf '2027-01-01 10:00:00 | feature-branch | docs-only\n' > .harness/verified
touch -t 202701011000 .harness/verified
set +e
OUT=$(.githooks/pre-commit 2>&1); RC=$?
set -e
assert_eq "refuses code committed against a docs-only stamp" "$RC" 1
assert_has "explaining that it vouches for no test" "$OUT" "vouches for no test"
assert_has "and naming the code being smuggled" "$OUT" "src/late.ts"
done_repo

# The hook reads the same HARNESS_CODE_PATHS as the gate and must read it the same
# way. While only the gate understood a file at the root, a docs-only stamp still
# let that file through the hook - the two disagreeing is worse than the original
# hole, because one of them says the commit was checked.
new_repo
mkdir -p .githooks scripts/harness && cp "$HOME_DIR/core/pre-commit" .githooks/pre-commit
chmod +x .githooks/pre-commit
cp "$HOME_DIR/test/fixtures/config.sh" scripts/harness/config.sh
printf 'HARNESS_CODE_PATHS="src spec compose.lab.yaml"\n' >> scripts/harness/config.sh
git switch -q -c feature-branch
mkdir -p .harness
echo 'services: {}' > compose.lab.yaml
git add compose.lab.yaml
printf '2027-01-01 10:00:00 | feature-branch | docs-only\n' > .harness/verified
touch -t 202701011000 .harness/verified
set +e
OUT=$(.githooks/pre-commit 2>&1); RC=$?
set -e
assert_eq "the hook refuses a declared root file against a docs-only stamp too" "$RC" 1
assert_has "naming it" "$OUT" "compose.lab.yaml"
done_repo

new_repo
mkdir -p .githooks && cp "$HOME_DIR/core/pre-commit" .githooks/pre-commit
chmod +x .githooks/pre-commit
set +e
OUT=$(.githooks/pre-commit 2>&1); RC=$?
set -e
assert_eq "refuses on the default branch" "$RC" 1
assert_has "naming the branch it refused" "$OUT" "master"
done_repo

# --------------------------------------------------------- the land script ----
echo ""
echo "the land script"

# land talks to GitHub only through gh, so a fake gh on PATH stands in for it: it
# logs every call and answers from the environment - MAIN_* for the pull request
# being landed, CO_* for the companion in a repository named */site. sleep and
# osascript are stubbed too, so the polling costs nothing and no notification
# reaches the desktop of whoever runs the suite.
FAKE_BIN=$(mktemp -d)
cat > "$FAKE_BIN/gh" <<'EOF'
#!/bin/sh
echo "$* token=${GH_TOKEN:-none}" >> "$FAKE_LOG"
case "$1 $2" in
  "auth token") [ "$4" = "${FAKE_ACCOUNT:-me}" ] && [ -n "${FAKE_TOKEN:-}" ] && echo "$FAKE_TOKEN" && exit 0; exit 1 ;;
  "api --paginate")
    [ -z "${FILES_FAIL:-}" ] || exit 1
    # the companion's files are CO_FILES; PREV are the old names of renamed files,
    # printed only when land asks for them
    case "$3" in */site/*) echo "${CO_FILES-index.md}" | tr , '\n'; exit 0 ;; esac
    [ -z "${FILES-src/a.ts}" ] || echo "${FILES-src/a.ts}" | tr , '\n'
    case "$*" in *previous_filename*) [ -z "${PREV:-}" ] || echo "$PREV" | tr , '\n' ;; esac ;;
  "pr view")
    p=MAIN; case "$5" in */site) p=CO ;; esac
    case "$7" in
      state) eval "echo \${${p}_STATE:-OPEN}" ;;
      mergeable) eval "echo \${${p}_MERGEABLE:-MERGEABLE}" ;;
      # after an update the new head appears at once, or (HEAD_LAG) two reads later.
      # HEAD_SHA=local is the commit checked out, as when an agent lands its own
      # branch; moving is that commit at the first read and another one after.
      headRefOid)
        if [ -e "$FAKE_LOG.updated" ]; then
          k=$(( $(cat "$FAKE_LOG.reads" 2>/dev/null || echo 0) + 1 )); echo $k > "$FAKE_LOG.reads"
          if [ -n "${HEAD_LAG:-}" ] && [ $k -le 2 ]; then echo abcdef0123456789; else echo "1234567890abcde$(cat "$FAKE_LOG.updated")"; fi
        elif [ "${HEAD_SHA:-}" = local ]; then git rev-parse HEAD
        elif [ "${HEAD_SHA:-}" = moving ]; then
          [ -e "$FAKE_LOG.moved" ] && echo fedcba9876543210 || { touch "$FAKE_LOG.moved"; git rev-parse HEAD; }
        else echo "${HEAD_SHA-abcdef0123456789}"; fi ;;
      # BEHIND: start - behind until updated; late - goes behind at the first
      # merge attempt, until updated; always - never catches up
      mergeStateStatus)
        case "${BEHIND:-}" in
          start) [ -e "$FAKE_LOG.updated" ] && echo CLEAN || echo BEHIND ;;
          late) [ -e "$FAKE_LOG.tried" ] && [ ! -e "$FAKE_LOG.updated" ] && echo BEHIND || echo CLEAN ;;
          always) echo BEHIND ;;
          *) echo CLEAN ;;
        esac ;;
      headRefName) echo feature ;;
      changedFiles) echo "${CHANGED_FILES:-1}" ;;
      # a stacked pull request (8 or 9) is based on feature until something moves
      # it; CHILD_BASE says where it already points
      baseRefName) case "$3" in 8|9) echo "${CHILD_BASE:-feature}" ;; *) echo master ;; esac ;;
    esac ;;
  "pr checks")
    [ "${CHECKS:-pass}" = pass ] && exit 0
    # late: green, then a slower workflow registers a pending check, then green
    if [ "$CHECKS" = late ]; then
      case "$*" in *--watch*) exit 0 ;; esac
      n=$(( $(cat "$FAKE_LOG.n" 2>/dev/null || echo 0) + 1 )); echo $n > "$FAKE_LOG.n"
      [ $n -eq 2 ] && exit 8
      exit 0
    fi
    # none: gh's own words for a pull request no workflow ran on
    [ "$CHECKS" = none ] && { echo "no checks reported on the 'feature' branch" >&2; exit 1; }
    case "$*" in *--watch*) exit 1 ;; esac
    [ "${CHECKS:-pass}" = pending ] && exit 8
    exit 1 ;;
  "pr list") [ -z "${LIST_FAIL:-}" ] || exit 1; [ -z "${CHILDREN:-}" ] || echo "$CHILDREN" | tr , '\n' ;;
  # gh 2.46, the one Ubuntu ships: pr update-branch does not exist, and pr edit
  # fails on a deprecated GraphQL field even when it applied the change. land goes
  # through the REST API for both, which no gh version changes.
  "pr edit") echo "GraphQL: Projects (classic) is being deprecated (repository.pullRequest.projectCards)" >&2; exit 1 ;;
  "pr update-branch") echo 'unknown command "update-branch" for "gh pr"' >&2; exit 1 ;;
  # POST is a commit status - a review verdict -, PUT a pull request brought up to
  # date, PATCH one moved onto another base, and DELETE a branch deleted
  "api -X")
    case "$3" in
      POST) [ -z "${STATUS_FAIL:-}" ] || exit 1 ;;
      PUT)
        [ -z "${UPDATE_FAIL:-}" ] || exit 1
        # every update is a new commit, so a new head
        echo $(( $(cat "$FAKE_LOG.updated" 2>/dev/null || echo 0) + 1 )) > "$FAKE_LOG.updated" ;;
      PATCH) [ -z "${EDIT_FAIL:-}" ] || exit 1 ;;
      *) [ -z "${DELETE_FAIL:-}" ] || exit 1 ;;
    esac ;;
  # the merge methods the companion's repository allows, and those the rules on
  # its base leave (CO_RULES_FAIL: the 403 of a private repository on the free plan)
  "api repos/me/site") [ -z "${CO_REPO_FAIL:-}" ] || exit 1; echo "${CO_ALLOWED-merge squash rebase}" ;;
  "api repos/me/site/rules/branches/"*)
    [ -z "${CO_RULES_FAIL:-}" ] || { echo "gh: Upgrade to GitHub Pro (HTTP 403)" >&2; exit 1; }
    echo "${CO_RULED-merge squash rebase}" ;;
  # norma/review on a head: REVIEW is its state, REVIEW_DESC its description with
  # commas for spaces; no REVIEW is no status at all
  "api repos/me/app/commits/"*/status\?*)
    [ -z "${REVIEW_FAIL:-}" ] || exit 1
    [ -z "${REVIEW:-}" ] || echo "$REVIEW $(echo "${REVIEW_DESC:-blocking=0,unresolved=0}" | tr , ' ')" ;;
  # the parents of an updated head: the head before the update and the base's tip,
  # or UPDATE_PARENTS (commas for spaces); COMPARE is where that tip stands to the
  # base: identical or ahead when it is on it
  "api repos/me/app/commits/"*)
    if [ -n "${UPDATE_PARENTS:-}" ]; then echo "$UPDATE_PARENTS" | tr , ' '; exit 0; fi
    k=$(cat "$FAKE_LOG.updated")
    if [ "$k" -gt 1 ]; then p="1234567890abcde$((k - 1))"
    elif [ "${HEAD_SHA:-}" = local ]; then p=$(git rev-parse HEAD)
    else p="${HEAD_SHA-abcdef0123456789}"; fi
    echo "$p 0123456789fedcba" ;;
  "api repos/me/app/compare/0123456789fedcba...master") echo "${COMPARE-identical}" ;;
  "api repos/"*)
    [ -z "${REF_GONE:-}" ] || { echo "gh: Not Found (HTTP 404)" >&2; exit 1; }
    [ -z "${REF_FORBIDDEN:-}" ] || { echo "gh: Forbidden (HTTP 403)" >&2; exit 1; } ;;
  "pr merge")
    case "$*" in *--match-head-commit*) [ -z "${HEAD_MOVED:-}" ] || exit 1 ;; esac
    case "$3" in 3) [ -z "${CO_MERGE_FAIL:-}" ] || exit 1 ;; esac
    case "${BEHIND:-}" in
      start) [ -e "$FAKE_LOG.updated" ] || exit 1 ;;
      late) [ -e "$FAKE_LOG.tried" ] || { touch "$FAKE_LOG.tried"; exit 1; } ;;
      always) exit 1 ;;
    esac
    exit 0 ;;
esac
EOF
printf '#!/bin/sh\nexit 0\n' > "$FAKE_BIN/sleep"
cp "$FAKE_BIN/sleep" "$FAKE_BIN/osascript"
chmod +x "$FAKE_BIN"/*

with_land() {
  mkdir -p scripts/harness
  cp "$HOME_DIR/core/land" scripts/harness/land
  chmod +x scripts/harness/land
  cp "$HOME_DIR/test/fixtures/config.sh" scripts/harness/config.sh
  git remote add origin git@github.com:me/app.git
}

# run land with $LAND_ENV (space-separated VAR=value) on top of the fake gh,
# capturing stdout+stderr in $OUT, the exit code in $RC and gh's calls in $LOG.
# land reads config.sh from the default branch as origin has it, so the config a
# test wrote is first committed to master and origin/HEAD pointed at it, as a
# clone would have it - unless BRANCH_ONLY is set, which leaves it in the working
# tree the way a branch that edited it would. --no-verify: no hook is installed
# here, and one inherited from the machine's git config is not what is under test.
landing() {
  if [ -z "${BRANCH_ONLY:-}" ]; then
    git add scripts/harness/config.sh && git commit -qm config --no-verify --allow-empty
    git update-ref refs/remotes/origin/master HEAD
    git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/master
  fi
  : > "$R/gh.log"; rm -f "$R/gh.log.n" "$R/gh.log.updated" "$R/gh.log.tried" "$R/gh.log.reads" "$R/gh.log.moved"
  set +e
  OUT=$(env GH_TOKEN= $LAND_ENV FAKE_LOG="$R/gh.log" PATH="$FAKE_BIN:$PATH" \
    sh scripts/harness/land "$@" 2>&1)
  RC=$?
  set -e
  LOG=$(cat "$R/gh.log")
}

new_repo; with_land
LAND_ENV=""
landing
assert_eq "refuses to run without a pull request" "$RC" 2
assert_has "and says how it is called" "$OUT" "usage: scripts/harness/land [--owner] <pr>"
landing 7 site#3
assert_eq "refuses a companion that names no repository" "$RC" 2
landing 7 me/site#x
assert_eq "and one whose number is not a number" "$RC" 2
landing 7 me/site#3 me/other#4
assert_eq "refuses more than one companion" "$RC" 2
landing 7 me/app#7
assert_eq "refuses the pull request as its own companion" "$RC" 2
landing 7 ME/App#7
assert_eq "however it is capitalised" "$RC" 2

landing 7
assert_eq "lands a green pull request" "$RC" 0
assert_has "merging exactly the commit that went green" "$LOG" \
  "pr merge 7 -R me/app --merge --match-head-commit abcdef0123456789"
assert_has "and says so" "$OUT" "merged me/app#7"
assert_has "having waited on its checks" "$LOG" "pr checks 7 -R me/app --watch"

assert_has "deletes the merged branch" "$LOG" "api -X DELETE repos/me/app/git/refs/heads/feature"

# GitHub closes an open pull request whose base branch is deleted - it does not
# retarget it - so a stacked pull request is moved down before its base goes.
LAND_ENV="CHILDREN=8,9"
landing 7
assert_eq "lands the bottom of a stack" "$RC" 0
assert_has "moving the pull requests stacked on it onto its base" "$LOG" "api -X PATCH repos/me/app/pulls/8 -f base=master"
assert_has "every one of them" "$LOG" "api -X PATCH repos/me/app/pulls/9 -f base=master"
edit_at=$(grep -n "pulls/9 -f base=master" "$R/gh.log" | cut -d: -f1)
del_at=$(grep -n "api -X DELETE" "$R/gh.log" | cut -d: -f1)
assert_eq "before deleting the branch they were based on" \
  "$([ -n "$edit_at" ] && [ -n "$del_at" ] && [ "$edit_at" -lt "$del_at" ] && echo yes)" "yes"
LAND_ENV="CHILDREN=8 EDIT_FAIL=1"
landing 7
assert_eq "still lands when a stacked pull request cannot be moved" "$RC" 0
assert_no "but keeps the branch it depends on" "$LOG" "api -X DELETE"
assert_has "and says what to do" "$OUT" "kept branch feature, still the base of #8"
LAND_ENV="LIST_FAIL=1"
landing 7
assert_no "and keeps it when it cannot tell what depends on it" "$LOG" "api -X DELETE"
# A repository that deletes merged branches itself retargets what was stacked on
# them too, racing land's own move - which then fails although #8 is already on
# master and the branch is gone. That is a move, not a pull request left behind.
LAND_ENV="CHILDREN=8 EDIT_FAIL=1 CHILD_BASE=master DELETE_FAIL=1 REF_GONE=1"
landing 7
assert_eq "lands when GitHub moved the stacked pull request first" "$RC" 0
assert_has "reading where it points after the move failed" "$LOG" "pr view 8 -R me/app --json baseRefName"
assert_no "and does not claim it kept a branch that is gone" "$OUT" "kept branch"
assert_has "counting it as moved" "$OUT" "moved #8 onto master"
assert_no "nor that the delete failed" "$OUT" "could not delete"

# A repository that merges only branches that are up to date refuses a pull request
# whose base moved - before the wait, or during it, when another one lands first.
# land brings it up to date, and the update is a new head: pinned and tested again.
LAND_ENV="BEHIND=start"
landing 7
assert_eq "lands a pull request that is behind its base" "$RC" 0
assert_has "after bringing it up to date" "$LOG" "api -X PUT repos/me/app/pulls/7/update-branch -f expected_head_sha=abcdef0123456789"
assert_has "and saying why" "$OUT" "merges only branches that are up to date"
assert_has "pinned to the head the update produced" "$LOG" "pr merge 7 -R me/app --merge --match-head-commit 1234567890abcde1"
up_at=$(grep -n "pulls/7/update-branch" "$R/gh.log" | head -1 | cut -d: -f1)
# The fake's checks do not know which sha they are for, so "CI for the new head"
# is proven by order: the first watch comes after the update.
watch_at=$(grep -n "pr checks 7 -R me/app --watch" "$R/gh.log" | head -1 | cut -d: -f1)
assert_eq "whose CI it waited for" \
  "$([ -n "$up_at" ] && [ -n "$watch_at" ] && [ "$up_at" -lt "$watch_at" ] && echo yes)" "yes"
LAND_ENV="BEHIND=start HEAD_LAG=1"
landing 7
assert_eq "waits for the updated head to appear before pinning it" "$RC" 0
assert_has "and pins the new one, not the one read too early" "$LOG" "--match-head-commit 1234567890abcde1"
LAND_ENV="BEHIND=late"
landing 7
assert_eq "lands one that fell behind while its CI ran" "$RC" 0
assert_has "updating it after the refused merge" "$LOG" "api -X PUT repos/me/app/pulls/7/update-branch -f expected_head_sha=abcdef0123456789"
assert_has "and merging the updated head" "$LOG" "--match-head-commit 1234567890abcde1"
LAND_ENV="BEHIND=always"
landing 7
assert_eq "gives up on a base that never stops moving" "$RC" 1
assert_has "saying so" "$OUT" "still behind its base"
assert_eq "after three updates" "$(grep -c "pulls/7/update-branch" "$R/gh.log")" "3"
LAND_ENV="BEHIND=start UPDATE_FAIL=1"
landing 7
assert_eq "refuses when it cannot bring the pull request up to date" "$RC" 1
assert_has "and says so" "$OUT" "could not bring me/app#7 up to date"
assert_no "merging nothing" "$LOG" "pr merge"
LAND_ENV="HEAD_MOVED=1"
landing 7
assert_no "a refused merge does not guess at the reason" "$OUT" "a push after the checks passed?"

# A repository that deletes merged branches itself leaves nothing for land to
# delete; that is not a failure worth reporting.
LAND_ENV="DELETE_FAIL=1 REF_GONE=1"
landing 7
assert_eq "lands when GitHub already deleted the branch" "$RC" 0
assert_no "without claiming it could not delete it" "$OUT" "could not delete"
LAND_ENV="DELETE_FAIL=1"
landing 7
assert_has "but says so when the branch is really still there" "$OUT" "could not delete branch feature"
LAND_ENV="DELETE_FAIL=1 REF_FORBIDDEN=1"
landing 7
assert_has "or when it cannot tell, rather than reading an error as gone" "$OUT" "could not delete branch feature"

LAND_ENV="CHECKS=late"
landing 7
assert_eq "lands once a check that appeared after the first green is green too" "$RC" 0
assert_eq "watching again for it rather than merging on the first green" \
  "$(grep -c "pr checks 7 -R me/app --watch" "$R/gh.log")" "2"

LAND_ENV="HEAD_SHA="
landing 7
assert_eq "refuses when the head commit cannot be read" "$RC" 1
assert_no "rather than merging unpinned" "$LOG" "pr merge"

LAND_ENV="MAIN_STATE=MERGED"
landing 7
assert_eq "refuses a pull request that is not open" "$RC" 1
assert_has "saying which one" "$OUT" "me/app#7 is not open"
assert_no "and merges nothing" "$LOG" "pr merge"

LAND_ENV="CO_STATE=CLOSED"
landing 7 me/site#3
assert_eq "refuses when the companion is not open" "$RC" 1
assert_no "before merging either of them" "$LOG" "pr merge"

LAND_ENV="MAIN_MERGEABLE=CONFLICTING"
landing 7
assert_eq "refuses a pull request that conflicts with its base" "$RC" 1
assert_has "and says what to do about it" "$OUT" "bring the base branch into it first"
# A conflicting pull request gets no CI run, so waiting for one would wait forever.
assert_no "without waiting for a CI that will never run" "$LOG" "pr checks"
assert_no "and merges nothing" "$LOG" "pr merge"

LAND_ENV="MAIN_MERGEABLE=UNKNOWN"
landing 7
assert_eq "refuses when GitHub never settles whether it merges" "$RC" 1
assert_no "and merges nothing then either" "$LOG" "pr merge"

LAND_ENV="CHECKS=fail"
landing 7
assert_eq "refuses on red CI" "$RC" 1
assert_no "deleting no branch either" "$LOG" "api -X DELETE"
assert_has "saying nothing was merged" "$OUT" "CI is not green on me/app#7 - nothing merged"
assert_no "and merging nothing" "$LOG" "pr merge"

LAND_ENV="CHECKS=none"
landing 7
assert_eq "refuses a pull request that never gets checks" "$RC" 1
assert_no "rather than merging it untested" "$LOG" "pr merge"
# Told apart from red CI: "not green" sent agents looking for a failure on a
# documentation pull request whose checks were never going to come.
assert_has "saying no checks appeared" "$OUT" "no checks appeared on me/app#7 in two minutes - nothing merged"
assert_has "and where the paths CI skips belong" "$OUT" "HARNESS_LAND_NO_CI"
assert_no "not that CI is red" "$OUT" "CI is not green"

LAND_ENV="CHECKS=pending"
landing 7
assert_eq "refuses checks that are still pending when the watch gives up" "$RC" 1

LAND_ENV="HEAD_MOVED=1"
landing 7
assert_eq "refuses when the head moved after the checks passed" "$RC" 1
assert_has "and says nothing was merged" "$OUT" "nothing merged"

LAND_ENV=""
landing 7 me/site#3
assert_eq "lands the companion after the pull request" "$RC" 0
assert_no "saying nothing about a method it shares" "$OUT" "will merge with"
assert_has "pinned to the head it had when land started" "$LOG" \
  "pr merge 3 -R me/site --merge --match-head-commit abcdef0123456789"
main_at=$(grep -n "pr merge 7 " "$R/gh.log" | cut -d: -f1)
co_at=$(grep -n "pr merge 3 -R me/site" "$R/gh.log" | cut -d: -f1)
assert_eq "in that order" "$([ -n "$main_at" ] && [ -n "$co_at" ] && [ "$main_at" -lt "$co_at" ] && echo yes)" "yes"

# The companion's repository decides how it merges: a documentation site that keeps
# a linear history refuses the merge commit this project lands with.
LAND_ENV="CO_RULED=squash"
landing 7 me/site#3
assert_eq "lands a companion whose rules refuse a merge commit" "$RC" 0
assert_has "with a method its rules take" "$LOG" "pr merge 3 -R me/site --squash --match-head-commit abcdef0123456789"
assert_has "while the pull request keeps the project's own" "$LOG" "pr merge 7 -R me/app --merge"
assert_has "and says which method the companion gets" "$OUT" "me/site does not take merge - me/site#3 will merge with squash"
LAND_ENV="CO_ALLOWED=squash"
landing 7 me/site#3
assert_has "and a method its repository allows" "$LOG" "pr merge 3 -R me/site --squash"
echo 'HARNESS_LAND_METHOD=rebase' >> scripts/harness/config.sh
LAND_ENV="CO_ALLOWED=merge"
landing 7 me/site#3
assert_has "falling back to merge when that is all it takes" "$LOG" "pr merge 3 -R me/site --merge"
LAND_ENV=""
landing 7 me/site#3
assert_has "and taking the project's method when it can" "$LOG" "pr merge 3 -R me/site --rebase"
sed -i.bak '/HARNESS_LAND_METHOD/d' scripts/harness/config.sh
LAND_ENV="CO_RULES_FAIL=1"
landing 7 me/site#3
assert_eq "reads rules it cannot get as no rules" "$RC" 0
assert_has "and merges with the project's method" "$LOG" "pr merge 3 -R me/site --merge"
LAND_ENV="CO_ALLOWED=merge CO_RULED=squash"
landing 7 me/site#3
assert_eq "refuses a companion no method can merge" "$RC" 1
assert_has "saying so" "$OUT" "me/site takes none of merge, squash or rebase"
assert_no "before merging either of them" "$LOG" "pr merge"
LAND_ENV="CO_REPO_FAIL=1"
landing 7 me/site#3
assert_eq "refuses when it cannot read how the companion merges" "$RC" 1
assert_no "before merging either of them, too" "$LOG" "pr merge"
LAND_ENV="CO_MERGE_FAIL=1"
landing 7 me/site#3
assert_eq "stops when GitHub refuses the companion" "$RC" 1
assert_has "saying which half merged" "$OUT" "me/app#7 merged, but GitHub refused to merge me/site#3"
assert_no "without guessing why" "$OUT" "a push to it"

LAND_ENV="CO_MERGEABLE=CONFLICTING"
landing 7 me/site#3
assert_eq "stops when the companion conflicts" "$RC" 1
assert_has "saying the first one merged and the second did not" "$OUT" "me/app#7 merged, but me/site#3 does not merge cleanly"
assert_no "and leaving the companion alone" "$LOG" "pr merge 3"

# The paths CI ignores are the project's to name: without them, every pull request
# waits for checks, and a docs-only one would wait for checks that never come.
# The patterns are GitHub's paths-ignore syntax, not the shell's: ** crosses a
# directory and * does not. Read the shell's way, *.md would skip the wait for a
# src/README.md that GitHub does run CI for.
echo 'HARNESS_LAND_NO_CI="docs/** *.md"' >> scripts/harness/config.sh
LAND_ENV="CHECKS=none FILES=docs/guide/a.md,README.md"
landing 7
assert_eq "lands a pull request that only touches paths CI does not run on" "$RC" 0
assert_no "without waiting for checks it will never get" "$LOG" "pr checks"
assert_has "and says why" "$OUT" "no checks to wait for"
LAND_ENV="CHECKS=none FILES=docs/a.md,src/b.ts"
landing 7
assert_eq "but one file outside them is enough to wait for CI" "$RC" 1
assert_no "and not to merge without it" "$LOG" "pr merge"
LAND_ENV="CHECKS=none FILES=src/README.md"
landing 7
assert_eq "a single * does not cross a directory, as in GitHub's paths-ignore" "$RC" 1
assert_no "so that file waits for CI" "$LOG" "pr merge"
LAND_ENV="CHECKS=none FILES_FAIL=1"
landing 7
assert_eq "refuses when the files cannot be listed" "$RC" 1
assert_has "saying so" "$OUT" "could not list the files of me/app#7"
assert_no "instead of reading the silence as nothing CI runs on" "$LOG" "pr merge"
LAND_ENV="CHECKS=none FILES="
landing 7
assert_eq "an empty file list waits for CI like any other" "$RC" 1
assert_no "and merges nothing without it" "$LOG" "pr merge"
touch README.md docs.md
LAND_ENV="CHECKS=none FILES=other.md"
landing 7
assert_eq "the patterns are not expanded against the working tree" "$RC" 0
for bad in '[' 'a\\'; do
  sed -i.bak '/HARNESS_LAND_NO_CI/d' scripts/harness/config.sh
  echo "HARNESS_LAND_NO_CI='$bad'" >> scripts/harness/config.sh
  LAND_ENV="CHECKS=none FILES=src/a.ts"
  landing 7
  assert_eq "refuses a pattern that cannot be read: $bad" "$RC" 1
  assert_no "instead of reading it as nothing CI runs on: $bad" "$LOG" "pr merge"
done
echo 'HARNESS_LAND_NO_CI="docs/** !docs/api/**"' >> scripts/harness/config.sh
LAND_ENV=""
landing 7
assert_eq "refuses a negation it cannot honour" "$RC" 2
assert_no "before asking GitHub anything" "$LOG" "pr "
sed -i.bak '/HARNESS_LAND_NO_CI/d' scripts/harness/config.sh

# The branch being merged cannot loosen how it is merged. config.sh is read from
# the default branch as origin has it, as --landing reads who may merge: read from
# the working tree, a branch could add ** here and skip its own CI.
landing 7
echo 'HARNESS_LAND_NO_CI="**"' >> scripts/harness/config.sh
LAND_ENV="CHECKS=none FILES=src/a.ts" BRANCH_ONLY=1
landing 7
assert_eq "a branch that marks every path as CI-free still waits for CI" "$RC" 1
assert_no "and merges nothing without it" "$LOG" "pr merge"
echo 'HARNESS_LAND_METHOD=fast-forward' >> scripts/harness/config.sh
LAND_ENV=""
landing 7
assert_eq "a method set only on the branch does not reach land either" "$RC" 0
assert_has "which merges the way the default branch says" "$LOG" "pr merge 7 -R me/app --merge "
git symbolic-ref -d refs/remotes/origin/HEAD
git update-ref -d refs/remotes/origin/master
sed -i.bak '/HARNESS_LAND_METHOD/d' scripts/harness/config.sh
echo 'HARNESS_LAND_METHOD=squash' >> scripts/harness/config.sh
landing 7
assert_eq "with no default branch on origin it still lands" "$RC" 0
assert_has "with the defaults, not the working tree's config" "$LOG" "pr merge 7 -R me/app --merge "
assert_has "and says so" "$OUT" "landing with the defaults"
assert_has "naming how to give origin a default branch" "$OUT" "git remote set-head origin -a"
BRANCH_ONLY=
git checkout -q scripts/harness/config.sh

# Under Landing: agent the change, not its author, says whether an agent may land
# it. The harness's own paths, the project's HARNESS_LAND_OWNER_PATHS, and a floor
# guard that finds the bar lowered - or cannot look - make it the owner's.
mkdir -p docs/harness
printf '# Loop\n\n### Landing\n\nLanding: agent\n' > docs/harness/mandatory-steps.md
printf '#!/bin/sh\necho "floor stub $*"\nexit ${FLOOR_RC:-0}\n' > scripts/harness/verify
chmod +x scripts/harness/verify
git add docs/harness/mandatory-steps.md scripts/harness/verify
LAND_ENV="HEAD_SHA=local"
landing 7
assert_eq "an agent lands a pull request with nothing of the owner's in it" "$RC" 0
assert_has "once the floor guard looked at it" "$OUT" "floor stub --floor"
LAND_ENV="HEAD_SHA=local FILES=src/ci.yml PREV=.github/workflows/ci.yml"
landing 7
assert_eq "a file renamed out of an owner path is the owner's" "$RC" 1
assert_has "by its old name" "$OUT" "it touches .github/workflows/ci.yml"
LAND_ENV="HEAD_SHA=local FILES=.GitHub/workflows/ci.yml"
landing 7
assert_eq "an owner path in another case is the owner's: a macOS checkout is case-insensitive" "$RC" 1
LAND_ENV="HEAD_SHA=local CHANGED_FILES=3000"
landing 7
assert_eq "so is a pull request with more files than GitHub lists" "$RC" 1
assert_has "saying so" "$OUT" "it changes 3000 files, more than GitHub lists"
LAND_ENV="HEAD_SHA=local CHANGED_FILES=x"
landing 7
assert_eq "and one whose file count cannot be read" "$RC" 1
LAND_ENV="HEAD_SHA=local CO_FILES=.github/workflows/deploy.yml"
landing 7 me/site#3
assert_eq "a companion touching the harness's paths is the owner's" "$RC" 1
assert_has "named as the one that is" "$OUT" "me/site#3 is the owner's to land: it touches .github/workflows/deploy.yml"
assert_no "and nothing merged, the first one included" "$LOG" "pr merge"
LAND_ENV="HEAD_SHA=local"
landing 7 me/site#3
assert_eq "a clean one lands with it" "$RC" 0
LAND_ENV="HEAD_SHA=local BEHIND=start"
landing 7
assert_eq "an agent lands a checked pull request brought up to date" "$RC" 0
assert_has "pinned to the update" "$LOG" "--match-head-commit 1234567890abcde1"
LAND_ENV="HEAD_SHA=local BEHIND=start UPDATE_PARENTS=0000000000000000,0123456789fedcba"
landing 7
assert_eq "but not a head that moved beyond the update" "$RC" 1
assert_has "saying so" "$OUT" "moved beyond its update"
assert_no "and merging nothing" "$LOG" "pr merge"
# and what tells an agent what to do or what it may reach: its instructions, its
# settings, its MCP servers - for every agent the harness runs with
for f in scripts/harness/verify .githooks/pre-commit docs/harness/mandatory-steps.md \
  .agents/skills/run-task/SKILL.md .agents/rules.md .github/workflows/ci.yml \
  .claude/settings.json AGENTS.md CLAUDE.md packages/app/CLAUDE.md .mcp.json \
  .codex/config.toml .opencode/agent/review.md opencode.json opencode.jsonc \
  .pi/settings.json .cursor/mcp.json .vscode/mcp.json AGENTS.override.md \
  CLAUDE.local.md packages/app/.mcp.json packages/app/.claude/settings.json \
  packages/app/.agents/skills/x/SKILL.md packages/app/.codex/config.toml \
  GEMINI.md packages/app/GEMINI.md .cursor/rules/style.mdc .github/copilot-instructions.md; do
  LAND_ENV="HEAD_SHA=local FILES=src/a.ts,$f"
  landing 7
  assert_eq "refuses an agent a pull request touching $f" "$RC" 1
  assert_has "saying it is the owner's: $f" "$OUT" "me/app#7 is the owner's to land: it touches $f, an owner path"
  assert_no "and merging nothing: $f" "$LOG" "pr merge"
done
assert_has "naming the command the owner lands it with" "$OUT" "scripts/harness/land --owner 7"
for f in src/agents.ts docs/CLAUDE.md.txt .vscode/settings.json; do
  LAND_ENV="HEAD_SHA=local FILES=$f"
  landing 7
  assert_eq "a name that only resembles one is the agent's: $f" "$RC" 0
done
LAND_ENV="HEAD_SHA=local FILES=.github/workflows/ci.yml"
landing --owner 7
assert_eq "which lands it" "$RC" 0
assert_has "merged" "$LOG" "pr merge 7 -R me/app --merge"
landing --owner 7 me/site#3
assert_eq "with its companion" "$RC" 0
LAND_ENV="HEAD_SHA=local FILES=.github/workflows/ci.yml"
landing 7 me/site#3
assert_has "and the command it names keeps the companion" "$OUT" "scripts/harness/land --owner 7 me/site#3"
echo 'HARNESS_LAND_OWNER_PATHS="db/migrations/** *.sql"' >> scripts/harness/config.sh
LAND_ENV="HEAD_SHA=local FILES=src/a.ts,db/migrations/0042/users.rb"
landing 7
assert_eq "a path in HARNESS_LAND_OWNER_PATHS is the owner's too" "$RC" 1
assert_has "and named" "$OUT" "it touches db/migrations/0042/users.rb"
LAND_ENV="HEAD_SHA=local FILES=schema.sql"
landing 7
assert_eq "read in GitHub's syntax" "$RC" 1
LAND_ENV="HEAD_SHA=local FILES=src/schema.sql"
landing 7
assert_eq "where a single * does not cross a directory" "$RC" 0
LAND_ENV="HEAD_SHA=local FILES=.github/workflows/ci.yml"
landing 7
assert_eq "and the project's list adds to the harness's, never replaces it" "$RC" 1
sed -i.bak '/HARNESS_LAND_OWNER_PATHS/d' scripts/harness/config.sh
echo "HARNESS_LAND_OWNER_PATHS='['" >> scripts/harness/config.sh
LAND_ENV="HEAD_SHA=local"
landing 7
assert_eq "a pattern that cannot be read is the owner's" "$RC" 1
assert_has "saying which setting" "$OUT" "HARNESS_LAND_OWNER_PATHS holds a pattern that cannot be read"
sed -i.bak '/HARNESS_LAND_OWNER_PATHS/d' scripts/harness/config.sh
echo 'HARNESS_LAND_OWNER_PATHS="db/** !db/seeds/**"' >> scripts/harness/config.sh
landing 7
assert_eq "refuses a negation in HARNESS_LAND_OWNER_PATHS" "$RC" 2
assert_no "before asking GitHub anything" "$LOG" "pr "
sed -i.bak '/HARNESS_LAND_OWNER_PATHS/d' scripts/harness/config.sh
LAND_ENV="HEAD_SHA=local FLOOR_RC=1"
landing 7
assert_eq "a floor guard that finds the bar lowered makes it the owner's" "$RC" 1
assert_has "saying so" "$OUT" "the floor guard found the bar lowered"
assert_no "and merging nothing" "$LOG" "pr merge"
LAND_ENV="HEAD_SHA=local FLOOR_RC=2"
landing 7
assert_eq "so does one that could not check" "$RC" 1
assert_has "said apart" "$OUT" "the floor guard could not check it"
LAND_ENV=""
landing 7
assert_eq "a checkout that is not the pull request cannot have its floor checked" "$RC" 1
assert_has "and says which commit it is not at" "$OUT" "this checkout is not at abcdef0"
assert_no "without running the guard on the wrong code" "$OUT" "floor stub"
LAND_ENV="HEAD_SHA=local FILES_FAIL=1"
landing 7
assert_eq "files that cannot be listed are the owner's" "$RC" 1
assert_has "saying so" "$OUT" "its files could not be listed"
LAND_ENV="HEAD_SHA=local FILES="
landing 7
assert_eq "so is a file list that came back empty" "$RC" 1
LAND_ENV="HEAD_SHA=moving"
landing 7
assert_eq "a head that moved while its files were read refuses" "$RC" 1
assert_has "saying so" "$OUT" "moved while its files were read"
assert_no "and merges nothing" "$LOG" "pr merge"
rm scripts/harness/verify
LAND_ENV="HEAD_SHA=local"
landing 7
assert_eq "no gate to check the floor with is the owner's" "$RC" 1

# --landing <pr> answers the same question before land is run, from the same rules.
asking() {
  : > "$R/gh.log"; rm -f "$R/gh.log.moved"
  set +e
  OUT=$(env GH_TOKEN= $LAND_ENV FAKE_LOG="$R/gh.log" PATH="$FAKE_BIN:$PATH" \
    sh scripts/harness/land --landing "$@" 2>"$R/ask.err"); RC=$?
  ERR=$(cat "$R/ask.err"); LOG=$(cat "$R/gh.log")
  set -e
}
git checkout -q scripts/harness/verify
LAND_ENV="HEAD_SHA=local"
asking 7
assert_eq "--landing <pr> prints agent for a pull request an agent may land" "$OUT" "agent"
assert_eq "and exits 0" "$RC" 0
LAND_ENV="HEAD_SHA=local FILES=.githooks/pre-commit"
asking 7
assert_eq "and owner for one that is the owner's" "$OUT" "owner"
assert_has "saying why" "$ERR" "it touches .githooks/pre-commit, an owner path"
assert_eq "still exiting 0" "$RC" 0
asking 7 8
assert_eq "it takes one pull request at most" "$RC" 2
git rm -q docs/harness/mandatory-steps.md
LAND_ENV="HEAD_SHA=local FILES=.github/workflows/ci.yml"
landing 7
assert_eq "under Landing: owner land merges what it is given, as before" "$RC" 0
asking 7
assert_eq "and --landing <pr> is owner" "$OUT" "owner"
assert_no "without asking GitHub" "$LOG" "pr view"

# A review's verdict lives on the commit it vouches for: land --review <pr>
# blocking=<n> unresolved=<n> posts norma/review on the pull request's head, and
# only from a checkout at that head with nothing uncommitted - the code reviewed.
LAND_ENV="HEAD_SHA=local"
landing --review 7 blocking=0 unresolved=0
assert_eq "posts a review verdict" "$RC" 0
assert_has "as norma/review success on the head" "$LOG" \
  "api -X POST repos/me/app/statuses/$(git rev-parse HEAD) -f state=success -f context=norma/review -f description=blocking=0 unresolved=0"
assert_has "and says so" "$OUT" "norma/review success on"
landing --review 7 unresolved=0 blocking=1
assert_has "failure when anything blocks, in either order" "$LOG" "-f state=failure -f context=norma/review -f description=blocking=1 unresolved=0"
landing --review 7 blocking=0 unresolved=2
assert_has "or anything is unresolved" "$LOG" "-f state=failure"
LAND_ENV=""
landing --review 7 blocking=0 unresolved=0
assert_eq "refuses from a checkout that is not the pull request" "$RC" 1
assert_has "saying so" "$OUT" "this checkout is not at the head of me/app#7"
assert_no "and posts nothing" "$LOG" "statuses"
LAND_ENV="HEAD_SHA=local"
echo dirty >> README.md
landing --review 7 blocking=0 unresolved=0
assert_eq "refuses with uncommitted changes" "$RC" 1
assert_has "saying so" "$OUT" "uncommitted changes"
assert_no "posting nothing" "$LOG" "statuses"
git checkout -q README.md
# BRANCH_ONLY: landing would otherwise commit what is staged along with the config
echo staged >> README.md; git add README.md
BRANCH_ONLY=1
landing --review 7 blocking=0 unresolved=0
assert_eq "and with staged ones" "$RC" 1
BRANCH_ONLY=
git reset -q README.md; git checkout -q README.md
landing --review 7 blocking=00 unresolved=0
assert_has "reads counts as numbers, not strings" "$LOG" "-f state=success"
for bad in "7 blocking=0" "7 blocking=0 unresolved=x" "7 blocking=0 verdict=ok" \
  "x blocking=0 unresolved=0" "7 blocking= unresolved=0" "7 blocking=0 unresolved=0 x"; do
  landing --review $bad
  assert_eq "refuses a malformed verdict: $bad" "$RC" 2
done
LAND_ENV="HEAD_SHA=local STATUS_FAIL=1"
landing --review 7 blocking=0 unresolved=0
assert_eq "says when the verdict could not be posted" "$RC" 1
assert_has "in so many words" "$OUT" "could not post norma/review"

# HARNESS_LAND_REVIEW=required: land merges only a head with a passing verdict on it,
# whoever runs it.
echo 'HARNESS_LAND_REVIEW=required' >> scripts/harness/config.sh
LAND_ENV=""
landing 7
assert_eq "a project that requires a review refuses a head without one" "$RC" 1
assert_has "saying which head" "$OUT" "me/app#7 has no norma/review on abcdef0"
assert_has "and how to give it one" "$OUT" "scripts/harness/land --review 7 blocking=<n> unresolved=<n>"
assert_no "merging nothing" "$LOG" "pr merge"
assert_no "and not waiting for CI first" "$LOG" "pr checks"
LAND_ENV="REVIEW=failure REVIEW_DESC=blocking=1,unresolved=0"
landing 7
assert_eq "and a head whose review failed" "$RC" 1
assert_has "saying what it said" "$OUT" "norma/review on me/app#7 is failure (blocking=1 unresolved=0) at abcdef0"
LAND_ENV="REVIEW=success"
landing 7
assert_eq "it lands a head with a passing review" "$RC" 0
LAND_ENV="REVIEW=success BEHIND=start"
landing 7
assert_eq "and one it brought up to date after the review" "$RC" 0
LAND_ENV="REVIEW=success BEHIND=start UPDATE_PARENTS=0000000000000000,0123456789fedcba"
landing 7
assert_eq "but not one that moved beyond the update" "$RC" 1
assert_has "saying so" "$OUT" "moved beyond its update"
LAND_ENV="REVIEW=success BEHIND=start UPDATE_PARENTS=abcdef0123456789"
landing 7
assert_eq "nor a plain commit on top of the reviewed head" "$RC" 1
LAND_ENV="REVIEW=success BEHIND=start COMPARE=diverged"
landing 7
assert_eq "nor a merge of something that is not on the base" "$RC" 1
assert_no "merging nothing" "$LOG" "pr merge"
assert_has "asking only for the review status's first hundred contexts" "$LOG" "status?per_page=100"
assert_has "selecting norma/review from them" "$LOG" 'select(.context == "norma/review")'

LAND_ENV=""
landing --owner 7
assert_eq "--owner does not stand in for a review" "$RC" 1
LAND_ENV="REVIEW_FAIL=1"
landing 7
assert_eq "a review status that cannot be read refuses" "$RC" 1
assert_has "saying so" "$OUT" "could not read the review status of me/app#7"
sed -i.bak '/HARNESS_LAND_REVIEW/d' scripts/harness/config.sh
LAND_ENV=""
landing 7
assert_eq "without the setting, no review is asked for" "$RC" 0
echo 'HARNESS_LAND_REVIEW=yes' >> scripts/harness/config.sh
landing 7
assert_eq "refuses a value it does not know" "$RC" 2
assert_no "before asking GitHub anything" "$LOG" "pr "
sed -i.bak '/HARNESS_LAND_REVIEW/d' scripts/harness/config.sh

echo 'HARNESS_LAND_METHOD=squash' >> scripts/harness/config.sh
LAND_ENV=""
landing 7
assert_has "merges with the method the project configured" "$LOG" "pr merge 7 -R me/app --squash"
echo 'HARNESS_LAND_METHOD=fast-forward' >> scripts/harness/config.sh
landing 7
assert_eq "refuses a method gh does not have" "$RC" 2
assert_no "before touching GitHub" "$LOG" "pr "

# A machine with a work and a personal gh account: the active one may not see the
# repository, and the one named like its owner does.
sed -i.bak '/HARNESS_LAND_METHOD/d' scripts/harness/config.sh
LAND_ENV="FAKE_TOKEN=personal"
landing 7
assert_has "asks gh for the account named like the owner" "$LOG" "auth token --user me"
assert_has "and uses its token" "$LOG" "pr merge 7 -R me/app --merge --match-head-commit abcdef0123456789 token=personal"
LAND_ENV="FAKE_TOKEN=personal FAKE_ACCOUNT=somebody-else"
landing 7
assert_has "and leaves gh's own choice when there is no such account" "$LOG" "pr merge 7 -R me/app --merge --match-head-commit abcdef0123456789 token=none"
LAND_ENV="FAKE_TOKEN=personal GH_TOKEN=given"
landing 7
assert_has "but never overrides a token it was given" "$LOG" "token=given"
LAND_ENV="FAKE_TOKEN=personal GITHUB_TOKEN=given"
landing 7
assert_no "in either of the variables gh reads" "$LOG" "auth token"
git remote set-url origin https://github.com/me/app.git/
LAND_ENV=""
landing 7
assert_has "reads the repository from a remote with a trailing slash" "$LOG" "pr merge 7 -R me/app "
done_repo
rm -rf "$FAKE_BIN"

# Who lands is read by this, not by an agent interpreting the loop's prose at the
# moment it wants to merge. Only one exact line says agent; every doubt is owner.
# And it is read from the default branch as origin has it: the branch asking to be
# merged is the one place that cannot be trusted to say who may merge it.
new_repo; with_land
who() {
  set +e
  OUT=$(sh scripts/harness/land --landing 2>"$R/who.err"); RC=$?
  ERR=$(cat "$R/who.err")
  set -e
}
# commits the loop to master and points origin/HEAD at it, as a clone would
landing_doc() {
  mkdir -p docs/harness
  printf '# Loop\n\n%b\n' "$1" > docs/harness/mandatory-steps.md
  git add docs/harness/mandatory-steps.md && git commit -qm loop --no-verify
  git update-ref refs/remotes/origin/master HEAD
  git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/master
}
who
assert_eq "--landing reads a repository with no default branch on origin as owner" "$OUT" "owner"
assert_has "and says how to give it one" "$ERR" "git remote set-head origin -a"
landing_doc 'No such section here.'; who
assert_eq "reads a loop without the section as owner" "$OUT" "owner"
landing_doc '### Landing\n\nLanding: owner'; who
assert_eq "reads Landing: owner as owner" "$OUT" "owner"
assert_eq "without complaint" "$ERR" ""
landing_doc '### Landing\n\nLanding: agent\n\nWho merges.'; who
assert_eq "reads exactly Landing: agent under the heading as agent" "$OUT" "agent"
assert_eq "and exits 0 either way" "$RC" "0"
landing_doc '### Landing\n\nLanding: agent\r'; who
assert_eq "a file saved with CRLF endings reads the same" "$OUT" "agent"
for odd in 'Landing: Agent' 'Landing: agent # maybe' 'Landing: agent ' 'Landing:agent' 'Landing: agents' 'Who merges.'; do
  landing_doc "### Landing\n\n$odd"; who
  assert_eq "reads '$odd' as owner" "$OUT" "owner"
  assert_has "and says it could not read it: '$odd'" "$ERR" "cannot read"
done
landing_doc '### Landing\n\nLanding: agent\n\n### Landing\n\nLanding: agent'; who
assert_eq "reads two Landing sections as owner, even when both say agent" "$OUT" "owner"
assert_has "and says why" "$ERR" "2 Landing sections"
landing_doc 'Landing: agent\n\n### Landing\n\nLanding: owner'; who
assert_eq "a Landing line anywhere but under the heading counts for nothing" "$OUT" "owner"
landing_doc '### Landing\n\nLanding: owner\n\n```\nLanding: agent\n```'; who
assert_eq "nor does one further down the section" "$OUT" "owner"
landing_doc '### Landing\n\nLanding: owner'
git switch -q -c feature
printf '### Landing\n\nLanding: agent\n' > docs/harness/mandatory-steps.md
git commit -qam "grant myself the merge" --no-verify
who
assert_eq "a branch that rewrites the line does not grant itself the merge" "$OUT" "owner"
assert_has "and is told the default branch decides" "$ERR" "origin/master decides"
git switch -q master
landing_doc '### Landing\n\nLanding: agent'
git switch -q feature
git checkout -q master -- docs/harness/mandatory-steps.md
printf '### Landing\n\nLanding: owner\n' > docs/harness/mandatory-steps.md
who
assert_eq "and the default branch's agent stands while the branch says otherwise" "$OUT" "agent"
set +e; OUT=$(sh scripts/harness/land --landing extra 2>&1); RC=$?; set -e
assert_eq "--landing takes nothing else" "$RC" "2"
done_repo

# ---------------------------------------------------------- the installer ----
echo ""
echo "norma install"

new_repo
mkdir -p src && echo '{}' > package.json
OUT=$("$NORMA" install --profile node)
assert_has "install points at the setup interview" "$OUT" "harness-setup/SKILL.md"
assert_file "vendors the gate" scripts/harness/verify
assert_file "vendors the run context beside it" scripts/harness/run
assert_eq "executable, because the gate and the adapters call it" \
  "$([ -x scripts/harness/run ] && echo yes)" "yes"
assert_file "vendors the land script" scripts/harness/land
assert_eq "executable too, because the loop tells agents to run it" \
  "$([ -x scripts/harness/land ] && echo yes)" "yes"
assert_file "writes a config from the profile" scripts/harness/config.sh
assert_file "vendors the hook" .githooks/pre-commit
assert_file "vendors run-task as a real directory" .agents/skills/run-task/SKILL.md
# auto-run-task is a delta over run-task: it delegates every stage to that file by
# path, so shipping one without the other leaves a procedure pointing at nothing.
assert_file "vendors the autonomous variant beside it" .agents/skills/auto-run-task/SKILL.md
assert_file "vendors the setup interview" .agents/skills/harness-setup/SKILL.md
# The procedure behind step 5 of the loop. Vendored like the rest, because the
# project owns the commands but not the method.
assert_file "vendors the runtime verification procedure" .agents/skills/runtime-verification/SKILL.md
assert_file "and the architecture reference" .agents/skills/architecture-guidelines/references/backend.md
# start-project is the one skill that is not vendored: it runs before the
# project exists, and once it has finished run-task is the skill that matters.
assert_nofile "does not vendor start-project" .agents/skills/start-project
assert_file "creates the loop template" docs/harness/mandatory-steps.md
assert_file "creates the adoption map template" docs/harness/architecture-rules.md
assert_file "creates AGENTS.md" AGENTS.md
assert_eq "points CLAUDE.md at it" "$(readlink CLAUDE.md)" "AGENTS.md"
assert_eq "arms the hook path" "$(git config --get core.hooksPath)" ".githooks"
assert_has "AGENTS.md carries the block" "$(cat AGENTS.md)" "harness:begin"
assert_has "and points at the loop entry point" "$(cat AGENTS.md)" "run-task"
assert_eq "the claude symlink stays inside the repo" "$(readlink .claude/skills/run-task)" "../../.agents/skills/run-task"
assert_has "the loop template names the one exception to its final stop" \
  "$(cat docs/harness/mandatory-steps.md)" "auto-run-task"
assert_has "and the AGENTS.md block tells an agent when that variant applies" \
  "$(cat AGENTS.md)" "auto-run-task"

git add -A >/dev/null 2>&1
# --no-verify on purpose: this test is about the installer, and the hook it just
# installed correctly refuses a commit on the default branch without a stamp.
git commit -qm harness --no-verify
"$NORMA" install --profile node >/dev/null
assert_eq "installing twice changes nothing" "$(git status --porcelain | wc -l | tr -d ' ')" "0"
done_repo

new_repo
echo '{}' > package.json
"$NORMA" install --profile node >/dev/null
echo "# MINE" > scripts/harness/config.sh
echo "# MY LOOP" > docs/harness/mandatory-steps.md
"$NORMA" install --profile node >/dev/null
assert_eq "an existing config.sh is never overwritten" "$(cat scripts/harness/config.sh)" "# MINE"
assert_eq "nor are the project's own documents" "$(cat docs/harness/mandatory-steps.md)" "# MY LOOP"
done_repo

new_repo
echo '{}' > package.json
printf '# My rules\n\nSomething mine above.\n' > AGENTS.md
"$NORMA" install --profile node >/dev/null
assert_has "existing AGENTS.md content is preserved" "$(cat AGENTS.md)" "Something mine above."
assert_has "and the block is appended" "$(cat AGENTS.md)" "Verification gate"
before=$(cat AGENTS.md)
"$NORMA" install --profile node >/dev/null
assert_eq "re-injecting the block is idempotent" "$(cat AGENTS.md)" "$before"
done_repo

new_repo
echo '{}' > package.json
printf '# Mine\n\n## Harness\n\nMy own harness notes, with run-task and scripts/harness/verify.\n' > AGENTS.md
"$NORMA" install --profile node >/dev/null
assert_eq "an existing Harness section is left alone" "$(grep -c '^## Harness' AGENTS.md)" "1"
assert_has "with its own content intact" "$(cat AGENTS.md)" "My own harness notes"
done_repo

echo ""
echo "the stack profiles"

# Every profile must be valid sh and satisfy the contract the gate enforces at
# startup, or `install` hands the project a config that refuses to run.
for prof in "$HOME_DIR"/profiles/*.sh; do
  pname=$(basename "$prof" .sh)
  if sh -n "$prof" 2>/dev/null; then ok "$pname is valid sh"; else no "$pname is valid sh" "sh -n failed"; fi
  pmissing=""
  for fn in HARNESS_CODE_PATHS harness_gates harness_test_selected harness_test_all; do
    grep -q "^$fn" "$prof" || pmissing="$pmissing $fn"
  done
  if [ -z "$pmissing" ]; then ok "$pname satisfies the config contract"; else no "$pname satisfies the config contract" "missing:$pmissing"; fi
done

# Every name detection can emit must have a profile behind it, or install dies
# on a repository it claimed to recognise.
for dname in $(sed -n '/^detect_profile()/,/^}/p' "$HOME_DIR/bin/norma" | sed -n 's/.*then echo \([a-z0-9-]\{1,\}\)$/\1/p'); do
  assert_file "detection can emit '$dname', and it has a profile" "$HOME_DIR/profiles/$dname.sh"
done

# One marker per repository, so each row exercises its own branch of the ladder.
for pair in pubspec.yaml:flutter Cargo.toml:rust go.mod:go mix.exs:elixir \
            Package.swift:swift pom.xml:java-maven build.gradle.kts:gradle \
            thing.csproj:dotnet artisan:laravel Gemfile:ruby manage.py:django \
            next.config.mjs:next pnpm-workspace.yaml:pnpm-turbo package.json:node \
            pyproject.toml:python main.tf:terraform; do
  marker=${pair%%:*}
  expect=${pair##*:}
  new_repo
  : > "$marker"
  OUT=$("$NORMA" install --dry-run)
  assert_has "detects $expect from $marker" "$OUT" "profile: $expect"
  done_repo
done

new_repo
printf '[package]\nname = "thing"\n' > Cargo.toml
echo '{}' > package.json
OUT=$("$NORMA" install --dry-run --profile node)
assert_has "an explicit --profile wins over detection" "$OUT" "profile: node"
done_repo

# The founding commit of a new project predates its toolchain: there is nothing
# the gate could run yet, so it is made with the hook overridden for that one
# command. That only works while install arms the hook through core.hooksPath
# rather than by writing into .git/hooks - and it must leave it armed.
new_repo
echo '{}' > package.json
"$NORMA" install --profile node >/dev/null
git add -A >/dev/null 2>&1
git -c core.hooksPath=.git/hooks commit -qm founding
assert_eq "a founding commit lands with the hook overridden once" "$(git log --oneline | wc -l | tr -d ' ')" "2"
assert_eq "and the hook is still armed afterwards" "$(git config --get core.hooksPath)" ".githooks"
assert_nofile "install never writes into .git/hooks" .git/hooks/pre-commit
echo change >> README.md
git add README.md
set +e
git commit -qm second >/dev/null 2>&1; RC=$?
set -e
assert_eq "so the commit right after it is refused" "$RC" 1
done_repo

echo ""
echo "norma start"

# `start` is the front door of a project that does not exist: it runs outside a
# repository, and its only job is to leave a note every agent reads on the way in.
NS=$(mktemp -d)
OUT=$(cd "$NS" && "$NORMA" start nuevo 2>&1)
assert_file "start creates the directory it is given" "$NS/nuevo/AGENTS.md"
assert_eq "and points CLAUDE.md at the note" "$(readlink "$NS/nuevo/CLAUDE.md")" "AGENTS.md"
assert_has "the note carries the procedure's absolute path" "$(cat "$NS/nuevo/AGENTS.md")" \
  "$HOME_DIR/skills/start-project/SKILL.md"
assert_has "and the human is told what to do next" "$OUT" "tell it what you want to build"
set +e
OUT=$(cd "$NS/nuevo" && "$NORMA" start 2>&1); RC=$?
set -e
assert_eq "it refuses where a project has already started" "$RC" 2
assert_has "and says what to use instead" "$OUT" "harness-setup"
rm -rf "$NS"

NS=$(mktemp -d)
(cd "$NS" && "$NORMA" start >/dev/null)
assert_file "with no argument it uses the current directory" "$NS/AGENTS.md"
rm -rf "$NS"

echo ""
echo "the skill library"

# A skill directory whose frontmatter name does not match it is invisible: the
# name is what an agent matches a request against, not the path it was found at.
for sk in "$HOME_DIR"/skills/*/; do
  sname=$(basename "$sk")
  if [ -f "$sk/SKILL.md" ]; then
    assert_eq "$sname declares its own name" "$(sed -n 's/^name: *//p' "$sk/SKILL.md" | head -1)" "$sname"
  else
    no "$sname has a SKILL.md" "missing"
  fi
done

# The Agent Skills specification allows six top-level frontmatter fields, and its
# reference validator rejects a skill with any other; a version or an author goes
# under metadata instead.
for sk in "$HOME_DIR"/skills/*/; do
  [ -f "$sk/SKILL.md" ] || continue
  sname=$(basename "$sk")
  extra=$(awk 'NR == 1 && $0 == "---" { f = 1; next } f && $0 == "---" { exit } f' "$sk/SKILL.md" |
    sed -n 's/^\([A-Za-z_-]*\):.*/\1/p' |
    grep -vxE 'name|description|license|compatibility|metadata|allowed-tools' || true)
  assert_eq "$sname uses only the frontmatter fields the spec allows" "$extra" ""
done

# Everything VENDORED_SKILLS names must exist, or install ships fewer skills than
# doctor counts from the same list.
for vs in $(sed -n 's/^VENDORED_SKILLS="\(.*\)"$/\1/p' "$HOME_DIR/bin/norma"); do
  assert_file "VENDORED_SKILLS names '$vs', and it is there" "$HOME_DIR/skills/$vs/SKILL.md"
done

# The loop used to end at "document", so closing the phase in the roadmap and
# archiving the change happened in a second branch after the merge - a branch, a
# review and a gate run each time, and a default branch carrying code whose delta
# specs had never been applied.
rt=$(cat "$HOME_DIR/skills/run-task/SKILL.md")
assert_has "run-task closes the change before handing over" "$rt" "## 8. Close the change"
assert_has "by archiving it, in this branch" "$rt" "openspec-archive-change/SKILL.md"
assert_has "and by closing the phase where the roadmap describes it" "$rt" "roadmap"
assert_has "then verifying again, because an archive rewrites files" "$rt" "re-run stage 5"
assert_has "the loop's last stage is still the human's" "$rt" "## 9. Hand over"

# The run context opens where the task first has a name the repository agrees
# with, and closes AFTER the archive. Both ends are load-bearing and both are
# prose, so they are asserted rather than trusted.
assert_has "run-task opens the run context on the branch stage" "$rt" "scripts/harness/run start"
assert_has "saying why a task run is not an agent session" "$rt" "not an agent session"
assert_has "and closes it at stage 8" "$rt" "scripts/harness/run close"
# Closing before the archive means the archive moves the summary and every link
# to it is written against a path that stops existing.
for doc in "$HOME_DIR/skills/run-task/SKILL.md" "$HOME_DIR/templates/mandatory-steps.md"; do
  arch=$(grep -n 'openspec-archive-change/SKILL.md' "$doc" | head -1 | cut -d: -f1)
  cl=$(grep -n 'scripts/harness/run close' "$doc" | head -1 | cut -d: -f1)
  if [ -n "$arch" ] && [ -n "$cl" ] && [ "$cl" -gt "$arch" ]; then
    ok "$(basename "$(dirname "$doc")")/$(basename "$doc") closes the run after the archive"
  else
    no "$(basename "$doc") closes the run after the archive" "archive at line ${arch:-?}, close at line ${cl:-?}"
  fi
done
# The block injected into a consumer's AGENTS.md is how an agent that reads by
# path learns the command exists at all. A skill nobody is told about is vendored
# and invisible, which is the failure the markers were added to stop.
assert_has "the AGENTS.md block names the run context" \
  "$(cat "$HOME_DIR/templates/agents-section.md")" "scripts/harness/run start"
# Who merges is the project's decision, so it lives in the template the project
# owns, as one line a skill can read - and the safe answer is the one it ships with.
ms=$(cat "$HOME_DIR/templates/mandatory-steps.md")
assert_has "the loop template records who lands a pull request" "$ms" "Landing: owner"
assert_eq "exactly once, so there is one answer to read" \
  "$(grep -c '^Landing: ' "$HOME_DIR/templates/mandatory-steps.md")" "1"
assert_has "and names the command that does it" "$ms" "scripts/harness/land <pr>"
assert_has "and the one that reads the line, so nobody reads it by eye" "$ms" "scripts/harness/land --landing"
# The template mentions both values in its own prose; the reader must still find
# exactly one line, the shipped one, and complain about nothing.
new_repo; with_land; mkdir -p docs/harness
cp "$HOME_DIR/templates/mandatory-steps.md" docs/harness/mandatory-steps.md
git add docs && git commit -qm loop --no-verify
git update-ref refs/remotes/origin/master HEAD
git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/master
assert_eq "land --landing reads the shipped template as owner" "$(sh scripts/harness/land --landing 2>&1)" "owner"
sed -i.bak 's/^Landing: owner$/Landing: agent/' docs/harness/mandatory-steps.md
git commit -qam agent --no-verify; git update-ref refs/remotes/origin/master HEAD
assert_eq "and the shipped template with its line set to agent as agent" "$(sh scripts/harness/land --landing 2>/dev/null)" "agent"
done_repo
assert_has "and what the other answer commits the agent to" "$ms" "Landing: agent"
assert_has "including when an agent must stop trying" "$ms" "attempts at the same failure"
assert_no "and no longer reserves every merge for the human" "$ms" "Merging, deploying and publishing stay with the human"
# The block is refreshed on every upgrade, including in projects whose template
# predates the line. It has to read their silence as the safe answer.
ag=$(cat "$HOME_DIR/templates/agents-section.md")
assert_has "the AGENTS.md block points an agent at that line" "$ag" "Landing:"
assert_has "through the command that reads it" "$ag" "scripts/harness/land --landing"
assert_has "and reads a template without it as the owner's" "$ag" "no such line"
assert_no "and no longer says merging is never the agent's" "$ag" "merging, deploying and"
assert_has "update-docs names the roadmap, which no diff points at" \
  "$(cat "$HOME_DIR/skills/update-docs/SKILL.md")" "roadmap entry"
# A review that read two thirds of the diff reads exactly like one that read all
# of it, and ends on the same verdict. The file checklist and the counts in the
# output are the only thing that makes the difference visible.
adv=$(cat "$HOME_DIR/skills/adversarial-review/SKILL.md")
assert_has "adversarial-review accounts for every file in the change" "$adv" "## 1. Map the change"
assert_has "closing each one as reviewed or skipped for a stated reason" "$adv" "skipped with a concrete"
assert_has "and reporting the coverage beside the verdict" "$adv" "Open with the coverage line"
# The pass that judges the findings shares an author with them, so left to its
# own taste it drops the ones it is least able to judge. The asymmetry and the
# protected subjects are what stop that.
assert_has "it fact-checks its findings before reporting them" "$adv" "## 4. Fact-check your own findings"
assert_has "dropping one only on the two grounds the diff can prove" "$adv" "exactly two grounds"
assert_has "and never on the subjects where being wrong costs most" "$adv" "Never drop a finding"
# Unsupervised, "make it green" is the dominant failure, and every road to it
# ends with the check passing. The removed lines are where it shows.
assert_has "it attacks a bar lowered to get to green" "$adv" "**A weakened bar.**"
assert_has "reading the removed lines, not only the added ones" "$adv" "**removed** lines"
assert_has "and blocks a loosening nobody justified" "$adv" "loosening it always does"
# Unsupervised, the archive has to travel inside the pull request: there is no
# second branch because there is nobody to remember it.
auto=$(cat "$HOME_DIR/skills/auto-run-task/SKILL.md")
assert_has "auto-run-task delivers after closing, not instead of it" "$auto" "### Stage 9 - Deliver"
# openspec-archive-change stops to ask three times, and unsupervised nobody
# answers. "Archive without syncing" is the plausible wrong pick: it leaves the
# specs describing a system that no longer exists, and looking finished.
assert_has "and answers the prompts the archive stops on" "$auto" "### Stage 8 - Close the change"
assert_has "syncing the delta specs rather than archiving past them" "$auto" "Archive without syncing"
# Archiving MOVES the change folder, so the log the pull request links is no
# longer where it was written - and a dead link to it is the same as no log.
assert_has "and links the autonomy log where the archive left it" "$auto" "changes/archive/"
assert_has "run-task says the reports move with the change" \
  "$(cat "$HOME_DIR/skills/run-task/SKILL.md")" "moves the change folder"
assert_has "the loop template makes closing the change binding too" \
  "$(cat "$HOME_DIR/templates/mandatory-steps.md")" "close the change"

# Skills reference each other by path. A path naming a skill nobody installs is a
# dead end at the worst moment - `auto-run-task` is nothing but such references.
# openspec-* are the exception: the openspec tool vendors those, not norma.
refs=$(grep -rho '\.agents/skills/[a-z0-9-]*' "$HOME_DIR"/skills/ | sed 's|.*/||' | sort -u)
vendored=$(sed -n 's/^VENDORED_SKILLS="\(.*\)"$/\1/p' "$HOME_DIR/bin/norma")
for r in $refs; do
  case $r in openspec-*|"") continue ;; esac
  found=0
  for v in $vendored; do [ "$v" = "$r" ] && found=1; done
  if [ "$found" -eq 1 ]; then
    ok "the '$r' a skill points at is a skill install ships"
  else
    no "the '$r' a skill points at is a skill install ships" "not in VENDORED_SKILLS"
  fi
done

# Starting a task on a dirty or stale branch costs the whole loop: the diff the
# review reads is not the change, and the gate vouches for somebody else's work.
# The hook refuses the default branch, which is the only one of these it can see.
assert_has "run-task checks the tree before it writes anything" \
  "$rt" "### Before the first edit"
assert_has "including a branch that is behind the base" "$rt" "behind the base"
assert_has "and work in the tree that is not this task's" "$rt" "not part of this task"

# A red gate, a red test or a review finding used to go straight back to an edit:
# stage 6 said "fix what it finds, then re-run stage 5" and nothing in between said
# what kind of wrong it was. Editing the implementation is right for exactly one of
# the four, and the expensive mistakes - loosening the check, re-running unchanged,
# inventing a capability nobody planned - are the other three mistaken for it.
assert_has "run-task classifies a failure before retrying it" \
  "$rt" "### When it comes back red"
assert_has "quoting the evidence that decided the classification" "$rt" "quote the line"
assert_has "only one of the four justifies editing the implementation" \
  "$rt" "only one of the four"
assert_has "a check that is wrong is fixed against the spec, never loosened" \
  "$rt" "never by deleting it"
assert_has "a missing capability goes back to the plan instead" "$rt" "work, not a retry"
assert_has "and a retry that changed nothing is not a retry" "$rt" "Never re-run unchanged"
# The compounding half, and the reason this repository keeps a reason beside every
# refusal: a failure that keeps coming back has to stop being retried and become a
# test, a gate or a line in the documents.
assert_has "a failure seen before is a gap, not another attempt" \
  "$rt" "becomes infrastructure"
# Unsupervised runs stage 5 exactly as written, so the classification has to reach
# the log that stands in for the human who would have read it.
assert_has "auto-run-task logs which of the four a failure was" \
  "$auto" "which of the four"
# Two classifications in sibling skills read as rivals unless one says how they
# compose: CI decides whose failure it is, stage 5 decides what is broken.
assert_has "the CI triage hands its own diff's failures to that classification" \
  "$auto" "When it comes back red"

# "Two attempts then escalate" treated a flake and a real regression the same, so
# a flake burned both attempts, and a base branch that was already red invited a
# fix that travels in this pull request - against this file's own limit of never
# working outside the phase.
assert_has "auto-run-task classifies a CI failure before reacting to it" \
  "$auto" "Caused by this change"
assert_has "a flake is retried and does not spend an attempt" "$auto" "does not spend"
assert_has "and a base branch that is already red is not this run's to fix" \
  "$auto" "Already red on the base branch"

# A real run hit HTTP 429 from its model provider - a request-rate cap, then a
# concurrency cap - and the agent translated that into "my budget is exhausted",
# then used the invented budget to justify ending the phase with 22 of 45 tasks
# undone. None of the seven escalation reasons covers a provider refusing you, so
# it had no sanctioned category and made one up.
assert_has "a provider limit is not one of the seven reasons" \
  "$auto" "A provider refusing you is not the harness blocking you"
assert_has "it is retried, and if it persists the run is interrupted, not finished" \
  "$auto" "interrupted, not finished"
# The same run reported an estimated budget as a fact, on a plan with unlimited
# tokens. An agent cannot measure what it has left, and the skill already forbids
# reporting anything else it has not checked.
assert_has "and a self-estimated budget is never reported as a fact" \
  "$auto" "cannot measure"
# The concurrency cap was tripped by fanning out subagents. No skill here ever
# asked for that fan-out, and now none leaves the ceiling unsaid - as arithmetic,
# because the limit is the provider's number and not the harness's.
assert_has "fanning out has a ceiling derived from the provider's own limit" \
  "$auto" "minus two"
# Agnostic by construction, same rule the sibling skill is held to: the arithmetic
# may not harden into one vendor's number.
# Whole words: the provider that prompted this is a three-letter name, and a
# substring check for it matches "dominant".
for tool in deepseek nan openai anthropic gemini; do
  if printf '%s' "$auto" | grep -qiE "(^|[^a-z])$tool([^a-z]|$)"; then
    no "auto-run-task names no provider ($tool)" "found in the skill"
  else
    ok "auto-run-task names no provider ($tool)"
  fi
done

# The autonomous variant removes the three stops, so the two limits that keep an
# unsupervised run reviewable have to be stated in it, explicitly.
auto=$(cat "$HOME_DIR/skills/auto-run-task/SKILL.md")
assert_has "auto-run-task delegates the stages to run-task instead of copying them" \
  "$auto" ".agents/skills/run-task/SKILL.md"
# Who merges is the project's line, not the skill's. The skill reads it, lands only
# through land and only on `agent`, and stops at the pull request on anything else.
assert_has "auto-run-task reads the project's Landing line" "$auto" "Landing:"
assert_has "through the reader that fails closed, not by eye" "$auto" "run \`scripts/harness/land --landing <pr>\`"
assert_has "spending CI attempts once, not again through land" "$auto" "gets no third through"
assert_has "governing the companion with this repository's line" "$auto" "pass one only if this run opened it"
assert_has "and reporting a give-up as the escalation it is" "$auto" "escalation
     reason 6"
assert_has "lands only through the land script" "$auto" "scripts/harness/land <pr>"
assert_has "stops at the open pull request on anything --landing does not print as agent" \
  "$auto" "anything \`--landing\` does not print as \`agent\`"
assert_has "and never edits the line to grant itself the merge" "$auto" "Never edit the \`Landing:\`"
assert_has "taking 'leave it open' only from the human in the conversation" "$auto" "in this conversation"
assert_has "and never merges by any other route" "$auto" "never merge the pull request by any other route"
assert_has "nor turns on auto-merge" "$auto" "never enable"
assert_has "and gives up landing after two attempts at the same failure" "$auto" "attempts at the same failure"
rt_ho=$(sed -n '/^## 9. Hand over/,/^## Reporting honestly/p' "$HOME_DIR/skills/run-task/SKILL.md")
assert_has "run-task's hand-over follows the Landing line once a pull request exists" "$rt_ho" "Landing:"
assert_has "read through land --landing too" "$rt_ho" "scripts/harness/land --landing"
assert_has "and honouring a request to leave it open" "$rt_ho" "to leave it open, it stays open"
assert_has "and still commits nothing before the human approves" "$rt_ho" "Do not commit, push, open a pull request"
hs_r2=$(sed -n '/^### Round 2/,/^### Round 3/p' "$HOME_DIR/skills/harness-setup/SKILL.md")
assert_has "harness-setup asks who lands a pull request" "$hs_r2" "Landing:"
assert_has "proposing the owner" "$hs_r2" "Propose \`owner\`"
assert_has "and, for agent, the permission Claude Code needs to run land" "$hs_r2" "Bash(scripts/harness/land:*)"
assert_has "never writing agent without the owner's explicit word" "$hs_r2" "never write \`agent\` on your"
assert_has "asking for the permission as a separate question" "$hs_r2" "ask a **separate** question"
assert_has "and the paths CI ignores, for land" "$hs_r2" "HARNESS_LAND_NO_CI"
assert_has "and recommends cancelling superseded CI runs" "$hs_r2" "concurrency"
assert_has "auto-run-task refuses to bypass the hook" "$auto" "--no-verify"
assert_has "auto-run-task records what it decided instead of asking" \
  "$auto" "reports/autonomy.md"

# Runtime verification was the one stage of the loop with no procedure behind it:
# run-task said "do the runtime verification the project requires" in a single
# line, and everything else lived in a template the PROJECT owns - so it never
# received an upgrade, and three consumers each drifted their own way.
rv=$(cat "$HOME_DIR/skills/runtime-verification/SKILL.md")
assert_has "runtime-verification decides the surface before touching anything" \
  "$rv" "Decide the surface first"
assert_has "and exercises the failure path, not only the happy one" "$rv" "failure path"
assert_has "it says what it did NOT cover" "$rv" "Not covered"
assert_has "and closes on an explicit verdict, like the adversarial pass" "$rv" "Verdict"
# Two values are not enough. A run blocked for want of a credential or a daemon
# is not a failed one, and an agent with only pass/fail to choose from reports the
# blocked case as "does not" - which sends the reviewer hunting a defect that was
# never there. Seen happening, which is why this is asserted.
assert_has "including the third outcome, a run that could not be verified at all" \
  "$rv" "could not be verified"
# An undeclared project is the common case on the first upgrade, and a skill that
# refuses until somebody edits a file norma does not own is a framework fighting
# the project. It reports the gap instead.
assert_has "an undeclared project is a finding, not a reason to skip" \
  "$rv" "TODO(harness)"
# The report has no single home: a project with OpenSpec keeps it in the change
# folder, and THIS repository has no openspec/ at all. Naming only one would make
# the skill unusable in the repository that ships it.
assert_has "the report location covers a project with OpenSpec" "$rv" "openspec/changes/"
assert_has "and one without it" "$rv" "Step 6"
# Agnostic by construction. The moment a skill names one agent's tooling it stops
# running identically under the others, which is the premise the whole harness
# rests on - instructions by path, never by an agent's shortcut.
for tool in Playwright playwright sonnet Sonnet "gh pr" MCP "/qa"; do
  if printf '%s' "$rv" | grep -qF "$tool"; then
    no "runtime-verification names no agent-specific tooling ($tool)" "found in the skill"
  else
    ok "runtime-verification names no agent-specific tooling ($tool)"
  fi
done
# The migration procedure moved out of the project-owned template and into the
# skill so it can be improved upstream. The template keeps its TODO: moving the
# procedure must not read as if the question had been answered.
assert_has "the migration procedure lives in the skill now" "$rv" "Apply it twice"
assert_has "including migrating a store that already has data" "$rv" "already has data"
assert_has "the loop template still asks the project for its own commands" \
  "$(cat "$HOME_DIR/templates/mandatory-steps.md")" "TODO(harness)"
assert_has "and reaches the procedure through the skill" \
  "$(cat "$HOME_DIR/templates/mandatory-steps.md")" "runtime-verification/SKILL.md"
# The loop has to actually call it, or the skill is shelf-ware.
assert_has "run-task reaches runtime verification through the skill" \
  "$rt" ".agents/skills/runtime-verification/SKILL.md"
# Stage 6 fixes findings and re-runs stage 5. The gate re-runs; the runtime check
# did not, so a review that changed behaviour left a report describing code that
# no longer existed.
assert_has "and re-runs it when a review finding changed behaviour" \
  "$rt" "Re-run the runtime verification"
# Unsupervised there is nobody to hand a credential over, so a verification that
# cannot run is an escalation rather than a silently skipped step. Match the
# escalation list alone: the phrase also appears in the autonomy log section
# further down, so asserting it against the whole file proved nothing at all.
esc=$(sed -n '/^### Stop and ask/,/^### How to stop/p' "$HOME_DIR/skills/auto-run-task/SKILL.md")
assert_has "unsupervised, a runtime check that cannot run escalates" \
  "$esc" "runtime verification that cannot be run"
# Without this round a new project installs a skill that looks for a declaration
# nobody was ever asked to write.
hs="$HOME_DIR/skills/harness-setup/SKILL.md"
assert_has "harness-setup asks how the project is exercised for real" \
  "$(cat "$hs")" "exercised for real"
# The heading is not the round. Assert what the round has to extract, or gutting
# its body down to a title would pass.
assert_has "including the account or fixture, and never a real credential" \
  "$(cat "$hs")" "Never a real credential"
assert_has "and whether there is a store to migrate" "$(cat "$hs")" "already has data"
# Evidence is the half deferred from the first version, and the shape matters more
# than the existence: "take a screenshot" is wrong for a CLI, where the evidence is
# the output and the exit code, and for an endpoint, where it is the response.
assert_has "the skill says what evidence a surface actually needs" \
  "$rv" "## 4. Capture what proves it"
assert_has "a screen is a still per state that matters" "$rv" "one still per state"
assert_has "a command is its real output and exit code" "$rv" "exit code"
# Video was considered and dropped on purpose. Saying so stops it being re-added
# as an obvious omission by whoever reads this next.
assert_has "and video is refused with its reason, not silently absent" \
  "$rv" "Not video"
# Evidence in the repository is evidence nobody ever deletes, and the report is a
# committed file, so it carries the filename and never this machine's paths.
assert_has "evidence is kept outside the repository" "$rv" "never inside the repository"
assert_has "and the committed report carries the name, not the path" \
  "$rv" "not the path"
# Unsupervised there is no hand-over message to put the paths in, so the evidence
# has to travel in the pull request or it does not exist for the reviewer.
assert_has "unsupervised, the evidence is attached to the pull request" \
  "$auto" "--attach"
assert_has "and an older gh that cannot attach is reported, not worked around" \
  "$auto" "do not improvise"

# One change can land on two surfaces at once - an endpoint and the screen that
# calls it - and keying the evidence off the repository instead of the surface
# gets that case wrong in exactly the repositories that have both.
assert_has "evidence is per surface, and a change can have several" \
  "$rv" "more than one surface"
# The committed report carries names, not paths, and the preferred way to capture
# is a subagent. Nothing said the subagent had to return the paths, so the one
# piece of information the pull request needs could be dropped on the way back.
assert_has "a delegated capture hands the paths back to the caller" \
  "$rv" "hand the paths back"
# Which forge a consumer is on is a project decision, and the first draft of this
# wrote `gh` in as the only path - the very thing the assertion above forbids in
# the sibling skill. A consumer on another forge got an instruction into a dead
# end, with "do not improvise" closing the exit.
assert_has "attaching evidence assumes no particular forge" \
  "$auto" "not the harness's to assume"
# gh rewrites the body reference only when it matches the attached path exactly;
# a near-miss uploads the file and leaves a dead link in the merged body.
assert_has "the body reference must match the attached path exactly" \
  "$auto" "byte for byte"
# The path is a machine path, and the pushed body may not keep one. It survives
# only if the upload failed, which is precisely when it must be taken out.
assert_has "and no machine path survives in the pushed body" \
  "$auto" "no longer carries"

# Adding a round renumbers the ones below it, and the "Write" section refers to
# one of them BY NUMBER. That back-reference can point at the wrong round with
# the whole suite still green - it did, until this test existed.
idx=$(sed -n 's/^### Round \([0-9]*\) - the index and the extras.*/\1/p' "$hs")
assert_eq "the round that decides AGENTS.md is the one the write step names" \
  "$(sed -n 's/.*only if round \([0-9]*\) said so.*/\1/p' "$hs")" "$idx"
assert_eq "and the rounds are numbered without a gap" \
  "$(sed -n 's/^### Round \([0-9]*\) .*/\1/p' "$hs" | tail -1)" "$(grep -c '^### Round ' "$hs")"
# Three documents state the count in words, and two of them are the ones nobody
# remembers to update.
rw=$(sed -n 's/.*Ask in \*\*\([a-z]*\) rounds\*\*.*/\1/p' "$hs")
assert_eq "the README agrees on how many rounds the interview has" \
  "$(sed -n 's/.*asks in \([a-z]*\) rounds.*/\1/p' "$HOME_DIR/README.md")" "$rw"
assert_eq "and so does the skill library document" \
  "$(sed -n 's/.*asks in \([a-z]*\) rounds,.*/\1/p' "$HOME_DIR/docs/03-skills.md")" "$rw"

# start-project is reached through `norma home`, because there is no repository
# to vendor it into yet - so that path has to work from anywhere.
assert_file "start-project ships with its document skeletons" \
  "$HOME_DIR/skills/start-project/references/documents.md"
NR=$(mktemp -d)
assert_eq "norma home prints the installation directory, outside any repository" \
  "$(cd "$NR" && "$NORMA" home)" "$HOME_DIR"
rm -rf "$NR"
assert_has "help offers the front door for a project that does not exist yet" \
  "$("$NORMA" help)" "norma start"

echo ""
echo "norma upgrade"

new_repo
echo '{}' > package.json
"$NORMA" install --profile node >/dev/null
echo "# MINE" > scripts/harness/config.sh
echo "broken" > scripts/harness/verify
printf '# Mine\n\n## Harness\n\nMy notes: run-task, scripts/harness/verify.\n' > AGENTS.md
rm -f scripts/harness/run scripts/harness/land
"$NORMA" upgrade --force >/dev/null 2>&1
assert_eq "upgrade restores the gate it owns" "$(head -1 scripts/harness/verify)" "#!/bin/sh"
assert_file "and brings the run context to a project installed before it existed" \
  scripts/harness/run
assert_file "and the land script to one installed before that" scripts/harness/land
assert_eq "and leaves config.sh alone" "$(cat scripts/harness/config.sh)" "# MINE"
assert_has "and never touches an AGENTS.md that carries no markers" "$(cat AGENTS.md)" "My notes"
assert_no "not even to append a block to it" "$(cat AGENTS.md)" "harness:begin"
done_repo

# The markers say "Managed by the norma installer". Before this, only `install`
# ever rewrote the block, so the promise was false on every upgrade: a skill
# added upstream reached Claude Code through .claude/skills and stayed invisible
# to every agent that reads AGENTS.md by path.
new_repo
echo '{}' > package.json
"$NORMA" install --profile node >/dev/null
sed -i.bak 's/^- \*\*Full procedure/- STALE MARKER TEXT\n- **Full procedure/' AGENTS.md && rm -f AGENTS.md.bak
assert_has "a marked block can go stale" "$(cat AGENTS.md)" "STALE MARKER TEXT"
OUT=$("$NORMA" upgrade 2>&1)
assert_no "upgrade refreshes the block the markers declare managed" "$(cat AGENTS.md)" "STALE MARKER TEXT"
assert_has "and leaves the markers in place for the next one" "$(cat AGENTS.md)" "harness:begin"
assert_has "saying so, because it is the one project file it may rewrite" "$OUT" "AGENTS.md"
printf '# Only mine\n' > AGENTS.md
"$NORMA" upgrade >/dev/null 2>&1
assert_eq "and once the markers are gone it never comes back" "$(cat AGENTS.md)" "# Only mine"
done_repo

# What lies outside the markers is the project's, and this is the test that says
# so: architecture notes, where-to-read-what, release process, house conventions.
new_repo
echo '{}' > package.json
"$NORMA" install --profile node >/dev/null
printf '# Mine\n\n## Architecture\nLayers: domain, data, presentation.\n\n%s\n## Harness\nSTALE\n%s\n\n## Release\nfastlane, see ops/release.md\n' \
  '<!-- harness:begin -->' '<!-- harness:end -->' > AGENTS.md
"$NORMA" upgrade >/dev/null 2>&1
A=$(cat AGENTS.md)
assert_has "what precedes the markers survives an upgrade" "$A" "Layers: domain, data, presentation."
assert_has "and what follows them too" "$A" "fastlane, see ops/release.md"
assert_no "only the block between them is replaced" "$A" "STALE"
assert_has "with the current block in its place" "$A" "auto-run-task"
done_repo

# The awk copies up to the begin marker and resumes at the end marker. Unpaired,
# it never resumes and deletes the rest of the file - which is why an unpaired
# marker is refused outright instead of processed hopefully. One trailing space
# on the end marker was enough to lose everything below it.
for broken in "begin-with-no-end" "end-that-does-not-match-to-the-byte"; do
  new_repo
  echo '{}' > package.json
  "$NORMA" install --profile node >/dev/null
  if [ "$broken" = "begin-with-no-end" ]; then
    printf '# Mine\n%s\nold\n\n## Release\nfastlane\n' '<!-- harness:begin -->' > AGENTS.md
  else
    printf '# Mine\n%s\nold\n%s \n\n## Release\nfastlane\n' '<!-- harness:begin -->' '<!-- harness:end -->' > AGENTS.md
  fi
  before=$(cat AGENTS.md)
  OUT=$("$NORMA" upgrade 2>&1)
  assert_has "refuses AGENTS.md with a $broken" "$OUT" "not a matching pair"
  assert_eq "and leaves the file byte for byte" "$(cat AGENTS.md)" "$before"
  assert_has "saying how to fix it" "$OUT" "exact to the byte"
  done_repo
done

# norma installs its own harness, and that is the one repository where a vendored
# copy is wrong: skills/ there IS the source, so a copy under .agents/ is a second
# version of it. Before this, an upgrade run in norma's own tree silently turned
# all eleven links into copies - undoing a decision docs/01-architecture.md calls
# load-bearing, and doing it where no consumer would ever notice.
NH=$(mktemp -d)
cp -R "$HOME_DIR/bin" "$HOME_DIR/core" "$HOME_DIR/skills" "$HOME_DIR/profiles" \
      "$HOME_DIR/templates" "$HOME_DIR/VERSION" "$NH/"
(cd "$NH" && git init -q && git config user.email t@example.com && git config user.name Test \
   && echo '{}' > package.json && "$NH/bin/norma" install --profile node) >/dev/null 2>&1
assert_eq "in norma's own repository a skill is a link into skills/, not a copy" \
  "$(readlink "$NH/.agents/skills/run-task")" "../../skills/run-task"
assert_eq "and Claude Code still reaches it the same way as anywhere else" \
  "$(readlink "$NH/.claude/skills/run-task")" "../../.agents/skills/run-task"

# The reason to run upgrade there at all: a skill added upstream needs its links.
rm -f "$NH/.agents/skills/commit" "$NH/.claude/skills/commit"
(cd "$NH" && "$NH/bin/norma" upgrade) >/dev/null 2>&1
assert_eq "upgrade creates the links a newly added skill needs" \
  "$(readlink "$NH/.agents/skills/commit")" "../../skills/commit"

ln -sfn ../../skills/renamed-upstream "$NH/.agents/skills/commit"
(cd "$NH" && "$NH/bin/norma" upgrade) >/dev/null 2>&1
assert_eq "and repairs one left pointing at a skill that moved" \
  "$(readlink "$NH/.agents/skills/commit")" "../../skills/commit"

rm -f "$NH/.agents/skills/commit"
mkdir -p "$NH/.agents/skills/commit" && echo copy > "$NH/.agents/skills/commit/SKILL.md"
OUT=$(cd "$NH" && "$NH/bin/norma" upgrade 2>&1)
assert_has "but a real directory there is reported, not silently replaced" "$OUT" "second copy of skills/commit"
assert_eq "and left where it is" "$(cat "$NH/.agents/skills/commit/SKILL.md")" "copy"
rm -rf "$NH"

# Paths alone would miss the tree this harness tells everyone to make: a worktree
# or second checkout of norma, driven by the INSTALLED cli. The paths differ, the
# repository is still norma, and copying would destroy its links just the same.
NW=$(mktemp -d)
cp -R "$HOME_DIR/bin" "$HOME_DIR/core" "$HOME_DIR/skills" "$HOME_DIR/profiles" \
      "$HOME_DIR/templates" "$HOME_DIR/VERSION" "$NW/"
(cd "$NW" && git init -q && git config user.email t@example.com && git config user.name Test \
   && echo '{}' > package.json && "$NORMA" install --profile node) >/dev/null 2>&1
assert_eq "another checkout of norma is still norma, whichever cli drives it" \
  "$(readlink "$NW/.agents/skills/run-task")" "../../skills/run-task"
rm -rf "$NW"

# A dry run that prints half the plan is worse than none: the link is how an
# agent reaches the skill, and it was never announced.
new_repo
echo '{}' > package.json
"$NORMA" install --profile node >/dev/null
rm -rf .agents/skills/commit .claude/skills/commit
OUT=$("$NORMA" upgrade --dry-run 2>&1)
assert_has "a dry run announces the skill it would vendor" "$OUT" "would vendor .agents/skills/commit"
assert_has "and the link an agent would reach it through" "$OUT" "would link .claude/skills/commit"
assert_nofile "and writes neither of them" .agents/skills/commit
done_repo

# Repairing, not just creating: a link pointing at the wrong place is exactly
# what survives a rename upstream, and doctor can only report it.
new_repo
echo '{}' > package.json
"$NORMA" install --profile node >/dev/null
ln -sfn ../../.agents/skills/somewhere-else .claude/skills/commit
"$NORMA" upgrade >/dev/null 2>&1
assert_eq "upgrade repairs a link pointing at the wrong skill" \
  "$(readlink .claude/skills/commit)" "../../.agents/skills/commit"
rm -f .claude/skills/commit
mkdir -p .claude/skills/commit && echo mine > .claude/skills/commit/SKILL.md
"$NORMA" upgrade >/dev/null 2>&1
assert_eq "but a real directory there is not the harness's to delete" \
  "$(cat .claude/skills/commit/SKILL.md)" "mine"
done_repo

echo ""
echo "norma doctor"

new_repo
set +e
OUT=$("$NORMA" doctor 2>&1); RC=$?
set -e
assert_eq "fails on a repository without a harness" "$RC" 1
assert_has "and says what is missing" "$OUT" "norma install"
done_repo

new_repo
echo '{}' > package.json
"$NORMA" install --profile node >/dev/null
set +e
OUT=$("$NORMA" doctor 2>&1); RC=$?
set -e
assert_eq "passes on a fresh install" "$RC" 0
assert_has "warning about the templates it cannot fill" "$OUT" "TODO(harness)"
assert_has "and checking the land script is there" "$OUT" "ok  scripts/harness/land present and executable"
rm scripts/harness/land
set +e
OUT=$("$NORMA" doctor 2>&1); RC=$?
set -e
assert_eq "fails when the land script is missing" "$RC" 1
assert_has "and says how to bring it back" "$OUT" "scripts/harness/land present and executable - run 'norma upgrade'"
done_repo

new_repo
echo '{}' > package.json
"$NORMA" install --profile node >/dev/null
ln -sfn "$HOME/somewhere/skill" .claude/skills/escaping
set +e
OUT=$("$NORMA" doctor 2>&1); RC=$?
set -e
assert_eq "catches a symlink that escapes the repository" "$RC" 1
assert_has "explaining why it matters" "$OUT" "another machine"
done_repo

# The gate deliberately does not refuse for this - verification must not gain a
# way to fail that has nothing to do with the code - so doctor is the only place
# a human is told that the next task is about to collect evidence against
# somebody else's identity.
new_repo
echo '{}' > package.json
"$NORMA" install --profile node >/dev/null
git switch -qc branch-a
sh scripts/harness/run start task-a >/dev/null
git switch -qc branch-b
set +e
OUT=$("$NORMA" doctor 2>&1); RC=$?
set -e
assert_has "doctor reports a run left open on another branch" "$OUT" "branch-a"
assert_has "and how to end it" "$OUT" "run close"
assert_eq "as a warning, not a blocking problem" "$RC" 0
done_repo

# ------------------------------------------------------- the install script ----
echo ""
echo "install.sh"

# A release repository whose newest version is not the newest as text - 0.10.0
# sorts before 0.2.0 that way - plus a tag that is not a version at all.
new_repo
SRC=$R
mkdir bin
# Resolves its own link, as the real one does, to find VERSION.
printf '#!/bin/sh\nme=$(readlink "$0" || echo "$0")\necho "norma $(cat "$(dirname "$me")/../VERSION")"\n' > bin/norma
chmod +x bin/norma
for v in 0.2.0 0.10.0 0.9.0 nightly; do
  echo "$v" > VERSION
  git add -A && git commit -qm "$v" && git tag "$v"
done
cd "$HOME_DIR"

# Runs install.sh against $SRC into the throwaway directory $I, with any extra
# environment given as arguments.
inst() {
  set +e
  OUT=$(env NORMA_REPO="$SRC" NORMA_HOME="$I/norma" NORMA_BIN_DIR="$I/bin" "$@" \
    sh "$HOME_DIR/install.sh" 2>&1)
  RC=$?
  set -e
}

I=$(mktemp -d)
inst
assert_eq "installs" "$RC" 0
assert_eq "the latest release by version, not by string order" "$("$I/bin/norma")" "norma 0.10.0"
assert_has "and says where it went" "$OUT" "$I/norma"
assert_has "and that the link directory is not on PATH" "$OUT" "Add $I/bin to your PATH"
inst NORMA_VERSION=0.2.0
assert_eq "running it again moves the install to a pinned release" "$("$I/bin/norma")" "norma 0.2.0"
rm -rf "$I"

# A link to another checkout is somebody's working copy - the maintainer's
# development clone, for one - and repointing it would change what they run.
I=$(mktemp -d)
mkdir "$I/bin"
ln -s /elsewhere/bin/norma "$I/bin/norma"
inst
assert_eq "refuses a norma link that points elsewhere" "$RC" 1
assert_has "naming where it points" "$OUT" "/elsewhere/bin/norma"
assert_nofile "before cloning anything" "$I/norma"
assert_eq "and leaves the link alone" "$(readlink "$I/bin/norma")" "/elsewhere/bin/norma"
rm -rf "$I"

I=$(mktemp -d)
mkdir "$I/norma"
touch "$I/norma/somebodys-file"
inst
assert_eq "refuses a NORMA_HOME that is not a norma checkout" "$RC" 1
assert_has "and says how to get past it" "$OUT" "set NORMA_HOME"
assert_nofile "without linking anything" "$I/bin/norma"
rm -rf "$I"

I=$(mktemp -d)
mkdir "$I/bin"
echo "somebody's script" > "$I/bin/norma"
inst
assert_eq "refuses a file where the link would go" "$RC" 1
assert_eq "and leaves it as it was" "$(cat "$I/bin/norma")" "somebody's script"
rm -rf "$I"

# Without a release there is nothing to pin, and installing master is what the
# script exists to avoid. The non-version tag must not count as one.
cd "$SRC"
git tag -d 0.2.0 0.10.0 0.9.0 >/dev/null
cd "$HOME_DIR"
I=$(mktemp -d)
inst
assert_eq "refuses a repository with no release" "$RC" 1
assert_has "saying so" "$OUT" "found no release"
assert_nofile "without cloning" "$I/norma"
rm -rf "$I"

cd "$SRC"
done_repo

# --------------------------------------------------------------------- end ----
echo ""
printf '%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
