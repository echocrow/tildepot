#!/usr/bin/env bats
#
# Tests for `tildepot repo open`

setup() {
  load ../test_lib.sh

  # Mock open.
  # shellcheck disable=SC2317,SC2329
  function open() {
    test::log "Mocking open; args: open $*"
    # noop
  }
  export -f open
}

teardown() {
  rm -rf "$TEST_APP_REPO_ROOT"

  unset -f open
}

function assert_open_called() {
  local dir="$1"
  assert_output --partial "Mocking open; args: open -R $dir"
}

@test "calls open with the default repo location" {
  mkdir -p "$TEST_APP_REPO_ROOT"

  run tildepot repo open
  assert_success
  assert_open_called "$TEST_APP_REPO_ROOT"
}

@test "calls open with '--repo-dir'" {
  local dir="$BATS_TEST_TMPDIR"

  run tildepot repo open --repo-dir "$dir"
  assert_success
  assert_open_called "$dir"
}

@test "calls open with early-defined '--repo-dir'" {
  local dir="$BATS_TEST_TMPDIR"

  run tildepot --repo-dir "$dir" repo open
  assert_success
  assert_open_called "$dir"
}

@test "aborts when the default repo location does not exist" {
  rm -rf "$TEST_APP_REPO_ROOT"

  run tildepot repo open
  assert_failure
  assert_dir_not_exists "$TEST_APP_REPO_ROOT"
}
@test "aborts when '--repo-dir' does not exist" {
  local dir="$BATS_TEST_TMPDIR/does-not-exist"

  run tildepot repo open --repo-dir "$dir"
  assert_failure
  assert_dir_not_exists "$dir"
}
