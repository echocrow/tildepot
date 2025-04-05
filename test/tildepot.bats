#!/usr/bin/env bats
#
# Tests for `tildepot`

TILDEPOT_VERSION=0.0.0-test

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert
  bats_load_library bats-file

  PATH="$BATS_CWD/dist:$PATH"
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

_assert_help() {
  assert_line "tildepot $TILDEPOT_VERSION"
  assert_line --partial "Usage:"
  assert_line "Options:"
  assert_line "Commands:"
}
@test "prints help on 'help'" {
  run tildepot help
  _assert_help
}
@test "prints help on '--help'" {
  run tildepot --help
  _assert_help
}
@test "prints help on '-h'" {
  run tildepot -h
  _assert_help
}

@test "prints help by default" {
  run tildepot
  _assert_help
}

@test "errors on invalid command" {
  run tildepot invalid_command
  assert_failure
}
@test "errors on invalid option" {
  run tildepot --invalid-command
  assert_failure
}
