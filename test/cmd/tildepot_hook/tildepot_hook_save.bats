#!/usr/bin/env bats
#
# Tests for `tildepot save`

setup() {
	load ../../test_lib.sh
	load ../tildepot_run/tildepot_run_lib.sh
	load ./tildepot_hook_test.sh

	test::setup_assert_hook_cmd save
}

@test "describes hook command" {
	test::assert_hook_cmd "describes hook command"
}

@test "fails without any bundle files" {
	test::assert_hook_cmd "fails without any bundle files"
}

@test "calls hook for all bundles" {
	test::assert_hook_cmd "calls hook for all bundles"
}

@test "calls hook for only for listed bundles" {
	test::assert_hook_cmd "calls hook for only for listed bundles"
}

@test "errors when hook errors" {
	test::assert_hook_cmd "errors when hook errors"
}

@test "calls hook when '--force' is set despite hook skip returning 0" {
	test::assert_hook_cmd "calls hook when '--force' is set despite hook skip returning 0"
}
