#!/bin/bash
#
# tildepot bundles helpers.

source "$(dirname "${BASH_SOURCE[0]}")/txt.sh"

# Path to a bundle's directory. This will be set by the bundles loader.
export BUNDLE_DIR=""

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

function bundles::_load_parent_bundle() {
  local child_bundle_file="${1?}"
  local depth="${2:-0}"

  local parent_bundle="${INHERIT:-}"
  if [[ -z $parent_bundle ]]; then
    return 0
  fi
  if [[ $depth -ge 5 ]]; then
    lib::abort "Failed to load parent bundle; too many levels of inheritance: $depth"
  fi

  local parent_file=
  case $parent_bundle in
  # Load local parent bundle.
  ./* | ../*) parent_file="$(dirname "$child_bundle_file")/$parent_bundle" ;;
  # Load local parent bundle (absolute path).
  /*) parent_file="$parent_bundle" ;;
  # Unknown inherit format.
  *) lib::abort "Unknown parent bundle format: $parent_bundle" ;;
  esac

  if [[ ! -f $parent_file ]]; then
    lib::abort "Failed to load parent bundle; missing file: $parent_file"
  fi

  unset 'INHERIT'

  # shellcheck source=/dev/null
  source "$parent_file"

  # Recursively load parent bundle.
  bundles::_load_parent_bundle "$parent_file" "$((depth + 1))"

  # Reload child bundle to override stock bundle.
  # shellcheck source=/dev/null
  source "$child_bundle_file"
}

function bundles::_scan_bundles() {
  find "$APP_REPO_ROOT/bundles" -type f -name '*.sh' -mindepth 1 -maxdepth 1 |
    sort |
    xargs -I {} basename {} '.sh'
}

function bundles::_fmt_bundle_name() {
  local basename="$1"
  # Trim leading numbers (presumed for file sorting).
  echo "${basename##[0-9]* }"
}

function bundles::_exec_hook() {
  local bundle="$1"
  local hook="$2"

  local hook_fn
  hook_fn="$(bundles::_fmt_hook_fn_hooks "$hook")"

  ! declare -F "$hook_fn" >/dev/null && return

  # Check optional "${HOOK_FN}_SKIP" function
  local hook_skip_fn="${hook_fn}_SKIP"
  if declare -F "$hook_skip_fn" >/dev/null && ! app::force; then
    local skip_msg=''
    local hook_skip=
    if ! app::dev "> $hook_skip_fn"; then
      skip_msg="$($hook_skip_fn)" && hook_skip=1
    fi
    if [[ -n $skip_msg || $hook_skip ]]; then
      lib::ohai "Skipping ${txt_bold}${txt_blue}${bundle} ${hook}${txt_reset}."
      [[ -n $skip_msg ]] && tilde::warning "Reason: ${skip_msg}."
      return 0
    fi
  fi

  lib::ohai "Running ${txt_blue}${bundle} ${hook//_/-}${txt_reset}..."

  case "$hook" in
  snapshot)
    mkdir -p "$APP_REPO_ROOT/state/${bundle}"
    ;;
  esac

  if ! app::dev "> $hook_fn"; then
    $hook_fn
  fi

  printf "\n"
}

function bundles::_fmt_hook_fn_hooks() {
  local hook="$1"
  echo "$hook" | tr '[:lower:]' '[:upper:]'
}

function bundles::exec_hooks() {
  local bundle_basename="$1"
  local hooks=() && IFS='/' read -ra hooks <<<"$2"

  local bundle
  bundle="$(bundles::_fmt_bundle_name "$bundle_basename")"

  local bundle_file="$APP_REPO_ROOT/bundles/${bundle_basename}.sh"
  export BUNDLE_DIR="$APP_REPO_ROOT/state/${bundle}"

  unset 'INHERIT'
  unset -f 'SKIP'
  local hook_fn
  for hook in "${hooks[@]}"; do
    hook_fn="$(bundles::_fmt_hook_fn_hooks "$hook")"
    unset -f "${hook_fn}_SKIP" "${hook_fn}"
  done

  # Load user bundle.
  # shellcheck source=/dev/null
  source "$bundle_file"

  bundles::_load_parent_bundle "$bundle_file"

  # Check optional "SKIP" function
  local skip_fn="SKIP"
  if declare -F "$skip_fn" >/dev/null; then
    local skip_msg=''
    local skip=
    if ! app::dev "> $skip_fn"; then
      skip_msg="$($skip_fn)" && skip=1
    fi
    if [[ -n $skip_msg || $skip ]]; then
      lib::ohai "Skipping ${txt_bold}${txt_blue}${bundle}${txt_reset}."
      [[ -n $skip_msg ]] && tilde::warning "Reason: ${skip_msg}."
      return 0
    fi
  fi

  for hook in "${hooks[@]}"; do
    bundles::_exec_hook "$bundle" "$hook"
  done
}

function bundles::_invoke_bundle() {
  local bundle_basename="$1"
  local hooks=() && IFS='/' read -ra hooks <<<"$2"

  local opts=()
  app::force && opts+=('--force')

  # Spawn a new process to avoid leaking variables/functions.
  "$0" _exec-bundle "${opts[@]-}" "$bundle_basename" "${hooks[@]}"
}

function bundles::invoke() {
  local bundles=() && IFS='/' read -ra bundles <<<"$1"
  local hooks_str="$2"

  local hooks=() && IFS='/' read -ra hooks <<<"$hooks_str"

  if [[ ${#hooks[@]} -eq 0 ]]; then
    lib::abort "No hooks specified."
  fi

  local all_bundle_basenames=()
  while read -r name; do all_bundle_basenames+=("$name"); done < <(bundles::_scan_bundles)
  if [[ ${#all_bundle_basenames[@]} -eq 0 ]]; then
    lib::abort "No bundle files found."
  fi

  local bundle_basenames=("${all_bundle_basenames[@]}")
  if [[ ${#bundles[@]} -gt 0 ]]; then
    bundle_basenames=()
    # Get all bundle names.
    local all_bundles=()
    for basename in "${all_bundle_basenames[@]}"; do
      all_bundles+=("$(bundles::_fmt_bundle_name "$basename")")
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
    bundles::_invoke_bundle "$bundle_basename" "$hooks_str"
  done
}
