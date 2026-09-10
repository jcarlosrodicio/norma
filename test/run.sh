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
HARNESS=$HOME_DIR/bin/harness
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
  git init -q
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

# ------------------------------------------------------- the gate contract ----
echo ""
echo "the config.sh contract"

new_repo
mkdir -p scripts/harness
cp "$HOME_DIR/core/verify" scripts/harness/verify
gate --docs-only
assert_eq "no config.sh is a hard failure" "$RC" 2
assert_has "and it says how to fix it" "$OUT" "harness install"
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

# ---------------------------------------------------------- the installer ----
echo ""
echo "harness install"

new_repo
mkdir -p src && echo '{}' > package.json
OUT=$("$HARNESS" install --profile node)
assert_has "install points at the setup interview" "$OUT" "harness-setup/SKILL.md"
assert_file "vendors the gate" scripts/harness/verify
assert_file "writes a config from the profile" scripts/harness/config.sh
assert_file "vendors the hook" .githooks/pre-commit
assert_file "vendors run-task as a real directory" .agents/skills/run-task/SKILL.md
assert_file "vendors the setup interview" .agents/skills/harness-setup/SKILL.md
assert_file "and the architecture reference" .agents/skills/architecture-guidelines/references/backend.md
assert_file "creates the loop template" docs/harness/mandatory-steps.md
assert_file "creates the adoption map template" docs/harness/architecture-rules.md
assert_file "creates AGENTS.md" AGENTS.md
assert_eq "points CLAUDE.md at it" "$(readlink CLAUDE.md)" "AGENTS.md"
assert_eq "arms the hook path" "$(git config --get core.hooksPath)" ".githooks"
assert_has "AGENTS.md carries the block" "$(cat AGENTS.md)" "harness:begin"
assert_has "and points at the loop entry point" "$(cat AGENTS.md)" "run-task"
assert_eq "the claude symlink stays inside the repo" "$(readlink .claude/skills/run-task)" "../../.agents/skills/run-task"

git add -A >/dev/null 2>&1
# --no-verify on purpose: this test is about the installer, and the hook it just
# installed correctly refuses a commit on the default branch without a stamp.
git commit -qm harness --no-verify
"$HARNESS" install --profile node >/dev/null
assert_eq "installing twice changes nothing" "$(git status --porcelain | wc -l | tr -d ' ')" "0"
done_repo

new_repo
echo '{}' > package.json
"$HARNESS" install --profile node >/dev/null
echo "# MINE" > scripts/harness/config.sh
echo "# MY LOOP" > docs/harness/mandatory-steps.md
"$HARNESS" install --profile node >/dev/null
assert_eq "an existing config.sh is never overwritten" "$(cat scripts/harness/config.sh)" "# MINE"
assert_eq "nor are the project's own documents" "$(cat docs/harness/mandatory-steps.md)" "# MY LOOP"
done_repo

new_repo
echo '{}' > package.json
printf '# My rules\n\nSomething mine above.\n' > AGENTS.md
"$HARNESS" install --profile node >/dev/null
assert_has "existing AGENTS.md content is preserved" "$(cat AGENTS.md)" "Something mine above."
assert_has "and the block is appended" "$(cat AGENTS.md)" "Verification gate"
before=$(cat AGENTS.md)
"$HARNESS" install --profile node >/dev/null
assert_eq "re-injecting the block is idempotent" "$(cat AGENTS.md)" "$before"
done_repo

new_repo
echo '{}' > package.json
printf '# Mine\n\n## Harness\n\nMy own harness notes, with run-task and scripts/harness/verify.\n' > AGENTS.md
"$HARNESS" install --profile node >/dev/null
assert_eq "an existing Harness section is left alone" "$(grep -c '^## Harness' AGENTS.md)" "1"
assert_has "with its own content intact" "$(cat AGENTS.md)" "My own harness notes"
done_repo

echo ""
echo "harness upgrade"

new_repo
echo '{}' > package.json
"$HARNESS" install --profile node >/dev/null
echo "# MINE" > scripts/harness/config.sh
echo "broken" > scripts/harness/verify
printf '# Mine\n\n## Harness\n\nMy notes: run-task, scripts/harness/verify.\n' > AGENTS.md
"$HARNESS" upgrade --force >/dev/null 2>&1
assert_eq "upgrade restores the gate it owns" "$(head -1 scripts/harness/verify)" "#!/bin/sh"
assert_eq "and leaves config.sh alone" "$(cat scripts/harness/config.sh)" "# MINE"
assert_has "and never touches AGENTS.md" "$(cat AGENTS.md)" "My notes"
done_repo

echo ""
echo "harness doctor"

new_repo
set +e
OUT=$("$HARNESS" doctor 2>&1); RC=$?
set -e
assert_eq "fails on a repository without a harness" "$RC" 1
assert_has "and says what is missing" "$OUT" "harness install"
done_repo

new_repo
echo '{}' > package.json
"$HARNESS" install --profile node >/dev/null
set +e
OUT=$("$HARNESS" doctor 2>&1); RC=$?
set -e
assert_eq "passes on a fresh install" "$RC" 0
assert_has "warning about the templates it cannot fill" "$OUT" "TODO(harness)"
done_repo

new_repo
echo '{}' > package.json
"$HARNESS" install --profile node >/dev/null
ln -sfn "$HOME/somewhere/skill" .claude/skills/escaping
set +e
OUT=$("$HARNESS" doctor 2>&1); RC=$?
set -e
assert_eq "catches a symlink that escapes the repository" "$RC" 1
assert_has "explaining why it matters" "$OUT" "another machine"
done_repo

# --------------------------------------------------------------------- end ----
echo ""
printf '%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
