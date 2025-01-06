#!/bin/bash
#
# Build tildepot.

# shellcheck source-path=../

# Enable strict mode
set -euo pipefail

ROOT="$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")"
DIST="$ROOT/dist"

source "$ROOT/src/lib.sh"

function build_cmd() {
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
    print_file_header "$file"
    echo "function _tildepot_${sub_type}_${sub_file}() {"
    process_file "$file"
    echo "}"
    echo ""
  done < <(find "$ROOT/src" -type f -name '*.sh' -mindepth 2 -maxdepth 2)

  # Embed main source files.
  while read -r file; do
    print_file_header "$file"
    process_file "$file"
    echo ""
  done < <(find "$ROOT/src" -type f -name '*.sh' -mindepth 1 -maxdepth 1)

  # Invoke main cmd.
  echo "_tildepot_cmd_${cmd} \"\$@\""
}

function print_file_header() {
  local file="$1"

  echo '########'
  echo "# tildepot-build source=${file#"$ROOT"/}"
  echo '########'
}

function process_file() {
  local file="$1"

  local past_header=
  while IFS='' read -r line; do

    # Skip regular, top-level source imports.
    [[ "$line" == 'source "$(dirname "${BASH_SOURCE[0]}")/'* ]] && continue

    # Skip build-ignore directives.
    [[ "$line" == *'# tildepot-build ignore' ]] && continue

    # Skip file headers (shebangs, file description, shellcheck directives).
    if [[ ! "$past_header" ]]; then
      [[ "$line" == '#'* || ! "$line" ]] && continue
      past_header=1
    fi

    # Print non-source lines as-is.
    [[ ! "$line" == *'source '* ]] && echo "$line" && continue

    # Handle source line.
    local src_file="${line#*source }"
    src_file="${src_file#\"}"
    src_file="${src_file%\"}"
    local ws="${line%%[! ]*}"

    # Embed nested source files as functions call.
    if [[ "$src_file" =~ ^\$APP_ROOT/src/([a-z]+)/([a-z_]+).sh$ ]]; then
      local sub_type="${BASH_REMATCH[1]}"
      local sub_file="${BASH_REMATCH[2]}"
      echo "${ws}_tildepot_${sub_type}_${sub_file} \"\$@\""
    # Leave variable source imports as-is.
    elif [[ "$src_file" =~ ^\$[a-z_]+$ ]]; then
      echo "$line"
    # Abort on unknown source files.
    else
      abort "Build error: Unknown source file '$src_file'"
    fi
  done <"$file"
}

function main() {
  ohai_app "Building..."

  mkdir -p "$DIST"

  while read -r file; do
    local cmd
    cmd="$(basename "$file")"

    local bin="${DIST}/${cmd}"

    build_cmd "$cmd" >"$bin"

    chmod +x "$bin"
    ohai_app "Built [${bin#"$ROOT"/}]."
  done < <(find "$ROOT/cmd" -type f)
}

main "$@"
