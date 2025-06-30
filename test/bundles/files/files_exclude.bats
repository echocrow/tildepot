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

  test::it 'deletes state item on save'
  test::put 'dirty' "$TEST_FILES_STATE/foo/fizz"
  test_files::run_assert_save

  test::it 'keeps host item on restore'
  test_files::run_assert_restore

  test::it 'replaces items from host on restore'
  test::put 'dirty' "$TEST_FILES_STATE/foo/fizz"
  test_files::run_assert_restore
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

  test::it 'deletes state item on save'
  test::put 'dirty' "$TEST_FILES_STATE/foo/fizz/buzz"
  test_files::run_assert_save

  test::it 'keeps host item on restore'
  test_files::run_assert_restore

  test::it 'replaces items from host on restore'
  test::put 'dirty' "$TEST_FILES_STATE/foo/fizz/buzz"
  test_files::run_assert_restore
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

  test::it 'restores file'
  test_files::run_assert_restore
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

  test::it 'restores file'
  test_files::run_assert_restore
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

  test::it 'keeps host item on restore'
  test_files::run_assert_restore
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
}

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
