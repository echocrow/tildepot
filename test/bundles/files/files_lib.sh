#!/usr/bin/env bash
#
# Bats helpers for tildepot files-bundle tests

# Setup
# Set up files bundle.
mkdir "$TEST_APP_REPO"
mkdir "$TEST_APP_REPO/bundles"
export TEST_FILES_STATE="$TEST_APP_REPO/state/files"
# Set up home mock source dir.
export TEST_HOME_MOCK="$BATS_TEST_TMPDIR/mock"
mkdir "$TEST_HOME_MOCK"
# Set up temp dir as home.
_TEST_PREV_HOME="$HOME"
export HOME="$BATS_TEST_TMPDIR/home"
mkdir "$HOME"
# Set up state target dir.
export TEST_FILES_TARGET="$BATS_TEST_TMPDIR/state-target"
mkdir "$TEST_FILES_TARGET"

_TEST_FILES_BUNDLE_PATH="$TEST_APP_REPO/bundles/files.sh"

function test_files::teardown() {
	unset HOME
}

function test_files::reset_home() {
	test::cp "$TEST_HOME_MOCK" "$HOME"
}
function test_files::clear_home() {
	rm -rf "$HOME"
	mkdir "$HOME"
}

function test_files::mock_setup() {
	local files_cfg=${1?}

	test::mock_bundle \
		'files' \
		"$_TEST_FILES_BUNDLE_PATH" \
		"
			export EXTEND='$BATS_CWD/bundles/files.sh'

			export FILES='$files_cfg'
		"
}
function test_files::extend_mock_bundle() {
	local content="${1?}"

	echo "$content" >>"$_TEST_FILES_BUNDLE_PATH"
}

function test_files::run_assert_save() {
	run tildepot save files
	assert_success
	test::assert_dirs_equal "$TEST_FILES_STATE" "$TEST_FILES_TARGET"
}
function test_files::run_assert_restore() {
	while [[ $# -gt 0 ]]; do
		case $1 in
		--clean) test_files::clear_home ;;
		*) lib::abort "Unknown argument: $1" ;;
		esac
		shift
	done

	run tildepot restore files -y
	assert_success
	test::assert_dirs_equal "$HOME" "$TEST_HOME_MOCK"
}

function test_files::assert_invalid_config() {
	local msg="$1"

	test::it 'aborts on save'
	run tildepot save files
	assert_failure
	assert_line --partial "Invalid config"
	assert_line --partial "$msg"

	test::it 'aborts on restore'
	run tildepot restore files -y
	assert_failure
	assert_line --partial "Invalid config"
	assert_line --partial "$msg"
}
