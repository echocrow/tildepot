#!/usr/bin/env bats
#
# Tests for `src/cmd.sh` `cmd::help`

# shellcheck disable=SC2030,SC2031,SC2034,SC2317,SC2329

setup() {
  load ../test_lib.sh

  load ../../src/cmd.sh
  CMD_CFG_OPTS=()
}

function _define_app() {
  function cmds::app_name() {
    echo 'my-app'
  }
  function cmds::app_version() {
    echo '0.1.2'
  }
}

@test "prints help of root command by default" {
  _define_app

  run cmd::help
  assert_success
  assert_output "$(test::dedent "
    my-app 0.1.2

    Usage: my-app [command] [options] [arguments]
  ")"
}

@test "prints help of root command with global options" {
  _define_app

  function cmds::global_args() {
    CMD_CFG_OPTS+=(g my-global '' 'My global opt help.')
  }

  run cmd::help
  assert_success
  assert_output "$(test::dedent "
    my-app 0.1.2

    Usage: my-app [command] [options] [arguments]

    Global options:
    $(lib::print_two_col '  -g, --my-global' 'My global opt help.' 28)
  ")"
}

@test "fails when command does not exist" {
  run cmd::help foo
  assert_failure
  assert_output 'Error: Unknown command: foo'
}

@test "prints help for command" {
  _define_app

  function cmds::cmd:foo() {
    echo 'hello world'
  }

  run cmd::help foo
  assert_success
  assert_output "$(test::dedent "
    my-app foo

    Usage: my-app foo
  ")"

  test::it 'does not call cmd fn'
  refute_line 'hello world'
}

@test "prints help for command with opts" {
  _define_app

  function cmds::cmd:foo:args() {
    CMD_CFG_OPTS+=(o my-opt OPT 'Some opt desc.')
  }
  function cmds::cmd:foo() {
    true
  }

  run cmd::help foo
  assert_success
  assert_output "$(test::dedent "
    my-app foo

    Usage: my-app foo [options]

    Options:
    $(lib::print_two_col '  -o, --my-opt OPT' 'Some opt desc.' 28)
  ")"
}

# @test "prints help for command with only global opts" {
#   _define_app

#   function cmds::global_args() {
#     CMD_CFG_OPTS+=(g my-global '' 'My global opt help.')
#   }
#   function cmds::cmd:foo() {
#     true
#   }

#   run cmd::help foo
#   assert_success
#   assert_output "$(test::dedent "
#     my-app foo

#     Usage: my-app foo [options]

#     Global Options:
#     $(lib::print_two_col '  -g, --my-global' 'My global opt help.' 28)
#   ")"
# }

@test "prints help for command with description" {
  _define_app

  function cmds::cmd:foo:help() {
    echo 'My command description.'
    echo
    echo 'My second paragraph.'
  }
  function cmds::cmd:foo() {
    true
  }

  run cmd::help foo
  assert_success
  assert_output "$(test::dedent "
    my-app foo

    My command description.

    My second paragraph.

    Usage: my-app foo
  ")"
}

# todo: [options] foo when CMD_CFG_ARGS_FWD_ALL=1

# todo: cmds::list
