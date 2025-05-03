#!/usr/bin/env bats
#
# Tests for `release` script (commits)

setup() {
  load release_lib.sh
}

teardown() {
  test::release_lib_teardown
}

@test "ignores non-conventional commits" {
  test::git_commit -m "foo bar"

  run release
  assert_success
  assert_line "(foo) skipping package"
  assert_dir_not_exists "$TEST_RELEASE_DIST_DIR"
}

@test "ignores unrelated scope commits" {
  test::git_commit -m "feat(other-scope): foobar"

  run release
  assert_success
  assert_line "(foo) skipping package"
  assert_dir_not_exists "$TEST_RELEASE_DIST_DIR"
}

@test "ignores non-release commits" {
  test::git_commit -m "chore(foo): foobar"

  run release
  assert_success
  assert_line --partial "non-release type chore"
  assert_line "(foo) skipping package"
  assert_dir_not_exists "$TEST_RELEASE_DIST_DIR"
}

@test "bumps patch version from 'patch' type commit" {
  test::git_commit -m "fix(foo): my title"

  run release
  assert_success
  assert_line --partial "fix @ foo bumps patch"
  assert_line "(foo) package bump: patch"
}
@test "bumps minor version from 'minor' type commit" {
  test::git_commit -m "feat(foo): my title"

  run release
  assert_success
  assert_line --partial "feat @ foo bumps minor"
  assert_line "(foo) package bump: minor"
}
@test "bumps major version from commit with '!' after scope" {
  test::git_commit -m "feat!(foo): my title"

  run release
  assert_success
  assert_line --partial "feat @ foo bumps major"
  assert_line "(foo) package bump: major"
}
@test "bumps major version from commit with 'BREAKING CHANGE:' body" {
  test::git_commit -m "feat(foo): my title" -m "BREAKING CHANGE: my desc"

  run release
  assert_success
  assert_line --partial "feat @ foo bumps major"
  assert_line "(foo) package bump: major"
}
@test "bumps major version from commit with 'BREAKING CHANGE:' footer" {
  test::git_commit -m "feat(foo): my title" -m "my body" -m "BREAKING CHANGE: my footer"

  run release
  assert_success
  assert_line --partial "feat @ foo bumps major"
  assert_line "(foo) package bump: major"
}
@test "does not bump major version from commit with '!' in message" {
  test::git_commit -m "feat(foo): my title!"

  run release
  assert_success
  refute_line --partial "feat @ foo bumps major"
  refute_line "(foo) package bump: major"
}

@test "picks the most significant commit bump (minor > patch)" {
  test::git_commit -m "feat(foo): commit"
  test::git_commit -m "fix(foo): commit"

  run release
  assert_success
  assert_line "(foo) package bump: minor"
}
@test "picks the most significant commit bump (patch < minor)" {
  test::git_commit -m "fix(foo): commit"
  test::git_commit -m "feat(foo): commit"

  run release
  assert_success
  assert_line "(foo) package bump: minor"
}
@test "picks the most significant commit bump (major > minor)" {
  test::git_commit -m "feat!(foo): commit"
  test::git_commit -m "feat(foo): commit"

  run release
  assert_success
  assert_line "(foo) package bump: major"
}
@test "picks the most significant commit bump (minor < major)" {
  test::git_commit -m "feat(foo): commit"
  test::git_commit -m "feat!(foo): commit"

  run release
  assert_success
  assert_line "(foo) package bump: major"
}
@test "picks the most significant commit bump (major > patch)" {
  test::git_commit -m "feat!(foo): commit"
  test::git_commit -m "fix(foo): commit"

  run release
  assert_success
  assert_line "(foo) package bump: major"
}
@test "picks the most significant commit bump (patch < major)" {
  test::git_commit -m "fix(foo): commit"
  test::git_commit -m "feat!(foo): commit"

  run release
  assert_success
  assert_line "(foo) package bump: major"
}
