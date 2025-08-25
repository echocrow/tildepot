#!/usr/bin/env bats
#
# Tests for `src/cmd.sh` options

# shellcheck disable=SC2030,SC2031,SC2034,SC2317,SC2329

setup() {
  load ../test_lib.sh

  load ../../src/cmd.sh
}

function test::_dump_array() {
  local len="$#"
  echo "$#:[$*]"
}

@test "fails when unknown opt is passed" {
  function cmds::cmd:foo:args() {
    CMD_CFG_OPTS+=(o opt '' '')
  }
  function cmds::cmd:foo() {
    true
  }

  run cmd::main foo --invalid-opt
  assert_failure
  assert_output "Error: Unknown option: --invalid-opt"
}

###
# Bool opts.
###

@test "accepts bool opts (short format)" {
  function cmds::cmd:foo:args() {
    CMD_CFG_OPTS+=(a aaa '' '')
    CMD_CFG_OPTS+=(b bbb '' '')
  }
  function cmds::cmd:foo() {
    echo "aaa=[${CMD_OPT_aaa-}] bbb=[${CMD_OPT_bbb-}]"
  }

  run cmd::main foo -a
  assert_success
  assert_output "aaa=[1] bbb=[]"
}
@test "accepts bool opts (long format)" {
  function cmds::cmd:foo:args() {
    CMD_CFG_OPTS+=(a aaa '' '')
    CMD_CFG_OPTS+=(b bbb '' '')
  }
  function cmds::cmd:foo() {
    echo "aaa=[${CMD_OPT_aaa-}] bbb=[${CMD_OPT_bbb-}]"
  }

  run cmd::main foo --aaa
  assert_success
  assert_output "aaa=[1] bbb=[]"
}

@test "treats arg after bool opt as param" {
  function cmds::cmd:foo:args() {
    CMD_CFG_OPTS+=(a aaa '' '')
    CMD_CFG_PARAMS_COUNT=0-3
  }
  function cmds::cmd:foo() {
    echo "aaa=[${CMD_OPT_aaa-}] params=$(test::_dump_array "$@")"
  }

  run cmd::main foo -a b c
  assert_success
  assert_output "aaa=[1] params=2:[b c]"
}

###
# String opts.
###

@test "accepts string opts (short format)" {
  function cmds::cmd:foo:args() {
    CMD_CFG_OPTS+=(a aaa 'A' '')
    CMD_CFG_OPTS+=(b bbb 'B' '')
  }
  function cmds::cmd:foo() {
    echo "aaa=[${CMD_OPT_aaa-}] bbb=[${CMD_OPT_bbb-}]"
  }

  run cmd::main foo -a foo
  assert_success
  assert_output "aaa=[foo] bbb=[]"
}
@test "accepts string opts (long format)" {
  function cmds::cmd:foo:args() {
    CMD_CFG_OPTS+=(a aaa 'A' '')
    CMD_CFG_OPTS+=(b bbb 'B' '')
  }
  function cmds::cmd:foo() {
    echo "aaa=[${CMD_OPT_aaa-}] bbb=[${CMD_OPT_bbb-}]"
  }

  run cmd::main foo --aaa foo
  assert_success
  assert_output "aaa=[foo] bbb=[]"
}

@test "treats arg after string opt value as param" {
  function cmds::cmd:foo:args() {
    CMD_CFG_OPTS+=(a aaa 'A' '')
    CMD_CFG_PARAMS_COUNT=0-3
  }
  function cmds::cmd:foo() {
    echo "aaa=[${CMD_OPT_aaa-}] params=$(test::_dump_array "$@")"
  }

  run cmd::main foo -a b c d
  assert_success
  assert_output "aaa=[b] params=2:[c d]"
}

@test "stores last value for repeated string opts" {
  function cmds::cmd:foo:args() {
    CMD_CFG_OPTS+=(o opt 'O' '')
  }
  function cmds::cmd:foo() {
    echo "opt=[${CMD_OPT_opt-}]"
  }

  run cmd::main foo -o foo -o bar
  assert_success
  assert_output "opt=[bar]"
}

###
# Array opts.
###

@test "accepts array opts (short format)" {
  function cmds::cmd:foo:args() {
    CMD_CFG_OPTS+=(a aaa 'A[]' '')
    CMD_CFG_OPTS+=(b bbb 'B[]' '')
  }
  function cmds::cmd:foo() {
    echo "aaa=$(test::_dump_array ${CMD_OPT_aaa+"${CMD_OPT_aaa[@]}"}) bbb=$(test::_dump_array ${CMD_OPT_bbb+"${CMD_OPT_bbb[@]}"})"
  }

  run cmd::main foo -a foo -a bar
  assert_success
  assert_output "aaa=2:[foo bar] bbb=0:[]"
}
@test "accepts array opts (long format)" {
  function cmds::cmd:foo:args() {
    CMD_CFG_OPTS+=(a aaa 'A[]' '')
    CMD_CFG_OPTS+=(b bbb 'B[]' '')
  }
  function cmds::cmd:foo() {
    echo "aaa=$(test::_dump_array ${CMD_OPT_aaa+"${CMD_OPT_aaa[@]}"}) bbb=$(test::_dump_array ${CMD_OPT_bbb+"${CMD_OPT_bbb[@]}"})"
  }

  run cmd::main foo --aaa foo --aaa bar
  assert_success
  assert_output "aaa=2:[foo bar] bbb=0:[]"
}
@test "accepts array opts (mixed formats)" {
  function cmds::cmd:foo:args() {
    CMD_CFG_OPTS+=(o opt 'O[]' '')
  }
  function cmds::cmd:foo() {
    echo "opt=$(test::_dump_array "${CMD_OPT_opt[@]}")"
  }

  run cmd::main foo --opt foo -o bar --opt baz
  assert_success
  assert_output "opt=3:[foo bar baz]"
}

@test "differentiates between array opts and params" {
  function cmds::cmd:foo:args() {
    CMD_CFG_OPTS+=(o opt 'O[]' '')
    CMD_CFG_PARAMS_COUNT=0-3
  }
  function cmds::cmd:foo() {
    echo "opt=$(test::_dump_array "${CMD_OPT_opt[@]}") params=$(test::_dump_array "$@")"
  }

  run cmd::main foo param1 -o val1 param2 -o val2 param3
  assert_success
  assert_output "opt=2:[val1 val2] params=3:[param1 param2 param3]"
}

###
# Root opts.
###

# todo root opts (short)
# todo root opts (long)

# todo: runs 'cmds::root_cmd' when any root opt is set

###
# Global opts.
###

# todo global opts before command (short)
# todo global opts before command (long)

# todo global opts after command (short)
# todo global opts after command (long)

# todo global opts array before & after command

###
# Misc.
###

@test "handles opts with hyphens as underscores" {
  function cmds::cmd:foo:args() {
    CMD_CFG_OPTS+=(o my-opt 'O' '')
  }
  function cmds::cmd:foo() {
    echo "my_opt=[${CMD_OPT_my_opt-}]"
  }

  run cmd::main foo --my-opt foo
  assert_success
  assert_output "my_opt=[foo]"
}

@test "ignores all opts when 'CMD_CFG_ARGS_FWD_ALL=1'" {
  function cmds::cmd:foo:args() {
    CMD_CFG_ARGS_FWD_ALL=1
    CMD_CFG_OPTS+=(o opt 'O' '')
    CMD_CFG_PARAMS_COUNT=0-10
  }
  function cmds::cmd:foo() {
    echo "opt=[${CMD_OPT_opt-}] params=$(test::_dump_array "$@")"
  }

  run cmd::main foo --opt foo param1 param2 --opt bar
  assert_success
  assert_output "opt=[] params=6:[--opt foo param1 param2 --opt bar]"
}

@test "accepts opts before first param" {
  function cmds::cmd:foo:args() {
    CMD_CFG_OPTS+=(o opt '' '')
    CMD_CFG_PARAMS_COUNT=1-2
  }
  function cmds::cmd:foo() {
    echo "opt=[${CMD_OPT_opt-}] params=$(test::_dump_array "$@")"
  }

  run cmd::main foo param --opt
  assert_success
  assert_output "opt=[1] params=1:[param]"
}
@test "accepts opts after last param" {
  function cmds::cmd:foo:args() {
    CMD_CFG_OPTS+=(o opt '' '')
    CMD_CFG_PARAMS_COUNT=1-2
  }
  function cmds::cmd:foo() {
    echo "opt=[${CMD_OPT_opt-}] params=$(test::_dump_array "$@")"
  }

  run cmd::main foo --opt param
  assert_success
  assert_output "opt=[1] params=1:[param]"
}
@test "accepts opts between params" {
  function cmds::cmd:foo:args() {
    CMD_CFG_OPTS+=(o opt '' '')
    CMD_CFG_PARAMS_COUNT=1-2
  }
  function cmds::cmd:foo() {
    echo "opt=[${CMD_OPT_opt-}] params=$(test::_dump_array "$@")"
  }

  run cmd::main foo param1 --opt param2
  assert_success
  assert_output "opt=[1] params=2:[param1 param2]"
}
