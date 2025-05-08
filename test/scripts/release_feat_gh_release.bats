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
  local sha="${3?}"
  local args=("${@:4}")

  local release_name="${pkg}@${version}"
  local changelog_path="$TEST_RELEASE_DIST_DIR/${pkg}/CHANGELOG.md"

  local want_args=(
    release create
    "$release_name"
    --target "$sha"
    --title "$release_name"
    --notes-file "$changelog_path"
    "${args[@]}"
    "$TEST_RELEASE_DIST_DIR/${pkg}/assets/*"
  )
  assert_line "[TEST] MOCK gh ${want_args[*]}"
}

function refute_gh_release() {
  case $# in
  0)
    refute_line --partial "[TEST] MOCK gh release"
    ;;
  1)
    local pkg="$1"
    refute_line --partial "[TEST] MOCK gh release create $pkg"
    ;;
  2)
    local pkg="$1"
    local version="$2"
    local release_name="${pkg}@${version}"
    refute_line --partial "[TEST] MOCK gh release create $release_name"
    ;;
  *) lib::abort "Invalid number of arguments: [$#]" ;;
  esac

}

@test "does not create release on non-release" {
  test::git_commit -m "feat(foo): my commit"
  git tag -a 'foo@1.0.0' -m ''

  run release
  assert_success
  refute_line --partial "[TEST] gh"
}

@test "create release on release" {
  local shas=()
  shas+=("$(test::git_commit_print -m "feat(foo): my commit")")

  run release
  assert_success
  assert_gh_release 'foo' '1.0.0' "${shas[0]}"
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
  local shas=()
  shas+=("$(test::git_commit_print -m "feat(foo): my commit")")

  run release
  assert_success
  assert_gh_release 'foo' '1.0.0-next.1' "${shas[0]}" --prerelease
}

@test "create release on latest in-scope commit" {
  local shas=()
  shas+=("$(test::git_commit_print -m "feat(foo): 01")")
  shas+=("$(test::git_commit_print -m "feat(foo): 02")")
  shas+=("$(test::git_commit_print -m "feat(bar): 03")")
  shas+=("$(test::git_commit_print -m "feat(bar): misc feat(foo) commit")")
  shas+=("$(test::git_commit_print -m "misc")")

  run release
  assert_success
  assert_gh_release 'foo' '1.0.0' "${shas[1]}"
}

@test "create release on latest non-release in-scope commit" {
  local shas=()
  shas+=("$(test::git_commit_print -m "feat(foo): 01")")
  shas+=("$(test::git_commit_print -m "chore(foo): 02")")
  shas+=("$(test::git_commit_print -m "feat(foo): 03")")
  shas+=("$(test::git_commit_print -m "chore(foo): 04")")
  shas+=("$(test::git_commit_print -m "feat(bar): 05")")

  run release
  assert_success
  assert_gh_release 'foo' '1.0.0' "${shas[3]}"
}

@test "create multiple releases" {
  test::extend_cfg '{
    "packages": [{"name": "aa"}, {"name": "bb"}, {"name": "cc"}]
  }'

  local shas=()
  shas+=("$(test::git_commit_print -m "feat(aa): my commit")")
  shas+=("$(test::git_commit_print -m "feat(bb): my commit")")

  run release
  assert_success
  assert_gh_release 'aa' '1.0.0' "${shas[0]}"
  assert_gh_release 'bb' '1.0.0' "${shas[1]}"
  refute_gh_release 'cc'
}

@test "enforces non-latest for auxiliary packages" {
  test::extend_cfg .packages[0].auxiliary 'true'

  local shas=()
  shas+=("$(test::git_commit_print -m "feat(foo): my commit")")

  run release
  assert_success
  assert_gh_release 'foo' '1.0.0' "${shas[0]}" --latest=false
}
