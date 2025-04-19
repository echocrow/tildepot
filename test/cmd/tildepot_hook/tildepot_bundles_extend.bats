#!/usr/bin/env bats
#
# Tests for `tildepot` bundles: EXTEND behavior
#
# These tests use the `install` hook as stand-in for all hook commands. The same
# tests are assumed to also pass for all other hook commands.

setup() {
  load ../../test_lib.sh
  load ./tildepot_hook_lib.sh
}

###
# Extend local file
###

@test "inherits hook from relative (nested) path" {
  mkdir "$TILDEPOT_HOME/bundles/my-bases"
  test::mock_bundle parent "$TILDEPOT_HOME/bundles/my-bases" "
    $(test::mock_hook_fn install)
  "
  test::mock_bundle child "
    EXTEND='./my-bases/parent.sh'
  "

  run tildepot install
  assert_success
  test::assert_bundle_output --hook-run child install --hook-exec parent install
}

@test "inherits hook from relative (sibling) path" {
  mkdir "$TILDEPOT_HOME/my-bases"
  test::mock_bundle parent "$TILDEPOT_HOME/my-bases" "
    $(test::mock_hook_fn install)
  "
  test::mock_bundle child "
    EXTEND='../my-bases/parent.sh'
  "

  run tildepot install
  assert_success
  test::assert_bundle_output --hook-run child install --hook-exec parent install
}

@test "inherits hook from absolute path" {
  assert_equal "${TILDEPOT_HOME:0:1}" "/"

  mkdir "$TILDEPOT_HOME/my-bases"
  test::mock_bundle parent "$TILDEPOT_HOME/my-bases" "
    $(test::mock_hook_fn install)
  "
  test::mock_bundle child "
    EXTEND='$TILDEPOT_HOME/my-bases/parent.sh'
  "

  run tildepot install
  assert_success
  test::assert_bundle_output --hook-run child install --hook-exec parent install
}

@test "aborts bundle inherits from missing local file" {
  test::mock_bundle child "EXTEND='./missing.sh'"

  run tildepot install
  assert_failure
  assert_output --partial "missing file"
}

###
# Parent hook override
###

@test "overrides hook from parent" {
  mkdir "$TILDEPOT_HOME/bundles/base"
  test::mock_bundle parent "$TILDEPOT_HOME/bundles/base" "
    $(test::mock_hook_fn install)
  "
  test::mock_bundle child "
    EXTEND='./base/parent.sh'
    $(test::mock_hook_fn install)
  "

  run tildepot install
  assert_success
  test::assert_bundle_output --hook child install
}

###
# Repeated extension
###

@test "inherits hook from parent's parent" {
  mkdir "$TILDEPOT_HOME/bundles/my-bases"
  test::mock_bundle top "$TILDEPOT_HOME/bundles/my-bases" "
    $(test::mock_hook_fn install)
  "
  test::mock_bundle middle "$TILDEPOT_HOME/bundles/my-bases" "
    EXTEND='./top.sh'
  "
  test::mock_bundle bottom "
    EXTEND='./my-bases/middle.sh'
  "

  run tildepot install
  assert_success
  test::assert_bundle_output --hook-run bottom install --hook-exec top install
}

@test "inherits hook from parent's parent's parent" {
  test::mock_bundle p0 "$TILDEPOT_HOME" "$(test::mock_hook_fn install)"
  test::mock_bundle p1 "$TILDEPOT_HOME" "EXTEND='./p0.sh'"
  test::mock_bundle p2 "$TILDEPOT_HOME" "EXTEND='./p1.sh'"
  test::mock_bundle leaf "EXTEND='$TILDEPOT_HOME/p2.sh'"

  run tildepot install
  assert_success
  test::assert_bundle_output --hook-run leaf install --hook-exec p0 install
}

@test "aborts when bundle inherit change is too deep or infinite" {
  test::mock_bundle left "$TILDEPOT_HOME" "EXTEND='./right.sh'"
  test::mock_bundle right "$TILDEPOT_HOME" "EXTEND='./left.sh'"
  test::mock_bundle leaf "EXTEND='$TILDEPOT_HOME/left.sh'"

  run tildepot install
  assert_failure
  assert_output --partial "too many levels"
}
