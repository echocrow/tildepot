#!/bin/bash
#
# tildepot modules helpers.

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

function scan_mods() {
  # Read mods and their weights
  local entries=''
  local mod
  while read -r file; do
    mod="$(dirname "$file" | xargs basename)"

    load_mod "$mod"
    weight="${WEIGHT:-50}"

    entries+="$weight"$'\t'"$mod"$'\n'
  done < <(find "$REPO_ROOT/mods" -type f -name 'mod.sh' -mindepth 2 -maxdepth 2)

  # Sort and output mod names
  chomp "$entries" | sort -n | cut -f2
}

function load_mod() {
  local mod="$1"

  # Reset mod variables & functions
  unset -v WEIGHT
  unset -f INSTALL UPDATE SNAPSHOT DIFF APPLY

  local mod_file="$REPO_ROOT/mods/$mod/mod.sh"
  export MOD_DIR="$REPO_ROOT/mods/$mod"

  # shellcheck source=/dev/null
  source "$mod_file"
}

function invoke_mod() {
  local mod="$1"
  local hook="$2"

  load_mod "$mod"

  local hook_fn
  hook_fn="$(echo "$hook" | tr '[:lower:]' '[:upper:]')"

  if [[ $(type -t $hook_fn) == function ]]; then
    ohai "Running ${tty_blue}${mod} ${hook}${tty_reset}..."
    $hook_fn
    printf "\n"
  fi
}

function invoke_mods() {
  local hook="$1"
  local limit_mods=("${@:2}")

  while read -r mod; do
    if [[ "${#limit_mods[@]}" -gt 0 ]] && ! in_array "$mod" "${limit_mods[@]}"; then
      continue
    fi
    invoke_mod "$mod" "$hook"
  done < <(scan_mods)
}
