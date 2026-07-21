#!/usr/bin/env bats
#
# Tests for `files-bundle` processing

setup() {
	load ../../test_lib.sh
	load ../../test_bundle_lib.sh
	load ./files_lib.sh
}

teardown() {
	test_files::teardown
}

@test "processes files during save & restore" {
	test_files::mock_setup "
		foo  ~/foo  @my-io
	"
	# shellcheck disable=SC2016
	test_files::extend_mock_bundle '
		function bundle::save::my-io() {
			echo "[TEST] SAVE $1"
			echo "fizz" >>"$1"
		}
		function bundle::restore::my-io() {
			echo "[TEST] RESTORE $1"
			sed "\$d" "$1" >"$1.tmp"
			mv "$1.tmp" "$1"
		}
	'

	test::put 'foo' "$TEST_HOME_MOCK/foo"
	test_files::reset_home
	cp "$HOME/foo" "$TEST_FILES_TARGET/foo"
	echo 'fizz' >>"$TEST_FILES_TARGET/foo"

	test::it 'saves & processes file'
	test_files::run_assert_save

	test::it 'does not alter original host file'
	assert_files_equal "$HOME/foo" "$TEST_HOME_MOCK/foo"
	test::it 'saves & processes file in private dir'
	assert_line "[TEST] SAVE $TEST_APP_REPO/.tildepot/state/files/foo"

	test::it 'restores & processes file'
	test_files::run_assert_restore --clean

	test::it 'does not alter original state file'
	assert_files_equal "$TEST_FILES_STATE/foo" "$TEST_FILES_TARGET/foo"
	test::it 'restores & processes file in private dir'
	assert_line "[TEST] RESTORE $TEST_APP_REPO/.tildepot/state/files/foo"
}

@test "processes grouped files during save & restore" {
	test_files::mock_setup "
		[aa]  @my-io
		foo  ~/foo
		bar  ~/bar
		[bb]
		baz  ~/baz
	"
	# shellcheck disable=SC2016
	test_files::extend_mock_bundle '
		function bundle::save::my-io() {
			echo "fizz" >>"$1"
		}
		function bundle::restore::my-io() {
			sed "\$d" "$1" >"$1.tmp"
			mv "$1.tmp" "$1"
		}
	'

	test::put 'foo' "$TEST_HOME_MOCK/foo"
	test::put 'bar' "$TEST_HOME_MOCK/bar"
	test::put 'baz' "$TEST_HOME_MOCK/baz"
	test_files::reset_home
	test::cp "$HOME/foo" "$TEST_FILES_TARGET/aa/foo"
	test::cp "$HOME/bar" "$TEST_FILES_TARGET/aa/bar"
	test::cp "$HOME/baz" "$TEST_FILES_TARGET/bb/baz"
	echo 'fizz' >>"$TEST_FILES_TARGET/aa/foo"
	echo 'fizz' >>"$TEST_FILES_TARGET/aa/bar"

	test::it 'saves & processes file'
	test_files::run_assert_save

	test::it 'restores & processes file'
	test_files::run_assert_restore --clean
}

@test "processes files with implicit group & item name during save & restore" {
	test_files::mock_setup "
		[group]  @explicit
		item     ~/my-file
	"
	# shellcheck disable=SC2016
	test_files::extend_mock_bundle '
		function _save() {
			local file="${1?}"
			local line="${2?}"
			echo "$line" >>"$file"
		}
		function _restore() {
			local file="${1?}"
			local line="${2?}"
			[[ $(tail -n 1 "$file") != "$line" ]] && return
			sed "\$d" "$file" >"$file.tmp"
			mv "$file.tmp" "$file"
		}

		function bundle::save::explicit() {
			_save "$1" "explicit"
		}
		function bundle::restore::explicit() {
			_restore "$1" "explicit"
		}

		function bundle::save::group() {
			_save "$1" "group"
		}
		function bundle::restore::group() {
			_restore "$1" "group"
		}

		function bundle::save::group/item() {
			_save "$1" "group/item"
		}
		function bundle::restore::group/item() {
			_restore "$1" "group/item"
		}
	'

	test::put 'hello' "$TEST_HOME_MOCK/my-file"
	test_files::reset_home
	test::cp "$HOME/my-file" "$TEST_FILES_TARGET/group/item"
	{
		echo 'explicit'
		echo 'group'
		echo 'group/item'
	} >>"$TEST_FILES_TARGET/group/item"

	test::it 'saves & processes file by explicit -> group -> item'
	test_files::run_assert_save

	test::it 'restores & processes file by item -> group -> explicit'
	test_files::run_assert_restore --clean
}

@test "aborts when explicit processor does not exist" {
	test_files::mock_setup "
		foo  ~/foo  @my-io
	"

	test::it 'aborts on save'
	test::put 'foo' "$HOME/foo"
	run tildepot save files
	assert_failure
	assert_line "==> Failed to process files entry; unknown IO type my-io"

	test::it 'aborts on restore'
	test::put 'foo' "$TEST_FILES_STATE/foo"
	run tildepot restore files -y
	assert_failure
	assert_line "==> Failed to process files entry; unknown IO type my-io"
}

@test "skips process when file does not exist" {
	test_files::mock_setup "
		foo  ~/foo  @bar
	"
	test_files::extend_mock_bundle '
		function bundle::save::bar() {
			echo "[TEST] PROC BAR: SAVE"
		}
		function bundle::restore::bar() {
			echo "[TEST] PROC BAR: RESTORE"
		}
	'

	test::it 'ignores missing host file'
	test_files::run_assert_save
	refute_line --partial "[TEST] PROC BAR"

	test::it 'ignores missing state file'
	test_files::run_assert_restore
	refute_line --partial "[TEST] PROC BAR"
}

@test "keeps files as-is when process errors" {
	test_files::mock_setup "
		foo  ~/foo  @bar
	"
	test_files::extend_mock_bundle '
		function bundle::save::bar() {
			return 1
		}
		function bundle::restore::bar() {
			return 1
		}
	'

	test::put 'host' "$TEST_HOME_MOCK/foo"
	test_files::reset_home
	test::put 'state' "$TEST_FILES_STATE/foo"
	test::cp "$TEST_FILES_STATE/foo" "$TEST_FILES_TARGET/foo"

	test::it 'keeps files on save'
	run tildepot save files
	assert_failure
	test::assert_dirs_equal "$HOME" "$TEST_HOME_MOCK"
	test::assert_dirs_equal "$TEST_FILES_STATE" "$TEST_FILES_TARGET"

	test::it 'keeps files on restore'
	run tildepot restore files -y
	assert_failure
	test::assert_dirs_equal "$HOME" "$TEST_HOME_MOCK"
	test::assert_dirs_equal "$TEST_FILES_STATE" "$TEST_FILES_TARGET"
}

@test "keeps files as-is when late process errors" {
	test_files::mock_setup "
		foo  ~/foo
		bar  ~/bar  @fail
	"
	test_files::extend_mock_bundle '
		function bundle::save::fail() {
			return 1
		}
		function bundle::restore::fail() {
			return 1
		}
	'

	test::put 'host' "$TEST_HOME_MOCK/foo"
	test::put 'host' "$TEST_HOME_MOCK/bar"
	test_files::reset_home
	test::put 'state' "$TEST_FILES_STATE/foo"
	test::put 'state' "$TEST_FILES_STATE/bar"
	test::cp "$TEST_FILES_STATE/foo" "$TEST_FILES_TARGET/foo"
	test::cp "$TEST_FILES_STATE/bar" "$TEST_FILES_TARGET/bar"

	test::it 'keeps files on save'
	run tildepot save files
	assert_failure
	test::assert_dirs_equal "$HOME" "$TEST_HOME_MOCK"
	test::assert_dirs_equal "$TEST_FILES_STATE" "$TEST_FILES_TARGET"

	test::it 'keeps files on restore'
	run tildepot restore files -y
	assert_failure
	test::assert_dirs_equal "$HOME" "$TEST_HOME_MOCK"
	test::assert_dirs_equal "$TEST_FILES_STATE" "$TEST_FILES_TARGET"
}

###
# Built-in processors
###

@test "provides built-in processor: plutil" {
	test_files::mock_setup "
		[cfg]  @plutil
		config.plist  ~/config.plist
	"

	test::put '<plist></plist>' "$TEST_HOME_MOCK/config.plist"
	test_files::reset_home
	test::cp "$HOME/config.plist" "$TEST_FILES_TARGET/cfg/config.plist"

	# Mock plutil.
	# shellcheck disable=SC2317,SC2329
	function plutil() {
		test::log "Mocking plutil; args: plutil $*"
	}
	export -f plutil

	test::it 'saves & converts file to xml'
	test_files::run_assert_save
	test::assert_log "Mocking plutil; args: plutil -convert xml1 $TEST_APP_REPO/.tildepot/state/files/cfg/config.plist"

	test::it 'restores & converts file to binary'
	test_files::run_assert_restore
	test::assert_log "Mocking plutil; args: plutil -convert binary1 $TEST_APP_REPO/.tildepot/state/files/cfg/config.plist"

	unset -f plutil
}
