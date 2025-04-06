#!/bin/bash
#
# Run tests for tildepot.

# Enable strict mode
set -euo pipefail

ROOT="$(dirname "${BASH_SOURCE[0]}")/.."

source "$ROOT/src/lib.sh"

function test::bats() {
  local bats_args=("--recursive" "$ROOT/test")

  if command -v bats >/dev/null 2>&1; then
    # Run `bats` directly (e.g. in GitHub Actions).
    bats "${bats_args[@]}"
  else
    # Run `bats` via Docker.
    local container="tildepot-bats"
    # Reuse existing container if it exists.
    if docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
      docker start -i "$container"
    else
      docker run -it --name "$container" -v "$PWD:/code" bats/bats:latest "${bats_args[@]}"
    fi
  fi
}

function test::main() {
  lib::ohai "Test files with [bats]..."
  test::bats
  lib::ohai "All tests passed with [bats]."
}

test::main "$@"
