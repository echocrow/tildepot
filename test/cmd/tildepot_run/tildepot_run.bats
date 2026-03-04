#!/usr/bin/env bats
#
# Tests for `tildepot run`

setup() {
	load ../../test_lib.sh
}

function test::_assert_run_cmd_usage() {
	assert_line "tildepot run"
	assert_line "Usage: tildepot run [options] HOOK"
	assert_line "Options:"
	assert_line --partial -- '-b, --bundle BUNDLE[]'
	assert_line --partial -- '-f, --force'
}

@test "describes run command" {
	test::it "prints usage on '--help'"
	run tildepot run --help
	assert_success
	test::_assert_run_cmd_usage

	test::it "prints usage on '-h'"
	run tildepot run -h
	assert_success
	test::_assert_run_cmd_usage
}

@test "fails without a hook parameter" {
	run tildepot run
	assert_failure
	assert_line --partial "Error: Too few parameters"
	assert_line --partial "expected 1, got 0"
}
