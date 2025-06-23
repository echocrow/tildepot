#!/usr/bin/env bats
#
# Tests for `files-bundle`

setup() {
  load ../../test_lib.sh
  load ./files_lib.sh
}

teardown() {
  test_bundle::teardown
}

@test "saves & restores dir" {
  test_bundle::mock_setup "
    foo  ~/.config/foo
  "

  test_bundle::load_home_mock_fixture
  local DST_NAME="foo"
  local SRC_NAME=".config/foo"
  local MCK="$TEST_HOME_MOCK/$SRC_NAME"
  test_bundle::reload_home
  local DST="$TEST_FILE_STATE/$DST_NAME"
  local SRC="$HOME/$SRC_NAME"

  test::it 'saves dir'
  test_bundle::run_save
  assert_success
  test_bundle::assert_dirs_equal "$DST" "$MCK"
  assert_line "==> Stored ~/$SRC_NAME in $DST_NAME"

  test::it 'overrides saved dir'
  echo 'dirty' >>"$DST/dirty"
  rm -rf "$DST/feats"
  test_bundle::run_save
  assert_success
  test_bundle::assert_dirs_equal "$DST" "$MCK"

  test::it 'restores dir'
  test_bundle::reset_home
  test_bundle::run_restore
  assert_success
  test_bundle::assert_dirs_equal "$SRC" "$MCK"
  assert_line "==> Restored ~/$SRC_NAME from $DST_NAME"

  test::it 'overrides source dir'
  echo 'dirty' >>"$SRC/dirty"
  rm -rf "$SRC/feats"
  test_bundle::run_restore
  assert_success
  test_bundle::assert_dirs_equal "$SRC" "$MCK"
}

@test "saves & restores file" {
  test_bundle::mock_setup "
    dotfile  ~/.dotfile
  "

  test_bundle::load_home_mock_fixture
  local DST_NAME="dotfile"
  local SRC_NAME=".dotfile"
  local MCK="$TEST_HOME_MOCK/$SRC_NAME"
  test_bundle::reload_home
  local DST="$TEST_FILE_STATE/$DST_NAME"
  local SRC="$HOME/$SRC_NAME"

  test::it 'saves file'
  test_bundle::run_save
  assert_success
  assert_files_equal "$DST" "$MCK"
  assert_line "==> Stored ~/$SRC_NAME in $DST_NAME"

  test::it 'overrides saved file'
  echo 'dirty' >>"$DST"
  test_bundle::run_save
  assert_success
  assert_files_equal "$DST" "$MCK"

  test::it 'restores file'
  test_bundle::reset_home
  test_bundle::run_restore
  assert_success
  assert_files_equal "$SRC" "$MCK"
  assert_line "==> Restored ~/$SRC_NAME from $DST_NAME"

  test::it 'overrides source file'
  echo 'dirty' >>"$SRC"
  test_bundle::run_restore
  assert_success
  assert_files_equal "$SRC" "$MCK"
}

@test "saves & restores file with escaped spaces in path" {
  test_bundle::mock_setup "
    spaced  ~/dir\ with\ space/file\ with\ space
  "

  test_bundle::load_home_mock_fixture
  local DST_NAME="spaced"
  local SRC_NAME="dir with space/file with space"
  local MCK="$TEST_HOME_MOCK/$SRC_NAME"
  test::put 'hello world' "$MCK"
  test_bundle::reload_home
  local DST="$TEST_FILE_STATE/$DST_NAME"
  local SRC="$HOME/$SRC_NAME"

  test::it 'saves file'
  test_bundle::run_save
  assert_success
  assert_files_equal "$DST" "$MCK"
  assert_line "==> Stored ~/$SRC_NAME in $DST_NAME"

  test::it 'restores file'
  test_bundle::reset_home
  test_bundle::run_restore
  assert_success
  assert_files_equal "$SRC" "$MCK"
  assert_line "==> Restored ~/$SRC_NAME from $DST_NAME"
}

@test "saves & restores file tab-separated columns" {
  local tab=$'\t'
  test_bundle::mock_setup "
    dotfile${tab}~/.dotfile
  "

  test_bundle::load_home_mock_fixture
  local DST_NAME="dotfile"
  local SRC_NAME=".dotfile"
  local MCK="$TEST_HOME_MOCK/$SRC_NAME"
  test_bundle::reload_home
  local DST="$TEST_FILE_STATE/$DST_NAME"
  local SRC="$HOME/$SRC_NAME"

  test::it 'saves file'
  test_bundle::run_save
  assert_success
  assert_files_equal "$DST" "$MCK"
  assert_line "==> Stored ~/$SRC_NAME in $DST_NAME"

  test::it 'restores file'
  test_bundle::reset_home
  test_bundle::run_restore
  assert_success
  assert_files_equal "$SRC" "$MCK"
  assert_line "==> Restored ~/$SRC_NAME from $DST_NAME"
}

@test "groups files via header line" {
  test_bundle::mock_setup "
    [config]
    foo  ~/.config/foo

    [dots]
    file  ~/.dotfile
  "

  test::put 'foo' "$TEST_HOME_MOCK/.config/foo/config.foo"
  test::put 'bar' "$TEST_HOME_MOCK/.dotfile"
  test_bundle::reload_home

  test::it 'saves file'
  test_bundle::run_save
  assert_success
  test::assert_dir_files -d 5 "$TEST_FILE_STATE" \
    "config/foo/config.foo" \
    "dots/file"
  assert_line "==> Stored ~/.config/foo in config/foo"
  assert_line "==> Stored ~/.dotfile in dots/file"

  test::it 'restores file'
  test_bundle::reset_home
  test_bundle::run_restore
  assert_success
  test_bundle::assert_dirs_equal "$HOME" "$TEST_HOME_MOCK"
}

# TODO: test path io
# TODO: test path io via group
