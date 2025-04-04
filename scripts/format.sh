#!/bin/bash
#
# Format files for tildepot.

# Enable strict mode
set -euo pipefail

ROOT="$(dirname "${BASH_SOURCE[0]}")/.."

source "$ROOT/src/lib.sh"
source "$ROOT/scripts/run/shfmt.sh"

SHFMT_ARGS=(
  --language-dialect bash
  --indent 2
  --simplify
)

function format::src() {
  lib::ohai "Formatting source files with [shfmt]..."
  while read -r file; do
    echo "- ${file#"$ROOT"/}"
    shfmt "${SHFMT_ARGS[@]}" --write "$file"
  done < <(find "$ROOT" -type f \( -name "*.sh" -o -path "$ROOT/cmd/*" \))
  lib::ohai "All files formatted."
}

function format::main() {
  format::src
}

format::main
