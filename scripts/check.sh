#!/bin/bash
#
# Run checks for tildepot.

# Enable strict mode
set -euo pipefail

ROOT="$(dirname "${BASH_SOURCE[0]}")/.."

source "$ROOT/src/lib.sh"
source "$ROOT/scripts/run/shellcheck.sh"

function check::shellcheck() {
  lib::ohai "Checking files with [shellcheck]..."
  local shellcheck_failed=
  while read -r file; do
    echo "- ${file#"$ROOT"/}"
    shellcheck "$file" || shellcheck_failed=1
  done < <(find "$ROOT" -type f -not -name ".*" \( \
    -name "*.sh" -o \
    -path "$ROOT/cmd/*" -o \
    -path "$ROOT/dist/*" -o \
    \( -path "$ROOT/test/*" -name "*.bats" \) \
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
