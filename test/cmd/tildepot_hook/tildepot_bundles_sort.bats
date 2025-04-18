#!/usr/bin/env bats
#
# Tests for `tildepot` bundles: sort order
#
# These tests use the `install` hook as stand-in for all hook commands. The same
# tests are assumed to also pass for all other hook commands.

setup() {
  load ../../test_lib.sh
  load ./tildepot_hook_lib.sh
}

@test "calls multiple bundles in alphabetical order" {
  test::mock_hook bbb install
  test::mock_hook ccc install
  test::mock_hook aaa install

  run tildepot install
  assert_success
  test::assert_hook_invoked --index 0 aaa install
  test::assert_hook_invoked --index 2 bbb install
  test::assert_hook_invoked --index 4 ccc install
}

@test "calls multiple bundles in alphabetical order with numerical prefix" {
  test::mock_bundle aaa "02 aaa.sh" "$(test::mock_hook_fn install)"
  test::mock_bundle bbb "42 bbb.sh" "$(test::mock_hook_fn install)"
  test::mock_bundle ccc "00 ccc.sh" "$(test::mock_hook_fn install)"

  run tildepot install
  assert_success
  test::assert_hook_invoked --index 0 ccc install
  test::assert_hook_invoked --index 2 aaa install
  test::assert_hook_invoked --index 4 bbb install
}
