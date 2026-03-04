#!/usr/bin/env bash
#
# Bats helpers for release script tests

function test::_release_lib_setup() {
	load ../test_lib.sh

	# Use test temp dir as repo & pwd.
	mkdir "$BATS_TEST_TMPDIR/repo"
	cd "$BATS_TEST_TMPDIR/repo" || exit
	export TEST_RELEASE_DIST_DIR="$BATS_TEST_TMPDIR/repo/dist/release"

	# Set up basic release config
	export TEST_RELEASE_CONFIG_PATH="$BATS_TEST_TMPDIR/repo/.releaserc"
	cat >"$TEST_RELEASE_CONFIG_PATH" <<-EOF
		{
			"packages": [{"name": "foo"}]
		}
	EOF

	# Make release script available
	function release() {
		bash "$BATS_CWD/scripts/release.sh" "$@"
	}
	export -f release

	# Init git
	git init --initial-branch=main --quiet
	git config user.email "test.${BATS_TEST_NUMBER}@test.test"
	git config user.name "Test $BATS_TEST_NUMBER"
	git commit -am "Initial commit" --quiet --allow-empty

	# Mock git
	export _TEST_GIT_BIN
	_TEST_GIT_BIN="$(command -v git)"
	function git() {
		local cmd="$1"
		case $cmd in
		fetch) test::log "git fetch disabled in this test" ;;
		*) "$_TEST_GIT_BIN" "$@" ;;
		esac
	}
	export -f git

	# Mock gh
	function gh() {
		test::log "MOCK gh $*"
	}
	export -f gh
}
test::_release_lib_setup

function test::release_lib_teardown() {
	unset TEST_RELEASE_DIST_DIR
	unset -f release
	unset _TEST_GIT_BIN
	unset -f git
	unset -f gh
}

function test::git_commit() {
	git commit --quiet --allow-empty "$@"
}
function test::git_commit_print() {
	test::git_commit "$@"
	git rev-parse --short HEAD
}

function test::extend_cfg() {
	case $# in
	1)
		local cfg="$1"
		jq --argjson cfg "$cfg" '. + $cfg' "$TEST_RELEASE_CONFIG_PATH" >"$TEST_RELEASE_CONFIG_PATH.tmp"
		;;
	2)
		local path="$1"
		local value="$2"
		if [[ ${value:0:1} == '"' || ${value:0:1} == '{' || ${value:0:1} == '[' || $value == 'true' || $value == 'false' ]]; then
			jq --argjson value "$value" "$path"' = $value' "$TEST_RELEASE_CONFIG_PATH" >"$TEST_RELEASE_CONFIG_PATH.tmp"
		else
			jq --arg value "$value" "$path"' = $value' "$TEST_RELEASE_CONFIG_PATH" >"$TEST_RELEASE_CONFIG_PATH.tmp"
		fi
		;;
	*) lib::abort "Invalid number of arguments: [$#]" ;;
	esac
	mv "$TEST_RELEASE_CONFIG_PATH.tmp" "$TEST_RELEASE_CONFIG_PATH"
}
