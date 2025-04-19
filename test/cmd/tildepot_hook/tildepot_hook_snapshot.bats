#!/usr/bin/env bats
#
# Tests for `tildepot snapshot`

setup() {
  load ../../test_lib.sh
  load ./tildepot_hook_lib.sh
}

@test "describes hook command" {
  test::test_hook_cmd snapshot
}

@test "calls hook for all bundles" {
  test::mock_hook aaa snapshot
  test::mock_hook bbb snapshot

  run tildepot snapshot
  assert_success
  test::assert_bundle_output --hook aaa snapshot --hook bbb snapshot
}

@test "skips hook when hook skip returns 0" {
  test::mock_hook_skip foo snapshot "return 0"

  run tildepot snapshot
  assert_success
  test::assert_bundle_output --hook-skip foo snapshot
}
@test "calls hook when hook skip returns 1" {
  test::mock_hook_skip foo snapshot "return 1"

  run tildepot snapshot
  assert_success
  test::assert_bundle_output --hook foo snapshot
}
@test "skips hook when hook skip prints message" {
  test::mock_hook_skip foo snapshot "echo 'mock reason'"

  run tildepot snapshot
  assert_success
  test::assert_bundle_output --hook-skip foo snapshot --skip-reason "mock reason"
}
@test "skips hook when hook skip prints conditional message" {
  test::mock_hook_skip foo snapshot "[[ 0 ]] && echo 'mock reason'"

  run tildepot snapshot
  assert_success
  test::assert_bundle_output --hook-skip foo snapshot --skip-reason "mock reason"
}
@test "calls hook when hook skip does not print conditional message" {
  test::mock_hook_skip foo snapshot "[[ '' ]] && echo 'mock reason'"

  run tildepot snapshot
  assert_success
  test::assert_bundle_output --hook foo snapshot
}
@test "calls hook when '--force' is set despite hook skip returning 0" {
  test::mock_hook_skip foo snapshot "return 0"

  run tildepot snapshot --force
  assert_success
  test::assert_bundle_output --hook foo snapshot
}
