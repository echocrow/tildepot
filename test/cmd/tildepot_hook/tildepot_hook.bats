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
  local bundle_file
  bundle_file="$(test::mock_hook aaa install)"
  mv "$bundle_file" "$(dirname "$bundle_file")/02 aaa.sh"
  bundle_file="$(test::mock_hook bbb install)"
  mv "$bundle_file" "$(dirname "$bundle_file")/42 bbb.sh"
  bundle_file="$(test::mock_hook ccc install)"
  mv "$bundle_file" "$(dirname "$bundle_file")/00 ccc.sh"

  run tildepot install
  assert_success
  test::assert_hook_invoked --index 0 ccc install
  test::assert_hook_invoked --index 2 aaa install
  test::assert_hook_invoked --index 4 bbb install
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

# TODO: hook local inherit (relative path)
# TODO: hook local inherit (absolute path)
# TODO: hook local inherit (double inherit)
# TODO: hook local inherit (error on recursive inherit)
