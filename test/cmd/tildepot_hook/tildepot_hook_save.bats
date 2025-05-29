#!/usr/bin/env bats
#
# Tests for `tildepot save`

setup() {
  load ../../test_lib.sh
  load ./tildepot_hook_lib.sh
  load ./tildepot_hook_test.sh

  test::setup_assert_hook_cmd save
}

@test "describes hook command" {
  test::assert_hook_cmd "describes hook command"
}

@test "calls hook for all bundles" {
  test::assert_hook_cmd "calls hook for all bundles"
}

@test "aborts early when hook errors" {
  test::assert_hook_cmd "aborts early when hook errors"
}

@test "skips hook when hook skip returns 0" {
  test::assert_hook_cmd "skips hook when hook skip returns 0"
}

@test "calls hook when hook skip returns 1" {
  test::assert_hook_cmd "calls hook when hook skip returns 1"
}

@test "skips hook when hook skip prints message" {
  test::assert_hook_cmd "skips hook when hook skip prints message"
}

@test "skips hook when hook skip prints conditional message" {
  test::assert_hook_cmd "skips hook when hook skip prints conditional message"
}

@test "prints multi-line skip reason on separate, prefixed lines" {
  test::assert_hook_cmd "prints multi-line skip reason on separate, prefixed lines"
}

@test "calls hook when hook skip does not print conditional message" {
  test::assert_hook_cmd "calls hook when hook skip does not print conditional message"
}

@test "calls hook when '--force' is set despite hook skip returning 0" {
  test::assert_hook_cmd "calls hook when '--force' is set despite hook skip returning 0"
}
