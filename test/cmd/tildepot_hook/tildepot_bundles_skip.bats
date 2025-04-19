#!/usr/bin/env bats
#
# Tests for `tildepot` bundles: SKIP() function
#
# These tests use the `install` hook as stand-in for all hook commands. The same
# tests are assumed to also pass for all other hook commands.

setup() {
  load ../../test_lib.sh
  load ./tildepot_hook_lib.sh
}

@test "skips hook when bundle skip returns 0" {
  test::mock_bundle_skip foo "return 0"
  test::mock_hook foo install

  run tildepot install
  assert_success
  test::assert_bundle_output --skip foo
}

@test "calls hook when bundle skip returns 1" {
  test::mock_bundle_skip foo "return 1"
  test::mock_hook foo install

  run tildepot install
  assert_success
  test::assert_bundle_output --hook foo install
}

@test "skips hook when bundle skip prints message" {
  test::mock_bundle_skip foo "echo 'mock reason'"
  test::mock_hook foo install

  run tildepot install
  assert_success
  test::assert_bundle_output --skip foo --skip-reason "mock reason"
}

@test "skips hook when bundle skip prints conditional message" {
  test::mock_bundle_skip foo "[[ 0 ]] && echo 'mock reason'"
  test::mock_hook foo install

  run tildepot install
  assert_success
  test::assert_bundle_output --skip foo --skip-reason "mock reason"
}

@test "calls hook when bundle skip does not print conditional message" {
  test::mock_bundle_skip foo "[[ '' ]] && echo 'mock reason'"
  test::mock_hook foo install

  run tildepot install
  assert_success
  test::assert_bundle_output --hook foo install
}
