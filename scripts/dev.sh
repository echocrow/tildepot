#!/usr/bin/env bash
#
# Start dev mode for tildepot.

# Enable strict mode
set -euo pipefail

ROOT="$(dirname "${BASH_SOURCE[0]}")/.."

source "$ROOT/src/lib.sh"
source "$ROOT/scripts/scripts_lib.sh"

function dev::build() {
	# Gather files
	local files=()
	# Gather files: src & scripts
	while read -r file; do
		files+=("$file")
	done < <(find "$ROOT/src" "$ROOT/scripts" -type f -name '*.sh')
	# Gather files: cmd
	while read -r file; do
		files+=("$file")
	done < <(find "$ROOT/cmd" -type f)

	scripts::watch "$ROOT" "${files[@]}" -- make build "$@"
}

function dev::test() {
	# Gather files
	local files=()
	# Gather files: src/scripts/bundles
	while read -r file; do
		files+=("$file")
	done < <(find "$ROOT/src" "$ROOT/scripts" "$ROOT/bundles" -type f -name '*.sh')
	# Gather files: test
	while read -r file; do
		files+=("$file")
	done < <(find "$ROOT/test" -type f \( -name '*.bats' -o -name '*.sh' \))

	scripts::watch "$ROOT" "${files[@]}" -- make test "$@"
}

function dev::main() {
	local mode="${1?missing mode}"
	shift

	case $mode in
	build) dev::build "$@" ;;
	test) dev::test "$@" ;;
	*) lib::abort "Unknown mode: $mode" ;;
	esac
}

dev::main "$@"
