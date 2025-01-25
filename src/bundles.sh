#!/bin/bash
#
# tildepot bundles helpers.

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

function bundles_hook_description() {
  local hook="$1"

  case "$hook" in
  init) echo "Run first-time initialization. Runs ${tty_bold}install${tty_reset}, ${tty_bold}update${tty_reset}, and ${tty_bold}apply${tty_reset}." ;;
  install) echo "Run first-time install steps." ;;
  update) echo "Update commands & applications" ;;
  snapshot) echo "Store (export) a snapshot of the current state of your system." ;;
  apply) echo "Restore (import) the current snapshot into your system." ;;
  *) abort "Unknown hook '$hook'" ;;
  esac
}

function load_stock_bundle() {
  local bundle="$1"

  # Load a well-known bundle.
  # This could be streamlined, but listing them here simplifies build.
  # shellcheck source=/dev/null
  case "$bundle" in
  brew) source "$APP_ROOT/src/bundles/brew.sh" ;;
  cron) source "$APP_ROOT/src/bundles/cron.sh" ;;
  fish) source "$APP_ROOT/src/bundles/fish.sh" ;;
  pnpm) source "$APP_ROOT/src/bundles/pnpm.sh" ;;
  esac
}

function scan_bundles() {
  find "$REPO_ROOT/bundles" -type f -name '*.sh' -mindepth 1 -maxdepth 1 |
    sort |
    xargs -I {} basename {} '.sh'
}

function unset_bundle_hook_fn() {
  local hook_fn="$1"
  unset -f "${hook_fn}" "${hook_fn}_SKIP"
  unset -f "PRE_${hook_fn}" "PRE_${hook_fn}_SKIP"
  unset -f "POST_${hook_fn}" "POST_${hook_fn}_SKIP"
}

function load_bundle() {
  local bundle="$1"

  # Reset bundle variables & functions
  unset_bundle_hook_fn INSTALL
  unset_bundle_hook_fn UPDATE
  unset_bundle_hook_fn SNAPSHOT
  unset_bundle_hook_fn DIFF
  unset_bundle_hook_fn APPLY

  local bundle_file="$REPO_ROOT/bundles/${bundle}.sh"
  export BUNDLE_DIR="$REPO_ROOT/state/${bundle}"

  load_stock_bundle "$bundle"

  # shellcheck source=/dev/null
  source "$bundle_file"
}

function invoke_bundle() {
  local bundle="$1"
  local hook="$2"
  local force="$3"

  load_bundle "$bundle"

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
      ohai_app "Skipping ${tty_bold}${tty_blue}${bundle} ${hook}${tty_reset}."
      [[ -n "$skip_msg" ]] && ohai_warning "Reason: ${skip_msg}."
      return
    fi
  fi

  ohai_app "Running ${tty_blue}${bundle} ${hook//_/-}${tty_reset}..."
  invoke_bundle_pre "$bundle" "$hook"
  $hook_fn
  printf "\n"
}

function invoke_bundle_pre() {
  local bundle="$1"
  local hook="$2"

  case "$hook" in
  snapshot)
    mkdir -p "$BUNDLE_DIR"
    ;;
  esac
}

function invoke_bundles() {
  local hook="$1"
  local force="$2"
  local limit_bundles=("${@:3}")

  local bundles=()
  while read -r line; do bundles+=("$line"); done < <(scan_bundles)

  # Limit bundles, but keep sorting.
  if [[ "${#limit_bundles[@]}" -gt 0 ]]; then
    local all_bundles=("${bundles[@]}")
    bundles=()
    for bundle in "${all_bundles[@]}"; do
      in_array "$bundle" "${limit_bundles[@]}" && bundles+=("$bundle")
    done
  fi

  for bundle in "${bundles[@]}"; do
    invoke_bundle "$bundle" "pre_${hook}" "$force"
  done
  for bundle in "${bundles[@]}"; do
    invoke_bundle "$bundle" "${hook}" "$force"
  done
  for bundle in "${bundles[@]}"; do
    invoke_bundle "$bundle" "post_${hook}" "$force"
  done
}
