#!/usr/bin/env bats
#
# Tests for `tildepot apply`

setup() {
  load ../../test_lib.sh
  load ./tildepot_hook_lib.sh
}

@test "describes hook command" {
  test::test_hook_cmd apply
}

@test "calls hook for all bundles" {
  test::mock_hook aaa apply
  test::mock_hook bbb apply

  run tildepot apply -y
  assert_success
  test::assert_bundle_output --hook aaa apply --hook bbb apply
}

@test "skips hook when hook skip returns 0" {
  test::mock_hook_skip foo apply "return 0"

  run tildepot apply -y
  assert_success
  test::assert_bundle_output --hook-skip foo apply
}
@test "calls hook when hook skip returns 1" {
  test::mock_hook_skip foo apply "return 1"

  run tildepot apply -y
  assert_success
  test::assert_bundle_output --hook foo apply
}
@test "skips hook when hook skip prints message" {
  test::mock_hook_skip foo apply "echo 'mock reason'"

  run tildepot apply -y
  assert_success
  test::assert_bundle_output --hook-skip foo apply --skip-reason "mock reason"
}
@test "skips hook when hook skip prints conditional message" {
  test::mock_hook_skip foo apply "[[ 0 ]] && echo 'mock reason'"

  run tildepot apply -y
  assert_success
  test::assert_bundle_output --hook-skip foo apply --skip-reason "mock reason"
}
@test "calls hook when hook skip does not print conditional message" {
  test::mock_hook_skip foo apply "[[ '' ]] && echo 'mock reason'"

  run tildepot apply -y
  assert_success
  test::assert_bundle_output --hook foo apply
}
@test "calls hook when '--force' is set despite hook skip returning 0" {
  test::mock_hook_skip foo apply "return 0"

  run tildepot apply -y --force
  assert_success
  test::assert_bundle_output --hook foo apply
}

# Additional hook tests.
@test "props for confirmation before applying" {
  test::mock_hook foo apply

  run test::expect_prompt \
    --output "Restoring snapshots will override" \
    --prompt "Continue?" y \
    tildepot apply
  assert_success
  test::assert_bundle_output --partial --hook foo apply
}
