#!/usr/bin/env bash
#
# tildepot bundle helpers.

source "$(dirname "${BASH_SOURCE[0]}")/txt.sh"

# Path to a bundle's directory. This will be set by the bundles loader.
export BUNDLE_DIR=""

# Maximum depth to recurse when loading parent bundles.
_TILDEPOT_BUNDLE__MAX_EXTEND_DEPTH=5

# List of known hook functions.
_TILDEPOT_BUNDLE__HOOK_FNS=(
  SKIP

  INSTALL_SKIP
  INSTALL

  UPDATE_SKIP
  UPDATE

  SNAPSHOT_SKIP
  SNAPSHOT

  APPLY_SKIP
  APPLY
)

# Keep a reference of the current hook & depth.
_TILDEPOT_BUNDLE__CURR_HOOK_FN=
_TILDEPOT_BUNDLE__CURR_DEPTH_IDX=

# Dynamically globals:
# - Store at which bundle-inheritance depths an individual hook was implemented:
#   _TILDEPOT_BUNDLE__HOOK_DEPTHS_${HOOK_FN}=

function bundle::fmt_bundle_name() {
  local basename="$1"
  # Trim leading numbers (presumed for file sorting).
  echo "${basename##[0-9]* }"
}

function bundle::_clone_hook_fn() {
  local hook_fn="${1?}"
  local depth="${2?}"

  local new_name="bundle::__hook_${depth}_${hook_fn}"
  eval "$(declare -f "$hook_fn" | sed "1s/$hook_fn/$new_name/")"
}

function bundle::_track_hooks_implementation() {
  local depth="${1?}"

  local hook_fn
  for hook_fn in "${_TILDEPOT_BUNDLE__HOOK_FNS[@]}"; do
    if declare -F "$hook_fn" >/dev/null; then
      local var="_TILDEPOT_BUNDLE__HOOK_DEPTHS_${hook_fn}"
      local curr_depths="${!var-}"
      printf -v "$var" "%s" "${curr_depths}${depth}"
      if [[ -n $curr_depths ]]; then
        bundle::_clone_hook_fn "$hook_fn" "$depth"
      fi
    fi
  done
}

function bundle::_unset_hook_api() {
  unset EXTEND
  local hook_fn
  for hook_fn in "${_TILDEPOT_BUNDLE__HOOK_FNS[@]}"; do
    unset -f "$hook_fn"
  done
}

function bundle::_load_bundle() {
  local bundle_file="${1?}"
  local depth="${2:-0}"

  # Unset all hook variables & functions, so we can track new definitions.
  bundle::_unset_hook_api

  # Load bundle.
  # shellcheck source=/dev/null
  source "$bundle_file"

  local parent_bundle="${EXTEND:-}"

  # No need to track hook implementations if there are no parent bundles.
  [[ $depth -eq 0 && -z $parent_bundle ]] && return 0

  # Track implementations of hooks defined in the current bundle.
  bundle::_track_hooks_implementation "$depth"

  if [[ -n $parent_bundle ]]; then
    if [[ $depth -ge $_TILDEPOT_BUNDLE__MAX_EXTEND_DEPTH ]]; then
      lib::abort "Failed to load parent bundle; too many levels of inheritance (>=$depth)"
    fi

    local parent_file=
    case $parent_bundle in
    # Load local parent bundle.
    ./* | ../*) parent_file="$(dirname "$bundle_file")/$parent_bundle" ;;
    # Load local parent bundle (absolute path).
    /*) parent_file="$parent_bundle" ;;
    # Unknown inherit format.
    *) lib::abort "Unknown parent bundle format: $parent_bundle" ;;
    esac

    if [[ ! -f $parent_file ]]; then
      lib::abort "Failed to load parent bundle; missing file: $parent_file"
    fi

    # Recursively load parent bundle.
    bundle::_load_bundle "$parent_file" "$((depth + 1))"

    # Reload child bundle to override stock bundle.
    # shellcheck source=/dev/null
    source "$bundle_file"
  fi
}

function bundle::_call_hook_fn() {
  local hook_fn="${1?}"

  _TILDEPOT_BUNDLE__CURR_HOOK_FN="$hook_fn"
  _TILDEPOT_BUNDLE__CURR_DEPTH_IDX=0

  "$hook_fn"
  return "$?"
}

function bundle::_print_skip_reason() {
  local name="$1"
  local skip_msg="$2"

  lib::ohai "Skipping ${txt_bold}${txt_blue}${name}${txt_reset}."
  if [[ -n $skip_msg ]]; then
    if [[ $skip_msg == *$'\n'* ]]; then
      tilde::warning "Reason:"$'\n'"$skip_msg"
    else
      tilde::warning "Reason: $skip_msg"
    fi
  fi
}

function bundle::_exec_hook() {
  local bundle="$1"
  local hook="$2"

  local hook_fn
  hook_fn="$(bundle::_fmt_hook_fn_hooks "$hook")"

  ! declare -F "$hook_fn" >/dev/null && return

  # Check optional "${HOOK}_SKIP" function
  local hook_skip_fn="${hook_fn}_SKIP"
  if declare -F "$hook_skip_fn" >/dev/null && ! app::force; then
    local skip_msg=''
    local hook_skip=
    if ! app::dev "> $hook_skip_fn"; then
      skip_msg="$(bundle::_call_hook_fn "$hook_skip_fn")" && hook_skip=1
    fi
    if [[ -n $skip_msg || $hook_skip ]]; then
      bundle::_print_skip_reason "${bundle} ${hook}" "$skip_msg"
      return 0
    fi
  fi

  lib::ohai "Running ${txt_blue}${bundle} ${hook//_/-}${txt_reset}..."

  case "$hook" in
  snapshot)
    mkdir -p "$_TILDEPOT_APP__REPO_ROOT/state/${bundle}"
    ;;
  esac

  if ! app::dev "> $hook_fn"; then
    bundle::_call_hook_fn "$hook_fn"
  fi

  printf "\n"
}

function bundle::_fmt_hook_fn_hooks() {
  local hook="$1"
  echo "$hook" | tr '[:lower:]' '[:upper:]'
}

function bundle::_define_super_fn() {
  # shellcheck disable=SC2317
  function SUPER() {
    local hook_fn="${_TILDEPOT_BUNDLE__CURR_HOOK_FN:?}"
    local depth_idx="${_TILDEPOT_BUNDLE__CURR_DEPTH_IDX:?}"

    local depths_var="_TILDEPOT_BUNDLE__HOOK_DEPTHS_${hook_fn}"
    local depths="${!depths_var}"

    depth_idx=$((depth_idx + 1))
    _TILDEPOT_BUNDLE__CURR_DEPTH_IDX="$depth_idx"

    local depth="${depths:depth_idx:1}"
    if [[ -z $depth ]]; then
      # Return 0 on regular hooks to allow for no-op SUPER calls
      # Only return non-zero result on "SKIP" and "${HOOK}_SKIP" functions,
      # because 0-returns indicate a skip match.
      [[ $hook_fn != *'SKIP' ]]
      return
    fi

    local super_fn="bundle::__hook_${depth}_${hook_fn}"
    if ! declare -F "$super_fn" >/dev/null; then
      lib::abort "Failed to find hook implementation for [$hook_fn] at depth [$depth]"
    fi
    "$super_fn"
    return "$?"
  }
}

function bundle::exec_hooks() {
  local bundle_basename="$1"
  local hooks=("${@:2}")

  local bundle
  bundle="$(bundle::fmt_bundle_name "$bundle_basename")"

  local bundle_file="$_TILDEPOT_APP__REPO_ROOT/bundles/${bundle_basename}.sh"
  export BUNDLE_DIR="$_TILDEPOT_APP__REPO_ROOT/state/${bundle}"

  bundle::_unset_hook_api

  local hook_fn
  local hook
  for hook in "${hooks[@]}"; do
    hook_fn="$(bundle::_fmt_hook_fn_hooks "$hook")"
    unset -f "${hook_fn}_SKIP" "${hook_fn}"
  done

  bundle::_load_bundle "$bundle_file"

  bundle::_define_super_fn

  # Check optional "SKIP" function
  local skip_fn="SKIP"
  if declare -F "$skip_fn" >/dev/null; then
    local skip_msg=''
    local skip=
    if ! app::dev "> $skip_fn"; then
      skip_msg="$(bundle::_call_hook_fn "$skip_fn")" && skip=1
    fi
    if [[ -n $skip_msg || $skip ]]; then
      bundle::_print_skip_reason "$bundle" "$skip_msg"
      return 0
    fi
  fi

  local hook
  for hook in "${hooks[@]}"; do
    bundle::_exec_hook "$bundle" "$hook"
  done
}
