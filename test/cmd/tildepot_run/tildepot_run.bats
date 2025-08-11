#!/usr/bin/env bats
#
# Tests for `tildepot run`

setup() {
  load ../../test_lib.sh
}

function test::_assert_run_cmd_usage() {
  assert_line "tildepot run"
  assert_line "Usage: tildepot run [options] HOOK"
  assert_line "Options:"
  assert_line --partial -- '-b, --bundle BUNDLE[]'
  assert_line --partial -- '-f, --force'
}

@test "describes run command" {
  # This test uses the `save` hook as stand-in for all hook commands.

  test::it "prints usage on '--help'"
  run tildepot run save --help
  assert_success
  test::_assert_run_cmd_usage

  test::it "prints usage on '-h'"
  run tildepot run save -h
  assert_success
  test::_assert_run_cmd_usage
}
