#!/bin/bash
#
# tildepot hook CLI.

source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

function description() {
  local hook="$1"

  bundles_hook_description "$hook"

  case "$hook" in
  init | apply)
    echo "${tty_yellow}Warning${tty_reset}: This will overwrite any changes made to your system since the snapshot was taken."
    ;;
  esac
}

function usage() {
  local hook="$1"
  local status="${2:-0}"

  cat <<EOS
tildepot $hook

$(description "$hook")

Usage: tildepot $hook [options]

Flags:
  -h, --help            Display this help message
  -y, --yes             Answer yes to all prompts
  -f, --force           Force-run '$hook', ignoring skip-checks.
  --bundle BUNDLE       Limit command to one or more bundles
EOS
  exit "$status"
}

function main() {
  local hook="$1"
  shift

  local bundles=()
  local yes=
  local force=
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help)
      usage "$hook"
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
      usage "$hook" 1
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
      invoke_bundles "$hook" "$force" "${bundles[@]}"
    else
      invoke_bundles "$hook" "$force"
    fi
  done

  exit 0
}

main "$@"
