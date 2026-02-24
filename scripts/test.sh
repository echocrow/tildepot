#!/usr/bin/env bash
#
# Run tests for tildepot.

# Enable strict mode
set -euo pipefail

REL_ROOT="$(dirname "${BASH_SOURCE[0]}")/.."
ROOT="$(realpath "$REL_ROOT")"

source "$ROOT/src/lib.sh"
source "$ROOT/scripts/scripts_lib.sh"

# Optional local bats binary, useful to test code on the current OS & setup. Use
# with caution, as tests may mess with global state, such as bin directories.
# source "$ROOT/scripts/run/bats.sh"

function test::bats() {
  local tests=("$@")
  if [[ ${#tests[@]} -eq 0 ]]; then
    tests+=("$REL_ROOT/test")
  else
    local _tests=()
    local test
    for test in "${tests[@]}"; do
      test="$REL_ROOT/$test"
      [[ ! -d $test && -f ${test}.bats ]] && test="${test}.bats"
      _tests+=("$test")
    done
    tests=("${_tests[@]}")
  fi

  local bats_args=("--recursive" "${tests[@]}")

  local bats_bin="bats"
  if tilde::cmd_exists "$bats_bin"; then
    # Run `bats` directly (e.g. in GitHub Actions).
    "$bats_bin" "${bats_args[@]}"
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
