#!/usr/bin/env bash
#
# Bats helpers for tildepot hook alias command tests

__TILDEPOT_HOOK_TEST_HOOK=
__TILDEPOT_HOOK_TEST_HOOK_ARGS=()

function test::setup_assert_hook_cmd() {
  __TILDEPOT_HOOK_TEST_HOOK="${1?}"
  __TILDEPOT_HOOK_TEST_HOOK_ARGS=("${@:2}")
}

function test::_assert_hook_cmd_usage() {
  local hook="$1"
  assert_line "tildepot $hook"
  assert_line "Usage: tildepot $hook [options]"
  assert_line "Options:"
}

function test::assert_hook_cmd() {
  local test="${1?}"

  local hook="$__TILDEPOT_HOOK_TEST_HOOK"
  local args=(
    ${__TILDEPOT_HOOK_TEST_HOOK_ARGS+"${__TILDEPOT_HOOK_TEST_HOOK_ARGS[@]}"}
  )

  case "$test" in

  "describes hook command")
    test::it "prints usage on '--help'"
    run tildepot "$hook" ${args+"${args[@]}"} --help
    assert_success
    test::_assert_hook_cmd_usage "$hook"

    test::it "prints usage on '-h'"
    run tildepot "$hook" ${args+"${args[@]}"} -h
    assert_success
    test::_assert_hook_cmd_usage "$hook"
    ;;

  "fails without any bundle files")
    run tildepot "$hook" ${args+"${args[@]}"}
    assert_failure
    assert_output "Error: No bundles found."
    ;;

  "calls hook for all bundles")
    test::mock_hook aaa "$hook"
    test::mock_hook bbb "$hook"

    run tildepot "$hook" ${args+"${args[@]}"}
    assert_success
    test::assert_bundle_output --hook aaa "$hook" --hook bbb "$hook"
    ;;

  "calls hook for only for bundles in '--bundle' list")
    test::mock_hook aaa "$hook"
    test::mock_hook bbb "$hook"
    test::mock_hook ccc "$hook"

    run tildepot "$hook" ${args+"${args[@]}"} --bundle aaa --bundle ccc
    assert_success
    test::assert_bundle_output --hook aaa "$hook" --hook ccc "$hook"
    ;;

  "errors when hook errors")
    test::mock_hook foo "$hook" "
      echo '[TEST] SIMULATING ERROR' >&2 && return 1
    "

    run tildepot "$hook" ${args+"${args[@]}"}
    assert_failure
    test::assert_bundle_output \
      --hook-run foo "$hook" \
      "[TEST] SIMULATING ERROR" \
      --failure
    ;;

  "calls hook when '--force' is set despite hook skip returning 0")
    test::mock_hook_skip foo "$hook" "return 0"

    run tildepot "$hook" ${args+"${args[@]}"} --force
    assert_success
    test::assert_bundle_output --hook foo "$hook"
    ;;

  *)
    test::abort "Unknown hook test: $test"
    ;;

  esac

}
