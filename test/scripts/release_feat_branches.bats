#!/usr/bin/env bats
#
# Tests for `release` script (branches)

setup() {
	load release_lib.sh
}

teardown() {
	test::release_lib_teardown
}

@test "releases full version on full-release branch" {
	test::extend_cfg '{"branches": {"full": ["my-branch"]}}'
	git checkout -b 'my-branch' --quiet
	test::git_commit -m "feat(foo): my title!"

	run release
	assert_success
	assert_line "current branch: my-branch"
	assert_line "release type: full"
	assert_line "(foo) new version: 1.0.0"
}

@test "releases next version on pre-release branch" {
	test::extend_cfg '{"branches": {"prerelease": ["my-branch"]}}'
	git checkout -b 'my-branch' --quiet
	test::git_commit -m "feat(foo): my title!"

	run release
	assert_success
	assert_line "current branch: my-branch"
	assert_line "release type: next"
	assert_line "(foo) new version: 1.0.0-next.1"
}

@test "aborts on non-release branch" {
	git checkout -b 'my-branch' --quiet
	test::git_commit -m "feat(foo): my title!"

	run release
	assert_failure
	refute_line --partial "release type:"
	refute_line --partial "(foo) new version"
	assert_line --partial "my-branch is not a release branch"
}
