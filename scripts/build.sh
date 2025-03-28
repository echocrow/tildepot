#!/bin/bash
#
# Build tildepot.

# shellcheck source-path=../

# Enable strict mode
set -euo pipefail

ROOT="$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")"
DIST="$ROOT/dist"

source "$ROOT/src/lib.sh"

function build::_build_cmd() {
  local cmd="$1"

  # Process main cmd file.
  local shellcheck_printed=
  while IFS='' read -r line; do
    [[ "$line" == '# shellcheck source-path='* ]] && continue
    [[ "$line" == 'source '* ]] && continue

    echo "$line"

    if [[ ! "$shellcheck_printed" && ! "$line" ]]; then
      # Disable false-positive shellcheck warnings.
      echo "# shellcheck disable=SC2317"
      shellcheck_printed=1
    fi
  done <"${ROOT}/cmd/${cmd}"
  echo ""

  # Embed nested source files as functions.
  while read -r file; do
    local sub_file
    sub_file="$(basename "$file" '.sh')"
    local sub_type
    sub_type="$(dirname "$file" | xargs basename)"
    build::_print_file_header "$file"
    echo "function _tildepot_${sub_type}_${sub_file}() {"
    build::_process_file "$file"
    echo "}"
    echo ""
  done < <(find "$ROOT/src" -type f -name '*.sh' -mindepth 2 -maxdepth 2)

  # Embed main source files.
  while read -r file; do
    build::_print_file_header "$file"
    build::_process_file "$file"
    echo ""
  done < <(find "$ROOT/src" -type f -name '*.sh' -mindepth 1 -maxdepth 1)

  # Invoke main cmd.
  echo "_tildepot_cmd_${cmd} \"\$@\""
}

function build::_print_file_header() {
  local file="$1"

  echo '########'
  echo "# tildepot-build source=${file#"$ROOT"/}"
  echo '########'
}

function build::_process_file() {
  local file="$1"

  local past_header=
  while IFS='' read -r line; do

    # Skip regular, top-level source imports.
    # shellcheck disable=SC2016
    [[ "$line" == 'source "$(dirname "${BASH_SOURCE[0]}")/'* ]] && continue

    # Skip build-ignore directives.
    [[ "$line" == *'# tildepot-build ignore' ]] && continue

    # Skip file headers (shebangs, file description, shellcheck directives).
    if [[ ! "$past_header" ]]; then
      [[ "$line" == '#'* || ! "$line" ]] && continue
      past_header=1
    fi

    # Omit top-level export statements.
    if [[ "$line" == 'export '* ]]; then
      [[ "$line" == *'='* ]] && echo "${line/'export '/}"
      continue
    fi

    # Print non-source lines as-is.
    [[ ! "$line" == *'source '* ]] && echo "$line" && continue

    # Multiple source directives per line are not supported.
    [[ "$line" == *'source '*'source '* ]] && lib::abort "Build error: Too many source directives in a single line in \"$file\":" "$line"

    # Leave basic variable source imports as-is.
    [[ "$line" =~ 'source "$'[a-z_]+'"'($| ) ]] && echo "$line" && continue

    # Embed nested source files as functions call.
    # shellcheck disable=SC2016
    if [[ "$line" =~ 'source "$APP_ROOT/src/'([a-z]+)'/'([a-z_]+)'.sh"' ]]; then
      local sub_type="${BASH_REMATCH[1]}"
      local sub_file="${BASH_REMATCH[2]}"
      local fn_cmd="_tildepot_${sub_type}_${sub_file}"
      echo "${line/${BASH_REMATCH[0]}/$fn_cmd}"
      continue
    fi

    # Keep lines that likely print text containing "source".
    [[ "$line" =~ [\'\"].*'source'.*[\'\"] ]] && echo "$line" && continue
    # Keep lines that likely create "source"-named variables.
    [[ "$line" =~ 'while '.*' -r '.*source ]] && echo "$line" && continue
    # Ignore comments.
    [[ "$line" =~ ^' '*# ]] && continue

    lib::abort "Build error: Unhandled source line in \"$file\":" "$line"
  done <"$file"
}

function build::main() {
  lib::ohai "Building..."

  mkdir -p "$DIST"

  while read -r file; do
    local cmd
    cmd="$(basename "$file")"

    local bin="${DIST}/${cmd}"

    build::_build_cmd "$cmd" >"$bin"

    chmod +x "$bin"
    lib::ohai "Built [${bin#"$ROOT"/}]."
  done < <(find "$ROOT/cmd" -type f)
}

build::main "$@"
