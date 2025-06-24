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

  test::put 'my dotfile' "$TEST_HOME_MOCK/.my-dotfile"
  test_files::reset_home
  cp -r "$HOME/.my-dotfile" "$TEST_FILES_TARGET/my-dot"

  test::it 'saves file'
  test_files::run_assert_save
  assert_line "==> Stored ~/.my-dotfile in my-dot"

  test::it 'overrides saved file'
  echo 'dirty' >>"$TEST_FILES_STATE/my-dot"
  test_files::run_assert_save

  test::it 'restores file'
  test_files::run_assert_restore
  assert_line "==> Restored ~/.my-dotfile from my-dot"

  test::it 'overrides source file'
  echo 'dirty' >>"$HOME/.my-dotfile"
  test_files::run_assert_restore --skip-clear
}

@test "saves & restores dir" {
  test_files::mock_setup "
    foo  ~/.config/foo
  "

  test::put 'foo-config' "$TEST_HOME_MOCK/.config/foo/config.foo"
  test::put 'fizz' "$TEST_HOME_MOCK/.config/foo/subdir/fizz.foo"
  test::put 'buzz' "$TEST_HOME_MOCK/.config/foo/subdir/buzz.foo"
  test_files::reset_home
  cp -r "$HOME/.config/foo" "$TEST_FILES_TARGET/foo"

  test::it 'saves dir'
  test_files::run_assert_save
  assert_line "==> Stored ~/.config/foo in foo"

  test::it 'overrides saved dir'
  echo 'dirty' >>"$TEST_FILES_STATE/foo/dirty"
  rm -rf "$TEST_FILES_STATE/foo/subdir"
  test_files::run_assert_save

  test::it 'restores dir'
  test_files::run_assert_restore
  assert_line "==> Restored ~/.config/foo from foo"

  test::it 'overrides source dir'
  echo 'dirty' >>"$HOME/.config/foo/dirty"
  rm -rf "$HOME/.config/foo/subdir"
  test_files::run_assert_restore --skip-clear
}

###
# Formats
###

@test "saves & restores file with escaped spaces" {
  test_files::mock_setup "
    name\ with\ space  ~/dir\ with\ space/file\ with\ space
  "

  local DST="name with space"
  local SRC="dir with space/file with space"
  test::put 'hello world' "$TEST_HOME_MOCK/$SRC"
  test_files::reset_home
  cp -r "$HOME/$SRC" "$TEST_FILES_TARGET/$DST"

  test::it 'saves file'
  test_files::run_assert_save
  assert_line "==> Stored ~/$SRC in $DST"

  test::it 'restores file'
  test_files::run_assert_restore --skip-clear
  assert_line "==> Restored ~/$SRC from $DST"
}

@test "saves & restores file tab-separated columns" {
  local tab=$'\t'
  test_files::mock_setup "
    my-file${tab}~/my-file
  "

  test::put 'foobar' "$TEST_HOME_MOCK/my-file"
  test_files::reset_home
  cp -r "$HOME/my-file" "$TEST_FILES_TARGET/my-file"

  test::it 'saves file'
  test_files::run_assert_save

  test::it 'restores file'
  test_files::run_assert_restore --skip-clear
}

###
# Groups
###

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
  test_files::run_assert_save
  assert_line "==> Stored ~/.config/foo in config/foo"
  assert_line "==> Stored ~/.dotfile in dots/file"

  test::it 'restores file'
  test_files::run_assert_restore --skip-clear
}

###
# IO processing
###

@test "processes files during save & restore" {
  test_files::mock_setup "
    [my-group]  @my-io
    foo  ~/foo
  "
  # shellcheck disable=SC2016
  test_files::mock_bundle '
    function bundle::parse::my-io() {
      echo "extra line" >>"$1"
    }
    function bundle::serialize::my-io() {
      head -n -1 "$1" >"$1.tmp"
      mv "$1.tmp" "$1"
    }
  '

  test::put "foo"$'\n'"bar" "$TEST_HOME_MOCK/foo"
  test_files::reset_home
  mkdir "$TEST_FILES_TARGET/my-group"
  cp -r "$HOME/foo" "$TEST_FILES_TARGET/my-group/foo"
  echo 'extra line' >>"$TEST_FILES_TARGET/my-group/foo"

  test::it 'saves & parses file'
  test_files::run_assert_save

  test::it 'restores & serializes file'
  test_files::run_assert_restore --skip-clear
}

@test "aborts when processor does not exist" {
  test_files::mock_setup "
    [my-group]  @my-io
    foo  ~/foo
  "

  test::it 'aborts on save'
  run tildepot save --bundle files
  assert_failure
  assert_line "==> Failed to process files entry; unknown IO type my-io"

  test::it 'aborts on restore'
  run tildepot restore --bundle files -y
  assert_failure
  assert_line "==> Failed to process files entry; unknown IO type my-io"
}

# TODO: built-in io: plutil
