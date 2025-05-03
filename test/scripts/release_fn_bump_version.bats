#!/usr/bin/env bats
#
# Tests for `release::bump_version` function

setup() {
  load ../test_lib.sh
  load ../../scripts/release.sh
}

function assert_version() {
  local version="${1?}"
  assert_success
  assert_output "$version"
}

function assert_version_test() {
  local name="$BATS_TEST_DESCRIPTION"
  if [[ ! $name =~ ^([^ ]+)' '([^ ]+)' '([^ ]+)' => '([^ ]+)$ ]]; then
    test::abort "Test name does not match pattern"
  fi
  local curr_versions="${BASH_REMATCH[1]}"
  local release_types=("${BASH_REMATCH[2]}")
  local bump_types=("${BASH_REMATCH[3]}")
  local expected_version="${BASH_REMATCH[4]}"

  local curr_full_version
  local curr_version
  if [[ $curr_versions == */* ]]; then
    curr_full_version="${curr_versions%%/*}"
    curr_version="${curr_versions##*/}"
  else
    curr_full_version="$curr_versions"
    curr_version="$curr_versions"
  fi
  [[ $curr_full_version == '-' ]] && curr_full_version=
  [[ $curr_version == '-' ]] && curr_version=

  [[ ${release_types[0]} == '*' ]] && release_types=(next full)
  [[ ${bump_types[0]} == '-' ]] && bump_types=('')
  [[ ${bump_types[0]} == '*' ]] && bump_types=(patch minor major)

  [[ $expected_version == '-' ]] && expected_version=

  local bump_type
  local release_type
  local is_prerelease
  for bump_type in "${bump_types[@]}"; do
    for release_type in "${release_types[@]}"; do
      is_prerelease=
      [[ $release_type == next ]] && is_prerelease=1
      run release::bump_version "$curr_full_version" "$curr_version" "$is_prerelease" "$bump_type"
      assert_success
      assert_output "$expected_version"
    done
  done
}

###
# Releases (no changes)
###

@test "- * - => -" {
  assert_version_test
}

@test "1.0.0 * - => -" {
  assert_version_test
}

@test "1.0.0/1.0.1-next.123 full - => 1.0.1" {
  assert_version_test
}
@test "1.0.0/1.1.0-next.123 full - => 1.1.0" {
  assert_version_test
}
@test "1.0.0/2.0.0-next.123 full - => 2.0.0" {
  assert_version_test
}

@test "1.0.0/1.0.1-next.4 next - => -" {
  assert_version_test
}

###
# First-time releases
###

@test "- full * => 1.0.0" {
  assert_version_test
}

@test "- next * => 1.0.0-next.1" {
  assert_version_test
}

###
# Releases from full version
###

@test "1.0.0 full patch => 1.0.1" {
  assert_version_test
}
@test "1.0.0 full minor => 1.1.0" {
  assert_version_test
}
@test "1.0.0 full major => 2.0.0" {
  assert_version_test
}

@test "1.0.0 next patch => 1.0.1-next.1" {
  assert_version_test
}
@test "1.0.0 next minor => 1.1.0-next.1" {
  assert_version_test
}
@test "1.0.0 next major => 2.0.0-next.1" {
  assert_version_test
}

###
# Full releases from next version
###

@test "1.0.0/1.0.1-next.4 full patch => 1.0.1" {
  assert_version_test
}
@test "1.0.0/1.0.1-next.4 full minor => 1.1.0" {
  assert_version_test
}
@test "1.0.0/1.0.1-next.4 full major => 2.0.0" {
  assert_version_test
}

@test "1.0.0/1.1.0-next.4 full patch => 1.1.0" {
  assert_version_test
}
@test "1.0.0/1.1.0-next.4 full minor => 1.1.0" {
  assert_version_test
}
@test "1.0.0/1.1.0-next.4 full major => 2.0.0" {
  assert_version_test
}

@test "1.0.0/2.0.0-next.4 full * => 2.0.0" {
  assert_version_test
}

###
# Next releases from next version
###

@test "1.0.0/1.0.1-next.4 next patch => 1.0.1-next.5" {
  assert_version_test
}
@test "1.0.0/1.0.1-next.4 next minor => 1.1.0-next.1" {
  assert_version_test
}
@test "1.0.0/1.0.1-next.4 next major => 2.0.0-next.1" {
  assert_version_test
}

@test "1.0.0/1.1.0-next.4 next patch => 1.1.0-next.5" {
  assert_version_test
}
@test "1.0.0/1.1.0-next.4 next minor => 1.1.0-next.5" {
  assert_version_test
}
@test "1.0.0/1.1.0-next.4 next major => 2.0.0-next.1" {
  assert_version_test
}

@test "1.0.0/2.0.0-next.4 next * => 2.0.0-next.5" {
  assert_version_test
}
