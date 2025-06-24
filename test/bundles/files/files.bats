#!/usr/bin/env bats
#
# Tests for `files-bundle`

setup() {
  load ../../test_lib.sh
  load ./files_lib.sh
}

teardown() {
  test_files::teardown
}

@test "saves & restores file" {
  test_files::mock_setup "
    my-dot  ~/.my-dotfile
  "

  local DST_NAME="my-dot"
  local SRC_NAME=".my-dotfile"
  local MCK="$TEST_HOME_MOCK/$SRC_NAME"
  test::put 'my dotfile' "$MCK"
  test_files::reset_home
  cp -r "$HOME/$SRC_NAME" "$TEST_FILES_TARGET/$DST_NAME"
  local DST="$TEST_FILES_STATE/$DST_NAME"
  local SRC="$HOME/$SRC_NAME"

  test::it 'saves file'
  run tildepot save --bundle files
  assert_success
  test_files::assert_dirs_equal "$TEST_FILES_STATE" "$TEST_FILES_TARGET"
  assert_line "==> Stored ~/$SRC_NAME in $DST_NAME"

  test::it 'overrides saved file'
  echo 'dirty' >>"$DST"
  run tildepot save --bundle files
  assert_success
  test_files::assert_dirs_equal "$TEST_FILES_STATE" "$TEST_FILES_TARGET"

  test::it 'restores file'
  test_files::clear_home
  run tildepot restore --bundle files -y
  assert_success
  test_files::assert_dirs_equal "$HOME" "$TEST_HOME_MOCK"
  assert_line "==> Restored ~/$SRC_NAME from $DST_NAME"

  test::it 'overrides source file'
  echo 'dirty' >>"$SRC"
  run tildepot restore --bundle files -y
  assert_success
  test_files::assert_dirs_equal "$HOME" "$TEST_HOME_MOCK"
}

@test "saves & restores dir" {
  test_files::mock_setup "
    foo  ~/.config/foo
  "

  local DST_NAME="foo"
  local SRC_NAME=".config/foo"
  local MCK="$TEST_HOME_MOCK/$SRC_NAME"
  test::put 'foo-config' "$MCK/config.foo"
  test::put 'fizz' "$MCK/subdir/fizz.foo"
  test::put 'buzz' "$MCK/subdir/buzz.foo"
  test_files::reset_home
  cp -r "$HOME/$SRC_NAME" "$TEST_FILES_TARGET/$DST_NAME"
  local DST="$TEST_FILES_STATE/$DST_NAME"
  local SRC="$HOME/$SRC_NAME"

  test::it 'saves dir'
  run tildepot save --bundle files
  assert_success
  test_files::assert_dirs_equal "$TEST_FILES_STATE" "$TEST_FILES_TARGET"
  assert_line "==> Stored ~/$SRC_NAME in $DST_NAME"

  test::it 'overrides saved dir'
  echo 'dirty' >>"$DST/dirty"
  rm -rf "$DST/subdir"
  run tildepot save --bundle files
  assert_success
  test_files::assert_dirs_equal "$TEST_FILES_STATE" "$TEST_FILES_TARGET"

  test::it 'restores dir'
  test_files::clear_home
  run tildepot restore --bundle files -y
  assert_success
  test_files::assert_dirs_equal "$HOME" "$TEST_HOME_MOCK"
  assert_line "==> Restored ~/$SRC_NAME from $DST_NAME"

  test::it 'overrides source dir'
  echo 'dirty' >>"$SRC/dirty"
  rm -rf "$SRC/subdir"
  run tildepot restore --bundle files -y
  assert_success
  test_files::assert_dirs_equal "$HOME" "$TEST_HOME_MOCK"
}

@test "saves & restores file with escaped spaces" {
  test_files::mock_setup "
    name\ with\ space  ~/dir\ with\ space/file\ with\ space
  "

  local DST_NAME="name with space"
  local SRC_NAME="dir with space/file with space"
  local MCK="$TEST_HOME_MOCK/$SRC_NAME"
  test::put 'hello world' "$MCK"
  test_files::reset_home
  cp -r "$HOME/$SRC_NAME" "$TEST_FILES_TARGET/$DST_NAME"
  local DST="$TEST_FILES_STATE/$DST_NAME"
  local SRC="$HOME/$SRC_NAME"

  test::it 'saves file'
  run tildepot save --bundle files
  assert_success
  test_files::assert_dirs_equal "$TEST_FILES_STATE" "$TEST_FILES_TARGET"
  assert_line "==> Stored ~/$SRC_NAME in $DST_NAME"

  test::it 'restores file'
  test_files::clear_home
  run tildepot restore --bundle files -y
  assert_success
  test_files::assert_dirs_equal "$HOME" "$TEST_HOME_MOCK"
  assert_line "==> Restored ~/$SRC_NAME from $DST_NAME"
}

@test "saves & restores file tab-separated columns" {
  local tab=$'\t'
  test_files::mock_setup "
    my-file${tab}~/my-file
  "

  local DST_NAME="my-file"
  local SRC_NAME="my-file"
  local MCK="$TEST_HOME_MOCK/$SRC_NAME"
  test::put 'foobar' "$MCK"
  test_files::reset_home
  cp -r "$HOME/$SRC_NAME" "$TEST_FILES_TARGET/$DST_NAME"
  local DST="$TEST_FILES_STATE/$DST_NAME"
  local SRC="$HOME/$SRC_NAME"

  test::it 'saves file'
  run tildepot save --bundle files
  assert_success
  test_files::assert_dirs_equal "$TEST_FILES_STATE" "$TEST_FILES_TARGET"

  test::it 'restores file'
  test_files::clear_home
  run tildepot restore --bundle files -y
  assert_success
  test_files::assert_dirs_equal "$HOME" "$TEST_HOME_MOCK"
}

@test "groups files via header line" {
  test_files::mock_setup "
    [config]
    foo  ~/.config/foo

    [dots]
    file  ~/.dotfile
  "

  test::put 'foo' "$TEST_HOME_MOCK/.config/foo/config.foo"
  test::put 'bar' "$TEST_HOME_MOCK/.dotfile"
  test_files::reset_home
  mkdir "$TEST_FILES_TARGET/config"
  cp -r "$HOME/.config/foo" "$TEST_FILES_TARGET/config/foo"
  mkdir "$TEST_FILES_TARGET/dots"
  cp -r "$HOME/.dotfile" "$TEST_FILES_TARGET/dots/file"

  test::it 'saves file'
  run tildepot save --bundle files
  assert_success
  test_files::assert_dirs_equal "$TEST_FILES_STATE" "$TEST_FILES_TARGET"
  assert_line "==> Stored ~/.config/foo in config/foo"
  assert_line "==> Stored ~/.dotfile in dots/file"

  test::it 'restores file'
  test_files::clear_home
  run tildepot restore --bundle files -y
  assert_success
  test_files::assert_dirs_equal "$HOME" "$TEST_HOME_MOCK"
}

# TODO: test path io
# TODO: test path io via group
