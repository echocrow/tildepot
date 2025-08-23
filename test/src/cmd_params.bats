#!/usr/bin/env bats
#
# Tests for `src/cmd.sh` parameters

# shellcheck disable=SC2034,SC2317,SC2329

setup() {
  load ../test_lib.sh

  load ../../src/cmd.sh
}

@test "does not accept any parameters by default" {
  function cmds::cmd:my_cmd() {
    echo 'hello world'
  }

  run cmd::main my_cmd arg1 arg2
  assert_failure
  refute_line 'hello world'
  assert_line --partial 'Error:'
  assert_line --partial 'Too many parameters'
  assert_line --partial 'expected 0, got 2'
}

@test "does not accept any parameters when set to zero" {
  function cmds::cmd:my_cmd:args() {
    CMD_CFG_PARAMS_COUNT=0
  }
  function cmds::cmd:my_cmd() {
    echo 'hello world'
  }

  run cmd::main my_cmd arg1 arg2
  assert_failure
  refute_line 'hello world'
  assert_line --partial 'Error:'
  assert_line --partial 'Too many parameters'
  assert_line --partial 'expected 0, got 2'
}

@test "fails when too few parameters are provided" {
  function cmds::cmd:my_cmd:args() {
    CMD_CFG_PARAMS_COUNT=1
  }
  function cmds::cmd:my_cmd() {
    echo 'hello world'
  }

  run cmd::main my_cmd
  assert_failure
  refute_line 'hello world'
  assert_line --partial 'Error:'
  assert_line --partial 'Too few parameters'
  assert_line --partial 'expected 1, got 0'
}

@test "fails when too many parameters are provided" {
  function cmds::cmd:my_cmd:args() {
    CMD_CFG_PARAMS_COUNT=1
  }
  function cmds::cmd:my_cmd() {
    echo 'hello world'
  }

  run cmd::main my_cmd arg1 arg2
  assert_failure
  refute_line 'hello world'
  assert_line --partial 'Error:'
  assert_line --partial 'Too many parameters'
  assert_line --partial 'expected 1, got 2'
}

@test "passes next args to command fn" {
  function cmds::cmd:my_cmd:args() {
    CMD_CFG_PARAMS_COUNT=2
  }
  function cmds::cmd:my_cmd() {
    echo "args: $# $*"
  }

  run cmd::main my_cmd arg1 arg2
  assert_success
  assert_output 'args: 2 arg1 arg2'
}

@test "removes space-separated cmd name from cmd args" {
  function cmds::cmd:my_cmd:args() {
    CMD_CFG_PARAMS_COUNT=2
  }
  function cmds::cmd:my_cmd() {
    echo "args: $# $*"
  }

  run cmd::main my_cmd arg1 arg2
  assert_success
  assert_output 'args: 2 arg1 arg2'
}

@test "accepts a range of params" {
  function cmds::cmd:my_cmd:args() {
    CMD_CFG_PARAMS_COUNT=2-4
  }
  function cmds::cmd:my_cmd() {
    echo "args: $#"
  }

  test::it 'fails when below lower limit'
  run cmd::main my_cmd arg1
  assert_failure
  assert_line --partial 'Too few parameters'

  test::it 'succeeds when matching lower limit'
  run cmd::main my_cmd arg1 arg2
  assert_success
  assert_output 'args: 2'

  test::it 'succeeds when between lower and upper limit'
  run cmd::main my_cmd arg1 arg2 arg3
  assert_success
  assert_output 'args: 3'

  test::it 'succeeds when matching upper limit'
  run cmd::main my_cmd arg1 arg2 arg3 arg4
  assert_success
  assert_output 'args: 4'

  test::it 'fails when exceeding upper limit'
  run cmd::main my_cmd arg1 arg2 arg3 arg4 arg5
  assert_failure
  assert_line --partial 'Too many parameters'
}

@test "accepts a min limit of params" {
  function cmds::cmd:my_cmd:args() {
    CMD_CFG_PARAMS_COUNT=3-
  }
  function cmds::cmd:my_cmd() {
    echo "args: $#"
  }

  test::it 'fails when below lower limit'
  run cmd::main my_cmd arg1 arg2
  assert_failure
  assert_line --partial 'Too few parameters'

  test::it 'succeeds when matching lower limit'
  run cmd::main my_cmd arg1 arg2 arg3
  assert_success
  assert_output 'args: 3'

  test::it 'succeeds when exceeding lower limit'
  run cmd::main my_cmd arg1 arg2 arg3 arg4
  assert_success
  assert_output 'args: 4'
}

@test "accepts a max limit of params" {
  function cmds::cmd:my_cmd:args() {
    CMD_CFG_PARAMS_COUNT=-2
  }
  function cmds::cmd:my_cmd() {
    echo "args: $#"
  }

  test::it 'succeeds without params'
  run cmd::main my_cmd
  assert_success
  assert_output 'args: 0'

  test::it 'succeeds when below upper limit'
  run cmd::main my_cmd arg1
  assert_success
  assert_output 'args: 1'

  test::it 'succeeds when matching upper limit'
  run cmd::main my_cmd arg1 arg2
  assert_success
  assert_output 'args: 2'

  test::it 'fails when exceeding upper limit'
  run cmd::main my_cmd arg1 arg2 arg3
  assert_failure
  assert_line --partial 'Too many parameters'
}
