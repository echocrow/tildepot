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
  while IFS='' read -r line; do
    [[ ! "$line" =~ 'source ' ]] && echo "$line"
  done <"${ROOT}/cmd/${cmd}"

  # Embed nested source files as functions.
  while read -r file; do
    local sub_file
    sub_file="$(basename "$file" '.sh')"
    local sub_type
    sub_type="$(dirname "$file" | xargs basename)"
    echo ""
    echo "# tildepot source=${file#"$ROOT"/}"
    echo "function _tildepot_${sub_type}_${sub_file}() {"
    while IFS='' read -r line; do
      process_file_line "$line"
    done <"$file"
    echo "}"
    echo ""
  done < <(find "$ROOT/src" -type f -name '*.sh' -mindepth 2 -maxdepth 2)

  # Embed main source files.
  while read -r file; do
    echo "# tildepot source=${file#"$ROOT"/}"
    while IFS='' read -r line; do
      process_file_line "$line"
    done <"$file"
  done < <(find "$ROOT/src" -type f -name '*.sh' -mindepth 1 -maxdepth 1)

  # Invoke main.
  echo ""
  echo "_tildepot_cmd_${cmd} \"\$@\""
}

function process_file_line() {
  local line="$1"

  [[ ! "$line" =~ 'source ' ]] && echo "$line" && return

  # Handle source line.
  local src_file="${line#*source }"
  src_file="${src_file#\"}"
  src_file="${src_file%\"}"

  local ws="${line%%[! ]*}"

  # shellcheck disable=SC2016
  if [[ $src_file =~ ^\$APP_ROOT/src/([a-z]+)/([a-z_]+).sh$ ]]; then
    # Embed nested source files as functions call.
    local sub_type="${BASH_REMATCH[1]}"
    local sub_file="${BASH_REMATCH[2]}"
    echo "${ws}_tildepot_${sub_type}_${sub_file} \"\$@\""
  elif [[ $line =~ ^'source "$(dirname "${BASH_SOURCE[0]}")/' ]]; then
    # Skip regular, top-level source imports.
    return
  elif [[ $src_file =~ ^\$[a-z_]+$ ]]; then
    # Leave variable source imports as-is.
    echo "$line"
  else
    abort "Unknown source file: $src_file"
  fi
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
