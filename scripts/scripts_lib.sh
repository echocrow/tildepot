#!/usr/bin/env bash
#
# Helper functions for tildepot scripts.

function scripts::watch() {
  local root="$1"
  shift

  local files=()
  while [[ $# -gt 0 && $1 != '--' ]]; do
    files+=("$1")
    shift
  done

  if [[ $1 != '--' ]]; then
    lib::abort "Missing '--' delimiter argument"
  fi
  shift

  local cmd=("$@")

  # Create a named pipe
  local fifo
  fifo=$(mktemp -u)
  mkfifo "$fifo"

  # Abuse `tail` to watch files for changes.
  tail -f "${files[@]}" >"$fifo" 2>&1 &

  lib::ohai "Watching ${#files[@]} files:"
  printf -- "- %s\n" "${files[@]/$root\//}"

  local last_build=
  while IFS= read -r line <&3 || [[ -n $line ]]; do
    [[ $SECONDS == "$last_build" ]] && continue
    last_build="$SECONDS"
    "${cmd[@]}" &
  done 3<"$fifo"

  # Clean up
  rm "$fifo"
}
