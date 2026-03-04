#!/usr/bin/env bats
#
# Tests for `release` script (assets)

setup() {
	load release_lib.sh
}

teardown() {
	test::release_lib_teardown
}

@test "does not copy assets by default" {
	test::git_commit -m "feat(foo): my commit"

	run release
	assert_success
	assert_dir_not_exists "$TEST_RELEASE_DIST_DIR/foo/assets"

	test::it 'does not complain about missing assets'
	refute_line --partial "jq: error"
}

@test "does not copy assets on non-release" {
	test::extend_cfg '.packages[0].assets' '["my_asset.txt"]'
	echo "hello world" >"$PWD/my_asset.txt"

	test::git_commit -m "feat(foo): my commit"
	git tag -a 'foo@1.0.0' -m ''

	run release
	assert_success
	assert_dir_not_exists "$TEST_RELEASE_DIST_DIR/foo/assets"
}

@test "copies assets on release relative to root dir" {
	test::extend_cfg '.packages[0].assets' '["my_asset.txt"]'
	echo "txt" >"$PWD/my_asset.txt"
	echo "txt" >"$PWD/my_other_asset.txt"

	test::git_commit -m "feat(foo): my commit"

	run release
	assert_success
	test::assert_dir_files -d 5 "$TEST_RELEASE_DIST_DIR" \
		"foo/assets/my_asset.txt" \
		"foo/CHANGELOG.md"
	assert_files_equal "$TEST_RELEASE_DIST_DIR/foo/assets/my_asset.txt" "$PWD/my_asset.txt"
}

@test "copies assets dir on release" {
	test::extend_cfg '.packages[0].assets' '["fizz"]'
	mkdir "$PWD/fizz"
	echo "aa" >"$PWD/fizz/aa.txt"
	echo "bb" >"$PWD/fizz/bb.txt"

	test::git_commit -m "feat(foo): my commit"

	run release
	assert_success
	test::assert_dir_files -d 5 "$TEST_RELEASE_DIST_DIR" \
		"foo/assets/fizz/aa.txt" \
		"foo/assets/fizz/bb.txt" \
		"foo/CHANGELOG.md"
	assert_files_equal "$TEST_RELEASE_DIST_DIR/foo/assets/fizz/aa.txt" "$PWD/fizz/aa.txt"
	assert_files_equal "$TEST_RELEASE_DIST_DIR/foo/assets/fizz/bb.txt" "$PWD/fizz/bb.txt"
}

@test "copies nested file on release" {
	test::extend_cfg '.packages[0].assets' '["fizz/aa.txt"]'
	mkdir "$PWD/fizz"
	echo "aa" >"$PWD/fizz/aa.txt"
	echo "bb" >"$PWD/fizz/bb.txt"

	test::git_commit -m "feat(foo): my commit"

	run release
	assert_success
	test::assert_dir_files -d 5 "$TEST_RELEASE_DIST_DIR" \
		"foo/assets/aa.txt" \
		"foo/CHANGELOG.md"
	assert_files_equal "$TEST_RELEASE_DIST_DIR/foo/assets/aa.txt" "$PWD/fizz/aa.txt"
}

@test "copies multiple files & dirs on release" {
	test::extend_cfg '.packages[0].assets' '["fizz/buzz", "foo/bar.txt"]'
	mkdir -p "$PWD/fizz/buzz"
	mkdir -p "$PWD/foo/bar"
	echo "aa" >"$PWD/fizz/aa.txt"
	echo "bb" >"$PWD/fizz/buzz/bb.txt"
	echo "cc" >"$PWD/fizz/buzz/cc.txt"
	echo "bar" >"$PWD/foo/bar.txt"
	echo "buzz" >"$PWD/foo/buzz.txt"

	test::git_commit -m "feat(foo): my commit"

	run release
	assert_success
	test::assert_dir_files -d 5 "$TEST_RELEASE_DIST_DIR" \
		"foo/assets/bar.txt" \
		"foo/assets/buzz/bb.txt" \
		"foo/assets/buzz/cc.txt" \
		"foo/CHANGELOG.md"
	assert_files_equal "$TEST_RELEASE_DIST_DIR/foo/assets/bar.txt" "$PWD/foo/bar.txt"
	assert_files_equal "$TEST_RELEASE_DIST_DIR/foo/assets/buzz/bb.txt" "$PWD/fizz/buzz/bb.txt"
	assert_files_equal "$TEST_RELEASE_DIST_DIR/foo/assets/buzz/cc.txt" "$PWD/fizz/buzz/cc.txt"
}

@test "copies the right file for the right package" {
	test::extend_cfg '.packages' '[
		{"name": "aa", "assets": ["txt/aa.txt"]},
		{"name": "bb", "assets": ["txt/bb.txt"]},
		{"name": "cc", "assets": ["txt/cc.txt"]}
	]'
	mkdir "$PWD/txt"
	echo "aa" >"$PWD/txt/aa.txt"
	echo "bb" >"$PWD/txt/bb.txt"
	echo "cc" >"$PWD/txt/cc.txt"

	test::git_commit -m "feat(aa): my commit"
	test::git_commit -m "feat(cc): my commit"

	run release
	assert_success
	test::assert_dir_files -d 5 "$TEST_RELEASE_DIST_DIR" \
		"aa/assets/aa.txt" \
		"aa/CHANGELOG.md" \
		"cc/assets/cc.txt" \
		"cc/CHANGELOG.md"
	assert_files_equal "$TEST_RELEASE_DIST_DIR/aa/assets/aa.txt" "$PWD/txt/aa.txt"
	assert_files_equal "$TEST_RELEASE_DIST_DIR/cc/assets/cc.txt" "$PWD/txt/cc.txt"
}

@test "aborts when an asset file does not exist" {
	test::extend_cfg '.packages[0].assets' '["my_asset.txt"]'

	test::git_commit -m "feat(foo): my commit"

	run release
	assert_failure
	assert_output --partial "Asset not found"
}
@test "aborts when a nested asset file does not exist" {
	test::extend_cfg '.packages[0].assets' '["foo/bar.txt"]'
	mkdir "$PWD/foo"

	test::git_commit -m "feat(foo): my commit"

	run release
	assert_failure
	assert_output --partial "Asset not found"
}
@test "aborts when an asset dir does not exist" {
	test::extend_cfg '.packages[0].assets' '["fizz/buzz"]'
	mkdir "$PWD/fizz"

	test::git_commit -m "feat(foo): my commit"

	run release
	assert_failure
	assert_output --partial "Asset not found"
}

@test "clears previous assets" {
	test::extend_cfg '.packages' '[
		{"name": "aa", "assets": ["txt/aa.txt"]},
		{"name": "bb", "assets": ["txt/bb.txt"]},
		{"name": "cc", "assets": ["txt/cc.txt"]}
	]'
	mkdir "$PWD/txt"
	echo "aa" >"$PWD/txt/aa.txt"
	echo "bb" >"$PWD/txt/bb.txt"
	echo "cc" >"$PWD/txt/cc.txt"

	test::git_commit -m "feat(aa): 01"
	test::git_commit -m "feat(bb): 01"

	run release
	test::it "outputs initial assets"
	assert_success
	test::assert_dir_files -d 5 "$TEST_RELEASE_DIST_DIR" \
		"aa/assets/aa.txt" \
		"aa/CHANGELOG.md" \
		"bb/assets/bb.txt" \
		"bb/CHANGELOG.md"

	git tag -a 'aa@1.0.0' -m ''
	git tag -a 'bb@1.0.0' -m ''
	test::git_commit -m "feat(aa): aa 02"
	test::git_commit -m "feat(cc): cc 01"

	run release
	test::it "cleared previous assets"
	assert_success
	test::assert_dir_files -d 5 "$TEST_RELEASE_DIST_DIR" \
		"aa/assets/aa.txt" \
		"aa/CHANGELOG.md" \
		"cc/assets/cc.txt" \
		"cc/CHANGELOG.md"
}
