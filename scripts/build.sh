#!/usr/bin/env bash
#
# Build tildepot.

# Enable strict mode
set -euo pipefail

ROOT="$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")"
DIST="$ROOT/dist"

# shellcheck disable=SC2016
DIRNAME_STR='$(dirname "${BASH_SOURCE[0]}")'

source "$ROOT/src/lib.sh"

SOURCED_FILES=()
STATIC_FILES=()

function build::_build_cmd() {
	local cmd="$1"
	local version="$2"
	local dev=
	[[ $version =~ -dev$ ]] && dev=1
	local test=
	[[ $version =~ -test$ ]] && test=1

	SOURCED_FILES=()
	STATIC_FILES=()

	local build_info=$'\n'
	build_info+="$(build::_print_header "set build info")"$'\n'
	build_info+="export __TILDEPOT_BUILD_VERSION=${version}"$'\n'
	build_info+="export __TILDEPOT_BUILD_DEV=${dev}"$'\n'
	build_info+="export __TILDEPOT_BUILD_TEST=${test}"$'\n'

	build::_process_file "${ROOT}/cmd/${cmd}" "$build_info"
}

function build::_print_header() {
	local msg="$1"

	echo '########'
	echo "# tildepot-build: $msg"
	echo '########'
}

function build::_print_file_header() {
	local file="$1"

	build::_print_header "source=${file#"$ROOT"/}"
}

function build::_process_file() {
	local file="${1?}"
	local header="${2-}"

	local is_entrypoint=
	[[ ${#SOURCED_FILES[@]} == 0 ]] && is_entrypoint=1

	if [[ ! -f $file ]]; then
		lib::abort "Build error: Source file not found: \"$file\""
	fi
	file="$(realpath "$file")"

	# Skip already-sourced files & avoid circular dependencies.
	local source_file
	for source_file in ${SOURCED_FILES+"${SOURCED_FILES[@]}"}; do
		[[ $source_file == "$file" ]] && return
	done
	SOURCED_FILES+=("$file")
	echo "- ${file#"$ROOT/"}" >&2

	local file_dir
	file_dir="$(dirname "$file")"

	if [[ ! $is_entrypoint ]]; then
		build::_print_file_header "$file"
	fi

	local line source_file var_name static_file
	local past_header=
	while IFS= read -r line; do

		# Embed top-level source imports.
		# shellcheck disable=SC2016
		if [[ $line == "source \"${DIRNAME_STR}/"* ]]; then
			source_file="${line#'source "'}"
			source_file="${source_file%'"'}"
			source_file="${source_file/"$DIRNAME_STR"/$file_dir}"
			build::_process_file "$source_file"
			continue
		fi

		# Embed top-level static files.
		# shellcheck disable=SC2016
		if [[ $line =~ ^([A-Z0-9_]+)'="$(cat "'("${DIRNAME_STR}/".*)')"'$ ]]; then
			local var_name="${BASH_REMATCH[1]}"
			local static_file="${BASH_REMATCH[2]}"
			static_file="${static_file%'"'}"
			static_file="${static_file/"$DIRNAME_STR"/$file_dir}"
			build::_process_static_file "$var_name" "$static_file"
			continue
		fi

		# Skip build-ignore directives.
		[[ $line == *'# tildepot-build ignore' ]] && continue

		# Skip file headers (shebangs, file description, shellcheck directives)
		# (except for entrypoints).
		if [[ ! $past_header ]]; then
			[[ ! $line ]] && past_header=1
			[[ $past_header && $header ]] && echo "$header"
			[[ ! $past_header && ! $is_entrypoint ]] && continue
		fi

		# Omit top-level export statements.
		if [[ $line == 'export '* ]]; then
			[[ $line == *=* ]] && echo "${line/'export '/}"
			continue
		fi

		# Print non-source lines as-is.
		[[ $line != *'source '* ]] && echo "$line" && continue

		# Multiple source directives per line are not supported.
		[[ $line == *'source '*'source '* ]] && lib::abort "Build error: Too many source directives in a single line in \"$file\":" "$line"

		# Leave basic variable source imports as-is.
		[[ $line =~ 'source "$'[a-z_]+'"'($| ) ]] && echo "$line" && continue

		lib::abort "Build error: Unhandled source line in \"$file\":" "$line"
	done <"$file"

	if [[ ! $is_entrypoint ]]; then
		echo
	fi
}

function build::_process_static_file() {
	local var_name="${1?}"
	local file="${2?}"

	if [[ ! -f $file ]]; then
		lib::abort "Build error: Static source file not found: \"$file\""
	fi
	file="$(realpath "$file")"

	# Find static file index if it has already been embedded.
	local already_loaded=
	local static_idx
	for ((static_idx = 0; static_idx < ${#STATIC_FILES[@]}; static_idx++)); do
		[[ ${STATIC_FILES[$static_idx]} != "$file" ]] && continue
		already_loaded=1
		break
	done

	local static_build_var="__TILDEPOT_BUILD_STATIC_${static_idx}"

	if [[ ! $already_loaded ]]; then
		build::_print_file_header "$file"
		printf "read -r -d '' %s <<'__TILDEPOT_BUILD_EOF' || :\n" "$static_build_var"
		cat "$file"
		printf '__TILDEPOT_BUILD_EOF\n\n'

		STATIC_FILES+=("$file")
	fi

	printf '%s="$%s"\n' "$var_name" "$static_build_var"
}

function build::main() {
	local version="${1:-0.0.0-dev}"
	lib::ohai "Building v${version}..."

	mkdir -p "$DIST"

	while read -r file; do
		local cmd
		cmd="$(basename "$file")"

		local bin="${DIST}/${cmd}"

		build::_build_cmd "$cmd" "$version" >"$bin"

		chmod +x "$bin"
		lib::ohai "Built [${bin#"$ROOT"/}]."
	done < <(find "$ROOT/cmd" -type f)
}

build::main "$@"
