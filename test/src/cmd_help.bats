#!/usr/bin/env bats
#
# Tests for `src/cmd.sh` `cmd::help`

# shellcheck disable=SC2030,SC2031,SC2034,SC2317,SC2329

setup() {
  load ../test_lib.sh

  load ../../src/cmd.sh

  function cmds::app_name() {
    echo 'my-app'
  }
  function cmds::app_version() {
    echo '0.1.2'
  }
}

###
# Root command help.
###

@test "prints help of root command by default" {
  run cmd::help
  assert_success
  assert_output "$(test::dedent "
    my-app 0.1.2

    Usage: my-app [command] [options] [arguments]
  ")"
}

@test "prints help of root command with global options" {
  function cmds::global_args() {
    CMD_CFG_OPTS+=(g my-global '' 'My global opt help.')
  }

  run cmd::help
  assert_success
  assert_output "$(test::dedent "
    my-app 0.1.2

    Usage: my-app [command] [options] [arguments]

    Global options:
      -g, --my-global           My global opt help.
  ")"
}

###
# Root command list.
###

@test "lists commands via 'cmds::list'" {
  function cmds::list() {
    echo 'foo'
    echo 'bar'
  }

  run cmd::help
  assert_success
  assert_output "$(test::dedent "
    my-app 0.1.2

    Usage: my-app [command] [options] [arguments]

    Commands:
      foo
      bar
  ")"
}

@test "lists commands via 'cmds::list' with custom categories" {
  function cmds::list() {
    echo 'Foobar:'
    echo 'foo'
    echo 'bar'
    echo 'Fizzbuzz:'
    echo 'fizz'
    echo 'buzz'
  }

  run cmd::help
  assert_success
  assert_output "$(test::dedent "
    my-app 0.1.2

    Usage: my-app [command] [options] [arguments]

    Foobar:
      foo
      bar

    Fizzbuzz:
      fizz
      buzz
  ")"
}

@test "lists commands with short help" {
  function cmds::list() {
    echo 'foo'
    echo 'bar'
  }
  function cmds::cmd:foo:help() {
    echo 'My foo command.'
  }
  function cmds::cmd:bar:help() {
    echo 'Some boo command.'
  }

  run cmd::help
  assert_success
  assert_output "$(test::dedent "
    my-app 0.1.2

    Usage: my-app [command] [options] [arguments]

    Commands:
      foo                       My foo command.
      bar                       Some boo command.
  ")"
}

@test "does not set '--long' flag for cmd help in command list" {
  function cmds::list() {
    echo 'foo'
  }
  function cmds::cmd:foo:help() {
    local long= && [[ ${1-} == '--long' ]] && long=1
    echo 'My foo command.'
    [[ ! $long ]] || echo "My extended description."
  }

  run cmd::help
  assert_success
  assert_output "$(test::dedent "
    my-app 0.1.2

    Usage: my-app [command] [options] [arguments]

    Commands:
      foo                       My foo command.
  ")"
}

###
# Command help.
###

@test "fails when command does not exist" {
  run cmd::help foo
  assert_failure
  assert_output 'Error: Unknown command: foo'
}

@test "prints help for command" {
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

###
# Command help options.
###

@test "prints help for command with opts" {
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
      -o, --my-opt OPT          Some opt desc.
  ")"
}

@test "prints help for command with only global opts" {
  function cmds::global_args() {
    CMD_CFG_OPTS+=(g my-global '' 'My global opt help.')
  }
  function cmds::cmd:foo() {
    true
  }

  run cmd::help foo
  assert_success
  assert_output "$(test::dedent "
    my-app foo

    Usage: my-app foo [options]

    Global options:
      -g, --my-global           My global opt help.
  ")"
}

@test "prints help for command with global & cmd opts" {
  function cmds::global_args() {
    CMD_CFG_OPTS+=(g my-global '' 'My global opt help.')
  }
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

    Global options:
      -g, --my-global           My global opt help.

    Options:
      -o, --my-opt OPT          Some opt desc.
  ")"
}

@test "relocates '[options]' in usage when 'CMD_CFG_ARGS_FWD_ALL=1'" {
  function cmds::global_args() {
    CMD_CFG_OPTS+=(g my-global '' 'My global opt help.')
  }
  function cmds::cmd:foo:args() {
    CMD_CFG_ARGS_FWD_ALL=1
  }
  function cmds::cmd:foo() {
    true
  }

  run cmd::help foo
  assert_success
  assert_output "$(test::dedent "
    my-app foo

    Usage: my-app [options] foo

    Global options:
      -g, --my-global           My global opt help.
  ")"
}

###
# Command help arguments.
###

@test "appends '[arguments]' to usage for command with params count" {
  function cmds::cmd:foo:args() {
    CMD_CFG_PARAMS_COUNT=1
  }
  function cmds::cmd:foo() {
    true
  }

  run cmd::help foo
  assert_success
  assert_output "$(test::dedent "
    my-app foo

    Usage: my-app foo [arguments]
  ")"
}

@test "omits '[arguments]' from usage when 'CMD_CFG_PARAMS_COUNT=0'" {
  function cmds::cmd:foo:args() {
    CMD_CFG_PARAMS_COUNT=0
  }
  function cmds::cmd:foo() {
    true
  }

  run cmd::help foo
  assert_success
  assert_output "$(test::dedent "
    my-app foo

    Usage: my-app foo
  ")"
}

@test "appends '\$CMD_CFG_PARAMS_HELP' to usage when set" {
  function cmds::cmd:foo:args() {
    CMD_CFG_PARAMS_HELP='MY PARAMS'
  }
  function cmds::cmd:foo() {
    true
  }

  run cmd::help foo
  assert_success
  assert_output "$(test::dedent "
    my-app foo

    Usage: my-app foo MY PARAMS
  ")"
}

@test "appends '\$CMD_CFG_PARAMS_HELP' to usage regardless of '\$CMD_CFG_PARAMS_COUNT'" {
  function cmds::cmd:foo:args() {
    CMD_CFG_PARAMS_HELP='MY PARAMS'
    CMD_CFG_PARAMS_COUNT=2
  }
  function cmds::cmd:foo() {
    true
  }

  run cmd::help foo
  assert_success
  assert_output "$(test::dedent "
    my-app foo

    Usage: my-app foo MY PARAMS
  ")"
}

###
# Command help description.
###

@test "prints cmd help for command" {
  function cmds::cmd:foo:help() {
    echo 'My foo command.'
  }
  function cmds::cmd:foo() {
    true
  }

  run cmd::help foo
  assert_success
  assert_output "$(test::dedent "
    my-app foo

    My foo command.

    Usage: my-app foo
  ")"
}

@test "does set '--long' flag for cmd help" {
  function cmds::cmd:foo:help() {
    local long= && [[ ${1-} == '--long' ]] && long=1
    echo 'My foo command.'
    [[ ! $long ]] || echo "My extended description."
  }
  function cmds::cmd:foo() {
    true
  }

  run cmd::help foo
  assert_success
  assert_output "$(test::dedent "
    my-app foo

    My foo command.
    My extended description.

    Usage: my-app foo
  ")"
}
