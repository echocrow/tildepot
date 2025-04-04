#!/usr/bin/env bats

TILDEPOT_VERSION=0.0.0-test

setup() {
  export BATS_LIB_PATH=${BATS_LIB_PATH:-"/usr/lib"}
  bats_load_library bats-support
  bats_load_library bats-assert
  bats_load_library bats-file

  DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" >/dev/null 2>&1 && pwd)"
  PATH="$DIR/../dist:$PATH"
}

@test "prints basic info by default" {
  run tildepot
  assert_line "tildepot $TILDEPOT_VERSION"
  assert_line --partial "Usage:"
  assert_line "Options:"
  assert_line "Commands:"
}

@test "prints version on 'version'" {
  run tildepot version
  assert_output "tildepot $TILDEPOT_VERSION"
}
@test "prints version on '--version'" {
  run tildepot --version
  assert_output "tildepot $TILDEPOT_VERSION"
}
@test "prints version on '-v'" {
  run tildepot -v
  assert_output "tildepot $TILDEPOT_VERSION"
}

@test "errors on invalid command" {
  run tildepot invalid_command
  assert_failure
}
@test "errors on invalid option" {
  run tildepot --invalid-command
  assert_failure
}
