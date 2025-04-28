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

function git_commit() {
  git commit --quiet --allow-empty "$@"
}

@test "aborts on non-release branch" {
  git checkout -b 'random-branch'

  run release
  assert_failure
  assert_line --partial "random-branch"
  assert_line --partial "not a release branch"
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
  assert_dir_not_exists "$TEST_RELEASE_DIST_DIR"
  assert_line "(foo) skipping package"
}

@test "ignores non-conventional commits" {
  git_commit -m "foo bar"

  run release
  assert_success
  assert_dir_not_exists "$TEST_RELEASE_DIST_DIR"
  assert_line "(foo) skipping package"
}

@test "ignores unrelated scope commits" {
  git_commit -m "feat(other-scope): foobar"

  run release
  assert_success
  assert_dir_not_exists "$TEST_RELEASE_DIST_DIR"
  assert_line "(foo) skipping package"
}

@test "ignores non-release commits" {
  git_commit -m "chore(foo): foobar"

  run release
  assert_success
  assert_dir_not_exists "$TEST_RELEASE_DIST_DIR"
  assert_line --partial "non-release type chore"
  assert_line "(foo) skipping package"
}

@test "bumps patch version from 'patch' type commit" {
  git_commit -m "fix(foo): my title"

  run release
  assert_success
  assert_line --partial "fix @ foo bumps patch"
  assert_line "(foo) package bump: patch"
}
@test "bumps minor version from 'minor' type commit" {
  git_commit -m "feat(foo): my title"

  run release
  assert_success
  assert_line --partial "feat @ foo bumps minor"
  assert_line "(foo) package bump: minor"
}
@test "bumps major version from commit with '!' after scope" {
  git_commit -m "feat!(foo): my title"

  run release
  assert_success
  assert_line --partial "feat @ foo bumps major"
  assert_line "(foo) package bump: major"
}
@test "bumps major version from commit with 'BREAKING CHANGE:' body" {
  git_commit -m "feat(foo): my title" -m "BREAKING CHANGE: my desc"

  run release
  assert_success
  assert_line --partial "feat @ foo bumps major"
  assert_line "(foo) package bump: major"
}
@test "bumps major version from commit with 'BREAKING CHANGE:' footer" {
  git_commit -m "feat(foo): my title" -m "my body" -m "BREAKING CHANGE: my footer"

  run release
  assert_success
  assert_line --partial "feat @ foo bumps major"
  assert_line "(foo) package bump: major"
}
@test "does not bump major version from commit with '!' in message" {
  git_commit -m "feat(foo): my title!"

  run release
  assert_success
  refute_line --partial "feat @ foo bumps major"
  refute_line "(foo) package bump: major"
}

@test "bumps the right package based on commit scope" {
  cat >"$BATS_TEST_TMPDIR/repo/.releaserc" <<<'{
    "packages": [{"name": "aa"}, {"name": "bb"}, {"name": "cc"}, {"name": "dd"}]
  }'

  git_commit -m "feat(aa): my title"
  git_commit -m "feat!(cc): my title"
  git_commit -m "fix(dd): my title"

  run release
  assert_success
  assert_line --partial "feat @ aa bumps minor"
  assert_line --partial "feat @ cc bumps major"
  assert_line --partial "fix @ dd bumps patch"

  assert_line "(aa) package bump: minor"
  assert_line "(bb) skipping package"
  assert_line "(cc) package bump: major"
  assert_line "(dd) package bump: patch"
}

@test "filters commits with custom 'scope'" {
  cat >"$BATS_TEST_TMPDIR/repo/.releaserc" <<<'{
    "packages": [{"name": "foo", "scope": "bar"}]
  }'

  git_commit -m "feat(foo): my title"
  git_commit -m "fix(bar): my title"

  run release
  assert_success
  refute_line --partial "feat @ foo"
  assert_line --partial "fix @ bar bumps"
  assert_line "(foo) package bump: patch"
}
@test "filters commits with 'scope' with wildcard" {
  cat >"$BATS_TEST_TMPDIR/repo/.releaserc" <<<'{
    "packages": [{"name": "foo", "scope": "fizz.*"}]
  }'

  git_commit -m "fix(foo): my title"
  git_commit -m "fix(fizz): my title"
  git_commit -m "fix(fizz-buzz): my title"
  git_commit -m "fix(buzz-fizz): my title"

  run release
  assert_success
  refute_line --partial "feat @ foo"
  assert_line --partial "fix @ fizz bumps"
  assert_line --partial "fix @ fizz-buzz bumps"
  refute_line --partial "feat @ buzz-fizz"
}
@test "filters commits with 'scope' with wildcard & negative match" {
  cat >"$BATS_TEST_TMPDIR/repo/.releaserc" <<<'{
    "packages": [{"name": "foo", "scope": "!.*-san"}]
  }'

  git_commit -m "fix(foo): my title"
  git_commit -m "fix(foo-san): my title"
  git_commit -m "fix(san-serif): my title"
  git_commit -m "fix(fizz-san-buzz): my title"

  run release
  assert_success
  assert_line --partial "fix @ foo bumps"
  refute_line --partial "fix @ foo-san"
  assert_line --partial "fix @ san-serif bumps"
  assert_line --partial "fix @ fizz-san-buzz"
}
