#!/usr/bin/env bash
#
# Bats test helpers

# Setup
bats_load_library bats-support
bats_load_library bats-assert
bats_load_library bats-file
# Add tildepot to PATH
PATH="$BATS_CWD/dist:$PATH"

# Assert that a command's usage output is correct
lib::_assert_cmd_usage() {
  local cmd="$1"
  assert_line "tildepot $cmd"
  assert_line --partial "Usage: tildepot $cmd "
  assert_line "Options:"
  assert_line "Commands:"
}

# Log a sub-test
lib::it() {
  echo "└─ $1"
}

# Test a sub-command
lib::test_cmd() {
  local cmd="$1"

  lib::it "errors and usage by default"
  run tildepot "$cmd"
  assert_failure
  lib::_assert_cmd_usage "$cmd"

  lib::it "prints usage on '--help'"
  run tildepot "$cmd" --help
  lib::_assert_cmd_usage "$cmd"

  lib::it "prints usage on '-h'"
  run tildepot "$cmd" -h
  lib::_assert_cmd_usage "$cmd"

  lib::it "errors on invalid option"
  run tildepot "$cmd" --my-invalid-command
  assert_failure
  assert_output --partial "Unknown option: --my-invalid-command"

  lib::it "errors on invalid command"
  run tildepot "$cmd" my_invalid_command
  assert_failure
  assert_output --partial "Unknown command: my_invalid_command"
}
