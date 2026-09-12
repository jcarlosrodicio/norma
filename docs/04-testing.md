# 04 · Testing

```sh
scripts/harness/verify <what you were verifying>   # the gate: parse + the suite
test/run.sh                                        # the suite alone, while iterating
```

One suite, currently 218 tests, a couple of seconds. The gate runs it whole - it
is indivisible, so there is nothing to select - after parsing every shell file. It covers the gate's real
behaviour, the config contract, the hook's four refusals, every stack profile and
the detection that chooses one, the shape of the skill library, and `start`,
`install`, `upgrade` and `doctor`.

It lives here, once, because the gate is the same file in every project. Before
this repository existed, the same eight tests were duplicated across three
projects in two languages - and the hook, the piece that actually enforces
anything, had no tests at all.

## How it works

Every test runs against a **throwaway git repository** created by `new_repo`,
with a stub stack adapter from `test/fixtures/config.sh` whose gates and runners
only echo. Nothing depends on a toolchain being installed, and nothing touches
this repository.

Helpers:

- `new_repo` creates the temporary repository **and moves into it**, setting `$R`.
- `done_repo` returns to the repository root and deletes it.
- `with_gate` copies `core/verify` plus the stub config into place.
- `gate <args>` runs the gate, capturing combined output in `$OUT` and the exit
  code in `$RC`.
- `assert_eq`, `assert_has`, `assert_no`, `assert_file`, `assert_nofile`.

## Conventions, each one paid for

- **Never call `new_repo` inside a command substitution.** `R=$(new_repo)` runs
  the `cd` in a subshell, so every later command lands in *this* repository
  instead of the temporary one. That mistake once wrote the harness into its own
  repo and left a branch named after a test.
- **Do not trust clock resolution.** A stamp and a staged file created in the same
  second are not ordered by `-nt`, and a test that needs a stale stamp will pass
  by accident. Age it explicitly: `touch -t 202601011000 .harness/verified`.
- **Assert the exit code and the message.** The code proves the refusal; the text
  proves the human is told what to do next, which is half the value.
- **Assert what must *not* appear too**, with `assert_no` - that no placeholder
  survives in a refusal, that a stamp was not written by a refused run.
- **`--no-verify` in a test needs a comment** saying why. There is one, in the
  installer test: the hook it just installed correctly refuses that commit.

## Adding a test

Put it in the section that owns the behaviour - the gate, the config contract, the
hook, the stack profiles, the skill library, the installer - keep the name a
sentence about behaviour, and run the suite.
Every change to `core/` or `bin/` arrives with one; the count goes in the commit
message.
