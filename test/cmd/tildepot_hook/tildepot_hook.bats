#!/usr/bin/env bats
#
# Tests for `tildepot` hooks
#
# These tests use the `install` hook as stand-in for all hook commands. The same
# tests are assumed to also pass for all other hook commands.

setup() {
  load ../../test_lib.sh
  load ./tildepot_hook_lib.sh
}

###
# Bundle SKIP() function
###

@test "skips hook when bundle skip returns 0" {
  test::mock_bundle_skip foo "return 0"
  test::mock_hook foo install

  run tildepot install
  assert_success
  test::assert_bundle_skipped foo install
}
@test "calls hook when bundle skip returns 1" {
  test::mock_bundle_skip foo "return 1"
  test::mock_hook foo install

  run tildepot install
  assert_success
  test::assert_hook_invoked foo install
}
@test "skips hook when bundle skip prints message" {
  test::mock_bundle_skip foo "echo 'mock reason'"
  test::mock_hook foo install

  run tildepot install
  assert_success
  test::assert_bundle_skipped foo install "mock reason"
}
@test "skips hook when bundle skip prints conditional message" {
  test::mock_bundle_skip foo "[[ 0 ]] && echo 'mock reason'"
  test::mock_hook foo install

  run tildepot install
  assert_success
  test::assert_bundle_skipped foo install "mock reason"
}
@test "calls hook when bundle skip does not print conditional message" {
  test::mock_bundle_skip foo "[[ '' ]] && echo 'mock reason'"
  test::mock_hook foo install

  run tildepot install
  assert_success
  test::assert_hook_invoked foo install
}

###
# Bundle sort order
###

@test "calls multiple bundles in alphabetical order" {
  test::mock_hook bbb install
  test::mock_hook ccc install
  test::mock_hook aaa install

  run tildepot install
  assert_success
  test::assert_hook_invoked --index 0 aaa install
  test::assert_hook_invoked --index 2 bbb install
  test::assert_hook_invoked --index 4 ccc install
}

@test "calls multiple bundles in alphabetical order with numerical prefix" {
  local bundle_file
  bundle_file="$(test::mock_hook aaa install)"
  mv "$bundle_file" "$(dirname "$bundle_file")/02 aaa.sh"
  bundle_file="$(test::mock_hook bbb install)"
  mv "$bundle_file" "$(dirname "$bundle_file")/42 bbb.sh"
  bundle_file="$(test::mock_hook ccc install)"
  mv "$bundle_file" "$(dirname "$bundle_file")/00 ccc.sh"

  run tildepot install
  assert_success
  test::assert_hook_invoked --index 0 ccc install
  test::assert_hook_invoked --index 2 aaa install
  test::assert_hook_invoked --index 4 bbb install
}

###
# Bundle filtering via `--bundle`
###

@test "calls sole '--bundle' hook" {
  test::mock_hook foo install
  test::mock_hook bar install

  run tildepot install --bundle foo
  assert_success
  test::assert_hook_invoked foo install
  test::refute_hook_called bar install
}
@test "calls multiple '--bundle' hooks" {
  test::mock_hook aaa install
  test::mock_hook bbb install
  test::mock_hook ccc install

  run tildepot install --bundle aaa --bundle bbb
  assert_success
  test::assert_hook_invoked aaa install
  test::assert_hook_invoked bbb install
  test::refute_hook_called ccc install
}
@test "calls multiple '--bundle' hooks in specified order" {
  test::mock_hook aaa install
  test::mock_hook bbb install
  test::mock_hook ccc install

  run tildepot install --bundle bbb --bundle aaa --bundle ccc
  assert_success
  test::assert_hook_invoked --index 0 bbb install
  test::assert_hook_invoked --index 2 aaa install
  test::assert_hook_invoked --index 4 ccc install
}
@test "errors on invalid '--bundle' name" {
  test::mock_hook aaa install

  run tildepot install --bundle missing
  assert_failure
  assert_output "Error: Bundle missing not found."
}
@test "does not invoke any bundles on invalid '--bundle' name" {
  test::mock_hook aaa install

  run tildepot install --bundle aaa --bundle missing
  assert_failure
  test::refute_hook_called aaa install
}

###
# Bundle inheritance
###

@test "child bundle inherits hook from relative (nested) path" {
  mkdir "$TILDEPOT_HOME/bundles/my-bases"
  mv "$(test::mock_hook parent install)" \
    "$TILDEPOT_HOME/bundles/my-bases/parent.sh"

  test::mock_inherited_bundle child "./my-bases/parent.sh"

  run tildepot install
  assert_success
  assert_line "$(test::hook_run_msg child install)"
  assert_line "$(test::hook_exec_msg parent install)"
}
@test "child bundle inherits hook from relative (sibling) path" {
  mkdir "$TILDEPOT_HOME/my-bases"
  mv "$(test::mock_hook parent install)" \
    "$TILDEPOT_HOME/my-bases/parent.sh"

  test::mock_inherited_bundle child "../my-bases/parent.sh"

  run tildepot install
  assert_success
  assert_line "$(test::hook_run_msg child install)"
  assert_line "$(test::hook_exec_msg parent install)"
}
@test "child bundle inherits hook from absolute path" {
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
@test "aborts bundle inherits from missing file" {
  test::mock_inherited_bundle child "./missing.sh"

  run tildepot install
  assert_failure
  assert_output --partial "missing file"
}

@test "child bundle hook overrides parent hook" {
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

@test "child bundle inherits hook from parent's parent" {
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
@test "child bundle inherits hook from parent's parent's parent" {
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
