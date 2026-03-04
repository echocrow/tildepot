#!/usr/bin/env bats
#
# Tests for `release` script (commit scopes)

setup() {
	load release_lib.sh
}

teardown() {
	test::release_lib_teardown
}

@test "bumps the right package based on commit scope" {
	test::extend_cfg '{
		"packages": [{"name": "aa"}, {"name": "bb"}, {"name": "cc"}, {"name": "dd"}]
	}'

	test::git_commit -m "feat(aa): my title"
	test::git_commit -m "feat(cc)!: my title"
	test::git_commit -m "fix(dd): my title"

	run release
	assert_success
	assert_line --partial "feat @ aa bumps minor"
	assert_line --partial "feat @ cc bumps major"
	assert_line --partial "fix @ dd bumps patch"

	assert_line "(aa) package bump: minor"
	assert_line "(bb) skipping package"
	assert_line "(cc) package bump: major"
	assert_line "(dd) package bump: patch"
}

@test "filters commits with custom 'scope'" {
	test::extend_cfg '{
		"packages": [{"name": "foo", "scope": "bar"}]
	}'

	test::git_commit -m "feat(foo): my title"
	test::git_commit -m "fix(bar): my title"

	run release
	assert_success
	refute_line --partial "feat @ foo"
	assert_line --partial "fix @ bar bumps"
	assert_line "(foo) package bump: patch"
}
@test "filters commits with 'scope' with wildcard" {
	test::extend_cfg '{
		"packages": [{"name": "foo", "scope": "fizz.*"}]
	}'

	test::git_commit -m "fix(foo): my title"
	test::git_commit -m "fix(fizz): my title"
	test::git_commit -m "fix(fizz-buzz): my title"
	test::git_commit -m "fix(buzz-fizz): my title"

	run release
	assert_success
	refute_line --partial "feat @ foo"
	assert_line --partial "fix @ fizz bumps"
	assert_line --partial "fix @ fizz-buzz bumps"
	refute_line --partial "feat @ buzz-fizz"
}
@test "filters commits with 'scope' with wildcard & negative match" {
	test::extend_cfg '{
		"packages": [{"name": "foo", "scope": "!.*-san"}]
	}'

	test::git_commit -m "fix(foo): my title"
	test::git_commit -m "fix(foo-san): my title"
	test::git_commit -m "fix(san-serif): my title"
	test::git_commit -m "fix(fizz-san-buzz): my title"

	run release
	assert_success
	assert_line --partial "fix @ foo bumps"
	refute_line --partial "fix @ foo-san"
	assert_line --partial "fix @ san-serif bumps"
	assert_line --partial "fix @ fizz-san-buzz"
}
@test "filters commits with 'scope' with multiple matches" {
	test::extend_cfg '{
		"packages": [{"name": "foo", "scope": "foo|bar"}]
	}'

	test::git_commit -m "fix(foo): msg"
	test::git_commit -m "fix(fizz): msg"
	test::git_commit -m "fix(foobar): msg"
	test::git_commit -m "fix(bar): msg"
	test::git_commit -m "fix(baz): msg"

	run release
	assert_success
	assert_line --partial "fix @ foo bumps"
	refute_line --partial "fix @ fizz"
	refute_line --partial "fix @ foobar"
	assert_line --partial "fix @ bar bumps"
	refute_line --partial "fix @ baz"
}

@test "skips when negative scope filter matches no commits" {
	test::extend_cfg '{
		"packages": [{"name": "foo", "scope": "!.*-foo"}]
	}'

	test::git_commit -m "fix(foo-foo): commit"
	test::git_commit -m "fix(foo-foo): commit"
	test::git_commit -m "fix(foo-foo): commit"

	run release
	assert_success
	refute_line --partial "fix @ foo-foo bumps"
	assert_line "(foo) package bump: -"
	assert_line "(foo) new version: -"
	assert_line "(foo) skipping package"
	assert_dir_not_exists "$TEST_RELEASE_DIST_DIR"
}
