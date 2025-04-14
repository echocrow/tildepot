#!/usr/bin/env bats
#
# Tests for `tildepot snapshot`

setup() {
  load ../../test_lib.sh
  load ./tildepot_hook_lib.sh
}

@test "calls hook for all bundles" {
  test::mock_hook foo snapshot
  test::mock_hook bar snapshot

  run tildepot snapshot
  assert_success
  test::assert_hook_invoked foo snapshot
  test::assert_hook_invoked bar snapshot
}

@test "skips hook when hook skip returns 0" {
  test::mock_hook_skip foo snapshot "return 0"

  run tildepot snapshot
  assert_success
  test::assert_hook_skipped foo snapshot
}
@test "calls hook when hook skip returns 1" {
  test::mock_hook_skip foo snapshot "return 1"

  run tildepot snapshot
  assert_success
  test::assert_hook_invoked foo snapshot
}
@test "skips hook when hook skip prints message" {
  test::mock_hook_skip foo snapshot "echo 'mock reason'"

  run tildepot snapshot
  assert_success
  test::assert_hook_skipped foo snapshot "mock reason"
}
@test "skips hook when hook skip prints conditional message" {
  test::mock_hook_skip foo snapshot "[[ 0 ]] && echo 'mock reason'"

  run tildepot snapshot
  assert_success
  test::assert_hook_skipped foo snapshot "mock reason"
}
@test "calls hook when hook skip does not print conditional message" {
  test::mock_hook_skip foo snapshot "[[ '' ]] && echo 'mock reason'"

  run tildepot snapshot
  assert_success
  test::assert_hook_invoked foo snapshot
}
@test "calls hook when '--force' is set despite hook skip returning 0" {
  test::mock_hook_skip foo snapshot "return 0"

  run tildepot snapshot --force
  assert_success
  test::assert_hook_invoked foo snapshot
}
