#!/usr/bin/env bats
#
# Tests for `tildepot` bundles: filtering via trailing `BUNDLE...` parameters
#
# These tests use the `save` hook as stand-in for all hook commands. The same
# tests are assumed to also pass for all other hook commands.

setup() {
	load ../../test_lib.sh
	load ./tildepot_run_lib.sh
}

@test "calls sole listed-bundle hook" {
	test::mock_hook foo save
	test::mock_hook bar save

	run tildepot run save foo
	assert_success
	test::assert_bundle_output --hook foo save
}

@test "calls multiple listed-bundle hooks" {
	test::mock_hook aaa save
	test::mock_hook bbb save
	test::mock_hook ccc save

	run tildepot run save aaa bbb
	assert_success
	test::assert_bundle_output --hook aaa save --hook bbb save
}

@test "calls multiple listed-bundle hooks in specified order" {
	test::mock_hook aaa save
	test::mock_hook bbb save
	test::mock_hook ccc save

	run tildepot run save bbb aaa ccc
	assert_success
	test::assert_bundle_output \
		--hook bbb save \
		--hook aaa save \
		--hook ccc save
}

@test "errors on invalid listed-bundle name" {
	test::mock_hook aaa save

	run tildepot run save missing
	assert_failure
	assert_output "Error: Bundle missing not found."
}

@test "does not invoke any bundles on invalid listed-bundle name" {
	test::mock_hook aaa save

	run tildepot run save aaa missing
	assert_failure
	assert_output "Error: Bundle missing not found."
}
