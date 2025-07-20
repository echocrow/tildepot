#!/usr/bin/env bats
#
# Tests for `release` script (gh release)

setup() {
  load release_lib.sh
  export CI=true
}

teardown() {
  test::release_lib_teardown
  unset CI
}

function assert_gh_release() {
  local pkg="${1?}"
  local version="${2?}"
  local args=("${@:3}")
  local release_name="${pkg}@${version}"
  local changelog_path="$TEST_RELEASE_DIST_DIR/${pkg}/CHANGELOG.md"

  local branch
  branch="$(git rev-parse --abbrev-ref HEAD)"

  local want_args=(
    release create
    "$release_name"
    --title "$release_name"
    --notes-file "$changelog_path"
    --target "$branch"
    ${args+"${args[@]}"}
    "$TEST_RELEASE_DIST_DIR/${pkg}/assets/*"
  )
  test::assert_log "MOCK gh ${want_args[*]}"
}

function refute_gh_release() {
  case $# in
  0)
    test::refute_log --partial "MOCK gh release"
    ;;
  1)
    local pkg="$1"
    test::refute_log --partial "MOCK gh release create $pkg"
    ;;
  2)
    local pkg="$1"
    local version="$2"
    local release_name="${pkg}@${version}"
    test::refute_log --partial "MOCK gh release create $release_name"
    ;;
  *) lib::abort "Invalid number of arguments: [$#]" ;;
  esac

}

@test "does not create release on non-release" {
  test::git_commit -m "feat(foo): my commit"
  git tag -a 'foo@1.0.0' -m ''

  run release
  assert_success
  test::refute_log --partial "gh"
}

@test "create release on release" {
  test::git_commit -m "feat(foo): my commit"

  run release
  assert_success
  assert_gh_release 'foo' '1.0.0'
}

@test "does not release without CI env" {
  unset CI
  test::git_commit -m "feat(foo): my commit"

  run release
  assert_success
  refute_gh_release
  assert_line --partial "skipping release"
}

@test "create prereleases on prerelease" {
  git checkout -b 'next' --quiet
  test::git_commit -m "feat(foo): my commit"

  run release
  assert_success
  assert_gh_release 'foo' '1.0.0-next.1' --prerelease
}

@test "create release on latest non-release in-scope commit" {
  test::git_commit -m "feat(foo): 01"
  test::git_commit -m "chore(foo): 02"
  test::git_commit -m "feat(foo): 03"
  test::git_commit -m "chore(foo): 04"
  test::git_commit -m "feat(bar): 05"

  run release
  assert_success
  assert_gh_release 'foo' '1.0.0'
}

@test "create multiple releases" {
  test::extend_cfg '{
    "packages": [{"name": "aa"}, {"name": "bb"}, {"name": "cc"}]
  }'

  test::git_commit -m "feat(aa): my commit"
  test::git_commit -m "feat(bb): my commit"

  run release
  assert_success
  assert_gh_release 'aa' '1.0.0'
  assert_gh_release 'bb' '1.0.0'
  refute_gh_release 'cc'
}

@test "enforces non-latest for auxiliary packages" {
  test::extend_cfg .packages[0].auxiliary 'true'

  test::git_commit -m "feat(foo): my commit"

  run release
  assert_success
  assert_gh_release 'foo' '1.0.0' --latest=false
}
