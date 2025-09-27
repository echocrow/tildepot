#!/usr/bin/env bash
#
# tildepot bundles helpers.

source "$(dirname "${BASH_SOURCE[0]}")/txt.sh"

function bundles::_scan_bundles() {
  find "$_TILDEPOT_APP__REPO_ROOT/bundles" -mindepth 1 -maxdepth 1 -type f -name '*.sh' |
    sort |
    xargs -I {} basename {} '.sh'
}

function bundles::_invoke_bundle() {
  local bundle_basename="$1"
  local hooks=("${@:2}")

  local opts=()
  app::yes && opts+=('--yes')
  app::force && opts+=('--force')

  # Spawn a new process to avoid leaking variables/functions.
  "$0" _exec-bundle ${opts[@]+"${opts[@]}"} "$bundle_basename" "${hooks[@]}"
}

function bundles::invoke() {
  local bundles=()
  while [[ $# -gt 0 && $1 != -- ]]; do
    [[ -n $1 ]] && bundles+=("$1")
    shift
  done
  [[ $# -gt 0 ]] && shift

  local hooks=()
  while [[ $# -gt 0 && $1 != -- ]]; do
    [[ -n $1 ]] && hooks+=("$1")
    shift
  done
  [[ $# -gt 0 ]] && shift

  if [[ ${#hooks[@]} -eq 0 ]]; then
    lib::abort "No hooks specified."
  fi

  local all_bundle_basenames=()
  while read -r name; do all_bundle_basenames+=("$name"); done < <(bundles::_scan_bundles)
  if [[ ${#all_bundle_basenames[@]} -eq 0 ]]; then
    lib::abort "No bundles found."
  fi

  local bundle_basenames=("${all_bundle_basenames[@]}")
  if [[ ${#bundles[@]} -gt 0 ]]; then
    bundle_basenames=()
    # Get all bundle names.
    local all_bundles=()
    local basename
    for basename in "${all_bundle_basenames[@]}"; do
      all_bundles+=("$(bundle::fmt_bundle_name "$basename")")
    done
    # Get matching bundle basenames.
    local i
    local bundle
    for bundle in "${bundles[@]}"; do
      if ! i="$(lib::array_index "$bundle" "${all_bundles[@]}")"; then
        lib::abort "Bundle ${txt_bold}${txt_blue}${bundle}${txt_reset} not found."
      fi
      bundle_basenames+=("${all_bundle_basenames[i]}")
    done
  fi

  if lib::in_array 'restore' "${hooks[@]}"; then
    lib::require_confirm \
      --yes \
      "${txt_bold}Restoring will ${txt_yellow}override current files & settings${txt_reset}." \
      'Continue?'
  fi

  local bundle_basename
  for bundle_basename in "${bundle_basenames[@]}"; do
    bundles::_invoke_bundle "$bundle_basename" "${hooks[@]}"

    if ((${#hooks[@]} > 1)); then
      printf "${txt_bold}${txt_green}✔︎ Completed %s${txt_reset}.\n" "$(bundle::fmt_bundle_name "$bundle_basename")"
      printf '\n'
    fi
  done

  local hook_msg="${#hooks[@]} hooks"
  ((${#hooks[@]} == 1)) && hook_msg="${hooks[0]//_/ }"
  local bundle_msg="${#bundle_basenames[@]} bundles"
  ((${#bundle_basenames[@]} == 1)) && bundle_msg="$(bundle::fmt_bundle_name "${bundle_basenames[0]}")"
  printf "${txt_bold}${txt_green}✔︎ Completed %s for %s${txt_reset}.\n" "$hook_msg" "$bundle_msg"
}
