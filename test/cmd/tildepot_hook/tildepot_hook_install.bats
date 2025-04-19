#!/usr/bin/env bats
#
# Tests for `tildepot install`

setup() {
  load ../../test_lib.sh
  load ./tildepot_hook_lib.sh
}

@test "describes hook command" {
  test::test_hook_cmd install
}

@test "calls hook for all bundles" {
  test::mock_hook aaa install
  test::mock_hook bbb install

  run tildepot install
  assert_success
  test::assert_bundle_output --hook aaa install --hook bbb install
}

@test "skips hook when hook skip returns 0" {
  test::mock_hook_skip foo install "return 0"

  run tildepot install
  assert_success
  test::assert_bundle_output --hook-skip foo install
}
@test "calls hook when hook skip returns 1" {
  test::mock_hook_skip foo install "return 1"

  run tildepot install
  assert_success
  test::assert_bundle_output --hook foo install
}
@test "skips hook when hook skip prints message" {
  test::mock_hook_skip foo install "echo 'mock reason'"

  run tildepot install
  assert_success
  test::assert_bundle_output --hook-skip foo install --skip-reason "mock reason"
}
@test "skips hook when hook skip prints conditional message" {
  test::mock_hook_skip foo install "[[ 0 ]] && echo 'mock reason'"

  run tildepot install
  assert_success
  test::assert_bundle_output --hook-skip foo install --skip-reason "mock reason"
}
@test "calls hook when hook skip does not print conditional message" {
  test::mock_hook_skip foo install "[[ '' ]] && echo 'mock reason'"

  run tildepot install
  assert_success
  test::assert_bundle_output --hook foo install
}
@test "calls hook when '--force' is set despite hook skip returning 0" {
  test::mock_hook_skip foo install "return 0"

  run tildepot install --force
  assert_success
  test::assert_bundle_output --hook foo install
}
