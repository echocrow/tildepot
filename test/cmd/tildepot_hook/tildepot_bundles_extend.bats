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
  mv "$(test::mock_hook parent install)" \
    "$TILDEPOT_HOME/bundles/my-bases/parent.sh"

  test::mock_inherited_bundle child "./my-bases/parent.sh"

  run tildepot install
  assert_success
  assert_line "$(test::hook_run_msg child install)"
  assert_line "$(test::hook_exec_msg parent install)"
}

@test "inherits hook from relative (sibling) path" {
  mkdir "$TILDEPOT_HOME/my-bases"
  mv "$(test::mock_hook parent install)" \
    "$TILDEPOT_HOME/my-bases/parent.sh"

  test::mock_inherited_bundle child "../my-bases/parent.sh"

  run tildepot install
  assert_success
  assert_line "$(test::hook_run_msg child install)"
  assert_line "$(test::hook_exec_msg parent install)"
}

@test "inherits hook from absolute path" {
  assert_equal "${TILDEPOT_HOME:0:1}" "/"

  mkdir "$TILDEPOT_HOME/my-bases"
  mv "$(test::mock_hook parent install)" \
    "$TILDEPOT_HOME/my-bases/parent.sh"

  test::mock_inherited_bundle child "$TILDEPOT_HOME/my-bases/parent.sh"

  run tildepot install
  assert_success
  assert_line "$(test::hook_run_msg child install)"
  assert_line "$(test::hook_exec_msg parent install)"
}

@test "aborts bundle inherits from missing local file" {
  test::mock_inherited_bundle child "./missing.sh"

  run tildepot install
  assert_failure
  assert_output --partial "missing file"
}

###
# Parent hook override
###

@test "overrides hook from parent" {
  mkdir "$TILDEPOT_HOME/bundles/base"
  mv "$(test::mock_hook parent install)" \
    "$TILDEPOT_HOME/bundles/base/parent.sh"

  test::mock_inherited_bundle child "./base/parent.sh"
  test::mock_hook child install

  run tildepot install
  assert_success
  test::assert_hook_invoked child install
  refute_line "$(test::hook_exec_msg parent install)"
}

###
# Repeated extension
###

@test "inherits hook from parent's parent" {
  mkdir "$TILDEPOT_HOME/bundles/my-bases"
  mv "$(test::mock_hook top install)" \
    "$TILDEPOT_HOME/bundles/my-bases/top.sh"
  mv "$(test::mock_inherited_bundle middle "./top.sh")" \
    "$TILDEPOT_HOME/bundles/my-bases/middle.sh"
  test::mock_inherited_bundle bottom "./my-bases/middle.sh"

  run tildepot install
  assert_success
  assert_line "$(test::hook_run_msg bottom install)"
  assert_line "$(test::hook_exec_msg top install)"
}

@test "inherits hook from parent's parent's parent" {
  mkdir "$TILDEPOT_HOME/bundles/my-bases"
  mv "$(test::mock_hook p0 install)" \
    "$TILDEPOT_HOME/bundles/my-bases/p0.sh"
  mv "$(test::mock_inherited_bundle p1 "./p0.sh")" \
    "$TILDEPOT_HOME/bundles/my-bases/p1.sh"
  mv "$(test::mock_inherited_bundle p2 "./p1.sh")" \
    "$TILDEPOT_HOME/bundles/my-bases/p2.sh"
  test::mock_inherited_bundle leave "./my-bases/p2.sh"

  run tildepot install
  assert_success
  assert_line "$(test::hook_run_msg leave install)"
  assert_line "$(test::hook_exec_msg p0 install)"
}

@test "aborts when bundle inherit change is too deep or infinite" {
  mkdir "$TILDEPOT_HOME/bundles/my-bases"
  mv "$(test::mock_inherited_bundle left "./right.sh")" \
    "$TILDEPOT_HOME/bundles/my-bases/left.sh"
  mv "$(test::mock_inherited_bundle right "./left.sh")" \
    "$TILDEPOT_HOME/bundles/my-bases/right.sh"
  test::mock_inherited_bundle leave "./my-bases/left.sh"

  run tildepot install
  assert_failure
  assert_output --partial "too many levels"
}
