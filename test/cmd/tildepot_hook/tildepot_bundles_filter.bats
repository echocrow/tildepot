#!/usr/bin/env bats
#
# Tests for `tildepot` bundles: filtering via `--bundle`
#
# These tests use the `install` hook as stand-in for all hook commands. The same
# tests are assumed to also pass for all other hook commands.

setup() {
  load ../../test_lib.sh
  load ./tildepot_hook_lib.sh
}

@test "calls sole '--bundle' hook" {
  test::mock_hook foo install
  test::mock_hook bar install

  run tildepot install --bundle foo
  assert_success
  test::assert_hook_invoked foo install
  test::refute_hook_called bar install
}

@test "calls multiple '--bundle' hooks" {
  test::mock_hook aaa install
  test::mock_hook bbb install
  test::mock_hook ccc install

  run tildepot install --bundle aaa --bundle bbb
  assert_success
  test::assert_hook_invoked aaa install
  test::assert_hook_invoked bbb install
  test::refute_hook_called ccc install
}

@test "calls multiple '--bundle' hooks in specified order" {
  test::mock_hook aaa install
  test::mock_hook bbb install
  test::mock_hook ccc install

  run tildepot install --bundle bbb --bundle aaa --bundle ccc
  assert_success
  test::assert_hook_invoked --index 0 bbb install
  test::assert_hook_invoked --index 2 aaa install
  test::assert_hook_invoked --index 4 ccc install
}

@test "errors on invalid '--bundle' name" {
  test::mock_hook aaa install

  run tildepot install --bundle missing
  assert_failure
  assert_output "Error: Bundle missing not found."
}

@test "does not invoke any bundles on invalid '--bundle' name" {
  test::mock_hook aaa install

  run tildepot install --bundle aaa --bundle missing
  assert_failure
  test::refute_hook_called aaa install
}
