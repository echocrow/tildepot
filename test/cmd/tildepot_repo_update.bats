#!/usr/bin/env bats
#
# Tests for `tildepot repo update`

setup() {
	load ../test_lib.sh
	load ./tildepot_repo_lib.sh

	mkdir -p "$TEST_APP_REPO"

	_DOWNLOADED_BUNDLES_DIR="$TEST_APP_REPO/.tildepot/bundles"
}

teardown() {
	test::mock_download_teardown
}

function _run_assert_bundle_update() {
	local bundle_name="${1?}"
	local initial_version="${2?}"
	local want_version="${3?}"

	local initial_bundle="EXTEND=$bundle_name@$initial_version"
	local want_bundle="EXTEND=$bundle_name@$want_version"
	test::put "$initial_bundle" "$TEST_APP_REPO/bundles/$bundle_name.sh"

	run tildepot repo update -y
	assert_success

	assert_equal "$(cat "$TEST_APP_REPO/bundles/$bundle_name.sh")" "$want_bundle"
}

@test "succeeds when no remote bundles exist" {
	test_repo::mock_fetch_releases 'foo-bundle@1.0.0' 'bar-bundle@1.0.0'

	test::put 'EXTEND=baz-bundle@1.0.0' "$TEST_APP_REPO/bundles/baz.sh"
	test::put "$_DOWNLOADED_BUNDLES_DIR/baz_1-0-0.sh"

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
	test_repo::mock_fetch_releases 'foo-bundle@2.0.0'
	test::mock_download '# mock bundle'

	test::put 'EXTEND=foo-bundle@1.0.0' "$TEST_APP_REPO/bundles/foo.sh"
	test::put "$_DOWNLOADED_BUNDLES_DIR/foo_1-0-0.sh"

	run tildepot repo update -y
	assert_success
	assert_line 'Found 1 official bundle.'
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
	test_repo::mock_fetch_releases 'foo-bundle@2.0.0'
	test::mock_download '# mock bundle'

	local initial_bundle
	test::read initial_bundle <<-'EOF'
		# My bundle

		EXTEND=foo-bundle@1.0.0

		function foo() {
			echo 'EXTEND=foo-bundle@1.0.0'
		}
	EOF
	local want_bundle
	test::read want_bundle <<-'EOF'
		# My bundle

		EXTEND=foo-bundle@2.0.0

		function foo() {
			echo 'EXTEND=foo-bundle@1.0.0'
		}
	EOF

	test::put "$initial_bundle" "$TEST_APP_REPO/bundles/foo.sh"

	run tildepot repo update -y
	assert_success
	assert_equal "$(cat "$TEST_APP_REPO/bundles/foo.sh")" "$want_bundle"
}
@test "updates 'EXTEND' variable with single quotes" {
	test_repo::mock_fetch_releases 'foo-bundle@2.0.0'
	test::mock_download '# mock bundle'

	local initial_bundle="EXTEND='foo-bundle@1.0.0'"
	local want_bundle='EXTEND=foo-bundle@2.0.0'
	test::put "$initial_bundle" "$TEST_APP_REPO/bundles/foo.sh"

	run tildepot repo update -y
	assert_success
	assert_equal "$(cat "$TEST_APP_REPO/bundles/foo.sh")" "$want_bundle"
}
@test "updates 'EXTEND' variable with double quotes" {
	test_repo::mock_fetch_releases 'foo-bundle@2.0.0'
	test::mock_download '# mock bundle'

	local initial_bundle='EXTEND="foo-bundle@1.0.0"'
	local want_bundle='EXTEND=foo-bundle@2.0.0'
	test::put "$initial_bundle" "$TEST_APP_REPO/bundles/foo.sh"

	run tildepot repo update -y
	assert_success
	assert_equal "$(cat "$TEST_APP_REPO/bundles/foo.sh")" "$want_bundle"
}
@test "updates 'EXTEND' variable with spaces" {
	test_repo::mock_fetch_releases 'foo-bundle@2.0.0'
	test::mock_download '# mock bundle'

	local initial_bundle='  EXTEND=foo-bundle@1.0.0  '
	local want_bundle='EXTEND=foo-bundle@2.0.0'
	test::put "$initial_bundle" "$TEST_APP_REPO/bundles/foo.sh"

	run tildepot repo update -y
	assert_success
	assert_equal "$(cat "$TEST_APP_REPO/bundles/foo.sh")" "$want_bundle"
}
@test "updates 'EXTEND' variable with tabs" {
	test_repo::mock_fetch_releases 'foo-bundle@2.0.0'
	test::mock_download '# mock bundle'

	local initial_bundle=$'\t''EXTEND=foo-bundle@1.0.0'$'\t'
	local want_bundle='EXTEND=foo-bundle@2.0.0'
	test::put "$initial_bundle" "$TEST_APP_REPO/bundles/foo.sh"

	run tildepot repo update -y
	assert_success
	assert_equal "$(cat "$TEST_APP_REPO/bundles/foo.sh")" "$want_bundle"
}

@test "detects matching bundle release" {
	test_repo::mock_fetch_releases \
		'aaa-bundle@2.0.0' \
		'bbb-bundle@2.0.0' \
		'ccc-bundle@2.0.0'
	test::mock_download '# mock bundle'

	_run_assert_bundle_update 'bbb-bundle' '1.0.0' '2.0.0'
	assert_line 'Found 3 official bundles.'
}

@test "picks the latest bundle release" {
	test_repo::mock_fetch_releases \
		'foo-bundle@1.0.0' \
		'foo-bundle@3.0.0' \
		'foo-bundle@2.0.0'
	test::mock_download '# mock bundle'

	_run_assert_bundle_update 'foo-bundle' '0.0.0' '3.0.0'
	assert_line 'Found 1 official bundle.'
}

@test "picks the latest bundle release with multi-digit version numbers (major)" {
	test_repo::mock_fetch_releases \
		'foo-bundle@1.0.0' \
		'foo-bundle@2.0.0' \
		'foo-bundle@11.0.0' \
		'foo-bundle@3.0.0'
	test::mock_download '# mock bundle'

	_run_assert_bundle_update 'foo-bundle' '0.0.0' '11.0.0'
}
@test "picks the latest bundle release with multi-digit version numbers (minor)" {
	test_repo::mock_fetch_releases \
		'foo-bundle@2.0.9' \
		'foo-bundle@2.9.9' \
		'foo-bundle@1.888.0' \
		'foo-bundle@2.123.0' \
		'foo-bundle@1.999.0' \
		'foo-bundle@2.33.9' \
		'foo-bundle@2.8.0'
	test::mock_download '# mock bundle'

	_run_assert_bundle_update 'foo-bundle' '0.0.0' '2.123.0'
}
@test "picks the latest bundle release with multi-digit version numbers (patch)" {
	test_repo::mock_fetch_releases \
		'foo-bundle@2.3.0' \
		'foo-bundle@2.3.9' \
		'foo-bundle@2.1.888' \
		'foo-bundle@2.3.123' \
		'foo-bundle@2.1.999' \
		'foo-bundle@2.3.33' \
		'foo-bundle@2.3.8'
	test::mock_download '# mock bundle'

	_run_assert_bundle_update 'foo-bundle' '0.0.0' '2.3.123'
}
@test "picks the latest bundle release with multi-digit version numbers (pre-release)" {
	test_repo::mock_fetch_releases \
		'foo-bundle@1.2.3' \
		'foo-bundle@1.2.3-next.4' \
		'foo-bundle@1.2.3-next.14' \
		'foo-bundle@1.2.2-next.99'
	test::mock_download '# mock bundle'

	_run_assert_bundle_update 'foo-bundle' '0.0.0' '1.2.3-next.14'
}
@test "picks the latest bundle release with multi-digit version numbers (pre-release, preceded)" {
	test_repo::mock_fetch_releases \
		'foo-bundle@1.2.3-next.1' \
		'foo-bundle@1.2.3'
	test::mock_download '# mock bundle'

	_run_assert_bundle_update 'foo-bundle' '0.0.0' '1.2.3-next.1'
}

@test "skips same-version release" {
	test_repo::mock_fetch_releases 'foo-bundle@1.0.0'
	test::mock_download '# mock bundle (should not be downloaded)'

	_run_assert_bundle_update 'foo-bundle' '1.0.0' '1.0.0'
	assert_line 'Found 1 official bundle.'
	assert_line 'Nothing to update.'
	refute_line --partial "- Updated foo-bundle"
}

@test "follows local parents when scanning for bundle updates" {
	test_repo::mock_fetch_releases 'official-bundle@2.0.0'
	test::mock_download '# mock bundle'

	test::put 'EXTEND=../my-bundles/parent.sh' "$TEST_APP_REPO/bundles/child.sh"
	test::put 'EXTEND=official-bundle@1.0.0' "$TEST_APP_REPO/my-bundles/parent.sh"

	run tildepot repo update -y
	assert_success
	assert_line --partial "- Updated official-bundle"

	test::it "updates 'EXTEND' variable in parent bundle"
	test::assert_file_line "$TEST_APP_REPO/my-bundles/parent.sh" 'EXTEND=official-bundle@2.0.0'

	test::it 'leaves child bundle as-is'
	test::assert_file_line "$TEST_APP_REPO/bundles/child.sh" 'EXTEND=../my-bundles/parent.sh'
}

@test "prompts for confirmation before downloading bundle" {
	test_repo::mock_fetch_releases 'foo-bundle@2.0.0'
	test::mock_download '# mock bundle'

	local initial_bundle="EXTEND='foo-bundle@1.0.0'"
	local want_bundle='EXTEND=foo-bundle@2.0.0'
	test::put "$initial_bundle" "$TEST_APP_REPO/bundles/foo.sh"

	run test::expect_prompt \
		--ln "Found newer bundle foo-bundle@2.0.0 (current version: foo-bundle@1.0.0)" \
		--yn "Download and update" y \
		tildepot repo update
	assert_success
	assert_line --partial "- Updated foo-bundle"
}
@test "prompts for each bundle independently" {
	test_repo::mock_fetch_releases 'aaa-bundle@2.0.0' 'bbb-bundle@2.0.0' 'ccc-bundle@2.0.0'
	test::mock_download '# mock bundle'
	test::mock_download '# mock bundle'

	test::put "EXTEND='aaa-bundle@1.0.0'" "$TEST_APP_REPO/bundles/aaa.sh"
	test::put "EXTEND='bbb-bundle@1.0.0'" "$TEST_APP_REPO/bundles/bbb.sh"
	test::put "EXTEND='ccc-bundle@1.0.0'" "$TEST_APP_REPO/bundles/ccc.sh"

	run test::expect_prompt \
		--ln "aaa-bundle" \
		--yn "Download and update" y \
		--ln "bbb-bundle" \
		--yn "Download and update" n \
		--ln "ccc-bundle" \
		--yn "Download and update" y \
		tildepot repo update
	assert_success
	assert_line --partial "- Updated aaa-bundle"
	refute_line --partial "- Updated bbb-bundle"
	assert_line --partial "- Updated ccc-bundle"
}
