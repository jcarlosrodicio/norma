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
assert_has "auto-run-task delivers after closing, not instead of it" \
  "$(cat "$HOME_DIR/skills/auto-run-task/SKILL.md")" "### Stage 9 - Deliver"
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
