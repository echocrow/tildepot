#!/usr/bin/env bats
#
# Tests for `src/cmd.sh`

# shellcheck disable=SC2030,SC2031,SC2034,SC2317,SC2329

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

@test "runs root command when no command is provided" {
  function cmds::root_cmd() {
    echo 'my root cmd'
  }

  run cmd::main
  assert_success
  assert_output 'my root cmd'
}

@test "fails when root command is undefined and no command is provided" {
  run cmd::main
  assert_failure
  assert_line 'cmd-test 0.0.1-test'
  assert_line 'Usage: cmd-test [command] [options] [arguments]'
}

@test "accepts and sets root opts" {
  function cmds::root_args() {
    CMD_CFG_OPTS+=(f foo '' '')
  }
  function cmds::root_cmd() {
    if [[ -n ${CMD_OPT_foo-} ]]; then
      echo 'foo opt set'
    else
      echo 'foo opt not set'
    fi
  }

  test::it 'does not set opt when not provided'
  run cmd::main
  assert_success
  assert_output 'foo opt not set'

  test::it 'sets opt when provided (short format)'
  run cmd::main -f
  assert_success
  assert_output 'foo opt set'

  test::it 'sets opt when provided (long format)'
  run cmd::main --foo
  assert_success
  assert_output 'foo opt set'
}

@test "accepts and sets global opts" {
  function cmds::global_args() {
    CMD_CFG_OPTS+=(f foo '' '')
  }
  function cmds::root_cmd() {
    if [[ -n ${CMD_OPT_foo-} ]]; then
      echo 'foo opt set'
    else
      echo 'foo opt not set'
    fi
  }

  test::it 'does not set opt when not provided'
  run cmd::main
  assert_success
  assert_output 'foo opt not set'

  test::it 'sets opt when provided (short format)'
  run cmd::main -f
  assert_success
  assert_output 'foo opt set'

  test::it 'sets opt when provided (long format)'
  run cmd::main --foo
  assert_success
  assert_output 'foo opt set'
}

@test "fails on invalid option" {
  function cmds::global_args() {
    CMD_CFG_OPTS+=(f foo '' '')
  }
  function cmds::root_cmd() {
    echo 'my root cmd'
  }

  run cmd::main --bar
  assert_failure
  refute_line 'my root cmd'
  assert_output 'Error: Unknown option: --bar'
}
