#!/usr/bin/env bats
#
# Tests for `tildepot self uninstall`

setup() {
  load ../test_lib.sh
  export _TEMP_TILDEPOT="$BATS_TEST_TMPDIR/tildepot"
  cp "$TEST_BIN" "$_TEMP_TILDEPOT"
}

@test "uninstalls self" {
  run "$_TEMP_TILDEPOT" self uninstall -y
  assert_success
  assert_file_not_exist "$_TEMP_TILDEPOT"
  assert_exists "$TEST_BIN"
}
@test "uninstalls self from '--path'" {
  run tildepot self uninstall -y --path "$(dirname "$_TEMP_TILDEPOT")"
  assert_success
  assert_file_not_exist "$_TEMP_TILDEPOT"
  assert_exists "$TEST_BIN"
}
@test "prompts before uninstalling" {
  run test::expect_prompt \
    --prompt 'Uninstall tildepot from' y \
    "$_TEMP_TILDEPOT" self uninstall
  assert_success
  assert_file_not_exist "$_TEMP_TILDEPOT"
  assert_exists "$TEST_BIN"
}

@test "errors when '--path' does not exist" {
  run tildepot self uninstall --path "$BATS_TEST_TMPDIR/does-not-exist"
  assert_failure
  assert_output --partial "does not exist"
}
@test "errors when '--path' does not contain tildepot" {
  rm "$_TEMP_TILDEPOT"

  run tildepot self uninstall --path "$(dirname "$_TEMP_TILDEPOT")"
  assert_failure
  assert_output --partial "not installed at"
}
