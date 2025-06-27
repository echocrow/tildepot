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

###
# Basic behavior
###

@test "saves & restores file" {
  test_files::mock_setup "
    my-dot  ~/.my-dotfile
  "

  test::put 'my dotfile' "$TEST_HOME_MOCK/.my-dotfile"
  test_files::reset_home
  cp "$HOME/.my-dotfile" "$TEST_FILES_TARGET/my-dot"

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

@test "ignores non-existing entry" {
  test_files::mock_setup "
    foo  ~/foo
  "

  test_files::reset_home

  test::it 'ignores file on save'
  test_files::run_assert_save

  test::it 'removes previously saved file on save'
  echo 'foo' >"$TEST_FILES_STATE/foo"
  test_files::run_assert_save

  test::it 'ignores file on restore'
  test_files::run_assert_restore

  test::it 'removes source file on restore'
  echo 'foo' >"$HOME/foo"
  test_files::run_assert_restore --skip-clear
}

###
# Formats
###

@test "saves nested file" {
  test_files::mock_setup "
    foo/bar  ~/foobar
  "

  test::put 'foobar' "$TEST_HOME_MOCK/foobar"
  test_files::reset_home
  test::cp "$HOME/foobar" "$TEST_FILES_TARGET/foo/bar"

  test::it 'saves file'
  test_files::run_assert_save

  test::it 'restores file'
  test_files::run_assert_restore
}

@test "ignores comments and empty lines" {
  test_files::mock_setup "
    aa  ~/aa

    #bb  ~/bb

    cc  ~/cc
  "

  test::put 'aa' "$TEST_HOME_MOCK/aa"
  test::put 'bb' "$TEST_HOME_MOCK/bb"
  test::put '#bb' "$TEST_HOME_MOCK/#bb"
  test::put 'cc' "$TEST_HOME_MOCK/cc"
  test_files::reset_home
  cp "$HOME/aa" "$TEST_FILES_TARGET/aa"
  rm "$TEST_HOME_MOCK/bb"
  rm "$TEST_HOME_MOCK/#bb"
  cp "$HOME/cc" "$TEST_FILES_TARGET/cc"

  test::it 'saves file'
  test_files::run_assert_save

  test::it 'restores file'
  test_files::run_assert_restore
}

@test "saves & restores file with escaped spaces" {
  test_files::mock_setup "
    name\ with\ space  ~/dir\ with\ space/file\ with\ space
  "

  local DST="name with space"
  local SRC="dir with space/file with space"
  test::put 'hello world' "$TEST_HOME_MOCK/$SRC"
  test_files::reset_home
  cp "$HOME/$SRC" "$TEST_FILES_TARGET/$DST"

  test::it 'saves file'
  test_files::run_assert_save
  assert_line "==> Stored ~/$SRC in $DST"

  test::it 'restores file'
  test_files::run_assert_restore --skip-clear
  assert_line "==> Restored ~/$SRC from $DST"
}

@test "saves & restores file with non-escaped spaces" {
  test_files::mock_setup "
    name with space  ~/dir with space/file with space
  "

  local DST="name with space"
  local SRC="dir with space/file with space"
  test::put 'hello world' "$TEST_HOME_MOCK/$SRC"
  test_files::reset_home
  cp "$HOME/$SRC" "$TEST_FILES_TARGET/$DST"

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
  cp "$HOME/my-file" "$TEST_FILES_TARGET/my-file"

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
  test::cp "$HOME/.config/foo" "$TEST_FILES_TARGET/config/foo"
  test::cp "$HOME/.dotfile" "$TEST_FILES_TARGET/dots/file"

  test::it 'saves file'
  test_files::run_assert_save
  assert_line "==> Stored ~/.config/foo in config/foo"
  assert_line "==> Stored ~/.dotfile in dots/file"

  test::it 'restores file'
  test_files::run_assert_restore --skip-clear
}

@test "terminates groups on empty line" {
  test_files::mock_setup "
    [group]
    foo  ~/foo
    #
    bar  ~/bar

    root  ~/root
  "

  test::put 'foo' "$TEST_HOME_MOCK/foo"
  test::put 'bar' "$TEST_HOME_MOCK/bar"
  test::put 'root' "$TEST_HOME_MOCK/root"
  test_files::reset_home
  test::cp "$HOME/foo" "$TEST_FILES_TARGET/group/foo"
  test::cp "$HOME/bar" "$TEST_FILES_TARGET/group/bar"
  test::cp "$HOME/root" "$TEST_FILES_TARGET/root"

  test::it 'saves file'
  test_files::run_assert_save
  assert_line "==> Stored ~/foo in group/foo"
  assert_line "==> Stored ~/bar in group/bar"
  assert_line "==> Stored ~/root in root"

  test::it 'restores file'
  test_files::run_assert_restore --skip-clear
}

###
# Persistence
###

@test "leaves root files & dirs as-is" {
  test_files::mock_setup "
    aa  ~/aa
  "

  test::put 'aa' "$TEST_HOME_MOCK/aa"
  test_files::reset_home
  test::put 'bb' "$TEST_FILES_STATE/bb"
  test::put 'cc' "$TEST_FILES_STATE/cc/cc"
  test::cp "$HOME/aa" "$TEST_FILES_TARGET/aa"
  test::cp "$TEST_FILES_STATE/bb" "$TEST_FILES_TARGET/bb"
  test::cp "$TEST_FILES_STATE/cc" "$TEST_FILES_TARGET/cc"

  test::it 'keeps un-referenced items'
  test_files::run_assert_save
  refute_line "bb"
  refute_line "cc"

  test::it 'does not restore un-referenced items'
  test_files::run_assert_restore
  refute_line "bb"
  refute_line "cc"
  test_files::assert_dirs_equal "$TEST_FILES_STATE" "$TEST_FILES_TARGET"
}

@test "leaves nested files & dirs as-is" {
  test_files::mock_setup "
    foo/foo  ~/foo
  "

  test::put 'foo' "$TEST_HOME_MOCK/foo"
  test_files::reset_home
  test::put 'bar' "$TEST_FILES_STATE/foo/bar"
  test::put 'fizz/buzz' "$TEST_FILES_STATE/foo/fizz/buzz"
  test::cp "$HOME/foo" "$TEST_FILES_TARGET/foo/foo"
  test::cp "$TEST_FILES_STATE/foo/bar" "$TEST_FILES_TARGET/foo/bar"
  test::cp "$TEST_FILES_STATE/foo/fizz/buzz" "$TEST_FILES_TARGET/foo/fizz/buzz"

  test::it 'keeps un-referenced items'
  test_files::run_assert_save
  refute_line "bar"
  refute_line "fizz"

  test::it 'does not restore un-referenced items'
  test_files::run_assert_restore
  refute_line "bar"
  refute_line "fizz"
  test_files::assert_dirs_equal "$TEST_FILES_STATE" "$TEST_FILES_TARGET"
}

###
# IO processing
###

@test "processes files during save & restore" {
  test_files::mock_setup "
    foo  ~/foo  @my-io
  "
  # shellcheck disable=SC2016
  test_files::mock_bundle '
    function bundle::parse::my-io() {
      echo "fizz" >>"$1"
    }
    function bundle::serialize::my-io() {
      head -n -1 "$1" >"$1.tmp"
      mv "$1.tmp" "$1"
    }
  '

  test::put "foo" "$TEST_HOME_MOCK/foo"
  test_files::reset_home
  cp "$HOME/foo" "$TEST_FILES_TARGET/foo"
  echo 'fizz' >>"$TEST_FILES_TARGET/foo"

  test::it 'saves & parses file'
  test_files::run_assert_save

  test::it 'restores & serializes file'
  test_files::run_assert_restore --skip-clear
}

@test "processes grouped files during save & restore" {
  test_files::mock_setup "
    [aa]  @my-io
    foo  ~/foo
    bar  ~/bar
    [bb]
    baz  ~/baz
  "
  # shellcheck disable=SC2016
  test_files::mock_bundle '
    function bundle::parse::my-io() {
      echo "fizz" >>"$1"
    }
    function bundle::serialize::my-io() {
      head -n -1 "$1" >"$1.tmp"
      mv "$1.tmp" "$1"
    }
  '

  test::put "foo" "$TEST_HOME_MOCK/foo"
  test::put "bar" "$TEST_HOME_MOCK/bar"
  test::put "baz" "$TEST_HOME_MOCK/baz"
  test_files::reset_home
  test::cp "$HOME/foo" "$TEST_FILES_TARGET/aa/foo"
  test::cp "$HOME/bar" "$TEST_FILES_TARGET/aa/bar"
  test::cp "$HOME/baz" "$TEST_FILES_TARGET/bb/baz"
  echo 'fizz' >>"$TEST_FILES_TARGET/aa/foo"
  echo 'fizz' >>"$TEST_FILES_TARGET/aa/bar"

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

@test "provides built-in processor: plutil" {
  test_files::mock_setup "
    [cfg]  @plutil
    config.plist  ~/config.plist
  "

  test::put "<plist></plist>" "$TEST_HOME_MOCK/config.plist"
  test_files::reset_home
  test::cp "$HOME/config.plist" "$TEST_FILES_TARGET/cfg/config.plist"

  # Mock plutil.
  # shellcheck disable=SC2317
  function plutil() {
    test::log "Mocking plutil; args: plutil $*"
  }
  export -f plutil

  test::it 'saves & converts file to xml'
  test_files::run_assert_save
  test::assert_log "Mocking plutil; args: plutil -convert xml1 $TILDEPOT_HOME/"

  test::it 'restores & converts file to binary'
  test_files::run_assert_restore --skip-clear
  test::assert_log "Mocking plutil; args: plutil -convert binary1 $HOME/config.plist"

  unset -f plutil
}
