#!/usr/bin/env bats
#
# Tests for `tildepot`

setup() {
  load ../test_lib.sh
}

_assert_usage() {
  assert_line "tildepot $TEST_VERSION"
  assert_line --partial "Usage:"
  assert_line "Options:"
  assert_line "Commands:"
}
@test "errors and prints usage by default" {
  run tildepot
  assert_failure
  _assert_usage
}
@test "prints usage on 'help'" {
  run tildepot help
  assert_success
  _assert_usage
}
@test "prints usage on '--help'" {
  run tildepot --help
  assert_success
  _assert_usage
}
@test "prints usage on '-h'" {
  run tildepot -h
  assert_success
  _assert_usage
}

@test "prints version on 'version'" {
  run tildepot version
  assert_success
  assert_output "$TEST_VERSION"
}
@test "prints version on '--version'" {
  run tildepot --version
  assert_success
  assert_output "$TEST_VERSION"
}
@test "prints version on '-v'" {
  run tildepot -v
  assert_success
  assert_output "$TEST_VERSION"
}

@test "errors on invalid option" {
  run tildepot --my-invalid-option
  assert_failure
  assert_output --partial "Unknown option: --my-invalid-option"
}
@test "errors on invalid command" {
  run tildepot my_invalid_command
  assert_failure
  assert_output --partial "Unknown command: my_invalid_command"
}
