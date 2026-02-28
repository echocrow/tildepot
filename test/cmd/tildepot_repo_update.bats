#!/usr/bin/env bats
#
# Tests for `tildepot repo update`

setup() {
  load ../test_lib.sh

  mkdir -p "$TEST_APP_REPO"

  _DOWNLOADED_BUNDLES_DIR="$TEST_APP_REPO/.tildepot/bundles"
}

teardown() {
  test::mock_download_teardown
}

function _mock_fetch_releases() {
  local refs=''
  for ref in "$@"; do
    [[ $ref ]] && refs+="\"$ref\","
  done
  refs="${refs%,}"
  test::mock_download "{\"refs\": [$refs]}"
}

@test "succeeds when no remote bundles exist" {
  _mock_fetch_releases 'foo-bundle@1.0.0' 'bar-bundle@1.0.0'

  run tildepot repo update
  assert_success
  assert_line '=> Fetching latest releases...'
  assert_line 'Found 2 official bundles.'
  assert_line '=> Scanning & updating bundles...'
  assert_line 'Nothing to update.'
}

@test "aborts when fetching remote bundles fails" {
  test::mock_download --error

  run tildepot repo update
  assert_failure

  assert_line '=> Fetching latest releases...'
  assert_line 'Error: Failed to fetch latest releases.'
  refute_line '=> Scanning & updating bundles...'
}

@test "updates to latest releases" {
  _mock_fetch_releases 'foo-bundle@2.0.0'
  test::mock_download '# mock bundle'

  test::put 'EXTEND=foo-bundle@1.0.0' "$TEST_APP_REPO/bundles/foo.sh"
  test::put "$_DOWNLOADED_BUNDLES_DIR/foo_1-0-0.sh"

  run tildepot repo update -y
  assert_success
  assert_line "- Updated foo-bundle@1.0.0 to foo-bundle@2.0.0"
  assert_line --partial "Bundles updated."

  test::it "updates 'EXTEND' variable in bundle"
  test::assert_file_line "$TEST_APP_REPO/bundles/foo.sh" 'EXTEND=foo-bundle@2.0.0'
  test::refute_file_line "$TEST_APP_REPO/bundles/foo.sh" 'EXTEND=foo-bundle@1.0.0'

  test::it 'downloads newer bundle'
  assert_file_exist "$_DOWNLOADED_BUNDLES_DIR/foo_2-0-0.sh"

  test::it 'removes obsolete bundle'
  assert_file_not_exist "$_DOWNLOADED_BUNDLES_DIR/foo_1-0-0.sh"
}

@test "only updates 'EXTEND' variable in bundle" {
  _mock_fetch_releases 'foo-bundle@2.0.0'
  test::mock_download '# mock bundle'

  local initial_bundle
  initial_bundle="$(test::dedent "
    # My bundle

    EXTEND=foo-bundle@1.0.0

    function foo() {
      echo 'EXTEND=foo-bundle@1.0.0'
    }
  ")"
  local want_bundle
  want_bundle="$(test::dedent "
    # My bundle

    EXTEND=foo-bundle@2.0.0

    function foo() {
      echo 'EXTEND=foo-bundle@1.0.0'
    }
  ")"

  test::put "$initial_bundle" "$TEST_APP_REPO/bundles/foo.sh"

  run tildepot repo update -y
  assert_success
  assert_equal "$(cat "$TEST_APP_REPO/bundles/foo.sh")" "$want_bundle"
}
@test "updates 'EXTEND' variable with single quotes" {
  _mock_fetch_releases 'foo-bundle@2.0.0'
  test::mock_download '# mock bundle'

  local initial_bundle="EXTEND='foo-bundle@1.0.0'"
  local want_bundle='EXTEND=foo-bundle@2.0.0'
  test::put "$initial_bundle" "$TEST_APP_REPO/bundles/foo.sh"

  run tildepot repo update -y
  assert_success
  assert_equal "$(cat "$TEST_APP_REPO/bundles/foo.sh")" "$want_bundle"
}
@test "updates 'EXTEND' variable with double quotes" {
  _mock_fetch_releases 'foo-bundle@2.0.0'
  test::mock_download '# mock bundle'

  local initial_bundle='EXTEND="foo-bundle@1.0.0"'
  local want_bundle='EXTEND=foo-bundle@2.0.0'
  test::put "$initial_bundle" "$TEST_APP_REPO/bundles/foo.sh"

  run tildepot repo update -y
  assert_success
  assert_equal "$(cat "$TEST_APP_REPO/bundles/foo.sh")" "$want_bundle"
}
@test "updates 'EXTEND' variable with spaces" {
  _mock_fetch_releases 'foo-bundle@2.0.0'
  test::mock_download '# mock bundle'

  local initial_bundle='  EXTEND=foo-bundle@1.0.0  '
  local want_bundle='EXTEND=foo-bundle@2.0.0'
  test::put "$initial_bundle" "$TEST_APP_REPO/bundles/foo.sh"

  run tildepot repo update -y
  assert_success
  assert_equal "$(cat "$TEST_APP_REPO/bundles/foo.sh")" "$want_bundle"
}
@test "updates 'EXTEND' variable with tabs" {
  _mock_fetch_releases 'foo-bundle@2.0.0'
  test::mock_download '# mock bundle'

  local initial_bundle=$'\t''EXTEND=foo-bundle@1.0.0'$'\t'
  local want_bundle='EXTEND=foo-bundle@2.0.0'
  test::put "$initial_bundle" "$TEST_APP_REPO/bundles/foo.sh"

  run tildepot repo update -y
  assert_success
  assert_equal "$(cat "$TEST_APP_REPO/bundles/foo.sh")" "$want_bundle"
}

# TODO: skips same-version release

# TODO: resolves duplicate releases

# TODO: follows local parent
