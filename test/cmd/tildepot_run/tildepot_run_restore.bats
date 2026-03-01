#!/usr/bin/env bats
#
# Tests for `tildepot run restore`

setup() {
  load ../../test_lib.sh
  load ./tildepot_run_lib.sh
  load ./tildepot_run_test.sh

  test::setup_assert_run_cmd restore -y
}

@test "fails without any bundle files" {
  test::assert_run_cmd "fails without any bundle files"
}

@test "calls hook for all bundles" {
  test::assert_run_cmd "calls hook for all bundles"
}

@test "aborts early when hook errors" {
  test::assert_run_cmd "aborts early when hook errors"
}

@test "skips hook when hook skip returns 0" {
  test::assert_run_cmd "skips hook when hook skip returns 0"
}

@test "calls hook when hook skip returns 1" {
  test::assert_run_cmd "calls hook when hook skip returns 1"
}

@test "skips hook when hook skip prints message" {
  test::assert_run_cmd "skips hook when hook skip prints message"
}

@test "skips hook when hook skip prints conditional message" {
  test::assert_run_cmd "skips hook when hook skip prints conditional message"
}

@test "prints multi-line skip reason on separate, prefixed lines" {
  test::assert_run_cmd "prints multi-line skip reason on separate, prefixed lines"
}

@test "calls hook when hook skip does not print conditional message" {
  test::assert_run_cmd "calls hook when hook skip does not print conditional message"
}

@test "calls hook when '--force' is set despite hook skip returning 0" {
  test::assert_run_cmd "calls hook when '--force' is set despite hook skip returning 0"
}

###
# Prompt
###

@test "prompts for confirmation before restoring" {
  test::mock_hook foo restore

  run test::expect_prompt \
    --ln "Restoring will override" \
    --yn "Continue?" y \
    tildepot run restore
  assert_success
  test::assert_bundle_output --partial --hook foo restore
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
  test::mock_hook foo restore '
    echo "ROOT_VAR=[$_ROOT_VAR]"
    echo "FN_VAR=[$BUNDLE_STATE_DIR]"
  '

  run tildepot run restore -y
  assert_success
  test::it 'exposes var when parsing the file'
  assert_line "ROOT_VAR=[$want_dir]"
  test::it 'exposes var when running hook'
  assert_line "FN_VAR=[$want_dir]"
}

@test "copies repo bundle state into temp bundle state before hook" {
  test::put 'foobar' "$TILDEPOT_HOME/state/foo/my-state.txt"
  # shellcheck disable=SC2016
  test::mock_hook foo restore '
    echo "content=[$(cat "$BUNDLE_STATE_DIR/my-state.txt")]"
  '

  run tildepot run restore -y
  assert_success
  assert_line "content=[foobar]"
  test::it 'left repo bundle state in place'
  assert_file_contains "$TILDEPOT_HOME/state/foo/my-state.txt" "foobar"
}

@test "copies repo bundle state into temp bundle state before RESTORE_SKIP hook" {
  test::put 'foobar' "$TILDEPOT_HOME/state/foo/my-state.txt"
  # shellcheck disable=SC2016
  test::mock_hook foo restore_skip '
    local path="$BUNDLE_STATE_DIR/my-state.txt"
    [[ ! -f $path ]]
  '
  test::mock_hook foo restore

  run tildepot run restore -y
  assert_success
  test::assert_bundle_output --partial --hook-exec foo restore
}
@test "clears temp bundle state after positive RESTORE_SKIP" {
  test::put 'foobar' "$TILDEPOT_HOME/state/foo/my-state.txt"
  test::mock_hook foo restore_skip '
    true
  '
  test::mock_hook foo restore

  run tildepot run restore -y
  assert_success
  test::assert_bundle_output --partial --hook-skip foo restore ''
  assert_dir_not_exists "$TILDEPOT_HOME/.tildepot/state/foo"
}

@test "discards previous temp bundle state before hook" {
  test::put 'fizzbuzz' "$TILDEPOT_HOME/.tildepot/state/foo/my-state.txt"
  test::put 'foobar' "$TILDEPOT_HOME/state/foo/my-state.txt"
  # shellcheck disable=SC2016
  test::mock_hook foo restore '
    echo "content=[$(cat "$BUNDLE_STATE_DIR/my-state.txt")]"
  '

  run tildepot run restore -y
  assert_success
  refute_line "content=[fizzbuzz]"
}

@test "discards previous temp bundle state after hook" {
  test::put 'foobar' "$TILDEPOT_HOME/.tildepot/state/foo/my-state.txt"
  test::put 'foobar' "$TILDEPOT_HOME/state/foo/my-state.txt"
  test::mock_hook foo restore

  run tildepot run restore -y
  assert_success
  assert_file_not_exists "$TILDEPOT_HOME/.tildepot/state/foo/my-state.txt"
}
