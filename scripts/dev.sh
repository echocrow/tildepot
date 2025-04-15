#!/bin/bash
#
# Start dev mode for tildepot.

# Enable strict mode
set -euo pipefail

ROOT="$(dirname "${BASH_SOURCE[0]}")/.."

source "$ROOT/src/lib.sh"
source "$ROOT/scripts/scripts_lib.sh"

export BUILDING=
function dev::build() {
  source "$ROOT/scripts/build.sh"
}

function dev::main() {
  # Gather files
  local files=()
  # Gather files: src & scripts
  while read -r file; do
    files+=("$file")
  done < <(find "$ROOT/src" "$ROOT/scripts" -type f -name '*.sh')
  # Gather files: cmd
  while read -r file; do
    files+=("$file")
  done < <(find "$ROOT/cmd" -type f)

  scripts::watch "$ROOT" "${files[@]}" -- dev::build
}

dev::main "$@"
