#!/usr/bin/env bats
#
# Tests for `src/cmd.sh`

# shellcheck disable=SC2034,SC2317,SC2329

setup() {
  load ../test_lib.sh

  load ../../src/cmd.sh

  function cmds::app_name() {
    echo 'cmd-test'
  }
  function cmds::app_version() {
    echo '0.0.1-test'
  }
}

@test "runs command function" {
  function cmds::cmd:my_cmd() {
    echo 'my command'
  }

  run cmd::main my_cmd
  assert_success
  assert_output 'my command'
}

@test "fails when command function does not exist" {
  run cmd::main my_cmd
  assert_failure
  assert_line --partial 'Error:'
  assert_line --partial 'Unknown command'
  assert_line --partial 'my_cmd'
}

@test "runs command with space-separated name" {
  function cmds::cmd:my_cmd() {
    echo 'my command'
  }

  run cmd::main my cmd
  assert_success
  assert_output 'my command'
}

@test "fails & prints app name, version, and help when no arguments are provided" {
  run cmd::main
  assert_failure
  assert_line 'cmd-test 0.0.1-test'
  assert_line 'Usage: cmd-test [command] [options] [arguments]'
}
