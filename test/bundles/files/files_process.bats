#!/usr/bin/env bats
#
# Tests for `files-bundle` processing

setup() {
  load ../../test_lib.sh
  load ./files_lib.sh
}

teardown() {
  test_files::teardown
}

@test "processes files during save & restore" {
  test_files::mock_setup "
    foo  ~/foo  @my-io
  "
  # shellcheck disable=SC2016
  test_files::mock_bundle '
    function bundle::parse::my-io() {
      echo "[TEST] PARSE $1"
      echo "fizz" >>"$1"
    }
    function bundle::serialize::my-io() {
      echo "[TEST] SERIALIZE $1"
      head -n -1 "$1" >"$1.tmp"
      mv "$1.tmp" "$1"
    }
  '

  test::put 'foo' "$TEST_HOME_MOCK/foo"
  test_files::reset_home
  cp "$HOME/foo" "$TEST_FILES_TARGET/foo"
  echo 'fizz' >>"$TEST_FILES_TARGET/foo"

  test::it 'saves & parses file'
  test_files::run_assert_save

  test::it 'does not alter original host file'
  assert_files_equal "$HOME/foo" "$TEST_HOME_MOCK/foo"
  test::it 'parses file in private dir'
  assert_line "[TEST] PARSE $TILDEPOT_HOME/.tildepot/state/files/foo"

  test::it 'restores & serializes file'
  test_files::run_assert_restore

  test::it 'does not alter original state file'
  assert_files_equal "$TEST_FILES_STATE/foo" "$TEST_FILES_TARGET/foo"
  test::it 'serializes file in private dir'
  assert_line "[TEST] SERIALIZE $TILDEPOT_HOME/.tildepot/state/files/foo"
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

  test::put 'foo' "$TEST_HOME_MOCK/foo"
  test::put 'bar' "$TEST_HOME_MOCK/bar"
  test::put 'baz' "$TEST_HOME_MOCK/baz"
  test_files::reset_home
  test::cp "$HOME/foo" "$TEST_FILES_TARGET/aa/foo"
  test::cp "$HOME/bar" "$TEST_FILES_TARGET/aa/bar"
  test::cp "$HOME/baz" "$TEST_FILES_TARGET/bb/baz"
  echo 'fizz' >>"$TEST_FILES_TARGET/aa/foo"
  echo 'fizz' >>"$TEST_FILES_TARGET/aa/bar"

  test::it 'saves & parses file'
  test_files::run_assert_save

  test::it 'restores & serializes file'
  test_files::run_assert_restore
}

@test "processes files with implicit group & item name during save & restore" {
  test_files::mock_setup "
    [group]  @explicit
    item     ~/my-file
  "
  # shellcheck disable=SC2016
  test_files::mock_bundle '
    function _parse() {
      local file="${1?}"
      local line="${2?}"
      echo "$line" >>"$file"
    }
    function _serialize() {
      local file="${1?}"
      local line="${2?}"
      [[ $(tail -n 1 "$file") != "$line" ]] && return
      head -n -1 "$file" >"$file.tmp"
      mv "$file.tmp" "$file"
    }

    function bundle::parse::explicit() {
      _parse "$1" "explicit"
    }
    function bundle::serialize::explicit() {
      _serialize "$1" "explicit"
    }

    function bundle::parse::group() {
      _parse "$1" "group"
    }
    function bundle::serialize::group() {
      _serialize "$1" "group"
    }

    function bundle::parse::group/item() {
      _parse "$1" "group/item"
    }
    function bundle::serialize::group/item() {
      _serialize "$1" "group/item"
    }
  '

  test::put 'hello' "$TEST_HOME_MOCK/my-file"
  test_files::reset_home
  test::cp "$HOME/my-file" "$TEST_FILES_TARGET/group/item"
  {
    echo 'explicit'
    echo 'group'
    echo 'group/item'
  } >>"$TEST_FILES_TARGET/group/item"

  test::it 'parses file by explicit -> group -> item'
  test_files::run_assert_save

  test::it 'serializes file by item -> group -> explicit'
  test_files::run_assert_restore
}

@test "aborts when explicit processor does not exist" {
  test_files::mock_setup "
    foo  ~/foo  @my-io
  "

  test::it 'aborts on save'
  test::put 'foo' "$HOME/foo"
  run tildepot save --bundle files
  assert_failure
  assert_line "==> Failed to process files entry; unknown IO type my-io"

  test::it 'aborts on restore'
  test::put 'foo' "$TEST_FILES_STATE/foo"
  run tildepot restore --bundle files -y
  assert_failure
  assert_line "==> Failed to process files entry; unknown IO type my-io"
}

@test "skips process when file does not exist" {
  test_files::mock_setup "
    foo  ~/foo  @bar
  "
  test_files::mock_bundle '
    function bundle::parse::bar() {
      echo "[TEST] PROC BAR: PARSE"
    }
    function bundle::serialize::bar() {
      echo "[TEST] PROC BAR: SERIALIZE"
    }
  '

  test::it 'ignores missing host file'
  test_files::run_assert_save
  refute_line --partial "[TEST] PROC BAR"

  test::it 'ignores missing state file'
  test_files::run_assert_restore
  refute_line --partial "[TEST] PROC BAR"
}

@test "keeps files as-is when process errors" {
  test_files::mock_setup "
    foo  ~/foo  @bar
  "
  test_files::mock_bundle '
    function bundle::parse::bar() {
      return 1
    }
    function bundle::serialize::bar() {
      return 1
    }
  '

  test::put 'host' "$TEST_HOME_MOCK/foo"
  test_files::reset_home
  test::put 'state' "$TEST_FILES_STATE/foo"
  test::cp "$TEST_FILES_STATE/foo" "$TEST_FILES_TARGET/foo"

  test::it 'keeps files on save'
  run tildepot save --bundle files
  assert_failure
  test_files::assert_dirs_equal "$HOME" "$TEST_HOME_MOCK"
  test_files::assert_dirs_equal "$TEST_FILES_STATE" "$TEST_FILES_TARGET"

  test::it 'keeps files on restore'
  run tildepot restore --bundle files -y
  assert_failure
  test_files::assert_dirs_equal "$HOME" "$TEST_HOME_MOCK"
  test_files::assert_dirs_equal "$TEST_FILES_STATE" "$TEST_FILES_TARGET"
}

@test "keeps files as-is when late process errors" {
  test_files::mock_setup "
    foo  ~/foo
    bar  ~/bar  @fail
  "
  test_files::mock_bundle '
    function bundle::parse::fail() {
      return 1
    }
    function bundle::serialize::fail() {
      return 1
    }
  '

  test::put 'host' "$TEST_HOME_MOCK/foo"
  test::put 'host' "$TEST_HOME_MOCK/bar"
  test_files::reset_home
  test::put 'state' "$TEST_FILES_STATE/foo"
  test::put 'state' "$TEST_FILES_STATE/bar"
  test::cp "$TEST_FILES_STATE/foo" "$TEST_FILES_TARGET/foo"
  test::cp "$TEST_FILES_STATE/bar" "$TEST_FILES_TARGET/bar"

  test::it 'keeps files on save'
  run tildepot save --bundle files
  assert_failure
  test_files::assert_dirs_equal "$HOME" "$TEST_HOME_MOCK"
  test_files::assert_dirs_equal "$TEST_FILES_STATE" "$TEST_FILES_TARGET"

  test::it 'keeps files on restore'
  run tildepot restore --bundle files -y
  assert_failure
  test_files::assert_dirs_equal "$HOME" "$TEST_HOME_MOCK"
  test_files::assert_dirs_equal "$TEST_FILES_STATE" "$TEST_FILES_TARGET"
}

###
# Built-in processors
###

@test "provides built-in processor: plutil" {
  test_files::mock_setup "
    [cfg]  @plutil
    config.plist  ~/config.plist
  "

  test::put '<plist></plist>' "$TEST_HOME_MOCK/config.plist"
  test_files::reset_home
  test::cp "$HOME/config.plist" "$TEST_FILES_TARGET/cfg/config.plist"

  # Mock plutil.
  # shellcheck disable=SC2317
  function plutil() {
    test::log "Mocking plutil; cmd: [plutil $*]"
  }
  export -f plutil

  test::it 'saves & converts file to xml'
  test_files::run_assert_save
  test::assert_log "Mocking plutil; cmd: [plutil -convert xml1 $TILDEPOT_HOME/.tildepot/state/files/cfg/config.plist]"

  test::it 'restores & converts file to binary'
  test_files::run_assert_restore
  test::assert_log "Mocking plutil; cmd: [plutil -convert binary1 $TILDEPOT_HOME/.tildepot/state/files/cfg/config.plist]"

  unset -f plutil
}
