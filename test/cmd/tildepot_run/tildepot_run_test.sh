#!/usr/bin/env bash
#
# Bats helpers for tildepot run hook command tests

__TILDEPOT_RUN_TEST_HOOK=
__TILDEPOT_RUN_TEST_HOOK_ARGS=()

function test::setup_assert_run_cmd() {
  __TILDEPOT_RUN_TEST_HOOK="${1?}"
  __TILDEPOT_RUN_TEST_HOOK_ARGS=("${@:2}")
}

function test::assert_run_cmd() {
  local test="${1?}"

  local hook="$__TILDEPOT_RUN_TEST_HOOK"
  local args=(
    ${__TILDEPOT_RUN_TEST_HOOK_ARGS+"${__TILDEPOT_RUN_TEST_HOOK_ARGS[@]}"}
  )

  case "$test" in

  "fails without any bundle files")
    run tildepot run "$hook" ${args+"${args[@]}"}
    assert_failure
    assert_output "Error: No bundles found."
    ;;

  "calls hook for all bundles")
    test::mock_hook aaa "$hook"
    test::mock_hook bbb "$hook"

    run tildepot run "$hook" ${args+"${args[@]}"}
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

    run tildepot run "$hook" ${args+"${args[@]}"}
    assert_failure
    test::assert_bundle_output \
      --hook foo "$hook" \
      "[TEST] FOO HOOK EARLY" \
      "[TEST] SIMULATING ERROR" \
      --failure
    ;;

  "skips hook when hook skip returns 0")
    local hook_fn
    hook_fn="$(echo "$hook" | tr '[:lower:]' '[:upper:]')"

    test::mock_hook_skip foo "$hook" "return 0"

    run tildepot run "$hook" ${args+"${args[@]}"}
    assert_success
    test::assert_bundle_output --hook-skip foo "$hook" "Skipped by ${hook_fn}_SKIP function"
    ;;

  "calls hook when hook skip returns 1")
    test::mock_hook_skip foo "$hook" "return 1"

    run tildepot run "$hook" ${args+"${args[@]}"}
    assert_success
    test::assert_bundle_output --hook foo "$hook"
    ;;

  "skips hook when hook skip prints message")
    test::mock_hook_skip foo "$hook" "echo 'mock reason'"

    run tildepot run "$hook" ${args+"${args[@]}"}
    assert_success
    test::assert_bundle_output --hook-skip foo "$hook" "mock reason"
    ;;

  "skips hook when hook skip prints conditional message")
    test::mock_hook_skip foo "$hook" "[[ 0 ]] && echo 'mock reason'"

    run tildepot run "$hook" ${args+"${args[@]}"}
    assert_success
    test::assert_bundle_output --hook-skip foo "$hook" "mock reason"
    ;;

  "prints multi-line skip reason on separate, prefixed lines")
    test::mock_hook_skip foo "$hook" "
      echo 'mock reason 1'
      echo 'mock reason 2'
    "

    run tildepot run "$hook" ${args+"${args[@]}"}
    assert_success
    test::assert_bundle_output \
      --hook-skip foo "$hook" '' \
      --skip-reason "mock reason 1" \
      --skip-reason "mock reason 2"
    ;;

  "calls hook when hook skip does not print conditional message")
    test::mock_hook_skip foo "$hook" "[[ '' ]] && echo 'mock reason'"

    run tildepot run "$hook" ${args+"${args[@]}"}
    assert_success
    test::assert_bundle_output --hook foo "$hook"
    ;;

  "calls hook when '--force' is set despite hook skip returning 0")
    test::mock_hook_skip foo "$hook" "return 0"

    run tildepot run "$hook" ${args+"${args[@]}"} --force
    assert_success
    test::assert_bundle_output --hook foo "$hook"
    ;;

  *)
    test::abort "Unknown hook test: $test"
    ;;

  esac

}
