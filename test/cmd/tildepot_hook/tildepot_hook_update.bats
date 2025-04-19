#!/usr/bin/env bats
#
# Tests for `tildepot update`

setup() {
  load ../../test_lib.sh
  load ./tildepot_hook_lib.sh
}

@test "describes hook command" {
  test::test_hook_cmd update
}

@test "calls hook for all bundles" {
  test::mock_hook aaa update
  test::mock_hook bbb update

  run tildepot update
  assert_success
  test::assert_bundle_output --hook aaa update --hook bbb update
}

@test "skips hook when hook skip returns 0" {
  test::mock_hook_skip foo update "return 0"

  run tildepot update
  assert_success
  test::assert_bundle_output --hook-skip foo update
}
@test "calls hook when hook skip returns 1" {
  test::mock_hook_skip foo update "return 1"

  run tildepot update
  assert_success
  test::assert_bundle_output --hook foo update
}
@test "skips hook when hook skip prints message" {
  test::mock_hook_skip foo update "echo 'mock reason'"

  run tildepot update
  assert_success
  test::assert_bundle_output --hook-skip foo update --skip-reason "mock reason"
}
@test "skips hook when hook skip prints conditional message" {
  test::mock_hook_skip foo update "[[ 0 ]] && echo 'mock reason'"

  run tildepot update
  assert_success
  test::assert_bundle_output --hook-skip foo update --skip-reason "mock reason"
}
@test "calls hook when hook skip does not print conditional message" {
  test::mock_hook_skip foo update "[[ '' ]] && echo 'mock reason'"

  run tildepot update
  assert_success
  test::assert_bundle_output --hook foo update
}
@test "calls hook when '--force' is set despite hook skip returning 0" {
  test::mock_hook_skip foo update "return 0"

  run tildepot update --force
  assert_success
  test::assert_bundle_output --hook foo update
}
