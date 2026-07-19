#!/usr/bin/env bats
#
# Tests for `tildepot repo add`

setup() {
	load ../test_lib.sh
	load ./tildepot_repo_lib.sh

	mkdir -p "$TEST_APP_REPO"

	_DOWNLOADED_BUNDLES_DIR="$TEST_APP_REPO/.tildepot/bundles"
}

teardown() {
	test::mock_download_teardown
}

@test "creates a custom bundle given a custom name" {
	local want_bundle="$TEST_APP_REPO/bundles/my-bundle.sh"

	run tildepot repo add my-bundle
	assert_success
	assert_file_exists "$want_bundle"

	test::it 'has file header'
	test::assert_file_line "$want_bundle" '#!/usr/bin/env bash'
	test::assert_file_line "$want_bundle" '#'
	test::assert_file_line "$want_bundle" '# Custom "my-bundle" bundle.'

	test::it 'prints log messages'
	assert_line --partial 'Creating bundle my-bundle at bundles/my-bundle.sh'
	assert_line --partial 'Bundle created'
}

@test "aborts when repo directory does not exist" {
	rm -rf "$TEST_APP_REPO"

	run tildepot repo add
	assert_failure
	assert_output --partial 'Directory does not exist'
}

@test "fails when local bundle already exists" {
	test::put "$TEST_APP_REPO/bundles/my-bundle.sh"

	run tildepot repo add my-bundle
	assert_failure
	assert_output --partial "Bundle my-bundle already exists at bundles/my-bundle.sh"
	assert_file_exists "$TEST_APP_REPO/bundles/my-bundle.sh"
}

@test "accepts dot in bundle name" {
	run tildepot repo add 00.my-bundle
	assert_success
	assert_file_exists "$TEST_APP_REPO/bundles/00.my-bundle.sh"
}

@test "rejects other special characters in bundle name" {
	run tildepot repo add my/bundle
	assert_failure
	assert_output --partial "Invalid bundle name"
	assert_file_not_exists "$TEST_APP_REPO/bundles/my/bundle.sh"
}

###
# Extending an official bundle
###

@test "creates a custom bundle extending an official bundle" {
	test_repo::mock_fetch_releases 'official-bundle@1.0.0'
	test::mock_download --fixture mock_bundle.sh

	local want_bundle="$TEST_APP_REPO/bundles/my-bundle.sh"
	local want_parent_bundle="$TEST_APP_REPO/.tildepot/bundles/official_1-0-0.sh"

	run tildepot repo add --extend official my-bundle -y
	assert_success
	assert_file_exists "$want_bundle"

	test::it 'has file header'
	test::assert_file_line "$want_bundle" '#!/usr/bin/env bash'
	test::refute_file_line "$want_bundle" '# Custom "my-bundle" bundle.'

	test::it 'lists extended bundle'
	test::assert_file_line "$want_bundle" "export EXTEND='official-bundle@1.0.0'"

	test::it 'downloaded parent bundle'
	test::assert_mock_download_url official-bundle
	assert_files_equal "$want_parent_bundle" "$(test::fixture_path mock_bundle.sh)"
}

@test "accepts '-bundle' suffix for official bundle name" {
	test_repo::mock_fetch_releases 'official-bundle@1.0.0'
	test::mock_download '# mock bundle'

	local want_bundle="$TEST_APP_REPO/bundles/my-bundle.sh"

	run tildepot repo add --extend official-bundle my-bundle -y
	assert_success
	assert_file_exists "$want_bundle"

	test::assert_file_line "$want_bundle" "export EXTEND='official-bundle@1.0.0'"
}

@test "fails when extending an unknown official bundle" {
	test_repo::mock_fetch_releases 'official-bundle@1.0.0'

	run tildepot repo add --extend invalid my-bundle
	assert_failure
	assert_output --partial 'Unknown official bundle: invalid'
	assert_file_not_exists "$TEST_APP_REPO/bundles/my-bundle.sh"
}
@test "fails when extending an incomplete official bundle name" {
	test_repo::mock_fetch_releases 'foo-bar-bundle@1.0.0'

	run tildepot repo add --extend foo my-bundle
	assert_failure
	assert_output --partial 'Unknown official bundle: foo'
	assert_file_not_exists "$TEST_APP_REPO/bundles/my-bundle.sh"
}

@test "does not load remote bundles when creating a custom bundle" {
	test_repo::mock_fetch_releases 'official-bundle@1.0.0'
	test::mock_download '# mock bundle'

	run tildepot repo add my-bundle
	assert_success
	test::refute_mock_download_url
}

@test "aborts when fetching remote bundles failed" {
	test::mock_download --error

	run tildepot repo add --extend official my-bundle
	assert_failure
	assert_output --partial 'Failed to fetch latest releases.'
	refute_output --partial 'Unknown official bundle'
}

@test "inherits bundle name from parent bundle" {
	test_repo::mock_fetch_releases 'foobar-bundle@1.0.0'
	test::mock_download '# mock bundle'

	local want_bundle="$TEST_APP_REPO/bundles/foobar.sh"

	run tildepot repo add --extend foobar -y
	assert_success
	assert_file_exists "$want_bundle"
}
@test "inherits bundle name from parent bundle and drops '-bundle' suffix" {
	test_repo::mock_fetch_releases 'foobar-bundle@1.0.0'
	test::mock_download '# mock bundle'

	local want_bundle="$TEST_APP_REPO/bundles/foobar.sh"

	run tildepot repo add --extend foobar-bundle -y
	assert_success
	assert_file_exists "$want_bundle"
}

@test "skips downloading parent bundle when it already exists" {
	test_repo::mock_fetch_releases 'official-bundle@1.0.0'

	local parent_bundle="$TEST_APP_REPO/.tildepot/bundles/official_1-0-0.sh"
	test::put "$parent_bundle"

	run tildepot repo add --extend official
	assert_success

	test::refute_mock_download_url official-bundle
}

###
# Prompts
###

@test "prompts through creating custom bundle" {
	test_repo::mock_fetch_releases
	local want_bundle="$TEST_APP_REPO/bundles/my-bundle.sh"

	run test::expect_prompt \
		--qa 'Skeleton' '' \
		--qa 'Bundle name' my-bundle \
		tildepot repo add
	assert_success
	assert_file_exists "$want_bundle"
	assert_file_not_contains "$want_bundle" "EXTEND="
}

@test "prompts through forking official bundle" {
	test_repo::mock_fetch_releases 'foo-bundle@1.0.0'

	local want_bundle="$TEST_APP_REPO/bundles/bar.sh"

	run test::expect_prompt \
		--qa 'foo-bundle' 'f' \
		--qa 'Bundle name' bar \
		--yn 'Download' n \
		tildepot repo add
	assert_success
	assert_file_exists "$want_bundle"
	test::assert_file_line "$want_bundle" "export EXTEND='foo-bundle@1.0.0'"

	test::it 'did not download parent bundle when "no" was selected'
	test::refute_mock_download_url foo-bundle
	assert_file_not_exists "$TEST_APP_REPO/.tildepot/bundles/foo_1-0-0.sh"
}

@test "supports downloading parent bundle" {
	test_repo::mock_fetch_releases 'foo-bundle@1.0.0'
	test::mock_download --fixture mock_bundle.sh
	local want_parent_bundle="$TEST_APP_REPO/.tildepot/bundles/foo_1-0-0.sh"
	local want_bundle="$TEST_APP_REPO/bundles/bar.sh"

	run test::expect_prompt \
		--qa 'foo-bundle' 'f' \
		--qa 'Bundle name' bar \
		--yn 'Download' y \
		tildepot repo add
	assert_success
	test::assert_mock_download_url foo-bundle
	assert_files_equal "$want_parent_bundle" "$(test::fixture_path mock_bundle.sh)"
}

@test "defaults extended name to parent bundle name" {
	test_repo::mock_fetch_releases 'foo-bundle@1.0.0'

	run test::expect_prompt \
		--qa 'foo-bundle' 'f' \
		--qa 'Bundle name: (foo)' '' \
		--yn 'Download' n \
		tildepot repo add
	assert_success
	assert_file_exists "$TEST_APP_REPO/bundles/foo.sh"
}

@test "lists available official bundles" {
	test_repo::mock_fetch_releases 'aa-bundle@1.0.0' 'bb-bundle@1.0.0'

	run test::expect_prompt \
		--ln 'aa-bundle@1.0.0' \
		--qa 'bb-bundle@1.0.0' 'b' \
		--qa 'Bundle name' '' \
		--yn 'Download' n \
		tildepot repo add
	assert_success
	assert_file_exists "$TEST_APP_REPO/bundles/bb.sh"
}
@test "only lists latest bundle releases" {
	test_repo::mock_fetch_releases \
		'foo-bundle@1.0.0' \
		'foo-bundle@1.0.11' \
		'foo-bundle@1.0.2' \
		'bar-bundle@1.0.0-next.1' \
		'bar-bundle@1.0.0'

	run test::expect_prompt \
		--qa 'foo-bundle@1.0.11' 'f' \
		--qa 'Bundle name' '' \
		--yn 'Download' n \
		tildepot repo add
	assert_success
	refute_line --regexp 'foo-bundle@1\.0\.0$'
	assert_line --regexp 'foo-bundle@1\.0\.11$'
	refute_line --regexp 'foo-bundle@1\.0\.2$'
	assert_line --regexp 'bar-bundle@1\.0\.0-next.1$'
	refute_line --regexp 'bar-bundle@1\.0\.0$'
	assert_file_exists "$TEST_APP_REPO/bundles/foo.sh"
}
@test "omits non-bundle releases" {
	test_repo::mock_fetch_releases \
		'legacy@1.0.0' \
		'actual-bundle@1.0.0' \
		'1.2.3' \
		'v4.5.6'

	run test::expect_prompt \
		--qa 'actual-bundle@1.0.0' 'a' \
		--qa 'Bundle name' '' \
		--yn 'Download' n \
		tildepot repo add
	assert_success
	refute_line --regexp 'legacy@1\.0\.0$'
	assert_line --regexp 'actual-bundle@1\.0\.0$'
	refute_line --regexp '1\.2\.3$'
	refute_line --regexp 'v4\.5\.6$'
	assert_file_exists "$TEST_APP_REPO/bundles/actual.sh"
}
@test "sorts official bundles alphabetically" {
	test_repo::mock_fetch_releases 'foo-bundle@1.0.0' 'zz-bundle@1.0.0' 'aa-bundle@1.0.0' 'bar-bundle@1.0.0'

	run test::expect_prompt \
		--ln 'aa-bundle' \
		--ln 'bar-bundle' \
		--ln 'foo-bundle' \
		--ln 'zz-bundle' \
		--cancel \
		tildepot repo add
}

@test "allows picking option by arrow keys" {
	test_repo::mock_fetch_releases 'aa-bundle@1.0.0' 'bb-bundle@1.0.0' 'cc-bundle@1.0.0'

	run test::expect_prompt \
		--in '<down><down><return>' \
		--qa 'Bundle name' 'test' \
		--yn 'Download' n \
		tildepot repo add
	assert_success
	assert_file_contains "$TEST_APP_REPO/bundles/test.sh" "EXTEND='bb-bundle@1.0.0'"
}
@test "allows picking option by index number" {
	test_repo::mock_fetch_releases 'aa-bundle@1.0.0' 'bb-bundle@1.0.0' 'cc-bundle@1.0.0'

	run test::expect_prompt \
		--in '3<return>' \
		--qa 'Bundle name' 'test' \
		--yn 'Download' n \
		tildepot repo add
	assert_success
	assert_file_contains "$TEST_APP_REPO/bundles/test.sh" "EXTEND='cc-bundle@1.0.0'"
}
@test "allows picking option by letter" {
	test_repo::mock_fetch_releases 'aa-bundle@1.0.0' 'bb-bundle@1.0.0' 'cc-bundle@1.0.0'

	run test::expect_prompt \
		--in 'a<return>' \
		--qa 'Bundle name' 'test' \
		--yn 'Download' n \
		tildepot repo add
	assert_success
	assert_file_contains "$TEST_APP_REPO/bundles/test.sh" "EXTEND='aa-bundle@1.0.0'"
}

@test "requires a bundle name during prompt" {
	test_repo::mock_fetch_releases

	run test::expect_prompt \
		--qa 'Skeleton' '' \
		--qa 'Bundle name' '' \
		tildepot repo add
	assert_failure
	assert_output --partial "Invalid bundle name"
}
@test "rejects special characters in bundle name prompt" {
	test_repo::mock_fetch_releases

	run test::expect_prompt \
		--qa 'Skeleton' '' \
		--qa 'Bundle name' 'my/bundle' \
		tildepot repo add
	assert_failure
	assert_output --partial "Invalid bundle name"
	assert_file_not_exists "$TEST_APP_REPO/bundles/my/bundle.sh"
}

# TODO: prompt separates & lists unused bundles before already used bundles

# TODO: flesh out skeleton content for custom bundle option
