#!/usr/bin/env bats
#
# Tests for `tildepot self uninstall`

setup() {
  load ../test_lib.sh
  export _TEMP_TILDEPOT="$BATS_TEST_TMPDIR/tildepot"
  cp "$TEST_BIN" "$_TEMP_TILDEPOT"

  export _MOCK_APP_VERSION='0.0.0-mock'

  test::mock_download --fixture tildepot_mock.sh
}

teardown() {
  test::mock_download_teardown
}

function assert_updated() {
  local bin="$1"

  assert_output --partial "Updated Tildepot from $TEST_VERSION to $_MOCK_APP_VERSION"
  assert_file_exist "$bin"
  assert_file_not_empty "$bin"
  assert_file_executable "$bin"

  test::it "is the new mock version"
  assert_files_equal "$bin" "$(test::fixture_path tildepot_mock.sh)"
}

@test "updates self" {
  run "$_TEMP_TILDEPOT" self update
  assert_success
  assert_updated "$_TEMP_TILDEPOT"
}
@test "downloads latest version into '--path'" {
  cp "$TEST_BIN" "$BATS_TEST_TMPDIR/original"

  run tildepot self update --path "$(dirname "$_TEMP_TILDEPOT")"
  assert_success
  assert_updated "$_TEMP_TILDEPOT"

  test::it "did not overwrite original"
  assert_files_equal "$TEST_BIN" "$BATS_TEST_TMPDIR/original"
}

@test "skips when update version matches current version" {
  test::mock_download --path "$TEST_BIN"

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
