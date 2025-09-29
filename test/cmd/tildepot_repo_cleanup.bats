#!/usr/bin/env bats
#
# Tests for `tildepot repo cleanup`

setup() {
  load ../test_lib.sh

  mkdir -p "$TEST_APP_REPO"
}

@test "succeeds when nothing to do" {
  run tildepot repo cleanup
  assert_success

  assert_output --partial "$(test::dedent "
    => Cleaning up bundles...
    Nothing to delete.
  ")"
  assert_output --partial "$(test::dedent "
    => Cleaning up temporary files...
    Nothing to delete.
  ")"
  assert_output --partial "$(test::dedent "
    => Cleaning up state files...
    Nothing to delete.
  ")"
  assert_line --partial "Cleaned up tildepot repository."
}

@test "aborts when repo directory does not exist" {
  rm -rf "$TEST_APP_REPO"

  run tildepot repo cleanup
  assert_failure
}

@test "cleans up unused downloaded bundles" {
  skip
}

@test "cleans up temp files" {
  local temp_state_dir="$TEST_APP_REPO/.tildepot/state"
  mkdir -p "$temp_state_dir"
  test::put '' "$temp_state_dir/.dotfile"
  test::put 'foo' "$temp_state_dir/foo"
  test::put 'bar' "$temp_state_dir/sub-dir/bar"

  assert_dir_exists "$temp_state_dir"
  run tildepot repo cleanup
  assert_success
  assert_dir_not_exists "$temp_state_dir"
}

@test "cleans up unused state files" {
  # Mock present bundles.
  test::put '' "$TEST_APP_REPO/bundles/aa.sh"
  test::put '' "$TEST_APP_REPO/bundles/cc.sh"

  # Inject present & obsolete state files.
  test::put 'aa' "$TEST_APP_REPO/state/aa"
  test::put 'bb' "$TEST_APP_REPO/state/bb"
  test::put 'cc' "$TEST_APP_REPO/state/cc/sub"
  test::put 'dd' "$TEST_APP_REPO/state/dd/sub"

  run tildepot repo cleanup
  assert_success
  refute_line '- Deleted state/aa'
  assert_line '- Deleted state/bb'
  assert_line '- Deleted state/dd'
  refute_line '- Deleted state/cc'
  test::assert_dir_files --depth 2 "$TEST_APP_REPO/state" \
    'aa' \
    'cc/sub'
}
@test "matches special bundle basenames with state files" {
  # Mock present bundles.
  test::put '' "$TEST_APP_REPO/bundles/00 sorted.sh"
  test::put '' "$TEST_APP_REPO/bundles/cc.sh"

  # Inject present & obsolete state files.
  test::put '' "$TEST_APP_REPO/state/00 sorted"
  test::put '' "$TEST_APP_REPO/state/00"
  test::put '' "$TEST_APP_REPO/state/sorted"

  run tildepot repo cleanup
  assert_success
  assert_line '- Deleted state/00'
  assert_line '- Deleted state/00 sorted'
  refute_line '- Deleted state/sorted'
  test::assert_dir_files --depth 2 "$TEST_APP_REPO/state" \
    'sorted'
}
