#!/usr/bin/env bash
#
# Download and run bats.

# Enable strict mode
set -euo pipefail

BINS_DIR="$ROOT/scripts/.bin"
BATS_VERSION=v1.13.0

BATS_LIBS=(
	bats-assert@v2.2.4
	bats-file@v0.4.0
	bats-support@v0.3.0
)

BATS_DIR="$BINS_DIR/bats-$BATS_VERSION"
BATS_BIN="$BATS_DIR/bin/bats"

BATS_LIBS_DIR="$BINS_DIR/bats-$BATS_VERSION-lib"

function bats::install() {
	lib::ohai "Installing [bats] $BATS_VERSION..."

	mkdir -p "$BINS_DIR"

	rm -rf "$BATS_DIR"
	scripts::download_github_archive "bats-core" "bats-core" "$BATS_VERSION" "$BATS_DIR"

	chmod +x "$BATS_BIN"
}

function bats::require_libs() {
	local manifest_file="$BATS_LIBS_DIR/packages.txt"

	local manifest_data
	manifest_data="$(printf '%s\n' "${BATS_LIBS[@]}")"

	if [[ -f $manifest_file ]] && [[ $(cat "$manifest_file") == "$manifest_data" ]]; then
		return
	fi

	rm -rf "$BATS_LIBS_DIR"
	mkdir -p "$BATS_LIBS_DIR"

	local lib_name version
	for bats_lib in "${BATS_LIBS[@]}"; do
		lib_name="${bats_lib%%@*}"
		version="${bats_lib#*@}"
		scripts::download_github_archive "bats-core" "$lib_name" "$version" "$BATS_LIBS_DIR/$lib_name"
	done

	echo "$manifest_data" >"$manifest_file"
}

function bats() {
	[[ ! -f $BATS_BIN ]] && bats::install
	bats::require_libs
	BATS_LIB_PATH="$BATS_LIBS_DIR" "$BATS_BIN" "$@"
}
