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

@test "fails & prints app name, version, and help when no arguments are provided" {
  run cmd::main
  assert_failure
  assert_line 'cmd-test 0.0.1-test'
  assert_line 'Usage: cmd-test [command] [options] [arguments]'
}

###
# Pre-command hook.
###

@test "invokes 'cmds::handle_pre_cmd' hook before command" {
  function cmds::handle_pre_cmd() {
    echo "pre-cmd hook"
  }
  function cmds::cmd:my_cmd() {
    echo "my command"
  }

  run cmd::main my_cmd
  assert_success
  assert_output "$(test::dedent "
    pre-cmd hook
    my command
  ")"
}

@test "does not invoke 'cmds::handle_pre_cmd' on invalid command or opt" {
  function cmds::handle_pre_cmd() {
    echo "pre-cmd hook"
  }
  function cmds::cmd:my_cmd() {
    true
  }

  test::it 'skips on invalid command'
  run cmd::main invalid_cmd
  assert_failure
  refute_line 'pre-cmd hook'

  test::it 'skips on invalid opt'
  run cmd::main my_cmd --invalid-opt
  assert_failure
  refute_line 'pre-cmd hook'
}

@test "flushes opt values before 'cmds::handle_pre_cmd' hook" {
  function cmds::handle_pre_cmd() {
    echo "opt=[${CMD_OPT_opt-}]"
  }
  function cmds::cmd:my_cmd:args() {
    CMD_CFG_OPTS+=(o opt 'O' '')
  }
  function cmds::cmd:my_cmd() {
    true
  }

  run cmd::main my_cmd --opt foo
  assert_success
  assert_output "opt=[foo]"
}

###
# Commands with underscores.
###

@test "fails when namespaced sub-command does not exist" {
  function cmds::cmd:bar() {
    true
  }

  run cmd::main foo bar
  assert_failure
  assert_line --partial 'Error: Unknown command'

  test::it 'prints both namespace and full command in error'
  assert_output 'Error: Unknown commands: "foo" | "foo bar"'
}

@test "runs command with underscore-separated namespace" {
  function cmds::cmd:my_cmd() {
    echo 'my command'
  }

  test::it 'supports space notation (separate args)'
  run cmd::main my cmd
  assert_success
  assert_output 'my command'

  test::it 'supports space notation (single arg)'
  run cmd::main 'my cmd'
  assert_success
  assert_output 'my command'

  test::it 'supports underscore notation'
  run cmd::main my_cmd
  assert_success
  assert_output 'my command'

  test::it 'requires separation'
  run cmd::main mycmd
  assert_failure
  assert_output 'Error: Unknown command: mycmd'
}

@test "runs internal command with leading underscore" {
  function cmds::cmd:_internal() {
    echo 'my internal command'
  }

  test::it 'supports leading underscore'
  run cmd::main _internal
  assert_success
  assert_output 'my internal command'

  test::it 'requires leading underscore'
  run cmd::main internal
  assert_failure
  assert_output 'Error: Unknown command: internal'
}

@test "runs internal command with leading underscore and namespace" {
  function cmds::cmd:my__internal() {
    echo 'my internal sub-command'
  }

  test::it 'supports space notation (separate args)'
  run cmd::main my _internal
  assert_success
  assert_output 'my internal sub-command'

  test::it 'supports space notation (single arg)'
  run cmd::main 'my _internal'
  assert_success
  assert_output 'my internal sub-command'

  test::it 'supports underscore notation'
  run cmd::main my__internal
  assert_success
  assert_output 'my internal sub-command'

  test::it 'requires underscore (separate args)'
  run cmd::main my internal
  assert_failure
  assert_output 'Error: Unknown commands: "my" | "my internal"'

  test::it 'requires underscore (single arg)'
  run cmd::main 'my internal'
  assert_failure
  assert_output 'Error: Unknown command: my internal'

  test::it 'requires underscore (single underscore)'
  run cmd::main 'my_internal'
  assert_failure
  assert_output 'Error: Unknown command: my_internal'
}
