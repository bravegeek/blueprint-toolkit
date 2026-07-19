#!/usr/bin/env sh
# One-command remote bootstrap for the blueprint toolkit.
#
# Fetches the toolkit source into a temp dir and runs its install.sh,
# forwarding every argument after `--` unchanged — any verb (`init`,
# `add-skill <name>`, `doctor`) works, not just `init`. Lets a new user
# onboard without cloning the repo first:
#
#   curl -fsSL <raw-url>/bootstrap.sh | bash -s -- init .
#   curl -fsSL <raw-url>/bootstrap.sh | bash -s -- init /path/to/project my-project
#   curl -fsSL <raw-url>/bootstrap.sh | bash -s -- add-skill assessment .
#
# The fetched checkout lives only in a temp dir for this run (cleaned up on
# exit) — re-run the one-liner with a different verb for each step rather
# than expecting a lingering local checkout.
#
# Requires nothing beyond POSIX shell, curl, tar, and the toolkit's own
# Node 20+ / npx prerequisite (checked by `doctor`, which `init` runs at the
# end). No package manager, no git, no global install.
#
# Pin a tag/commit instead of a branch for reproducibility by setting
# BLUEPRINT_TOOLKIT_REF, e.g.:
#   BLUEPRINT_TOOLKIT_REF=v1.2.3 curl -fsSL <raw-url>/bootstrap.sh | bash -s -- init .

set -eu

REPO="${BLUEPRINT_TOOLKIT_REPO:-bravegeek/blueprint-toolkit}"
REF="${BLUEPRINT_TOOLKIT_REF:-main}"
TARBALL_URL="https://codeload.github.com/${REPO}/tar.gz/${REF}"

command -v curl >/dev/null 2>&1 || {
  echo "bootstrap.sh: curl is required but not found" >&2
  exit 1
}
command -v tar >/dev/null 2>&1 || {
  echo "bootstrap.sh: tar is required but not found" >&2
  exit 1
}

WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/blueprint-toolkit-bootstrap.XXXXXX")
cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT INT TERM

echo "Fetching blueprint toolkit (${REPO}@${REF})..." >&2
curl -fsSL "$TARBALL_URL" | tar -xz -C "$WORK_DIR"

SRC_DIR=$(find "$WORK_DIR" -mindepth 1 -maxdepth 1 -type d | head -n1)
[ -n "$SRC_DIR" ] && [ -f "$SRC_DIR/install.sh" ] || {
  echo "bootstrap.sh: fetched archive did not contain install.sh" >&2
  exit 1
}

# install.sh is bash (its own shebang requires it, e.g. for process
# substitution) — invoke it via bash explicitly rather than `sh`, which on
# many systems is dash and would break on bash-only syntax.
#
# Not `exec`: exec replaces this shell's process image, which would skip the
# `cleanup` trap above and leak the fetched checkout in $WORK_DIR. Run it as
# a normal command and propagate its exit status instead.
status=0
bash "$SRC_DIR/install.sh" "$@" || status=$?
exit "$status"
