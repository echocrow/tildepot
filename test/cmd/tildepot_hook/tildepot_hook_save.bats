#!/usr/bin/env bats
#
# Tests for `tildepot save`

setup() {
  load ../../test_lib.sh
  load ./tildepot_hook_lib.sh
  load ./tildepot_hook_test.sh

  test::setup_assert_hook_cmd save
}

@test "describes hook command" {
  test::assert_hook_cmd "describes hook command"
}

@test "calls hook for all bundles" {
  test::assert_hook_cmd "calls hook for all bundles"
}

@test "aborts early when hook errors" {
  test::assert_hook_cmd "aborts early when hook errors"
}

@test "skips hook when hook skip returns 0" {
  test::assert_hook_cmd "skips hook when hook skip returns 0"
}

@test "calls hook when hook skip returns 1" {
  test::assert_hook_cmd "calls hook when hook skip returns 1"
}

@test "skips hook when hook skip prints message" {
  test::assert_hook_cmd "skips hook when hook skip prints message"
}

@test "skips hook when hook skip prints conditional message" {
  test::assert_hook_cmd "skips hook when hook skip prints conditional message"
}

@test "prints multi-line skip reason on separate, prefixed lines" {
  test::assert_hook_cmd "prints multi-line skip reason on separate, prefixed lines"
}

@test "calls hook when hook skip does not print conditional message" {
  test::assert_hook_cmd "calls hook when hook skip does not print conditional message"
}

@test "calls hook when '--force' is set despite hook skip returning 0" {
  test::assert_hook_cmd "calls hook when '--force' is set despite hook skip returning 0"
}

###
# State management
###

@test "exports '\$BUNDLE_STATE_DIR' with path to temp bundle state dir" {
  local want_dir="$TILDEPOT_HOME/.tildepot/state/foo"
  # shellcheck disable=SC2016
  test::mock_bundle foo '
    _ROOT_VAR="$BUNDLE_STATE_DIR"
  '
  # shellcheck disable=SC2016
  test::mock_hook foo save '
    echo "ROOT_VAR=[$_ROOT_VAR]"
    echo "FN_VAR=[$BUNDLE_STATE_DIR]"
  '

  run tildepot save
  assert_success
  test::it 'exposes var when parsing the file'
  assert_line "ROOT_VAR=[$want_dir]"
  test::it 'exposes var when running hook'
  assert_line "FN_VAR=[$want_dir]"
}
@test "exports '\$BUNDLE_PREV_STATE_DIR' with path versioned bundle state dir" {
  local want_dir="$TILDEPOT_HOME/state/foo"
  # shellcheck disable=SC2016
  test::mock_bundle foo '
    _ROOT_VAR="$BUNDLE_PREV_STATE_DIR"
  '
  # shellcheck disable=SC2016
  test::mock_hook foo save '
    echo "ROOT_VAR=[$_ROOT_VAR]"
    echo "FN_VAR=[$BUNDLE_PREV_STATE_DIR]"
  '

  run tildepot save
  assert_success
  test::it 'exposes var when parsing the file'
  assert_line "ROOT_VAR=[$want_dir]"
  test::it 'exposes var when running hook'
  assert_line "FN_VAR=[$want_dir]"
}

@test "replaces repo bundle state with temp bundle state after run" {
  # shellcheck disable=SC2016
  test::mock_hook foo save '
    echo "foobar" > "$BUNDLE_STATE_DIR/my-state.txt"
  '

  run tildepot save
  assert_success
  assert_file_exists "$TILDEPOT_HOME/state/foo/my-state.txt"
  assert_file_contains "$TILDEPOT_HOME/state/foo/my-state.txt" "foobar"
}

@test "discards previous temp bundle state after hook" {
  test::put "foobar" "$TILDEPOT_HOME/.tildepot/state/foo/my-state.txt"
  test::put "foobar" "$TILDEPOT_HOME/state/foo/my-state.txt"
  test::mock_hook foo save

  run tildepot save
  assert_success
  assert_file_not_exists "$TILDEPOT_HOME/.tildepot/state/foo/my-state.txt"
}
