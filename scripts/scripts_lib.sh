#!/usr/bin/env bash
#
# Helper functions for tildepot scripts.

ROOT="$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")"

export SCRIPTS_SRC_FIND_ARGS=(
  -type f
  -not -name ".*"
  -not -path "$ROOT/scripts/.bin/*"
)

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

function scripts::download_github_archive() {
  local org="${1?}"
  local repo="${2?}"
  local version="${3?}"
  local target_dir="${4?}"

  local repo_url="https://github.com/${org}/${repo}/archive/refs/tags/${version}.tar.gz"
  mkdir -p "$target_dir"
  lib::ohai "Downloading [${org}/${repo}] $version..."
  lib::download "$repo_url" >"$target_dir.tar.gz"
  tar -xzf "$target_dir.tar.gz" -C "$target_dir" --strip-components=1
  rm -f "$target_dir.tar.gz"
}
