#!/usr/bin/env bats
#
# Tests for `tildepot self install`

setup() {
  load ../test_lib.sh
}

teardown() {
  rm -f "$LIB_TILDEPOT_DEFAULT_INSTALL_PATH/tildepot"
}

function assert_installed() {
  local dir="$1"
  assert_file_exist "$dir/tildepot"
  assert_file_not_empty "$dir/tildepot"
  assert_file_executable "$dir/tildepot"
  assert_files_equal "$dir/tildepot" "$LIB_TILDEPOT_BIN"
}

@test "copies itself into default install path" {
  local dir="$LIB_TILDEPOT_DEFAULT_INSTALL_PATH"
  assert_file_not_exist "$dir/tildepot"

  run tildepot self install -y
  assert_success
  assert_installed "$dir"
}

@test "copies itself into '--path'" {
  local dir="$BATS_TEST_TMPDIR"
  assert_file_not_exist "$dir/tildepot"

  run tildepot self install -y --path "$dir"
  assert_success
  assert_installed "$dir"
}

@test "replaces existing file" {
  local dir="$BATS_TEST_TMPDIR"
  touch "$dir/tildepot"
  assert_file_empty "$dir/tildepot"

  run tildepot self install -y --path "$dir"
  assert_success
  assert_installed "$dir"
  assert_file_not_empty "$dir/tildepot"
}
@test "prompts when replacing existing file" {
  local dir="$BATS_TEST_TMPDIR"
  touch "$dir/tildepot"

  run lib::expect_prompt \
    --prompt '"Continue installing"' y \
    --prompt '"Replace existing"' y \
    tildepot self install --path "$dir"
  assert_success
  assert_installed "$dir"
}

@test 'prompts when tildepot is already in \$PATH' {
  local dir="$BATS_TEST_TMPDIR"

  run lib::expect_prompt \
    --output '"already installed at"' \
    --prompt '"Continue installing"' y \
    tildepot self install --path "$dir"
  assert_success
  assert_installed "$dir"
}
@test 'does not prompt when tildepot is not in \$PATH' {
  local dir="$BATS_TEST_TMPDIR"

  PATH="$LIB_INITIAL_PATH" \
    run "$LIB_TILDEPOT_BIN" self install --path "$dir"
  assert_success
  assert_installed "$dir"
}

@test "aborts when installing into itself" {
  local dir
  dir="$(dirname "$LIB_TILDEPOT_BIN")"

  run tildepot self install --path "$dir"
  assert_success
  assert_installed "$dir"
  assert_output --partial "is already installed at"
}

@test "errors when '--path' does not exist" {
  run tildepot self install --path "$BATS_TEST_TMPDIR/does-not-exist"
  assert_failure
  assert_output --partial "does not exist"
}
