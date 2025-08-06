#!/usr/bin/env bash
#
# tildepot bundle helpers.

# Path to a bundle's (temporary & mutable) state directory. This will be set by
# the bundle runner.
export BUNDLE_STATE_DIR=""
# Path to a bundle's (version-controlled) state directory. This will be set by
# the bundle runner.
export BUNDLE_PREV_STATE_DIR=""

# Maximum depth to recurse when loading parent bundles.
_TILDEPOT_BUNDLE__MAX_EXTEND_DEPTH=5

# List of known hook functions.
_TILDEPOT_BUNDLE__HOOK_FNS=(
  SKIP

  INSTALL_SKIP
  INSTALL

  UPDATE_SKIP
  UPDATE

  SAVE_SKIP
  SAVE

  RESTORE_SKIP
  RESTORE
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
    # Official bundle release.
    *@*)
      [[ ! $parent_bundle =~ ^([a-z0-9_-]+)-bundle@([0-9.]+(-next\.[0-9]+)?)$ ]] &&
        lib::abort "Invalid bundle release format: $parent_bundle"
      local remote_bundle_name="${BASH_REMATCH[1]}"
      local remote_bundle_version="${BASH_REMATCH[2]}"
      local remote_bundle_url="$_TILDEPOT_APP__REPO_URL/releases/download/${remote_bundle_name}-bundle@${remote_bundle_version}/${remote_bundle_name}.sh"
      mkdir -p "$_TILDEPOT_APP__REPO_ROOT/.tildepot/bundles"
      parent_file="$_TILDEPOT_APP__REPO_ROOT/.tildepot/bundles/${remote_bundle_name}_${remote_bundle_version//./-}.sh"
      if [[ ! -f $parent_file ]]; then
        lib::require_confirm \
          "Found new bundle [$remote_bundle_name-bundle v$remote_bundle_version]" \
          "You're about to download this bundle from [$remote_bundle_url]" \
          "Continue?"
        if ! lib::download "$remote_bundle_url" >"$parent_file"; then
          lib::abort "Failed to download bundle [$remote_bundle_name-bundle v$remote_bundle_version]; are you sure it exists?"
        fi
      fi
      ;;
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

  lib::ohai "Skipping [${name}]."
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

  # Prepare
  case "$hook" in
  save)
    mkdir -p "$BUNDLE_STATE_DIR"
    mkdir -p "$BUNDLE_PREV_STATE_DIR"
    ;;
  restore)
    mkdir -p "$(dirname "$BUNDLE_STATE_DIR")"
    mkdir -p "$BUNDLE_PREV_STATE_DIR"
    rm -rf "$BUNDLE_STATE_DIR"
    cp -r "$BUNDLE_PREV_STATE_DIR" "$BUNDLE_STATE_DIR"
    ;;
  esac

  # Check optional "${HOOK}_SKIP" function
  local hook_skip_fn="${hook_fn}_SKIP"
  local hook_skip=
  if declare -F "$hook_skip_fn" >/dev/null && ! app::force; then
    local skip_msg=''
    if ! app::dev "> $hook_skip_fn"; then
      skip_msg="$(bundle::_call_hook_fn "$hook_skip_fn")" && hook_skip=1
    fi
    [[ -n $skip_msg ]] && hook_skip=1
  fi

  if [[ $hook_skip ]]; then
    bundle::_print_skip_reason "${bundle} ${hook}" "$skip_msg"
  else
    lib::ohai "Running [${bundle} ${hook//_/-}]..."
    if ! app::dev "> $hook_fn"; then
      bundle::_call_hook_fn "$hook_fn"
    fi

    printf "\n"
  fi

  # Cleanup
  case "$hook" in
  save)
    rm -rf "$BUNDLE_PREV_STATE_DIR"
    mv "$BUNDLE_STATE_DIR" "$BUNDLE_PREV_STATE_DIR"
    ;;
  restore)
    rm -rf "$BUNDLE_STATE_DIR"
    ;;
  esac
}

function bundle::_fmt_hook_fn_hooks() {
  local hook="$1"
  echo "$hook" | tr '[:lower:]' '[:upper:]'
}

function bundle::_define_super_fn() {
  # shellcheck disable=SC2317,SC2329
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
  export BUNDLE_STATE_DIR="$_TILDEPOT_APP__REPO_ROOT/.tildepot/state/${bundle}"
  export BUNDLE_PREV_STATE_DIR="$_TILDEPOT_APP__REPO_ROOT/state/${bundle}"

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
  local skip=
  if declare -F "$skip_fn" >/dev/null; then
    local skip_msg=''
    if ! app::dev "> $skip_fn"; then
      skip_msg="$(bundle::_call_hook_fn "$skip_fn")" && skip=1
    fi
    [[ -n $skip_msg ]] && skip=1
  fi

  if [[ $skip ]]; then
    bundle::_print_skip_reason "$bundle" "$skip_msg"
  else
    local hook
    for hook in "${hooks[@]}"; do
      bundle::_exec_hook "$bundle" "$hook"
    done
  fi
}
