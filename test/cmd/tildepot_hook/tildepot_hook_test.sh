#!/usr/bin/env bash
#
# Bats helpers for tildepot hook command tests

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
  local cmd_args=("${__TILDEPOT_HOOK_TEST_HOOK_ARGS[@]}")

  case "$test" in

  "describes hook command")
    test::it "fails by default without any bundle files"
    run tildepot "$hook" "${cmd_args[@]}"
    assert_failure
    assert_output "Error: No bundles found."

    test::it "prints usage on '--help'"
    run tildepot "$hook" "${cmd_args[@]}" --help
    test::_assert_hook_cmd_usage "$hook"

    test::it "prints usage on '-h'"
    run tildepot "$hook" "${cmd_args[@]}" -h
    test::_assert_hook_cmd_usage "$hook"
    ;;

  "calls hook for all bundles")
    test::mock_hook aaa "$hook"
    test::mock_hook bbb "$hook"

    run tildepot "$hook" "${cmd_args[@]}"
    assert_success
    test::assert_bundle_output --hook aaa "$hook" --hook bbb "$hook"
    ;;

  "aborts early when hook errors")
    test::mock_bundle foo "
      function simulate_error() {
        echo '[TEST] SIMULATING ERROR' >&2 && return 1
      }
      $(test::mock_hook_fn "$hook" "" "
        echo '[TEST] FOO HOOK EARLY' >&2
        simulate_error
        echo '[TEST] FOO HOOK LATE' >&2
      ")
    "

    run tildepot "$hook" "${cmd_args[@]}"
    assert_failure
    test::assert_bundle_output \
      --hook foo "$hook" \
      "[TEST] FOO HOOK EARLY" \
      "[TEST] SIMULATING ERROR"
    ;;

  "skips hook when hook skip returns 0")
    test::mock_hook_skip foo "$hook" "return 0"

    run tildepot "$hook" "${cmd_args[@]}"
    assert_success
    test::assert_bundle_output --hook-skip foo "$hook"
    ;;

  "calls hook when hook skip returns 1")
    test::mock_hook_skip foo "$hook" "return 1"

    run tildepot "$hook" "${cmd_args[@]}"
    assert_success
    test::assert_bundle_output --hook foo "$hook"
    ;;

  "skips hook when hook skip prints message")
    test::mock_hook_skip foo "$hook" "echo 'mock reason'"

    run tildepot "$hook" "${cmd_args[@]}"
    assert_success
    test::assert_bundle_output --hook-skip foo "$hook" --skip-reason "mock reason"
    ;;

  "skips hook when hook skip prints conditional message")
    test::mock_hook_skip foo "$hook" "[[ 0 ]] && echo 'mock reason'"

    run tildepot "$hook" "${cmd_args[@]}"
    assert_success
    test::assert_bundle_output --hook-skip foo "$hook" --skip-reason "mock reason"
    ;;

  "prints multi-line skip reason on separate, prefixed lines")
    test::mock_hook_skip foo "$hook" "
      echo 'mock reason 1'
      echo 'mock reason 2'
    "

    run tildepot "$hook" "${cmd_args[@]}"
    assert_success
    test::assert_bundle_output \
      --hook-skip foo "$hook" \
      --skip-reasons "mock reason 1" "mock reason 2"
    ;;

  "calls hook when hook skip does not print conditional message")
    test::mock_hook_skip foo "$hook" "[[ '' ]] && echo 'mock reason'"

    run tildepot "$hook" "${cmd_args[@]}"
    assert_success
    test::assert_bundle_output --hook foo "$hook"
    ;;

  "calls hook when '--force' is set despite hook skip returning 0")
    test::mock_hook_skip foo "$hook" "return 0"

    run tildepot "$hook" "${cmd_args[@]}" --force
    assert_success
    test::assert_bundle_output --hook foo "$hook"
    ;;

  *)
    test::abort "Unknown hook test: $test"
    ;;

  esac

}
