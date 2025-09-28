#!/usr/bin/env bats
#
# Tests for `tildepot repo git`

setup() {
  load ../test_lib.sh

  # Mock git.
  # shellcheck disable=SC2317,SC2329
  function git() {
    test::log "Mocking git; args: git $*"
  }
  export -f git

  mkdir -p "$TEST_APP_REPO"
}

teardown() {
  unset -f git
}

function assert_git_called() {
  test::assert_log "Mocking git; args: git -C $TEST_APP_REPO $*"
}
function assert_git_called_with_dir() {
  local dir="${1?}"
  shift
  test::assert_log "Mocking git; args: git -C $dir $*"
}

@test "fails without parameters" {
  run tildepot repo git
  assert_failure
  assert_line --partial "Error: Too few parameters"
  assert_line --partial "expected 1+, got 0"
}

@test "forwards parameters to git" {
  run tildepot repo git status
  assert_success
  assert_git_called status
}

@test "forwards tildepot-like options to git" {
  run tildepot repo git --help
  assert_success
  assert_git_called --help
  refute_line --partial "Usage: tildepot"
}

@test "forwards all parameters & options to git" {
  run tildepot repo git commit --allow-empty -m 'foo'
  assert_success
  assert_git_called commit --allow-empty -m 'foo'
}

@test "accepts global options before 'git' command" {
  local dir="$BATS_TEST_TMPDIR"

  run tildepot --repo-dir "$dir" repo git status
  assert_success
  assert_git_called_with_dir "$dir" status
}

@test "aborts when the default repo location does not exist" {
  rm -rf "$TEST_APP_REPO"

  run tildepot repo git status
  assert_failure
  assert_dir_not_exists "$TEST_APP_REPO"
}
@test "aborts when '--repo-dir' does not exist" {
  local dir="$BATS_TEST_TMPDIR/does-not-exist"

  run tildepot --repo-dir "$dir" repo git status
  assert_failure
  assert_dir_not_exists "$dir"
}
