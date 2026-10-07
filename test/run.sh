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
  # `-b master` explícito, no el defecto de la máquina. Media docena de
  # aserciones de esta suite nombran `master` como la rama por defecto, y el
  # primer CI lo dijo: el runner tiene `init.defaultBranch=main` y el hook
  # refusaba nombrando `main`, correctamente. La suite era la que daba por hecho
  # la configuración de git de quien la ejecuta.
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

# El veredicto es el estado del comando, y nada entre medias puede cambiarlo.
# Medido el 17-sep-2026 en grodar: `rtk pnpm typecheck` salía 0 donde
# `pnpm typecheck` salía 1, así que la verificación pasó con el typecheck roto,
# el hook dejó commitear y el fallo apareció en CI un minuto después. El envoltorio
# que recorta la salida no puede opinar sobre si algo pasó. Aquí se simula con un
# `rtk` de mentira que siempre sale 0: si el gate lo consultara, este test pasaría
# en verde con el comando fallando.
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
assert_has "auto-run-task ends at a pull request and never merges it" \
  "$auto" "never merge the pull request"
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
rm -f scripts/harness/run
"$NORMA" upgrade --force >/dev/null 2>&1
assert_eq "upgrade restores the gate it owns" "$(head -1 scripts/harness/verify)" "#!/bin/sh"
assert_file "and brings the run context to a project installed before it existed" \
  scripts/harness/run
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

# --------------------------------------------------------------------- end ----
echo ""
printf '%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
