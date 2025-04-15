#!/usr/bin/env bats
#
# Tests for `tildepot` hooks
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
  test::assert_bundle_skipped foo install
}
@test "calls hook when bundle skip returns 1" {
  test::mock_bundle_skip foo "return 1"
  test::mock_hook foo install

  run tildepot install
  assert_success
  test::assert_hook_invoked foo install
}
@test "skips hook when bundle skip prints message" {
  test::mock_bundle_skip foo "echo 'mock reason'"
  test::mock_hook foo install

  run tildepot install
  assert_success
  test::assert_bundle_skipped foo install "mock reason"
}
@test "skips hook when bundle skip prints conditional message" {
  test::mock_bundle_skip foo "[[ 0 ]] && echo 'mock reason'"
  test::mock_hook foo install

  run tildepot install
  assert_success
  test::assert_bundle_skipped foo install "mock reason"
}
@test "calls hook when bundle skip does not print conditional message" {
  test::mock_bundle_skip foo "[[ '' ]] && echo 'mock reason'"
  test::mock_hook foo install

  run tildepot install
  assert_success
  test::assert_hook_invoked foo install
}

# TODO: --bundle option (single)
# TODO: --bundle option (double)
# TODO: --bundle option (custom order)
# TODO: --bundle option (invalid bundle)

# TODO: hook local inherit (relative path)
# TODO: hook local inherit (absolute path)
# TODO: hook local inherit (double inherit)
# TODO: hook local inherit (error on recursive inherit)
