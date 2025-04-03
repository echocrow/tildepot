#!/bin/bash
#
# Run tests for tildepot.

# shellcheck source-path=../

# Enable strict mode
set -euo pipefail

ROOT="$(dirname "${BASH_SOURCE[0]}")/.."

source "$ROOT/src/lib.sh"
source "$ROOT/scripts/run/shellcheck.sh"

function test::shellcheck() {
  local shellcheck_failed=
  while read -r file; do
    lib::ohai "shellcheck [${file#"$ROOT"/}]"
    shellcheck "$file" || shellcheck_failed=1
  done < <(find "$ROOT" -type f -name '*.sh')
  [[ $shellcheck_failed ]] && lib::abort "Shellcheck failed."
}

function test::main() {
  test::shellcheck
}

test::main "$@"
