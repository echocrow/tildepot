#!/usr/bin/env bats
#
# Tests for `tildepot update`

setup() {
  load ../../test_lib.sh
  load ./tildepot_hook_lib.sh
}

@test "calls hook for all bundles" {
  test::mock_hook foo update
  test::mock_hook bar update

  run tildepot update
  assert_success
  test::assert_hook_invoked foo update
  test::assert_hook_invoked bar update
}

@test "skips hook when hook skip returns 0" {
  test::mock_hook_skip foo update "return 0"

  run tildepot update
  assert_success
  test::assert_hook_skipped foo update
}
@test "calls hook when hook skip returns 1" {
  test::mock_hook_skip foo update "return 1"

  run tildepot update
  assert_success
  test::assert_hook_invoked foo update
}
@test "skips hook when hook skip prints message" {
  test::mock_hook_skip foo update "echo 'mock reason'"

  run tildepot update
  assert_success
  test::assert_hook_skipped foo update "mock reason"
}
@test "skips hook when hook skip prints conditional message" {
  test::mock_hook_skip foo update "[[ 0 ]] && echo 'mock reason'"

  run tildepot update
  assert_success
  test::assert_hook_skipped foo update "mock reason"
}
@test "calls hook when hook skip does not print conditional message" {
  test::mock_hook_skip foo update "[[ '' ]] && echo 'mock reason'"

  run tildepot update
  assert_success
  test::assert_hook_invoked foo update
}
@test "calls hook when '--force' is set despite hook skip returning 0" {
  test::mock_hook_skip foo update "return 0"

  run tildepot update --force
  assert_success
  test::assert_hook_invoked foo update
}
