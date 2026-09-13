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
assert_has "update-docs names the roadmap, which no diff points at" \
  "$(cat "$HOME_DIR/skills/update-docs/SKILL.md")" "roadmap entry"
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
"$NORMA" upgrade --force >/dev/null 2>&1
assert_eq "upgrade restores the gate it owns" "$(head -1 scripts/harness/verify)" "#!/bin/sh"
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

# --------------------------------------------------------------------- end ----
echo ""
printf '%s passed, %s failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
