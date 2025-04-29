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
  export TEST_RELEASE_CONFIG_PATH="$BATS_TEST_TMPDIR/repo/.releaserc"
  cat >"$TEST_RELEASE_CONFIG_PATH" <<<'{
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
function git_commit_print() {
  git_commit "$@"
  git rev-parse --short HEAD
}

function extend_cfg() {
  local cfg="$1"
  jq --argjson cfg "$cfg" '. + $cfg' <"$TEST_RELEASE_CONFIG_PATH" >"$TEST_RELEASE_CONFIG_PATH.tmp"
  mv "$TEST_RELEASE_CONFIG_PATH.tmp" "$TEST_RELEASE_CONFIG_PATH"
}

###
# Basics
###

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

###
# Version bump from commits
###

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

@test "picks the most significant commit bump (minor > patch)" {
  git_commit -m "feat(foo): commit"
  git_commit -m "fix(foo): commit"

  run release
  assert_success
  assert_line "(foo) package bump: minor"
}
@test "picks the most significant commit bump (patch < minor)" {
  git_commit -m "fix(foo): commit"
  git_commit -m "feat(foo): commit"

  run release
  assert_success
  assert_line "(foo) package bump: minor"
}
@test "picks the most significant commit bump (major > minor)" {
  git_commit -m "feat!(foo): commit"
  git_commit -m "feat(foo): commit"

  run release
  assert_success
  assert_line "(foo) package bump: major"
}
@test "picks the most significant commit bump (minor < major)" {
  git_commit -m "feat(foo): commit"
  git_commit -m "feat!(foo): commit"

  run release
  assert_success
  assert_line "(foo) package bump: major"
}
@test "picks the most significant commit bump (major > patch)" {
  git_commit -m "feat!(foo): commit"
  git_commit -m "fix(foo): commit"

  run release
  assert_success
  assert_line "(foo) package bump: major"
}
@test "picks the most significant commit bump (patch < major)" {
  git_commit -m "fix(foo): commit"
  git_commit -m "feat!(foo): commit"

  run release
  assert_success
  assert_line "(foo) package bump: major"
}

###
# Release type from branch
###

@test "releases full version on full-release branch" {
  extend_cfg '{"branches": {"full": ["my-branch"]}}'
  git checkout -b 'my-branch' --quiet
  git_commit -m "feat(foo): my title!"

  run release
  assert_success
  assert_line "current branch: my-branch"
  assert_line "release type: full"
  assert_line "(foo) new version: 1.0.0"
}

@test "releases next version on pre-release branch" {
  extend_cfg '{"branches": {"prerelease": ["my-branch"]}}'
  git checkout -b 'my-branch' --quiet
  git_commit -m "feat(foo): my title!"

  run release
  assert_success
  assert_line "current branch: my-branch"
  assert_line "release type: next"
  assert_line "(foo) new version: 1.0.0-next.1"
}

@test "aborts on non-release branch" {
  git checkout -b 'my-branch' --quiet
  git_commit -m "feat(foo): my title!"

  run release
  assert_failure
  refute_line --partial "release type:"
  refute_line --partial "(foo) new version"
  assert_line --partial "my-branch is not a release branch"
}

###
# Commit scopes
###

@test "bumps the right package based on commit scope" {
  cat >"$TEST_RELEASE_CONFIG_PATH" <<<'{
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
  cat >"$TEST_RELEASE_CONFIG_PATH" <<<'{
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
  cat >"$TEST_RELEASE_CONFIG_PATH" <<<'{
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
  cat >"$TEST_RELEASE_CONFIG_PATH" <<<'{
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

###
# Version tags
###

@test "picks recent version from tag" {
  git_commit -m "feat(foo): old feature 0"
  git_commit -m "feat(foo): old feature 1"
  git tag -a 'foo@2.2.2' -m ''
  git_commit -m "feat(foo): new feature 0"

  run release
  assert_success
  assert_line "(foo) curr tag: foo@2.2.2"
  assert_line "(foo) curr version: 2.2.2"
  assert_line "(foo) curr full version: 2.2.2"
  assert_line "(foo) new version: 2.3.0"
}

@test "picks recent prerelease version & last full version from tags" {
  git checkout -b 'next' --quiet
  git_commit -m "feat(foo): old feature 0"
  git tag -a 'foo@2.2.2' -m ''
  git_commit -m "feat(foo): old feature 1"
  git tag -a 'foo@2.3.0-next.4' -m ''
  git_commit -m "feat(foo): new feature 0"

  run release
  assert_success
  assert_line "(foo) curr tag: foo@2.3.0-next.4"
  assert_line "(foo) curr version: 2.3.0-next.4"
  assert_line "(foo) curr full version: 2.2.2"
  assert_line "(foo) new version: 2.3.0-next.5"
}

@test "picks the highest (presumed most recent) tag (non-alphabetical)" {
  git_commit -m "feat(foo): old feature 0"
  git tag -a 'foo@9.9.9' -m ''
  git_commit -m "feat(foo): old feature 1"
  git tag -a 'foo@10.0.0' -m ''
  git_commit -m "feat(foo): new feature 0"

  run release
  assert_success
  assert_line "(foo) curr tag: foo@10.0.0"
  assert_line "(foo) curr version: 10.0.0"
  assert_line "(foo) curr full version: 10.0.0"
}

@test "ignores commits before last tag" {
  sha0=$(git_commit_print -m "feat(foo): commit 0")
  sha1=$(git_commit_print -m "feat(foo): commit 1")
  git tag -a 'foo@1.0.0' -m ''
  sha2=$(git_commit_print -m "feat(foo): commit 2")
  git tag -a 'foo@1.0.1-next.1' -m ''
  sha3=$(git_commit_print -m "feat(foo): commit 3")
  sha4=$(git_commit_print -m "feat(foo): commit 4")

  run release
  assert_success
  refute_line --partial "$sha0:"
  refute_line --partial "$sha1:"
  refute_line --partial "(foo) commit $sha2:"
  assert_line "(foo) base commit: $sha2"
  assert_line --partial "(foo) commit $sha3:"
  assert_line --partial "(foo) commit $sha4:"
}

@test "picks the right version based on package name prefix" {
  cat >"$TEST_RELEASE_CONFIG_PATH" <<<'{
    "packages": [{"name": "aa"}, {"name": "bb"}, {"name": "cc"}, {"name": "dd"}]
  }'

  base_sha="$(git rev-parse --short HEAD)"

  git_commit -m "feat(aa): commit"
  git_commit -m "feat(aa): commit"
  git tag -a 'aa@1.0.0' -m ''
  aa_base_sha="$(git rev-parse --short HEAD)"
  git_commit -m "feat(aa): commit"

  git_commit -m "feat(cc): commit"
  git tag -a 'cc@1.0.0' -m ''
  cc_base_sha="$(git rev-parse --short HEAD)"
  git_commit -m "feat(cc): commit"
  git_commit -m "feat(cc): commit"

  git_commit -m "feat(bb): commit"
  git_commit -m "feat(bb): commit"
  git tag -a 'bb@1.0.0' -m ''
  bb_base_sha="$(git rev-parse --short HEAD)"

  git_commit -m "feat(dd): commit"
  git_commit -m "feat(aa): commit"
  git_commit -m "feat(aa): commit"

  run release
  assert_success
  assert_line "(aa) base commit: $aa_base_sha"
  assert_line "(bb) base commit: $bb_base_sha"
  assert_line "(cc) base commit: $cc_base_sha"
  assert_line "(dd) base commit: $base_sha"
}
