#!/usr/bin/env bats
#
# Tests for `tildepot repo cleanup`

setup() {
  load ../test_lib.sh

  mkdir -p "$TEST_APP_REPO"

  _DOWNLOADED_BUNDLES_DIR="$TEST_APP_REPO/.tildepot/bundles"
  _TEMP_STATE_DIR="$TEST_APP_REPO/.tildepot/state"
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

###
# Unused downloaded bundles
###

@test "cleans up unused downloaded bundles" {
  test::mock_download --error

  test::put 'EXTEND=aa-bundle@1.0.0' "$TEST_APP_REPO/bundles/aa.sh"
  test::put 'EXTEND=bb-bundle@0.1.2-next.3' "$TEST_APP_REPO/bundles/bb.sh"

  test::put "$_DOWNLOADED_BUNDLES_DIR/aa_1-0-0.sh"
  test::put "$_DOWNLOADED_BUNDLES_DIR/aa_9-9-9.sh"
  test::put "$_DOWNLOADED_BUNDLES_DIR/bb_0-1-2-next-3.sh"
  test::put "$_DOWNLOADED_BUNDLES_DIR/bb_0-1-2.sh"
  test::put "$_DOWNLOADED_BUNDLES_DIR/cc_1-0-0.sh"

  run tildepot repo cleanup
  assert_success
  test::assert_dir_files "$_DOWNLOADED_BUNDLES_DIR" \
    'aa_1-0-0.sh' \
    'bb_0-1-2-next-3.sh'

  test::it 'does not download bundles during cleanup'
  test::refute_mock_download_url
}

@test "follows local parents when determining unused downloaded bundles" {
  test::put 'EXTEND=../my-bundles/bb.sh' "$TEST_APP_REPO/bundles/aa.sh"

  test::put 'EXTEND=cc-bundle@1.1.1' "$TEST_APP_REPO/my-bundles/bb.sh"

  test::put "$_DOWNLOADED_BUNDLES_DIR/aa_1-1-1.sh"
  test::put "$_DOWNLOADED_BUNDLES_DIR/bb_1-1-1.sh"
  test::put "$_DOWNLOADED_BUNDLES_DIR/cc_1-1-1.sh"

  run tildepot repo cleanup
  assert_success
  assert_line '- Deleted .tildepot/bundles/aa_1-1-1.sh'
  assert_line '- Deleted .tildepot/bundles/bb_1-1-1.sh'
  refute_line '- Deleted .tildepot/bundles/cc_1-1-1.sh'
  test::assert_dir_files "$_DOWNLOADED_BUNDLES_DIR" \
    'cc_1-1-1.sh'
}

@test "aborts without deleting on bad bundle config" {
  test::put 'EXTEND=invalid-name@@0' "$TEST_APP_REPO/bundles/aa.sh"

  test::put "$_DOWNLOADED_BUNDLES_DIR/aa_1-1-1.sh"
  test::put "$_DOWNLOADED_BUNDLES_DIR/bb_1-1-1.sh"

  run tildepot repo cleanup
  assert_line --partial 'Error: '
  assert_failure
  test::assert_dir_files "$_DOWNLOADED_BUNDLES_DIR" \
    'aa_1-1-1.sh' \
    'bb_1-1-1.sh'
}

@test "deletes all files when no bundles exist" {
  test::put "$_DOWNLOADED_BUNDLES_DIR/aa_1-0-0.sh"
  test::put "$_DOWNLOADED_BUNDLES_DIR/bb_1-0-0.sh"
  test::put "$_DOWNLOADED_BUNDLES_DIR/cc_1-0-0.sh"

  run tildepot repo cleanup
  assert_success
  test::assert_dir_files "$_DOWNLOADED_BUNDLES_DIR" ''
}

###
# Temp files
###

@test "cleans up temp files" {
  test::put "$_TEMP_STATE_DIR/.dotfile"
  test::put "$_TEMP_STATE_DIR/foo"
  test::put "$_TEMP_STATE_DIR/sub-dir/bar"

  assert_dir_exists "$_TEMP_STATE_DIR"
  run tildepot repo cleanup
  assert_success
  assert_dir_not_exists "$_TEMP_STATE_DIR"
}

###
# Unused state
###

@test "cleans up unused state files" {
  # Mock present bundles.
  test::put "$TEST_APP_REPO/bundles/aa.sh"
  test::put "$TEST_APP_REPO/bundles/cc.sh"

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
  test::put "$TEST_APP_REPO/bundles/00 sorted.sh"
  test::put "$TEST_APP_REPO/bundles/cc.sh"

  # Inject present & obsolete state files.
  test::put "$TEST_APP_REPO/state/00 sorted"
  test::put "$TEST_APP_REPO/state/00"
  test::put "$TEST_APP_REPO/state/sorted"

  run tildepot repo cleanup
  assert_success
  assert_line '- Deleted state/00'
  assert_line '- Deleted state/00 sorted'
  refute_line '- Deleted state/sorted'
  test::assert_dir_files --depth 2 "$TEST_APP_REPO/state" \
    'sorted'
}
