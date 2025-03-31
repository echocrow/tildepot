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
  cat <<EOS
tildepot $hook

$(cmd::description "$hook")

Usage: tildepot $hook [options]

Options:
  -h, --help            Display this help message
  -y, --yes             Answer yes to all prompts
  -f, --force           Force-run '$hook', ignoring skip-checks.
  --bundle BUNDLE       Limit command to one or more bundles
EOS
}

function cmd::main() {
  local hook="${1-}"
  [[ -z $hook ]] && lib::fatal "No hook specified"
  shift

  local yes=
  local force=
  local bundles=()
  while [[ ${1-} == -* ]]; do
    case $1 in
    -y | --yes) yes=1 ;;
    -f | --force) force=1 ;;
    --bundle) bundles+=("$2") && shift ;;
    -h | --help) cmd::usage "$hook" && exit 0 ;;
    *) lib::fatal "Unknown option: $1" ;;
    esac
    shift
  done

  local hooks=("$hook")
  [[ $hook == init ]] && hooks=(install apply update)

  bundles::invoke \
    "$(lib::join_by "/" "${bundles[@]-}")" \
    "$(lib::join_by "/" "${hooks[@]-}")" \
    "$yes" \
    "$force"

  exit 0
}

cmd::main "$@"
