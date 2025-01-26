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
  unset -f "${hook_fn}" "${hook_fn}_SKIP"
  unset -f "PRE_${hook_fn}" "PRE_${hook_fn}_SKIP"
  unset -f "POST_${hook_fn}" "POST_${hook_fn}_SKIP"
}

function bundles::exec_hook() {
  local bundle="$1"
  local hook="$2"
  local force="$3"

  local bundle_file="$APP_REPO_ROOT/bundles/${bundle}.sh"
  export BUNDLE_DIR="$APP_REPO_ROOT/state/${bundle}"

  bundles::_load_stock_bundle "$bundle"

  # shellcheck source=/dev/null
  source "$bundle_file"

  local hook_fn
  hook_fn="$(echo "$hook" | tr '[:lower:]' '[:upper:]')"

  ! [[ $(type -t "$hook_fn") == function ]] && return

  # Check optional "${HOOK_FN}_SKIP" function
  local hook_skip=
  local hook_skip_fn="${hook_fn}_SKIP"
  if [[ $(type -t "$hook_skip_fn") == function ]] && [[ ! "$force" ]]; then
    local skip_msg=''
    if skip_msg=$($hook_skip_fn); then
      [[ -z "$skip_msg" ]] && hook_skip=1
    fi
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
  $0 _exec-bundle "$bundle" "$hook" "${opts[@]:-}"
}

function bundles::invoke() {
  local hook="$1"
  local force="$2"
  local limit_bundles=("${@:3}")

  local bundles=()
  while read -r line; do bundles+=("$line"); done < <(bundles::_scan_bundles)

  # Limit bundles, but keep sorting.
  if [[ "${#limit_bundles[@]}" -gt 0 ]]; then
    local all_bundles=("${bundles[@]}")
    bundles=()
    # Check for invalid bundles.
    for bundle in "${limit_bundles[@]}"; do
      if ! lib::in_array "$bundle" "${all_bundles[@]}"; then
        lib::abort "Bundle ${txt_bold}${txt_blue}${bundle}${txt_reset} not found."
      fi
    done
    # Collect limited bundles, but keep sorting.
    for bundle in "${all_bundles[@]}"; do
      if lib::in_array "$bundle" "${limit_bundles[@]}"; then
        bundles+=("$bundle")
      fi
    done
  fi

  if [[ "${#bundles[@]}" -eq 0 ]]; then
    lib::abort "No bundles found."
  fi

  for bundle in "${bundles[@]}"; do
    bundles::_invoke_bundle "$bundle" "pre_${hook}" "$force"
  done
  for bundle in "${bundles[@]}"; do
    bundles::_invoke_bundle "$bundle" "${hook}" "$force"
  done
  for bundle in "${bundles[@]}"; do
    bundles::_invoke_bundle "$bundle" "post_${hook}" "$force"
  done
}
