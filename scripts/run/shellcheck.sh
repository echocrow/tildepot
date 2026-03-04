#!/usr/bin/env bash
#
# Download and run shellcheck.

# Enable strict mode
set -euo pipefail

BINS_DIR="$ROOT/scripts/.bin"
SHELLCHECK_VERSION=v0.10.0

SHELLCHECK_DIR="$BINS_DIR/shellcheck-$SHELLCHECK_VERSION"
SHELLCHECK_BIN="$SHELLCHECK_DIR/shellcheck"

function shellcheck::install() {
	lib::ohai "Installing [shellcheck] $SHELLCHECK_VERSION..."

	local os
	os="$(uname -s)"
	local machine
	machine="$(uname -m)"

	local platform
	case $os in
	Darwin)
		case $machine in
		x86_64) platform=darwin.x86_64 ;;
		arm64) platform=darwin.aarch64 ;;
		esac
		;;
	Linux)
		case $machine in
		x86_64) platform=linux.x86_64 ;;
		aarch64) platform=linux.aarch64 ;;
		esac
		;;
	esac
	if [[ -z $platform ]]; then
		lib::abort "Unsupported platform: $os/$machine"
	fi

	rm -rf "$SHELLCHECK_DIR"
	mkdir -p "$BINS_DIR"

	local bin_url="https://github.com/koalaman/shellcheck/releases/download/${SHELLCHECK_VERSION?}/shellcheck-${SHELLCHECK_VERSION?}.${platform?}.tar.xz"
	lib::download "$bin_url" |
		tar -xJ -C "$BINS_DIR"
}

function shellcheck() {
	[[ ! -f $SHELLCHECK_BIN ]] && shellcheck::install
	"$SHELLCHECK_BIN" "$@"
}
