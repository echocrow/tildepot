#!/bin/bash
#
# tildepot hook CLI.

source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

function tildepot_hook_description() {
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

function tildepot_hook_long_description() {
  local hook="$1"

  tildepot_hook_description "$hook"

  case "$hook" in
  init | apply)
    echo "${tty_yellow}Warning${tty_reset}: This will overwrite any changes made to your system since the snapshot was taken."
    ;;
  esac
}

function tildepot_hook_usage() {
  local hook="$1"
  local status="${2:-0}"

  cat <<EOS
tildepot $hook

$(tildepot_hook_long_description "$hook")

Usage: tildepot $hook [options]

Flags:
  -h, --help            Display this help message
  -y, --yes             Answer yes to all prompts
  -f, --force           Force-run '$hook', ignoring skip-checks.
  --bundle BUNDLE       Limit command to one or more bundles
EOS
  exit "$status"
}

function tildepot_hook_main() {
  local hook="$1"
  shift

  local bundles=()
  local yes=
  local force=
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help)
      tildepot_hook_usage "$hook"
      ;;
    --bundle)
      bundles+=("$2")
      shift
      ;;
    --bundle=*)
      bundles+=("${1#*=}")
      ;;
    -y | --yes)
      yes=1
      ;;
    -f | --force)
      force=1
      ;;
    *)
      warn "Unrecognized option: '$1'"
      tildepot_hook_usage "$hook" 1
      ;;
    esac
    shift
  done

  local hooks=()
  case "$hook" in
  init) hooks+=(install update apply) ;;
  *) hooks+=("$hook") ;;
  esac

  for hook in "${hooks[@]}"; do
    if
      [[ "$hook" == 'apply' && ! "$yes" ]] &&
        ! confirm "${tty_bold}Restoring snapshots will ${tty_yellow}override current files & settings.${tty_reset} Continue?"
    then
      abort "Aborting."
    fi

    if [[ "${#bundles[@]}" -gt 0 ]]; then
      invoke_bundles "$hook" "${bundles[@]}"
    else
      invoke_bundles "$hook"
    fi
  done

  exit 0
}
