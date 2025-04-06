#!/usr/bin/env bats
#
# Tests for `tildepot self uninstall`

setup() {
  load ../test_lib.sh
  export _TEMP_TILDEPOT="$BATS_TEST_TMPDIR/tildepot"
  cp "$LIB_TILDEPOT_BIN" "$_TEMP_TILDEPOT"

  export _MOCK_TILDEPOT_VERSION='0.0.0-mock'

  lib::mock_download --fixture tildepot_mock.sh
}

teardown() {
  lib::mock_download_teardown
}

function assert_updated() {
  local bin="$1"

  assert_output --partial "Updated Tildepot from $LIB_TILDEPOT_TEST_VERSION to $_MOCK_TILDEPOT_VERSION"
  assert_file_exist "$bin"
  assert_file_not_empty "$bin"
  assert_file_executable "$bin"

  lib::it "is the new mock version"
  assert_files_equal "$bin" "$(lib::fixture_path tildepot_mock.sh)"
}

@test "updates self" {
  run "$_TEMP_TILDEPOT" self update
  assert_success
  assert_updated "$_TEMP_TILDEPOT"
}
@test "downloads latest version into '--path'" {
  cp "$LIB_TILDEPOT_BIN" "$BATS_TEST_TMPDIR/original"

  run tildepot self update --path "$(dirname "$_TEMP_TILDEPOT")"
  assert_success
  assert_updated "$_TEMP_TILDEPOT"

  lib::it "did not overwrite original"
  assert_files_equal "$LIB_TILDEPOT_BIN" "$BATS_TEST_TMPDIR/original"
}

@test "skips when update version matches current version" {
  lib::mock_download --path "$LIB_TILDEPOT_BIN"

  run "$_TEMP_TILDEPOT" self update
  assert_success
  assert_output --partial "is already up to date"
}

@test "errors when '--path' does not exist" {
  run tildepot self update --path "$BATS_TEST_TMPDIR/does-not-exist"
  assert_failure
  assert_output --partial "does not exist"
}
@test "errors when '--path' does not contain tildepot" {
  rm "$_TEMP_TILDEPOT"
  run tildepot self update --path "$(dirname "$_TEMP_TILDEPOT")"
  assert_failure
  assert_output --partial "not installed at"
}
