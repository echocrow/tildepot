#!/bin/bash
#
# Format files for tildepot.

# Enable strict mode
set -euo pipefail

ROOT="$(dirname "${BASH_SOURCE[0]}")/.."

source "$ROOT/src/lib.sh"
source "$ROOT/scripts/run/shfmt.sh"

SHFMT_ARGS=(
  --indent 2
  --simplify
)

function format::src() {
  lib::ohai "Formatting source files with [shfmt]..."
  while read -r file; do
    echo "- ${file#"$ROOT"/}"
    shfmt "${SHFMT_ARGS[@]}" --write "$file"
  done < <(find "$ROOT" -type f -not -name ".*" \( \
    -name "*.sh" -o \
    -name "*.bats" -o \
    -path "$ROOT/cmd/*" \
    \))
  lib::ohai "All files formatted."
}

function format::build() {
  lib::ohai "Formatting build files with [shfmt]..."
  while read -r file; do
    echo "- ${file#"$ROOT"/}"
    shfmt "${SHFMT_ARGS[@]}" --write "$file"
  done < <(find "$ROOT" -type f -not -name ".*" -path "$ROOT/dist/*")
  lib::ohai "All files formatted."
}

function format::check() {
  lib::ohai "Checking files with [shfmt]..."
  while read -r file; do
    echo "- ${file#"$ROOT"/}"
    shfmt "${SHFMT_ARGS[@]}" --diff "$file"
  done < <(find "$ROOT" -type f -not -name ".*" \( \
    -name "*.sh" -o \
    -name "*.bats" -o \
    -path "$ROOT/cmd/*" -o \
    -path "$ROOT/dist/*" \
    \))
  lib::ohai "All files passed [shfmt]."
}

case ${1-} in
src) format::src ;;
build) format::build ;;
check) format::check ;;
*) lib::abort "Unknown command: ${1-}" ;;
esac
