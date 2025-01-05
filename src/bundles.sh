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

function scan_bundles() {
  # Read bundles and their weights
  local entries=''
  local bundle
  while read -r file; do
    bundle="$(basename "$file" '.sh')"

    load_bundle "$bundle"
    weight="${WEIGHT:-50}"

    entries+="$weight"$'\t'"$bundle"$'\n'
  done < <(find "$APP_ROOT/bundles" -type f -name '*.sh' -mindepth 1 -maxdepth 1)

  # Sort and output bundle names
  chomp "$entries" | sort -n | cut -f2
}

function load_bundle() {
  local bundle="$1"

  # Reset bundle variables & functions
  unset -v WEIGHT
  unset -f INSTALL UPDATE SNAPSHOT DIFF APPLY

  local bundle_file="$APP_ROOT/bundles/${bundle}.sh"
  export BUNDLE_DIR="$REPO_ROOT/state/${bundle}"

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

  ! [[ $(type -t $hook_fn) == function ]] && return

  # Check optional "${HOOK_FN}_SKIP" function
  local hook_skip=
  local hook_skip_fn="${hook_fn}_SKIP"
  if [[ $(type -t $hook_skip_fn) == function ]] && [[ ! "$force" ]]; then
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

  ohai_app "Running ${tty_blue}${bundle} ${hook}${tty_reset}..."
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

  while read -r bundle; do
    if [[ "${#limit_bundles[@]}" -gt 0 ]] && ! in_array "$bundle" "${limit_bundles[@]}"; then
      continue
    fi
    invoke_bundle "$bundle" "$hook" "$force"
  done < <(scan_bundles)
}
