#!/usr/bin/env bats
#
# Tests for `release::config` function

setup() {
  load ../test_lib.sh
  load ../../scripts/release.sh
}

function default_config_prop() {
  local prop="$1"
  jq -r "$prop" <<<"$RELEASE_CONFIG_DEFAULTS"
}

function assert_equal_jq_prop() {
  local actual_json="$1"
  local prop="$2"
  local expected="$3"

  local actual
  actual="$(jq -r "$prop" <<<"$actual_json")"

  expected="$(jq -r "." <<<"$expected")"

  assert_equal "$actual" "$expected"
}
function assert_output_jq_prop() {
  assert_equal_jq_prop "$output" "$@"
}

###
# Static config files
###

@test "aborts without a config file" {
  run release::config "$BATS_TEST_TMPDIR"
  assert_failure
  assert_output --partial "Config file not found"
}

@test "reads '.releaserc'" {
  local packages='[{"name": "foo"}]'
  echo '{"packages": '"$packages"'}' >"$BATS_TEST_TMPDIR/.releaserc"

  run release::config "$BATS_TEST_TMPDIR"
  assert_success
  assert_output_jq_prop '.packages' "$packages"

  test::it "outputs only a single JSON object"
  assert_equal "$(jq -r 'type' <<<"$output")" "object"
}

@test "reads '.releaserc.json'" {
  local packages='[{"name": "bar"}]'
  echo '{"packages": '"$packages"'}' >"$BATS_TEST_TMPDIR/.releaserc.json"

  run release::config "$BATS_TEST_TMPDIR"
  assert_success
  assert_output_jq_prop '.packages' "$packages"
}

@test "prefers '.releaserc' over '.releaserc.json'" {
  local packagesA='[{"name": "fizz"}]'
  echo '{"packages": '"$packagesA"'}' >"$BATS_TEST_TMPDIR/.releaserc"
  local packagesB='[{"name": "buzz"}]'
  echo '{"packages": '"$packagesB"'}' >"$BATS_TEST_TMPDIR/.releaserc.json"

  run release::config "$BATS_TEST_TMPDIR"
  assert_success
  assert_output_jq_prop '.packages' "$packagesA"
}

###
# Defaults & overrides
###

@test "sets default with minimal '.releaserc'" {
  echo '{"packages": [{"name": "foo"}]}' >"$BATS_TEST_TMPDIR/.releaserc"

  run release::config "$BATS_TEST_TMPDIR"
  assert_success
  assert_output_jq_prop '.branches' "$(default_config_prop '.branches')"
  assert_output_jq_prop '.commits_types' "$(default_config_prop '.commits_types')"
}

@test "overrides defaults from '.releaserc'" {
  local branches='{"full": ["fizz"], "prerelease": ["buzz"]}'
  echo '{
    "branches": '"$branches"',
    "packages": [{"name": "foo"}]
  }' >"$BATS_TEST_TMPDIR/.releaserc"

  run release::config "$BATS_TEST_TMPDIR"
  assert_success
  assert_output_jq_prop '.branches' "$branches"
  assert_output_jq_prop '.commits_types' "$(default_config_prop '.commits_types')"
}

@test "overrides nested defaults from '.releaserc'" {
  local prerelease_branches='["fizz", "buzz"]'
  echo '{
    "branches": {"prerelease": '"$prerelease_branches"'},
    "packages": [{"name": "foo"}]
  }' >"$BATS_TEST_TMPDIR/.releaserc"

  run release::config "$BATS_TEST_TMPDIR"
  assert_success
  assert_output_jq_prop '.branches.full' "$(default_config_prop '.branches.full')"
  assert_output_jq_prop '.branches.prerelease' "$prerelease_branches"
  assert_output_jq_prop '.commits_types' "$(default_config_prop '.commits_types')"
}

@test "does not override empty array from '.releaserc'" {
  local prerelease_branches='[]'
  echo '{
    "branches": {"prerelease": '"$prerelease_branches"'},
    "packages": [{"name": "foo"}]
  }' >"$BATS_TEST_TMPDIR/.releaserc"

  run release::config "$BATS_TEST_TMPDIR"
  assert_success
  assert_output_jq_prop '.branches.prerelease' "$prerelease_branches"
}

###
# Dynamic config script
###

@test "generates config via '.releaserc.sh'" {
  local packages='[{"name": "123"}]'
  echo "
    echo '{\"packages\": $packages}'
  " >"$BATS_TEST_TMPDIR/.releaserc.sh"

  run release::config "$BATS_TEST_TMPDIR"
  assert_success
  assert_output_jq_prop '.packages' "$packages"
}

@test "aborts when '.release.sh' returns no packages" {
  echo '{"packages": [{"name": "bar"}]}' >"$BATS_TEST_TMPDIR/.releaserc"
  echo "
    echo '{\"packages\": []}'
  " >"$BATS_TEST_TMPDIR/.releaserc.sh"

  run release::config "$BATS_TEST_TMPDIR"
  assert_failure
  assert_output --partial "Missing packages"
}

@test "processes config via '.releaserc.sh'" {
  local packageA='{"name": "foo"}'
  local packageB='{"name": "bar"}'
  echo '{"packages": ['"$packageA"']}' >"$BATS_TEST_TMPDIR/.releaserc"
  echo "
    jq '. | .packages += [$packageB]' <<<\"\$1\"
  " >"$BATS_TEST_TMPDIR/.releaserc.sh"

  run release::config "$BATS_TEST_TMPDIR"
  assert_success
  assert_output_jq_prop '.packages' "[$packageA, $packageB]"
}

@test "processes config via '.releaserc.sh' last" {
  local extra_prerelease_branches='["fizz", "buzz"]'
  echo '{"packages": [{"name": "foo"}]}' >"$BATS_TEST_TMPDIR/.releaserc"
  echo "
    jq '. | .branches.prerelease += $extra_prerelease_branches' <<<\"\$1\"
  " >"$BATS_TEST_TMPDIR/.releaserc.sh"

  run release::config "$BATS_TEST_TMPDIR"
  assert_success
  assert_output_jq_prop '.branches.prerelease' "$(
    jq -n "$(default_config_prop '.branches.prerelease') + $extra_prerelease_branches"
  )"
}

###
# Validation
###

@test "aborts without any packages" {
  echo '{"packages": []}' >"$BATS_TEST_TMPDIR/.releaserc"

  run release::config "$BATS_TEST_TMPDIR"
  assert_failure
  assert_output --partial "Missing packages"
}

@test "aborts when a package is missing a name" {
  echo '{
    "packages": [
      {"name": "foo"},
      {"missing":"name"},
      {"name": "baz"}
    ]
  }' >"$BATS_TEST_TMPDIR/.releaserc"

  run release::config "$BATS_TEST_TMPDIR"
  assert_failure
  assert_output --partial "Missing or empty package name"
}
@test "aborts when a package has an empty name" {
  echo '{"packages": [{"name": ""}]}' >"$BATS_TEST_TMPDIR/.releaserc"

  run release::config "$BATS_TEST_TMPDIR"
  assert_failure
  assert_output --partial "Missing or empty package name"
}
