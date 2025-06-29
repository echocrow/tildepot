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

@test "excludes nested file" {
  test_files::mock_setup "
    foo  ~/foo
      !fizz
  "

  test::put 'bar' "$TEST_HOME_MOCK/foo/bar"
  test::put 'fizz' "$TEST_HOME_MOCK/foo/fizz"
  test_files::reset_home
  test::put 'bar' "$TEST_FILES_TARGET/foo/bar"

  test::it 'excludes file'
  test_files::run_assert_save

  test::it 'restores file'
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
