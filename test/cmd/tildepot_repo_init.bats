#!/usr/bin/env bats
#
# Tests for `tildepot repo init`

setup() {
  load ../test_lib.sh
}

teardown() {
  rm -rf "$TEST_APP_REPO_ROOT"
  unset TILDEPOT_HOME
}

function assert_repo() {
  local dir="$1"
  assert_dir_exist "$dir"
  assert_dir_exist "$dir/.git"
  assert_file_exists "$dir/.gitignore"
  assert_output --partial "Initialized tildepot repository at $dir"
}

@test "inits a new git repo in default repo location" {
  rm -rf "$TEST_APP_REPO_ROOT"

  run tildepot repo init
  assert_success
  assert_repo "$TEST_APP_REPO_ROOT"
}

@test "inits a new repo in '--repo-dir'" {
  local dir="$BATS_TEST_TMPDIR"

  run tildepot repo init --repo-dir "$dir"
  assert_success
  assert_repo "$dir"
}
@test "inits a new repo in early-defined '--repo-dir'" {
  local dir="$BATS_TEST_TMPDIR"

  run tildepot --repo-dir "$dir" repo init
  assert_success
  assert_repo "$dir"
}

@test "inits new subdir for '--repo-dir'" {
  local dir="$BATS_TEST_TMPDIR/my-subdir"

  run tildepot repo init --repo-dir "$dir"
  assert_success
  assert_repo "$dir"
}
@test "aborts when '--repo-dir' parent dir does not exist" {
  local dir="$BATS_TEST_TMPDIR/does-not-exist/my-tildepot"

  run tildepot repo init --repo-dir "$dir"
  assert_failure
  assert_output --partial "does not exist"
}

@test "aborts when '--repo-dir' is not empty" {
  local dir="$BATS_TEST_TMPDIR"
  touch "$dir/foobar"

  run tildepot repo init --repo-dir "$dir"
  assert_failure
  assert_output --partial "is not empty"
}

@test "sets origin for '--repo' github owner" {
  local dir="$BATS_TEST_TMPDIR"

  run tildepot repo init --repo-dir "$dir" --repo "my-corp"
  assert_success
  test::assert_git_origin_url "$dir" "https://github.com/my-corp/tildepot.git"
}
@test "sets origin for '--repo' github owner/repo" {
  local dir="$BATS_TEST_TMPDIR"

  run tildepot repo init --repo-dir "$dir" --repo "my-username/my-tildepot"
  assert_success
  test::assert_git_origin_url "$dir" "https://github.com/my-username/my-tildepot.git"
}
@test "sets origin for '--repo' https url" {
  local dir="$BATS_TEST_TMPDIR"
  local origin="https://my.origin/repo.git"

  run tildepot repo init --repo-dir "$dir" --repo "$origin"
  assert_success
  test::assert_git_origin_url "$dir" "$origin"
}
@test "sets origin for '--repo' ssh destination" {
  local dir="$BATS_TEST_TMPDIR"
  local origin="me@my.origin:repo.git"

  run tildepot repo init --repo-dir "$dir" --repo "$origin"
  assert_success
  test::assert_git_origin_url "$dir" "$origin"
}
@test "aborts when '--repo' origin has too many slashes" {
  local dir="$BATS_TEST_TMPDIR"
  local origin="my/repo/suffix"

  run tildepot repo init --repo-dir "$dir" --repo "$origin"
  assert_failure
  assert_output --partial "Invalid repository origin"
}
@test "aborts when '--repo' origin does not match known format" {
  local dir="$BATS_TEST_TMPDIR"
  local origin="invalid://wherever"

  run tildepot repo init --repo-dir "$dir" --repo "$origin"
  assert_failure
  assert_output --partial "Invalid repository origin"
}

@test "inits a new repo in 'TILDEPOT_HOME' env var" {
  local dir="$BATS_TEST_TMPDIR"

  export TILDEPOT_HOME="$dir"
  run tildepot repo init
  assert_success
  assert_repo "$dir"
}
