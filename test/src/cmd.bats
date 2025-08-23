#!/usr/bin/env bats
#
# Tests for `src/cmd.sh`

setup() {
  load ../test_lib.sh

  load ../../src/cmd.sh
}

@test "runs command function" {
  # shellcheck disable=SC2317,SC2329
  function cmds::cmd:my_cmd() {
    echo 'hi'
  }

  run cmd::main my_cmd
  assert_success
  assert_output 'hi'
}

@test "fails when command function does not exist" {
  run cmd::main my_cmd
  assert_failure
  assert_line --partial 'Error:'
  assert_line --partial 'Unknown command'
  assert_line --partial 'my_cmd'
}

@test "runs command with space-separated name" {
  # shellcheck disable=SC2317,SC2329
  function cmds::cmd:my_cmd() {
    echo 'hi'
  }

  run cmd::main my cmd
  assert_success
  assert_output 'hi'
}
