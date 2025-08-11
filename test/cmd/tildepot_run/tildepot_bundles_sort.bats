#!/usr/bin/env bats
#
# Tests for `tildepot` bundles: sort order
#
# These tests use the `save` hook as stand-in for all hook commands. The same
# tests are assumed to also pass for all other hook commands.

setup() {
  load ../../test_lib.sh
  load ./tildepot_run_lib.sh
}

@test "calls multiple bundles in alphabetical order" {
  test::mock_hook bbb save
  test::mock_hook ccc save
  test::mock_hook aaa save

  run tildepot run save
  assert_success
  test::assert_bundle_output \
    --hook aaa save \
    --hook bbb save \
    --hook ccc save
}

@test "calls multiple bundles in alphabetical order with numerical prefix" {
  test::mock_bundle aaa "02 aaa.sh" "$(test::mock_hook_fn save)"
  test::mock_bundle bbb "42 bbb.sh" "$(test::mock_hook_fn save)"
  test::mock_bundle ccc "00 ccc.sh" "$(test::mock_hook_fn save)"

  run tildepot run save
  assert_success
  test::assert_bundle_output \
    --hook ccc save \
    --hook aaa save \
    --hook bbb save
}
