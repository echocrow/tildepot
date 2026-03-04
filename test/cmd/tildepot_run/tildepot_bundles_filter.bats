#!/usr/bin/env bats
#
# Tests for `tildepot` bundles: filtering via `--bundle`
#
# These tests use the `save` hook as stand-in for all hook commands. The same
# tests are assumed to also pass for all other hook commands.

setup() {
	load ../../test_lib.sh
	load ./tildepot_run_lib.sh
}

@test "calls sole '--bundle' hook" {
	test::mock_hook foo save
	test::mock_hook bar save

	run tildepot run save --bundle foo
	assert_success
	test::assert_bundle_output --hook foo save
}

@test "calls multiple '--bundle' hooks" {
	test::mock_hook aaa save
	test::mock_hook bbb save
	test::mock_hook ccc save

	run tildepot run save --bundle aaa --bundle bbb
	assert_success
	test::assert_bundle_output --hook aaa save --hook bbb save
}

@test "calls multiple '--bundle' hooks in specified order" {
	test::mock_hook aaa save
	test::mock_hook bbb save
	test::mock_hook ccc save

	run tildepot run save --bundle bbb --bundle aaa --bundle ccc
	assert_success
	test::assert_bundle_output \
		--hook bbb save \
		--hook aaa save \
		--hook ccc save
}

@test "errors on invalid '--bundle' name" {
	test::mock_hook aaa save

	run tildepot run save --bundle missing
	assert_failure
	assert_output "Error: Bundle missing not found."
}

@test "does not invoke any bundles on invalid '--bundle' name" {
	test::mock_hook aaa save

	run tildepot run save --bundle aaa --bundle missing
	assert_failure
	assert_output "Error: Bundle missing not found."
}
