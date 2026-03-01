#!/usr/bin/env bats
#
# Tests for `tildepot` bundles: EXTEND behavior
#
# These tests use the `save` hook as stand-in for all hook commands. The same
# tests are assumed to also pass for all other hook commands.

setup() {
  load ../../test_lib.sh
  load ./tildepot_run_lib.sh

  # Fast-fail downloads.
  test::mock_download --error
}

###
# Extend local file
###

@test "inherits hook from relative (nested) path" {
  mkdir "$TILDEPOT_HOME/bundles/my-bases"
  test::mock_bundle parent "$TILDEPOT_HOME/bundles/my-bases" "
    $(test::mock_hook_fn save)
  "
  test::mock_bundle child "
    EXTEND='./my-bases/parent.sh'
  "

  run tildepot run save
  assert_success
  test::assert_bundle_output --partial --hook-run child save --hook-exec parent save
}

@test "inherits hook from relative (sibling) path" {
  mkdir "$TILDEPOT_HOME/my-bases"
  test::mock_bundle parent "$TILDEPOT_HOME/my-bases" "
    $(test::mock_hook_fn save)
  "
  test::mock_bundle child "
    EXTEND='../my-bases/parent.sh'
  "

  run tildepot run save
  assert_success
  test::assert_bundle_output --partial --hook-run child save --hook-exec parent save
}

@test "inherits hook from absolute path" {
  assert_equal "${TILDEPOT_HOME:0:1}" "/"

  mkdir "$TILDEPOT_HOME/my-bases"
  test::mock_bundle parent "$TILDEPOT_HOME/my-bases" "
    $(test::mock_hook_fn save)
  "
  test::mock_bundle child "
    EXTEND='$TILDEPOT_HOME/my-bases/parent.sh'
  "

  run tildepot run save
  assert_success
  test::assert_bundle_output --partial --hook-run child save --hook-exec parent save
}

@test "aborts when bundle inherits from missing local file" {
  test::mock_bundle child "EXTEND='./missing.sh'"

  run tildepot run save
  assert_failure
  assert_output --partial "missing file"
}

###
# Parent hook override
###

@test "overrides hook from parent" {
  mkdir "$TILDEPOT_HOME/bundles/base"
  test::mock_bundle parent "$TILDEPOT_HOME/bundles/base" "
    $(test::mock_hook_fn save)
  "
  test::mock_bundle child "
    EXTEND='./base/parent.sh'
    $(test::mock_hook_fn save)
  "

  run tildepot run save
  assert_success
  test::assert_bundle_output --partial --hook child save
}

###
# Repeated extension
###

@test "inherits hook from parent's parent" {
  mkdir "$TILDEPOT_HOME/bundles/my-bases"
  test::mock_bundle top "$TILDEPOT_HOME/bundles/my-bases" "
    $(test::mock_hook_fn save)
  "
  test::mock_bundle middle "$TILDEPOT_HOME/bundles/my-bases" "
    EXTEND='./top.sh'
  "
  test::mock_bundle bottom "
    EXTEND='./my-bases/middle.sh'
  "

  run tildepot run save
  assert_success
  test::assert_bundle_output --partial --hook-run bottom save --hook-exec top save
}

@test "inherits hook from parent's parent's parent" {
  test::mock_bundle p0 "$TILDEPOT_HOME" "$(test::mock_hook_fn save)"
  test::mock_bundle p1 "$TILDEPOT_HOME" "EXTEND='./p0.sh'"
  test::mock_bundle p2 "$TILDEPOT_HOME" "EXTEND='./p1.sh'"
  test::mock_bundle leaf "EXTEND='$TILDEPOT_HOME/p2.sh'"

  run tildepot run save
  assert_success
  test::assert_bundle_output --partial --hook-run leaf save --hook-exec p0 save
}

@test "aborts when bundle inherit change is too deep or infinite" {
  test::mock_bundle left "$TILDEPOT_HOME" "EXTEND='./right.sh'"
  test::mock_bundle right "$TILDEPOT_HOME" "EXTEND='./left.sh'"
  test::mock_bundle leaf "EXTEND='$TILDEPOT_HOME/left.sh'"

  run tildepot run save
  assert_failure
  assert_output --partial "too many levels"
}

###
# Extend bundle release
###

@test "downloads & extends bundle release from tildepot repo" {
  test::mock_download --reset --fixture mock_bundle.sh
  test::mock_bundle child "
    EXTEND='foobar-bundle@1.2.3'
  "

  run tildepot run save -y
  assert_success
  test::assert_bundle_output --partial --hook-run child save --hook-exec mock save

  test::it 'downloads the bundle into the local repo'
  test::assert_mock_download_url \
    "$TEST_APP_REPO_URL/releases/download/foobar-bundle@1.2.3/foobar.sh"
  assert_files_equal "$TILDEPOT_HOME/.tildepot/bundles/foobar_1-2-3.sh" "$(test::fixture_path mock_bundle.sh)"
}

@test "skips download when bundle release already exists" {
  test::put "$(test::fixture mock_bundle.sh)" \
    "$TILDEPOT_HOME/.tildepot/bundles/foobar_1-2-3.sh"
  test::mock_bundle child "
    EXTEND='foobar-bundle@1.2.3'
  "

  run tildepot run save -y
  assert_success
  test::assert_bundle_output --partial --hook-run child save --hook-exec mock save
  test::refute_mock_download_url
}

@test "re-downloads bundle release when local version is outdated" {
  test::mock_download --reset --fixture mock_bundle.sh
  test::put "$(test::fixture mock_bundle.sh)" \
    "$TILDEPOT_HOME/.tildepot/bundles/foobar_1-2-3.sh"
  test::mock_bundle child "
    EXTEND='foobar-bundle@2.0.0'
  "

  run tildepot run save -y
  assert_success
  test::assert_bundle_output --partial --hook-run child save --hook-exec mock save

  test::it 're-downloads the bundle'
  test::assert_mock_download_url \
    "$TEST_APP_REPO_URL/releases/download/foobar-bundle@2.0.0/foobar.sh"
  assert_files_equal "$TILDEPOT_HOME/.tildepot/bundles/foobar_2-0-0.sh" "$(test::fixture_path mock_bundle.sh)"
}

@test "prompts for initial download of bundle release" {
  test::mock_download --reset --fixture mock_bundle.sh
  test::mock_bundle child "
    EXTEND='foobar-bundle@1.2.3'
  "

  run test::expect_prompt \
    --ln "foobar-bundle v1.2.3" \
    --ln "download" \
    --yn "Continue?" y \
    tildepot run save
  assert_success
}

@test "downloads prerelease of bundle release from tildepot repo" {
  test::mock_download --reset --fixture mock_bundle.sh
  test::mock_bundle child "
    EXTEND='foobar-bundle@1.2.3-next.4'
  "

  run tildepot run save -y
  assert_success
  test::assert_bundle_output --partial --hook-run child save --hook-exec mock save

  test::it 'downloads the bundle into the local repo'
  test::assert_mock_download_url \
    "$TEST_APP_REPO_URL/releases/download/foobar-bundle@1.2.3-next.4/foobar.sh"
  assert_files_equal "$TILDEPOT_HOME/.tildepot/bundles/foobar_1-2-3-next-4.sh" "$(test::fixture_path mock_bundle.sh)"
}

@test "aborts when bundle inherits with invalid bundle release version" {
  test::mock_bundle child "
    EXTEND='foobar-bundle@bad-version'
  "

  run tildepot run save
  assert_failure
  assert_output --partial "Invalid bundle release format"
}
@test "aborts when bundle inherits with invalid bundle release name" {
  test::mock_bundle child "
    EXTEND='invalid-name@1.0.0'
  "

  run tildepot run save
  assert_failure
  assert_output --partial "Invalid bundle release format"
}
@test "aborts when bundle inherits with invalid bundle release format" {
  test::mock_bundle child "
    EXTEND='foobar-bundle@1.0.0@'
  "

  run tildepot run save
  assert_failure
  assert_output --partial "Invalid bundle release format"
}

@test "aborts when bundle download failed" {
  test::mock_bundle child "
    EXTEND='foobar-bundle@9.9.9'
  "

  run tildepot run save -y
  assert_failure
  assert_output --partial "Failed to download bundle"
}
@test "retries download on second run after initial failure" {
  test::mock_download --reset

  test::mock_bundle child "
    EXTEND='foobar-bundle@9.9.9'
  "

  test::it 'fails on first run'
  test::mock_download --error
  run tildepot run save -y

  test::it 're-attempts download on second run'
  test::mock_download --error
  run tildepot run save -y
  assert_failure
  assert_output --partial "Failed to download bundle"
}
