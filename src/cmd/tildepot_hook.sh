#!/bin/bash
#
# tildepot hook CLI.

source "$(dirname "${BASH_SOURCE[0]}")/../txt.sh"

function cmd::description() {
  local hook="$1"

  bundles::hook_description "$hook"

  case "$hook" in
  init | apply)
    echo "${txt_yellow}Warning${txt_reset}: This will overwrite any changes made to your system since the snapshot was taken."
    ;;
  esac
}

function cmd::usage() {
  local hook="$1"
  local status="${2:-0}"

  cat <<EOS
tildepot $hook

$(cmd::description "$hook")

Usage: tildepot $hook [options]

Flags:
  -h, --help            Display this help message
  -y, --yes             Answer yes to all prompts
  -f, --force           Force-run '$hook', ignoring skip-checks.
  --bundle BUNDLE       Limit command to one or more bundles
EOS
  exit "$status"
}

function cmd::main() {
  local hook="$1"
  shift

  local bundles=()
  local yes=
  local force=
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help)
      cmd::usage "$hook"
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
      lib::warn "Unrecognized option: '$1'"
      cmd::usage "$hook" 1
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
        ! lib::confirm "${txt_bold}Restoring snapshots will ${txt_yellow}override current files & settings.${txt_reset} Continue?"
    then
      lib::abort "Aborting."
    fi

    if [[ "${#bundles[@]}" -gt 0 ]]; then
      bundles::invoke "$hook" "$force" "${bundles[@]}"
    else
      bundles::invoke "$hook" "$force"
    fi
  done

  exit 0
}

cmd::main "$@"
