#!/bin/bash
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
_TILDEPOT_BUNDLE__CURR_DEPTH=

function bundle::fmt_bundle_name() {
  local basename="$1"
  # Trim leading numbers (presumed for file sorting).
  echo "${basename##[0-9]* }"
}

function bundle::_get_fn_body() {
  local name="${1?}"
  declare -f "$name" | sed '1,2d;$d'
}

function bundle::_declare_fn() {
  local name="${1?}"
  local body="${2?}"
  eval "$name() {"$'\n'"$body"$'\n'"}"
}

function bundle::_clone_rename_fn() {
  local fn="${1?}"
  local new_name="${2?}"

  bundle::_declare_fn "$new_name" "$(bundle::_get_fn_body "$fn")"
}

function bundle::_refine_hook_fn() {
  local hook_fn="${1?}"
  local depth="${2?}"

  local body
  body="$(bundle::_get_fn_body "$hook_fn")"
  [[ $body == *"_TILDEPOT_BUNDLE__CURR_DEPTH="* ]] && return

  body="_TILDEPOT_BUNDLE__CURR_DEPTH=$depth"$'\n'"$body"
  bundle::_declare_fn "$hook_fn" "$body"

  bundle::_clone_rename_fn "$hook_fn" "bundle::__super_hook_${depth}_${hook_fn}"
}

function bundle::_refine_hook_fns() {
  local depth="${1?}"
  for fn in "${_TILDEPOT_BUNDLE__HOOK_FNS[@]}"; do
    if declare -F "$fn" >/dev/null; then
      bundle::_refine_hook_fn "$fn" "$depth"
    fi
  done
}

function bundle::_unset_hook_api() {
  unset EXTEND
  for fn in "${_TILDEPOT_BUNDLE__HOOK_FNS[@]}"; do
    unset -f "$fn"
  done
}

function bundle::_load_parent_bundle() {
  local child_bundle_file="${1?}"
  local depth="${2:-0}"

  local parent_bundle="${EXTEND:-}"
  [[ -z $parent_bundle ]] && return 0
  if [[ $depth -ge $_TILDEPOT_BUNDLE__MAX_EXTEND_DEPTH ]]; then
    lib::abort "Failed to load parent bundle; too many levels of inheritance (>=$depth)"
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

  # Unset all hook variables & functions, so we can track new definitions.
  bundle::_unset_hook_api

  # shellcheck source=/dev/null
  source "$parent_file"

  # Refine parent hook functions.
  bundle::_refine_hook_fns "$((depth + 1))"

  # Recursively load parent bundle.
  bundle::_load_parent_bundle "$parent_file" "$((depth + 1))"

  # Reload child bundle to override stock bundle.
  # shellcheck source=/dev/null
  source "$child_bundle_file"

  # Refine child hook functions.
  # This will skip already refined functions from the parent bundle not
  # overridden in the child bundle.
  bundle::_refine_hook_fns "$depth"
}

function bundle::_call_hook_fn() {
  local hook_fn="${1?}"

  _TILDEPOT_BUNDLE__CURR_HOOK_FN="$hook_fn"
  _TILDEPOT_BUNDLE__CURR_DEPTH=0

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
    local depth="${_TILDEPOT_BUNDLE__CURR_DEPTH:?}"

    depth=$((depth + 1))

    while [[ $depth -le $_TILDEPOT_BUNDLE__MAX_EXTEND_DEPTH ]]; do
      local super_fn="bundle::__super_hook_${depth}_${hook_fn}"
      if declare -F "$super_fn" >/dev/null; then
        "$super_fn"
        return "$?"
      fi
      ((depth++))
    done

    # Return 0 on regular hooks to allow for no-op SUPER calls
    # Only return non-zero result on "SKIP" and "${HOOK}_SKIP" functions,
    # because 0-returns indicate a skip match.
    [[ $hook_fn != *'SKIP' ]]
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
  for hook in "${hooks[@]}"; do
    hook_fn="$(bundle::_fmt_hook_fn_hooks "$hook")"
    unset -f "${hook_fn}_SKIP" "${hook_fn}"
  done

  # Load user bundle.
  # shellcheck source=/dev/null
  source "$bundle_file"

  bundle::_load_parent_bundle "$bundle_file"

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

  for hook in "${hooks[@]}"; do
    bundle::_exec_hook "$bundle" "$hook"
  done
}
