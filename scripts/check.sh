#!/usr/bin/env bash
#
# Run checks for tildepot.

# Enable strict mode
set -euo pipefail

ROOT="$(dirname "${BASH_SOURCE[0]}")/.."

source "$ROOT/src/lib.sh"
source "$ROOT/scripts/run/shellcheck.sh"

SRC_FIND_ARGS=(
  -type f
  -not -name ".*"
  -not -path "$ROOT/scripts/.bin/*"
)

function check::shellcheck() {
  lib::ohai "Checking files with [shellcheck]..."
  local shellcheck_failed=
  while read -r file; do
    echo "- ${file#"$ROOT"/}"
    shellcheck "$file" || shellcheck_failed=1
  done < <(find "$ROOT" "${SRC_FIND_ARGS[@]}" \( \
    -name "*.sh" -o \
    -name "*.bats" -o \
    -path "$ROOT/scripts/git_hooks/*" -o \
    -path "$ROOT/cmd/*" -o \
    -path "$ROOT/dist/*" -not -path "$ROOT/dist/release/*" \
    \))
  if [[ $shellcheck_failed ]]; then
    lib::abort "[shellcheck] found issues in one or more files!"
  fi
  lib::ohai "All files passed [shellcheck]."
}

function check::main() {
  check::shellcheck
}

check::main "$@"
