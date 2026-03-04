#!/usr/bin/env bats
#
# Tests for `release` script (version tags)

setup() {
	load release_lib.sh
}

teardown() {
	test::release_lib_teardown
}

@test "picks recent version from tag" {
	test::git_commit -m "feat(foo): old feature 0"
	test::git_commit -m "feat(foo): old feature 1"
	git tag -a 'foo@2.2.2' -m ''
	test::git_commit -m "feat(foo): new feature 0"

	run release
	assert_success
	assert_line "(foo) curr version: 2.2.2"
	assert_line "(foo) curr full version: 2.2.2"
	assert_line "(foo) new version: 2.3.0"
}

@test "picks recent prerelease version on prerelease" {
	git checkout -b 'next' --quiet
	test::git_commit -m "feat(foo): old feature 0"
	git tag -a 'foo@2.2.2' -m ''
	test::git_commit -m "feat(foo): old feature 1"
	git tag -a 'foo@2.3.0-next.4' -m ''
	test::git_commit -m "feat(foo): new feature 0"

	run release
	assert_success
	assert_line "(foo) curr version: 2.3.0-next.4"
	assert_line "(foo) new version: 2.3.0-next.5"
}
@test "picks recent prerelease & full version on full release" {
	test::git_commit -m "feat(foo): old feature 0"
	git tag -a 'foo@2.2.2' -m ''
	test::git_commit -m "feat(foo): old feature 1"
	git tag -a 'foo@2.3.0-next.4' -m ''
	test::git_commit -m "feat(foo): new feature 0"

	run release
	assert_success
	assert_line "(foo) curr version: 2.3.0-next.4"
	assert_line "(foo) curr full version: 2.2.2"
	assert_line "(foo) new version: 2.3.0"
}

@test "picks the highest (presumed most recent) tag (non-alphabetical)" {
	test::git_commit -m "feat(foo): old feature 0"
	git tag -a 'foo@9.9.9' -m ''
	test::git_commit -m "feat(foo): old feature 1"
	git tag -a 'foo@10.0.0' -m ''
	test::git_commit -m "feat(foo): new feature 0"

	run release
	assert_success
	assert_line "(foo) curr version: 10.0.0"
	assert_line "(foo) curr full version: 10.0.0"
}

@test "picks recent same-commit prerelease & full version on full release" {
	test::git_commit -m "feat(foo): old feature 0"
	git tag -a 'foo@2.3.0-next.4' -m ''
	git tag -a 'foo@2.3.0' -m ''
	test::git_commit -m "feat(foo): new feature 0"

	run release
	assert_success
	assert_line "(foo) curr version: 2.3.0"
	assert_line "(foo) new version: 2.4.0"
}

@test "ignores commits before last full release tag" {
	local shas=()
	shas+=("$(test::git_commit_print -m "feat(foo): commit 0")")
	shas+=("$(test::git_commit_print -m "feat(foo): commit 1")")
	git tag -a 'foo@1.0.0' -m ''
	shas+=("$(test::git_commit_print -m "feat(foo): commit 2")")
	git tag -a 'foo@1.0.1-next.1' -m ''
	shas+=("$(test::git_commit_print -m "feat(foo): commit 3")")
	shas+=("$(test::git_commit_print -m "feat(foo): commit 4")")

	run release
	assert_success
	refute_line --partial "${shas[0]}:"
	refute_line --partial "${shas[1]}:"
	assert_line --partial "(foo) ${shas[3]}:"
	assert_line --partial "(foo) ${shas[4]}:"
}

@test "ignores commits before last full release tag per package scope" {
	test::extend_cfg '{
		"packages": [{"name": "aa"}, {"name": "bb"}, {"name": "cc"}, {"name": "dd"}]
	}'

	local aa_shas=()
	local bb_shas=()
	local cc_shas=()
	local dd_shas=()
	aa_shas+=("$(test::git_commit_print -m "feat(aa): commit")")
	aa_shas+=("$(test::git_commit_print -m "feat(aa): commit")")
	git tag -a 'aa@1.0.0' -m ''
	aa_shas+=("$(test::git_commit_print -m "feat(aa): commit")")

	cc_shas+=("$(test::git_commit_print -m "feat(cc): commit")")
	git tag -a 'cc@1.0.0' -m ''
	cc_shas+=("$(test::git_commit_print -m "feat(cc): commit")")
	cc_shas+=("$(test::git_commit_print -m "feat(cc): commit")")

	bb_shas+=("$(test::git_commit_print -m "feat(bb): commit")")
	bb_shas+=("$(test::git_commit_print -m "feat(bb): commit")")
	git tag -a 'bb@1.0.0' -m ''

	dd_shas+=("$(test::git_commit_print -m "feat(dd): commit")")
	aa_shas+=("$(test::git_commit_print -m "feat(aa): commit")")
	aa_shas+=("$(test::git_commit_print -m "feat(aa): commit")")

	run release
	assert_success

	refute_line --partial "(aa) ${aa_shas[0]}:"
	refute_line --partial "(aa) ${aa_shas[1]}:"
	assert_line --partial "(aa) ${aa_shas[2]}:"
	assert_line --partial "(aa) ${aa_shas[3]}:"
	assert_line --partial "(aa) ${aa_shas[4]}:"

	refute_line --partial "(bb) ${bb_shas[0]}:"
	refute_line --partial "(bb) ${bb_shas[1]}:"

	refute_line --partial "(cc) ${cc_shas[0]}:"
	assert_line --partial "(cc) ${cc_shas[1]}:"
	assert_line --partial "(cc) ${cc_shas[2]}:"

	assert_line --partial "(dd) ${dd_shas[0]}:"
}

@test "handles prerelease-only version tags" {
	test::git_commit -m "feat(foo): feat 0"
	git tag -a 'foo@1.0.0-next.1' -m ''
	test::git_commit -m "feat(foo): feat 1"
	git tag -a 'foo@1.0.0-next.2' -m ''
	test::git_commit -m "feat(foo): feat 2"

	run release
	assert_success
	assert_line "(foo) curr version: 1.0.0-next.2"
	assert_line "(foo) curr full version: -"
	test::it "releases 1.0.0 after prerelease-only tags"
	assert_line "(foo) new version: 1.0.0"
}
