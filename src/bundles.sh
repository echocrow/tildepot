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
    bundle="$(dirname "$file" | xargs basename)"

    load_bundle "$bundle"
    weight="${WEIGHT:-50}"

    entries+="$weight"$'\t'"$bundle"$'\n'
  done < <(find "$REPO_ROOT/bundles" -type f -name 'bundle.sh' -mindepth 2 -maxdepth 2)

  # Sort and output bundle names
  chomp "$entries" | sort -n | cut -f2
}

function load_bundle() {
  local bundle="$1"

  # Reset bundle variables & functions
  unset -v WEIGHT
  unset -f INSTALL UPDATE SNAPSHOT DIFF APPLY

  local bundle_file="$REPO_ROOT/bundles/$bundle/bundle.sh"
  export BUNDLE_DIR="$REPO_ROOT/bundles/$bundle"

  # shellcheck source=/dev/null
  source "$bundle_file"
}

function invoke_bundle() {
  local bundle="$1"
  local hook="$2"
  local force="$3"
  local fifo="$4"

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
      ohai "Skipping ${tty_bold}${tty_blue}${bundle} ${hook}${tty_reset}."
      [[ -n "$skip_msg" ]] && ohai_warning "Reason: ${skip_msg}."
      return
    fi
  fi

  ohai "Running ${tty_blue}${bundle} ${hook}${tty_reset}..."
  invoke_bundle_fn "$hook_fn" "$fifo"
  printf "\n"
}

function invoke_bundle_fn() {
  local hook_fn="$1"
  local fifo="$2"

  # Invoke bundle hook, and alter the output
  $hook_fn >"$fifo" 2>&1 &
  while IFS= read -r line <&3 || [[ -n "$line" ]]; do
    fmt_bundle_output "$line"
  done 3<"$fifo"
}

function fmt_bundle_output() {
  local line="$1"
  [[ ! "$line" =~ ^['ℹ️✅⚠️❌'] ]] && echo "$line" && return

  local color="${tty_blue}"
  local icon="${line:0:2}"
  case "${icon%% }" in
  '✅') color="${tty_green}" ;;
  '❌') color="${tty_red}" ;;
  '⚠️') color="${tty_yellow}" ;;
  esac
  line=${line:2}
  line="${line## }"

  # Simplify repository paths.
  line="${line//$REPO_ROOT\//}"

  # Highlight brackets.
  line="${line//\[/$tty_blue}"
  line="${line//\]/$tty_reset}"

  echo "${color}==> ${tty_reset}${line}${tty_reset}"
}

function invoke_bundles() {
  local hook="$1"
  local force="$2"
  local limit_bundles=("${@:3}")

  # Create a named pipe
  local fifo
  fifo=$(mktemp -u)
  mkfifo "$fifo"

  while read -r bundle; do
    if [[ "${#limit_bundles[@]}" -gt 0 ]] && ! in_array "$bundle" "${limit_bundles[@]}"; then
      continue
    fi
    invoke_bundle "$bundle" "$hook" "$force" "$fifo"
  done < <(scan_bundles)

  # Clean up
  rm "$fifo"
}
