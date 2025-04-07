#!/bin/bash
#
# Run tests for tildepot.

# Enable strict mode
set -euo pipefail

ROOT="$(dirname "${BASH_SOURCE[0]}")/.."

source "$ROOT/src/lib.sh"

function test::bats() {
  local tests="${1-}"
  if [[ -z $tests ]]; then
    tests="$ROOT/test"
  else
    tests="$ROOT/$tests"
    [[ ! -d $tests && -f ${tests}.bats ]] && tests="${tests}.bats"
  fi

  local bats_args=("--recursive" "$tests")

  if tilde::cmd_exists bats; then
    # Run `bats` directly (e.g. in GitHub Actions).
    bats "${bats_args[@]}"
  else
    # Run `bats` via Docker.
    local container="tildepot-bats"

    local img_name="tildepot-bats:v1"
    if ! docker inspect "$img_name" >/dev/null 2>&1; then
      docker build -t "$img_name" "$ROOT/test"
    fi
    docker run -it --rm \
      --name "$container" \
      -v "$PWD:/code" \
      --network none \
      "$img_name" \
      "${bats_args[@]}"
  fi
}

function test::main() {
  lib::ohai "Test files with [bats]..."
  test::bats "$@"
  lib::ohai "All tests passed with [bats]."
}

test::main "$@"
