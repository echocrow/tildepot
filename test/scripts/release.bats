#!/usr/bin/env bats
#
# Tests for `release` script

setup() {
  load release_lib.sh
}

teardown() {
  test::release_lib_teardown
}

@test "fetches tags & processes packages" {
  run release
  assert_success

  test::it "fetched tags"
  assert_line --partial "Fetching tags..."
  test::assert_log "git fetch"

  test::it "processes packages"
  assert_line --partial "Processing package foo..."
}

@test "exists w/o releases w/o release commits" {
  run release
  assert_success
  assert_line "(foo) skipping package"
  assert_dir_not_exists "$TEST_RELEASE_DIST_DIR"
}

@test "aborts w/o a config" {
  rm "$TEST_RELEASE_CONFIG_PATH"

  run release
  assert_failure
  assert_line --partial "file not found"
  refute_line --partial "current branch:"
}

# TODO: Assets
