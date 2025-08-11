#!/usr/bin/env bats
#
# Tests for `tildepot git`

setup() {
  load ../test_lib.sh

  # Mock git.
  # shellcheck disable=SC2317,SC2329
  function git() {
    test::log "Mocking git; args: git $*"
  }
  export -f git

  mkdir -p "$TEST_APP_REPO_ROOT"
}

teardown() {
  rm -rf "$TEST_APP_REPO_ROOT"

  unset -f git
}

function assert_git_called() {
  test::assert_log "Mocking git; args: git -C $TEST_APP_REPO_ROOT $*"
}
function assert_git_called_with_dir() {
  local dir="${1?}"
  shift
  test::assert_log "Mocking git; args: git -C $dir $*"
}

@test "fails without parameters" {
  run tildepot git
  assert_failure
  assert_line --partial "Error: Too few parameters"
  assert_line --partial "expected 1+, got 0"
}

@test "forwards parameters to git" {
  run tildepot git status
  assert_success
  assert_git_called status
}

@test "forwards tildepot-like options to git" {
  run tildepot git --help
  assert_success
  assert_git_called --help
  refute_line --partial "Usage: tildepot"
}

@test "forwards all parameters & options to git" {
  run tildepot git commit --allow-empty -m 'foo'
  assert_success
  assert_git_called commit --allow-empty -m 'foo'
}

@test "accepts global options before 'git' command" {
  local dir="$BATS_TEST_TMPDIR"

  run tildepot --repo-dir "$dir" git status
  assert_success
  assert_git_called_with_dir "$dir" status
}
