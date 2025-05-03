#!/usr/bin/env bats
#
# Tests for `release` script

setup() {
  load release_lib.sh
}

teardown() {
  test::release_lib_teardown
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

###
# Version bump from commits
###

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

###
# Release type from branch
###

@test "releases full version on full-release branch" {
  test::extend_cfg '{"branches": {"full": ["my-branch"]}}'
  git checkout -b 'my-branch' --quiet
  test::git_commit -m "feat(foo): my title!"

  run release
  assert_success
  assert_line "current branch: my-branch"
  assert_line "release type: full"
  assert_line "(foo) new version: 1.0.0"
}

@test "releases next version on pre-release branch" {
  test::extend_cfg '{"branches": {"prerelease": ["my-branch"]}}'
  git checkout -b 'my-branch' --quiet
  test::git_commit -m "feat(foo): my title!"

  run release
  assert_success
  assert_line "current branch: my-branch"
  assert_line "release type: next"
  assert_line "(foo) new version: 1.0.0-next.1"
}

@test "aborts on non-release branch" {
  git checkout -b 'my-branch' --quiet
  test::git_commit -m "feat(foo): my title!"

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
  test::extend_cfg '{
    "packages": [{"name": "aa"}, {"name": "bb"}, {"name": "cc"}, {"name": "dd"}]
  }'

  test::git_commit -m "feat(aa): my title"
  test::git_commit -m "feat!(cc): my title"
  test::git_commit -m "fix(dd): my title"

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
  test::extend_cfg '{
    "packages": [{"name": "foo", "scope": "bar"}]
  }'

  test::git_commit -m "feat(foo): my title"
  test::git_commit -m "fix(bar): my title"

  run release
  assert_success
  refute_line --partial "feat @ foo"
  assert_line --partial "fix @ bar bumps"
  assert_line "(foo) package bump: patch"
}
@test "filters commits with 'scope' with wildcard" {
  test::extend_cfg '{
    "packages": [{"name": "foo", "scope": "fizz.*"}]
  }'

  test::git_commit -m "fix(foo): my title"
  test::git_commit -m "fix(fizz): my title"
  test::git_commit -m "fix(fizz-buzz): my title"
  test::git_commit -m "fix(buzz-fizz): my title"

  run release
  assert_success
  refute_line --partial "feat @ foo"
  assert_line --partial "fix @ fizz bumps"
  assert_line --partial "fix @ fizz-buzz bumps"
  refute_line --partial "feat @ buzz-fizz"
}
@test "filters commits with 'scope' with wildcard & negative match" {
  test::extend_cfg '{
    "packages": [{"name": "foo", "scope": "!.*-san"}]
  }'

  test::git_commit -m "fix(foo): my title"
  test::git_commit -m "fix(foo-san): my title"
  test::git_commit -m "fix(san-serif): my title"
  test::git_commit -m "fix(fizz-san-buzz): my title"

  run release
  assert_success
  assert_line --partial "fix @ foo bumps"
  refute_line --partial "fix @ foo-san"
  assert_line --partial "fix @ san-serif bumps"
  assert_line --partial "fix @ fizz-san-buzz"
}

@test "skips when negative scope filter matches no commits" {
  test::extend_cfg '{
    "packages": [{"name": "foo", "scope": "!.*-foo"}]
  }'

  test::git_commit -m "fix(foo-foo): commit"
  test::git_commit -m "fix(foo-foo): commit"
  test::git_commit -m "fix(foo-foo): commit"

  run release
  assert_success
  refute_line --partial "fix @ foo-foo bumps"
  assert_line "(foo) package bump: -"
  assert_line "(foo) new version: -"
  assert_line "(foo) skipping package"
  assert_dir_not_exists "$TEST_RELEASE_DIST_DIR"
}

###
# Version tags
###

@test "picks recent version from tag" {
  test::git_commit -m "feat(foo): old feature 0"
  test::git_commit -m "feat(foo): old feature 1"
  git tag -a 'foo@2.2.2' -m ''
  test::git_commit -m "feat(foo): new feature 0"

  run release
  assert_success
  assert_line "(foo) curr tag: foo@2.2.2"
  assert_line "(foo) curr version: 2.2.2"
  assert_line "(foo) curr full version: 2.2.2"
  assert_line "(foo) new version: 2.3.0"
}

@test "picks recent prerelease version & last full version from tags" {
  git checkout -b 'next' --quiet
  test::git_commit -m "feat(foo): old feature 0"
  git tag -a 'foo@2.2.2' -m ''
  test::git_commit -m "feat(foo): old feature 1"
  git tag -a 'foo@2.3.0-next.4' -m ''
  test::git_commit -m "feat(foo): new feature 0"

  run release
  assert_success
  assert_line "(foo) curr tag: foo@2.3.0-next.4"
  assert_line "(foo) curr version: 2.3.0-next.4"
  assert_line "(foo) curr full version: 2.2.2"
  assert_line "(foo) new version: 2.3.0-next.5"
}

@test "picks the highest (presumed most recent) tag (non-alphabetical)" {
  test::git_commit -m "feat(foo): old feature 0"
  git tag -a 'foo@9.9.9' -m ''
  test::git_commit -m "feat(foo): old feature 1"
  git tag -a 'foo@10.0.0' -m ''
  test::git_commit -m "feat(foo): new feature 0"

  run release
  assert_success
  assert_line "(foo) curr tag: foo@10.0.0"
  assert_line "(foo) curr version: 10.0.0"
  assert_line "(foo) curr full version: 10.0.0"
}

@test "ignores commits before last tag" {
  sha0=$(test::git_commit_print -m "feat(foo): commit 0")
  sha1=$(test::git_commit_print -m "feat(foo): commit 1")
  git tag -a 'foo@1.0.0' -m ''
  sha2=$(test::git_commit_print -m "feat(foo): commit 2")
  git tag -a 'foo@1.0.1-next.1' -m ''
  sha3=$(test::git_commit_print -m "feat(foo): commit 3")
  sha4=$(test::git_commit_print -m "feat(foo): commit 4")

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
  test::extend_cfg '{
    "packages": [{"name": "aa"}, {"name": "bb"}, {"name": "cc"}, {"name": "dd"}]
  }'

  base_sha="$(git rev-parse --short HEAD)"

  test::git_commit -m "feat(aa): commit"
  test::git_commit -m "feat(aa): commit"
  git tag -a 'aa@1.0.0' -m ''
  aa_base_sha="$(git rev-parse --short HEAD)"
  test::git_commit -m "feat(aa): commit"

  test::git_commit -m "feat(cc): commit"
  git tag -a 'cc@1.0.0' -m ''
  cc_base_sha="$(git rev-parse --short HEAD)"
  test::git_commit -m "feat(cc): commit"
  test::git_commit -m "feat(cc): commit"

  test::git_commit -m "feat(bb): commit"
  test::git_commit -m "feat(bb): commit"
  git tag -a 'bb@1.0.0' -m ''
  bb_base_sha="$(git rev-parse --short HEAD)"

  test::git_commit -m "feat(dd): commit"
  test::git_commit -m "feat(aa): commit"
  test::git_commit -m "feat(aa): commit"

  run release
  assert_success
  assert_line "(aa) base commit: $aa_base_sha"
  assert_line "(bb) base commit: $bb_base_sha"
  assert_line "(cc) base commit: $cc_base_sha"
  assert_line "(dd) base commit: $base_sha"
}

###
# Build commands
###

@test "skips build command on non-release" {
  # shellcheck disable=SC2317
  function my_build_cmd() {
    echo "[TEST] build command"
    echo '1' >>"$BATS_TEST_TMPDIR/my_build.txt"
  }
  export -f my_build_cmd
  test::extend_cfg '.packages[0].buildCommand' 'my_build_cmd'

  run release
  assert_success
  refute_line --partial "Running build command"
  refute_line "[TEST] build command"
  assert_file_not_exist "$BATS_TEST_TMPDIR/my_build.txt"
}

@test "skips empty build command" {
  test::extend_cfg '.packages[0].buildCommand' ''

  test::git_commit -m "feat(foo): my title"

  run release
  assert_success
  refute_line --partial "Running build command"
}

@test "runs build command once on release" {
  # shellcheck disable=SC2317
  function my_build_cmd() {
    echo "[TEST] build command"
    echo '1' >>"$BATS_TEST_TMPDIR/my_build.txt"
  }
  export -f my_build_cmd
  test::extend_cfg '.packages[0].buildCommand' 'my_build_cmd'
  echo '1' >"$BATS_TEST_TMPDIR/my_build_want.txt"

  test::git_commit -m "feat(foo): my title"

  run release
  assert_success
  assert_line --partial "Running build command"
  assert_line "[TEST] build command"
  assert_line --partial "Completed build command"

  test::it "only called the command once"
  assert_files_equal "$BATS_TEST_TMPDIR/my_build.txt" "$BATS_TEST_TMPDIR/my_build_want.txt"
}

@test "runs multi-args build command" {
  # shellcheck disable=SC2317
  function my_build_cmd() {
    local my_arg1="$1"
    local my_arg2="$2"
    echo "[TEST] build command; args: [$my_arg1] [$my_arg2]"
  }
  export -f my_build_cmd
  test::extend_cfg '.packages[0].buildCommand' 'my_build_cmd foo bar'

  test::git_commit -m "feat(foo): my title"

  run release
  assert_success
  assert_line "[TEST] build command; args: [foo] [bar]"
  assert_line --partial "Completed build command"
}

@test "aborts on invalid build command" {
  test::extend_cfg '.packages[0].buildCommand' 'my_invalid_build_cmd'

  test::git_commit -m "feat(foo): my title"

  # Require min version to support `run -127`.
  bats_require_minimum_version 1.5.0

  run -127 release
  assert_failure
  assert_line --partial "Running build command"
  refute_line --partial "Completed build command"
}

@test "aborts on failed build command" {
  # shellcheck disable=SC2317
  function my_build_cmd() {
    exit 1
  }
  export -f my_build_cmd
  test::extend_cfg '.packages[0].buildCommand' 'my_build_cmd'

  test::git_commit -m "feat(foo): my title"

  run release
  assert_failure
  assert_line --partial "Running build command"
  refute_line --partial "Completed build command"
}

@test "runs build command in strict mode" {
  # shellcheck disable=SC2317
  function my_build_cmd() {
    false
    echo '[TEST] late exec'
  }
  export -f my_build_cmd
  test::extend_cfg '.packages[0].buildCommand' 'my_build_cmd'

  test::git_commit -m "feat(foo): my title"

  run release
  assert_failure
  assert_line --partial "Running build command"
  refute_line --partial "[TEST] follow-up exec"
  refute_line --partial "[TEST] late exec"
  refute_line --partial "Completed build command"
}

@test "sets RELEASE_VERSION env var to next release version" {
  # shellcheck disable=SC2317
  function my_build_cmd() {
    local version="${RELEASE_VERSION:-}"
    echo "[TEST] build command; version: [$version]"
  }
  export -f my_build_cmd
  test::extend_cfg '.packages[0].buildCommand' 'my_build_cmd'

  test::git_commit -m "feat(foo): prev release"
  git tag -a 'foo@2.2.2' -m ''
  test::git_commit -m "feat(foo): my feat"

  run release
  assert_success
  assert_line "[TEST] build command; version: [2.3.0]"
}

###
# Assets
###

# TODO

###
# Summary
###

# TODO
