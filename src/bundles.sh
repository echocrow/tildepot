#!/bin/bash
#
# tildepot bundles helpers.

source "$(dirname "${BASH_SOURCE[0]}")/txt.sh"

function bundles::hook_description() {
  local hook="$1"

  case "$hook" in
  install) echo "Run first-time install steps." ;;
  update) echo "Update commands & applications." ;;
  snapshot) echo "Store (export) a snapshot of the current state of your system." ;;
  apply) echo "Restore (import) the current snapshot into your system." ;;
  *) lib::abort "Unknown hook '$hook'" ;;
  esac
}

function bundles::print_apply_warning() {
  echo "${txt_yellow}Warning:${txt_reset} This will overwrite any changes made to your system since the snapshot was taken."
}

function bundles::_scan_bundles() {
  find "$APP_REPO_ROOT/bundles" -type f -name '*.sh' -mindepth 1 -maxdepth 1 |
    sort |
    xargs -I {} basename {} '.sh'
}

function bundles::_invoke_bundle() {
  local bundle_basename="$1"
  local hooks=("${@:2}")

  local opts=()
  app::force && opts+=('--force')

  # Spawn a new process to avoid leaking variables/functions.
  "$0" _exec-bundle "${opts[@]-}" "$bundle_basename" "${hooks[@]}"
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
    for basename in "${all_bundle_basenames[@]}"; do
      all_bundles+=("$(bundle::fmt_bundle_name "$basename")")
    done
    # Get matching bundle basenames.
    local i
    for bundle in "${bundles[@]}"; do
      if ! i="$(lib::array_index "$bundle" "${all_bundles[@]}")"; then
        lib::abort "Bundle ${txt_bold}${txt_blue}${bundle}${txt_reset} not found."
      fi
      bundle_basenames+=("${all_bundle_basenames[i]}")
    done
  fi

  if lib::in_array 'apply' "${hooks[@]}"; then
    lib::require_confirm \
      "${txt_bold}Restoring snapshots will ${txt_yellow}override current files & settings${txt_reset}." \
      'Continue?'
  fi

  for bundle_basename in "${bundle_basenames[@]}"; do
    bundles::_invoke_bundle "$bundle_basename" "${hooks[@]}"
  done
}
