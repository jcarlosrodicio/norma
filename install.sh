#!/bin/sh
# Installs norma from a release tag, or moves an existing install to another one.
#
#   curl -fsSL https://raw.githubusercontent.com/jcarlosrodicio/norma/master/install.sh | sh
#
# NORMA_VERSION pins a release; without it, the latest one. NORMA_HOME is where the
# checkout lives and NORMA_BIN_DIR where the `norma` command is linked. Needs git.
set -eu

REPO=${NORMA_REPO:-https://github.com/jcarlosrodicio/norma.git}
DEST=${NORMA_HOME:-$HOME/.local/share/norma}
BIN_DIR=${NORMA_BIN_DIR:-$HOME/.local/bin}
LINK=$BIN_DIR/norma

die() { printf 'install.sh: %s\n' "$*" >&2; exit 1; }

command -v git >/dev/null 2>&1 || die "git is required"

# Refuse before touching anything: a link to another checkout is somebody's
# working copy, and a directory that is not a checkout is somebody's files.
if [ -L "$LINK" ]; then
  [ "$(readlink "$LINK")" = "$DEST/bin/norma" ] ||
    die "$LINK already points at $(readlink "$LINK"). Remove it to install here, or set NORMA_BIN_DIR."
elif [ -e "$LINK" ]; then
  die "$LINK exists and is not a link. Remove it to install here, or set NORMA_BIN_DIR."
fi
if [ -e "$DEST" ] && [ ! -d "$DEST/.git" ]; then
  die "$DEST exists and is not a norma checkout. Move it, or set NORMA_HOME."
fi

VERSION=${NORMA_VERSION:-}
if [ -z "$VERSION" ]; then
  # By version, not by string: 0.10.0 sorts before 0.2.0 as text.
  VERSION=$(git ls-remote --tags --refs "$REPO" | sed 's|.*refs/tags/||' |
    grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)
  [ -n "$VERSION" ] || die "found no release in $REPO, or could not reach it"
fi

if [ -d "$DEST/.git" ]; then
  git -C "$DEST" fetch -q --tags origin
  git -C "$DEST" -c advice.detachedHead=false checkout -q "$VERSION"
else
  mkdir -p "$(dirname "$DEST")"
  # Not `clone --branch`: with an annotated tag, git warns that it is not a commit.
  git clone -q --no-checkout "$REPO" "$DEST"
  git -C "$DEST" -c advice.detachedHead=false checkout -q "$VERSION"
fi

mkdir -p "$BIN_DIR"
[ -L "$LINK" ] || ln -s "$DEST/bin/norma" "$LINK"

printf '%s installed in %s, linked as %s\n' "$("$DEST/bin/norma" version)" "$DEST" "$LINK"
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) printf 'Add %s to your PATH to run it as `norma`.\n' "$BIN_DIR" ;;
esac
