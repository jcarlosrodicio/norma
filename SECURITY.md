# Security policy

norma installs a git hook and a verification gate into other repositories, and the
gate runs whatever commands a project's `scripts/harness/config.sh` names. Treat it
as you would any tool that runs code on commit.

## What norma does and does not do

- It is POSIX sh with no runtime dependencies, and it never reaches the network.
- `upgrade` replaces only the files the harness owns, and `install` writes a
  project-owned file only when it does not exist yet; the table in
  [`docs/01-architecture.md`](docs/01-architecture.md) is the contract.
  `scripts/harness/config.sh` belongs to the project, and its commands are the
  project's.
- The hook is a guard against forgetting, not a security boundary:
  `git commit --no-verify` skips it, which is why the full gate belongs in CI too.

## Reporting a vulnerability

Report it privately through
[GitHub's private vulnerability reporting](https://github.com/jcarlosrodicio/norma/security/advisories/new)
for this repository, with a minimal reproduction and no secrets. Please do not open
a public issue for something exploitable before it is fixed.

Examples of what counts: a way for `install` or `upgrade` to write or delete a file
the project owns, a path that escapes the repository, or a way for a change to get
past the gate or the hook without `--no-verify`.
