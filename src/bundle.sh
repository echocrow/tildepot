#!/bin/bash
#
# tildepot bundle helpers.

source "$(dirname "${BASH_SOURCE[0]}")/txt.sh"

# Path to a bundle's directory. This will be set by the bundles loader.
export BUNDLE_DIR=""

function bundle::fmt_bundle_name() {
  local basename="$1"
  # Trim leading numbers (presumed for file sorting).
  echo "${basename##[0-9]* }"
}

function bundle::_load_parent_bundle() {
  local child_bundle_file="${1?}"
  local depth="${2:-0}"

  local parent_bundle="${EXTEND:-}"
  if [[ -z $parent_bundle ]]; then
    return 0
  fi
  if [[ $depth -ge 5 ]]; then
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

  unset 'EXTEND'

  # shellcheck source=/dev/null
  source "$parent_file"

  # Recursively load parent bundle.
  bundle::_load_parent_bundle "$parent_file" "$((depth + 1))"

  # Reload child bundle to override stock bundle.
  # shellcheck source=/dev/null
  source "$child_bundle_file"
}

function bundle::_exec_hook() {
  local bundle="$1"
  local hook="$2"

  local hook_fn
  hook_fn="$(bundle::_fmt_hook_fn_hooks "$hook")"

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

function bundle::_fmt_hook_fn_hooks() {
  local hook="$1"
  echo "$hook" | tr '[:lower:]' '[:upper:]'
}

function bundle::exec_hooks() {
  local bundle_basename="$1"
  local hooks=("${@:2}")

  local bundle
  bundle="$(bundle::fmt_bundle_name "$bundle_basename")"

  local bundle_file="$APP_REPO_ROOT/bundles/${bundle_basename}.sh"
  export BUNDLE_DIR="$APP_REPO_ROOT/state/${bundle}"

  unset 'EXTEND'
  unset -f 'SKIP'
  local hook_fn
  for hook in "${hooks[@]}"; do
    hook_fn="$(bundle::_fmt_hook_fn_hooks "$hook")"
    unset -f "${hook_fn}_SKIP" "${hook_fn}"
  done

  # Load user bundle.
  # shellcheck source=/dev/null
  source "$bundle_file"

  bundle::_load_parent_bundle "$bundle_file"

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
    bundle::_exec_hook "$bundle" "$hook"
  done
}
