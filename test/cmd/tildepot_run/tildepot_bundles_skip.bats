#!/usr/bin/env bats
#
# Tests for `tildepot` bundles: SKIP() function
#
# These tests use the `save` hook as stand-in for all hook commands. The same
# tests are assumed to also pass for all other hook commands.

setup() {
  load ../../test_lib.sh
  load ./tildepot_run_lib.sh
}

@test "skips hook when bundle skip returns 0" {
  test::mock_bundle_skip foo "return 0"
  test::mock_hook foo save

  run tildepot run save
  assert_success
  test::assert_bundle_output --partial --skip foo --skip-reason "Skipped by SKIP function"
}

@test "calls hook when bundle skip returns 1" {
  test::mock_bundle_skip foo "return 1"
  test::mock_hook foo save

  run tildepot run save
  assert_success
  test::assert_bundle_output --partial --hook foo save
}

@test "skips hook when bundle skip prints message" {
  test::mock_bundle_skip foo "echo 'mock reason'"
  test::mock_hook foo save

  run tildepot run save
  assert_success
  test::assert_bundle_output --partial --skip foo --skip-reason "mock reason"
}

@test "skips hook when bundle skip prints conditional message" {
  test::mock_bundle_skip foo "[[ 0 ]] && echo 'mock reason'"
  test::mock_hook foo save

  run tildepot run save
  assert_success
  test::assert_bundle_output --partial --skip foo --skip-reason "mock reason"
}

@test "calls hook when bundle skip does not print conditional message" {
  test::mock_bundle_skip foo "[[ '' ]] && echo 'mock reason'"
  test::mock_hook foo save

  run tildepot run save
  assert_success
  test::assert_bundle_output --partial --hook foo save
}

@test "prints multi-line reason on separate lines" {
  test::mock_bundle_skip foo "
    echo 'mock reason 1'
    echo 'mock reason 2'
  "
  test::mock_hook foo save

  run tildepot run save
  assert_success
  test::assert_bundle_output --partial \
    --skip foo \
    --skip-reason "mock reason 1" \
    --skip-reason "mock reason 2"
}
