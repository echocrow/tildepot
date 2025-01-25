#!/bin/bash
#
# Start dev mode for tildepot.

# shellcheck source-path=../

# Enable strict mode
set -euo pipefail

ROOT="$(dirname "${BASH_SOURCE[0]}")/.."

source "$ROOT/src/lib.sh"

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

  # Create a named pipe
  local fifo
  fifo=$(mktemp -u)
  mkfifo "$fifo"

  # Abuse `tail` to watch files for changes.
  tail -f "${files[@]}" >"$fifo" 2>&1 &

  lib::ohai "Watching ${#files[@]} files:"
  printf -- "- %s\n" "${files[@]/$ROOT\//}"

  local last_build=
  while IFS= read -r line <&3 || [[ -n "$line" ]]; do
    [[ "$SECONDS" == "$last_build" ]] && continue
    last_build="$SECONDS"
    dev::build &
  done 3<"$fifo"

  # Clean up
  rm "$fifo"
}

dev::main "$@"
