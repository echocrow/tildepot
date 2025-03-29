#!/bin/bash
#
# tildepot bundles helpers.

source "$(dirname "${BASH_SOURCE[0]}")/txt.sh"

# Path to a bundle's directory. This will be set by the bundles loader.
export BUNDLE_DIR=""

function bundles::hook_description() {
  local hook="$1"

  case "$hook" in
  init) echo "Run first-time initialization. Runs ${txt_bold}install${txt_reset}, ${txt_bold}update${txt_reset}, and ${txt_bold}apply${txt_reset}." ;;
  install) echo "Run first-time install steps." ;;
  update) echo "Update commands & applications." ;;
  snapshot) echo "Store (export) a snapshot of the current state of your system." ;;
  apply) echo "Restore (import) the current snapshot into your system." ;;
  *) lib::abort "Unknown hook '$hook'" ;;
  esac
}

function bundles::_load_stock_bundle() {
  local bundle="$1"

  # Load a well-known bundle.
  # This could be streamlined, but listing them here simplifies build.
  # shellcheck source=/dev/null
  case "$bundle" in
  brew) source "$APP_ROOT/src/bundles/brew.sh" ;;
  cron) source "$APP_ROOT/src/bundles/cron.sh" ;;
  files) source "$APP_ROOT/src/bundles/files.sh" ;;
  fish) source "$APP_ROOT/src/bundles/fish.sh" ;;
  pnpm) source "$APP_ROOT/src/bundles/pnpm.sh" ;;
  esac
}

function bundles::_scan_bundles() {
  find "$APP_REPO_ROOT/bundles" -type f -name '*.sh' -mindepth 1 -maxdepth 1 |
    sort |
    xargs -I {} basename {} '.sh'
}

function bundles::_unset_bundle_hook_fn() {
  local hook_fn="$1"
  unset -f "${hook_fn}_SKIP" "${hook_fn}"
}

function bundles::exec_hook() {
  local bundle="$1"
  local hook="$2"
  local force="$3"

  local bundle_file="$APP_REPO_ROOT/bundles/${bundle}.sh"
  BUNDLE_DIR="$APP_REPO_ROOT/state/${bundle}"

  bundles::_load_stock_bundle "$bundle"

  # shellcheck source=/dev/null
  source "$bundle_file"

  local hook_fn
  hook_fn="$(echo "$hook" | tr '[:lower:]' '[:upper:]')"

  ! declare -F "$hook_fn" >/dev/null && return

  # Check optional "${HOOK_FN}_SKIP" function
  local hook_skip_fn="${hook_fn}_SKIP"
  if declare -F "$hook_skip_fn" >/dev/null && [[ ! "$force" ]]; then
    local skip_msg=''
    local hook_skip=
    skip_msg="$($hook_skip_fn)" && hook_skip=1
    if [[ -n "$skip_msg" || $hook_skip ]]; then
      lib::ohai "Skipping ${txt_bold}${txt_blue}${bundle} ${hook}${txt_reset}."
      [[ -n "$skip_msg" ]] && tilde::warning "Reason: ${skip_msg}."
      return
    fi
  fi

  lib::ohai "Running ${txt_blue}${bundle} ${hook//_/-}${txt_reset}..."

  case "$hook" in
  snapshot)
    mkdir -p "$APP_REPO_ROOT/state/${bundle}"
    ;;
  esac

  $hook_fn

  printf "\n"
}

function bundles::_invoke_bundle() {
  local bundle="$1"
  local hook="$2"
  local force="$3"

  local opts=()
  [[ "$force" ]] && opts+=('--force')

  # Spawn a new process to avoid leaking variables/functions.
  "$0" _exec-bundle "$bundle" "$hook" "${opts[@]:-}"
}

function bundles::invoke() {
  local hooks=() && IFS='/' read -ra hooks <<<"$1"
  local bundles=() && IFS='/' read -ra bundles <<<"$2"
  local yes="$3"
  local force="$4"

  if [[ "${#hooks[@]}" -eq 0 ]]; then
    lib::abort "No hooks specified."
  fi

  local all_bundles=()
  while read -r bundle; do all_bundles+=("$bundle"); done < <(bundles::_scan_bundles)

  if [[ "${#bundles[@]}" -eq 0 ]]; then
    bundles=("${all_bundles[@]}")
  else
    for bundle in "${bundles[@]}"; do
      if ! lib::in_array "$bundle" "${all_bundles[@]}"; then
        lib::abort "Bundle ${txt_bold}${txt_blue}${bundle}${txt_reset} not found."
      fi
    done
  fi

  if [[ "${#bundles[@]}" -eq 0 ]]; then
    lib::abort "No bundles found."
  fi

  if lib::in_array 'apply' "${hooks[@]}" && [[ ! "$yes" ]] &&
    ! lib::confirm "${txt_bold}Restoring snapshots will ${txt_yellow}override current files & settings.${txt_reset} Continue?"; then
    lib::abort "Aborting."
  fi

  for bundle in "${bundles[@]}"; do
    for hook in "${hooks[@]}"; do
      bundles::_invoke_bundle "$bundle" "${hook}" "$force"
    done
  done
}
