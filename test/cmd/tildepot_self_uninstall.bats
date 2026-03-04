#!/usr/bin/env bats
#
# Tests for `tildepot self uninstall`

setup() {
	load ../test_lib.sh
	export _TEMP_APP_BIN="$BATS_TEST_TMPDIR/my_bins/tildepot"
	mkdir -p "$(dirname "$_TEMP_APP_BIN")"
	cp "$TEST_BIN" "$_TEMP_APP_BIN"
}

@test "uninstalls self" {
	run "$_TEMP_APP_BIN" self uninstall -y
	assert_success
	assert_file_not_exist "$_TEMP_APP_BIN"
	assert_exists "$TEST_BIN"
}
@test "uninstalls self from '--path'" {
	run tildepot self uninstall -y --path "$(dirname "$_TEMP_APP_BIN")"
	assert_success
	assert_file_not_exist "$_TEMP_APP_BIN"
	assert_exists "$TEST_BIN"
}
@test "prompts before uninstalling" {
	run test::expect_prompt \
		--yn 'Uninstall tildepot from' y \
		"$_TEMP_APP_BIN" self uninstall
	assert_success
	assert_file_not_exist "$_TEMP_APP_BIN"
	assert_exists "$TEST_BIN"
}

@test "errors when '--path' does not exist" {
	run tildepot self uninstall --path "$BATS_TEST_TMPDIR/does-not-exist"
	assert_failure
	assert_output --partial "does not exist"
}
@test "errors when '--path' does not contain tildepot" {
	rm "$_TEMP_APP_BIN"

	run tildepot self uninstall --path "$(dirname "$_TEMP_APP_BIN")"
	assert_failure
	assert_output --partial "not installed at"
}
