#!/usr/bin/env bats
#
# Tests for `tildepot git`
#
# This is a test stub. For more `git` tests, see `tildepot_repo_git.bats`.

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

@test "fails without parameters" {
  run tildepot repo git
  assert_failure
  assert_line --partial "Error: Too few parameters"
  assert_line --partial "expected 1+, got 0"
}

@test "forwards parameters to git" {
  run tildepot repo git status
  assert_success
  test::assert_log "Mocking git; args: git -C $TEST_APP_REPO status"
}
