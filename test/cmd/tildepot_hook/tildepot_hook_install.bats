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
  test::mock_hook foo install
  test::mock_hook bar install

  run tildepot install
  assert_success
  test::assert_hook_invoked foo install
  test::assert_hook_invoked bar install
}

@test "skips hook when hook skip returns 0" {
  test::mock_hook_skip foo install "return 0"

  run tildepot install
  assert_success
  test::assert_hook_skipped foo install
}
@test "calls hook when hook skip returns 1" {
  test::mock_hook_skip foo install "return 1"

  run tildepot install
  assert_success
  test::assert_hook_invoked foo install
}
@test "skips hook when hook skip prints message" {
  test::mock_hook_skip foo install "echo 'mock reason'"

  run tildepot install
  assert_success
  test::assert_hook_skipped foo install "mock reason"
}
@test "skips hook when hook skip prints conditional message" {
  test::mock_hook_skip foo install "[[ 0 ]] && echo 'mock reason'"

  run tildepot install
  assert_success
  test::assert_hook_skipped foo install "mock reason"
}
@test "calls hook when hook skip does not print conditional message" {
  test::mock_hook_skip foo install "[[ '' ]] && echo 'mock reason'"

  run tildepot install
  assert_success
  test::assert_hook_invoked foo install
}
@test "calls hook when '--force' is set despite hook skip returning 0" {
  test::mock_hook_skip foo install "return 0"

  run tildepot install --force
  assert_success
  test::assert_hook_invoked foo install
}
