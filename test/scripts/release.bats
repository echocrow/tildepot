#!/usr/bin/env bats
#
# Tests for `release` script

setup() {
  load ../test_lib.sh

  # Use test temp dir as repo & pwd.
  mkdir "$BATS_TEST_TMPDIR/repo"
  cd "$BATS_TEST_TMPDIR/repo" || exit
  export TEST_RELEASE_DIST_DIR="$BATS_TEST_TMPDIR/repo/dist/release"

  # Set up basic release config
  cat >"$BATS_TEST_TMPDIR/repo/.releaserc" <<<'{
    "packages": [{"name": "foo"}]
  }'

  # Make release script available
  # shellcheck disable=SC2317
  function release() {
    bash "$BATS_CWD/scripts/release.sh" "$@"
  }
  export -f release

  # Init git
  git init --initial-branch=main --quiet
  git config user.email "test.${BATS_TEST_NUMBER}@test.test"
  git config user.name "Test $BATS_TEST_NUMBER"
  git commit -am "Initial commit" --quiet --allow-empty

  # Mock git
  export _TEST_GIT_BIN
  _TEST_GIT_BIN="$(command -v git)"
  # shellcheck disable=SC2317
  function git() {
    local cmd="$1"
    case $cmd in
    fetch) test::log "git fetch disabled in this test" ;;
    *) "$_TEST_GIT_BIN" "$@" ;;
    esac
  }
  export -f git
}

teardown() {
  unset TEST_RELEASE_DIST_DIR
  unset -f release
  unset _TEST_GIT_BIN
  unset -f git
}

@test "aborts on non-release branch" {
  git checkout -b 'random-branch'

  run release
  assert_failure
  assert_output --partial "random-branch"
  assert_output --partial "not a release branch"
}

@test "fetches tags & processes packages" {
  run release
  assert_success

  test::it "fetched tags"
  assert_output --partial "Fetching tags..."
  test::assert_log "git fetch"

  test::it "processes packages"
  assert_output --partial "Processing package foo..."
}

@test "exists w/o releases w/o release commits" {
  run release
  assert_success
  assert_dir_not_exists "$TEST_RELEASE_DIST_DIR"
  assert_output --partial "skipping package foo"
}

@test "ignores non-conventional commits" {
  git commit -am "foo bar" --quiet --allow-empty

  run release
  assert_success
  assert_dir_not_exists "$TEST_RELEASE_DIST_DIR"
  assert_output --partial "skipping package foo"
}

@test "ignores unrelated scope commits" {
  git commit -am "feat(other-scope): foobar" --quiet --allow-empty

  run release
  assert_success
  assert_dir_not_exists "$TEST_RELEASE_DIST_DIR"
  assert_output --partial "skipping package foo"
}

@test "ignores non-release commits" {
  git commit -am "chore(foo): foobar" --quiet --allow-empty

  run release
  assert_success
  assert_dir_not_exists "$TEST_RELEASE_DIST_DIR"
  assert_output --partial "non-release type chore"
  assert_output --partial "skipping package foo"
}

@test "bumps patch version from 'patch' type commit" {
  git commit -am "fix(foo): my title" --quiet --allow-empty

  run release
  assert_success
  assert_output --partial "fix @ foo bumps patch"
  assert_line "package bump: patch"
}
@test "bumps minor version from 'minor' type commit" {
  git commit -am "feat(foo): my title" --quiet --allow-empty

  run release
  assert_success
  assert_output --partial "feat @ foo bumps minor"
  assert_line "package bump: minor"
}
@test "bumps major version from breaking change commit" {
  git commit -am "feat!(foo): my title" --quiet --allow-empty

  run release
  assert_success
  assert_output --partial "feat @ foo bumps major"
  assert_line "package bump: major"
}

@test "package scope filter supports negative patterns" {
  skip
}
