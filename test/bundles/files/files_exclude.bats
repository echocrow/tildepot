#!/usr/bin/env bats
#
# Tests for `files-bundle` exclusions

setup() {
  load ../../test_lib.sh
  load ./files_lib.sh
}

teardown() {
  test_files::teardown
}

function test_files::refute_tools_log() {
  refute_line --partial 'find: '
  refute_line --partial 'rm: '
}

###
# Exact exclusions
###

@test "excludes nested file" {
  test_files::mock_setup "
    foo  ~/foo
      !fizz
  "

  test::put 'bar' "$TEST_HOME_MOCK/foo/bar"
  test::put 'fizz' "$TEST_HOME_MOCK/foo/fizz"
  test_files::reset_home
  test::put 'bar' "$TEST_FILES_TARGET/foo/bar"

  test::it 'excludes item on save'
  test_files::run_assert_save
  test_files::refute_tools_log

  test::it 'deletes state item on save'
  test::put 'dirty' "$TEST_FILES_STATE/foo/fizz"
  test_files::run_assert_save
  test_files::refute_tools_log

  test::it 'keeps host item on restore'
  test_files::run_assert_restore
  test_files::refute_tools_log

  test::it 'replaces items from host on restore'
  rm "$HOME/foo/bar"
  test::put 'dirty' "$TEST_FILES_STATE/foo/fizz"
  test_files::run_assert_restore
  test_files::refute_tools_log
}

@test "excludes nested dir" {
  test_files::mock_setup "
    foo  ~/foo
      !fizz
  "

  test::put 'bar' "$TEST_HOME_MOCK/foo/bar"
  test::put 'buzz' "$TEST_HOME_MOCK/foo/fizz/buzz"
  test_files::reset_home
  test::put 'bar' "$TEST_FILES_TARGET/foo/bar"

  test::it 'excludes item on save'
  test_files::run_assert_save
  test_files::refute_tools_log

  test::it 'deletes state item on save'
  test::put 'dirty' "$TEST_FILES_STATE/foo/fizz/buzz"
  test_files::run_assert_save
  test_files::refute_tools_log

  test::it 'keeps host item on restore'
  test_files::run_assert_restore
  test_files::refute_tools_log

  test::it 'replaces items from host on restore'
  rm "$HOME/foo/bar"
  test::put 'dirty' "$TEST_FILES_STATE/foo/fizz/buzz"
  test_files::run_assert_restore
  test_files::refute_tools_log
}

@test "excludes multiple items" {
  test_files::mock_setup "
    foo  ~/foo
      !fizz
      !buzz
  "

  test::put 'bar' "$TEST_HOME_MOCK/foo/bar"
  test::put 'fizz' "$TEST_HOME_MOCK/foo/fizz"
  test::put 'buzz' "$TEST_HOME_MOCK/foo/buzz"
  test_files::reset_home
  test::put 'bar' "$TEST_FILES_TARGET/foo/bar"

  test::it 'excludes file'
  test_files::run_assert_save
  test_files::refute_tools_log

  test::it 'restores file'
  test_files::run_assert_restore
  test_files::refute_tools_log
}

@test "ignores empty exclusion" {
  test_files::mock_setup "
    foo  ~/foo
      !fizz
  "

  test::put 'bar' "$TEST_HOME_MOCK/foo/bar"
  test_files::reset_home
  test::put 'bar' "$TEST_FILES_TARGET/foo/bar"

  test::it 'excludes file'
  test_files::run_assert_save
  test_files::refute_tools_log

  test::it 'restores file'
  test_files::run_assert_restore
  test_files::refute_tools_log
}

@test "accepts multiple common formats" {
  test_files::mock_setup "
    foo  ~/foo
      !./aa
      !/bb
      !cc/
      !./dd/
  "

  test::put 'bar' "$TEST_HOME_MOCK/foo/bar"
  test::put 'aa' "$TEST_HOME_MOCK/foo/aa"
  test::put 'bb' "$TEST_HOME_MOCK/foo/bb"
  test::put 'cc' "$TEST_HOME_MOCK/foo/cc/file"
  test::put 'dd' "$TEST_HOME_MOCK/foo/dd/file"
  test_files::reset_home
  test::put 'bar' "$TEST_FILES_TARGET/foo/bar"

  test::it 'excludes item on save'
  test_files::run_assert_save
  test_files::refute_tools_log

  test::it 'keeps host item on restore'
  test_files::run_assert_restore
  test_files::refute_tools_log
}

@test "restores excluded item from state when not present on host" {
  test_files::mock_setup "
    foo  ~/foo
      !file
      !dir
  "

  test::put 'bar' "$TEST_HOME_MOCK/foo/bar"
  test_files::reset_home
  test::put 'file' "$TEST_HOME_MOCK/foo/file"
  test::put 'dir' "$TEST_HOME_MOCK/foo/dir/nested"
  test::cp "$TEST_HOME_MOCK/foo" "$TEST_FILES_STATE/foo"

  test_files::run_assert_restore
  test_files::refute_tools_log
}

###
# Wildcard exclusions
###

@test "excludes wildcard-matching files" {
  test_files::mock_setup "
    foo  ~/foo
      !_*
  "

  test::put 'bar' "$TEST_HOME_MOCK/foo/bar"
  test::put '_bar' "$TEST_HOME_MOCK/foo/_bar"
  test::put '_baz' "$TEST_HOME_MOCK/foo/_baz"
  test_files::reset_home
  test::put 'bar' "$TEST_FILES_TARGET/foo/bar"

  test::it 'excludes file'
  test_files::run_assert_save
  test_files::refute_tools_log

  test::it 'restores file'
  test_files::run_assert_restore
  test_files::refute_tools_log
}

@test "excludes wildcard-matching dirs" {
  test_files::mock_setup "
    foo  ~/foo
      !_*
  "

  test::put 'bar' "$TEST_HOME_MOCK/foo/bar"
  test::put 'aa' "$TEST_HOME_MOCK/foo/_aa/file"
  test::put 'bb' "$TEST_HOME_MOCK/foo/_bb/file"
  test_files::reset_home
  test::put 'bar' "$TEST_FILES_TARGET/foo/bar"

  test::it 'excludes file'
  test_files::run_assert_save
  test_files::refute_tools_log

  test::it 'restores file'
  test_files::run_assert_restore
  test_files::refute_tools_log
}

@test "accepts multiple common formats with wildcards" {
  test_files::mock_setup "
    foo  ~/foo
      !./a*
      !/*b
      !c*/
  "

  test::put 'keep' "$TEST_HOME_MOCK/foo/keep"
  test::put 'aa' "$TEST_HOME_MOCK/foo/aa"
  test::put 'bb' "$TEST_HOME_MOCK/foo/bb"
  test::put 'cc' "$TEST_HOME_MOCK/foo/cc/file"
  test_files::reset_home
  test::put 'keep' "$TEST_FILES_TARGET/foo/keep"

  test::it 'excludes item on save'
  test_files::run_assert_save
  test_files::refute_tools_log

  test::it 'keeps host item on restore'
  test_files::run_assert_restore
  test_files::refute_tools_log
}

@test "matches trailing slashes to dirs only" {
  test_files::mock_setup "
    foo  ~/foo
      !a*/
  "

  test::put 'keep' "$TEST_HOME_MOCK/foo/keep"
  test::put 'a_file' "$TEST_HOME_MOCK/foo/a_file"
  test::put 'a_dir' "$TEST_HOME_MOCK/foo/a_dir/file"
  test_files::reset_home
  test::put 'keep' "$TEST_FILES_TARGET/foo/keep"
  test::put 'a_file' "$TEST_FILES_TARGET/foo/a_file"

  test::it 'excludes only dirs on save'
  test_files::run_assert_save
  test_files::refute_tools_log

  test::it 'excludes only dirs on restore'
  test::put 'dirty' "$HOME/foo/a_file"
  test_files::run_assert_restore
  test_files::refute_tools_log
}

# TODO: multiple wildcards

# TODO: restores wildcard-excluded item from state when not present on host

###
# Invalid configs
###

@test "aborts on too many columns in exclusion" {
  test_files::mock_setup "
    foo  ~/foo
      !fizz  buzz
  "

  test::it 'aborts on save'
  run tildepot save --bundle files
  assert_failure
  assert_line --partial "Invalid config"
  assert_line --partial "too many columns"

  test::it 'aborts on restore'
  run tildepot restore --bundle files -y
  assert_failure
  assert_line --partial "Invalid config"
  assert_line --partial "too many columns"
}

@test "aborts on missing parent" {
  test_files::mock_setup "
      !fizz
  "

  test_files::assert_invalid_config "missing parent"
}
@test "aborts on missing parent after group separation" {
  test_files::mock_setup "
    bar  ~/bar

      !fizz
  "

  test_files::assert_invalid_config "missing parent"
}
@test "aborts on missing parent after new group" {
  test_files::mock_setup "
    bar  ~/bar
    [fizz]
      !buzz
  "

  test_files::assert_invalid_config "missing parent"
}

###
# Misc edge cases
###

@test "ignores exclusion when parent item was skipped" {
  test_files::mock_setup "
    missing  ~/missing
      !nested
      !_*
    foo      ~/foo
  "

  test::put 'foo' "$TEST_HOME_MOCK/foo"
  test_files::reset_home
  test::cp "$HOME/foo" "$TEST_FILES_TARGET/foo"

  test::it 'saves files'
  test_files::run_assert_save
  test_files::refute_tools_log

  test::it 'restores files'
  test_files::run_assert_restore --clean
  test_files::refute_tools_log
}
