#!/bin/bash
#
# tildepot hook CLI.

source "$(dirname "${BASH_SOURCE[0]}")/../txt.sh"

function cmd::usage() {
  local hook="$1"
  cat <<EOS
tildepot $hook

$(
    bundles::hook_description "$hook"
    [[ "$hook" == 'apply' ]] && bundles::print_apply_warning
  )

Usage: tildepot $hook [options]

Options:
  -b, --bundle BUNDLE   Limit command to one or more bundles
  -f, --force           Force-run '$hook', ignoring skip-checks
  -h, --help            Display this help message
  -y, --yes             Answer yes to all prompts
EOS
}

function cmd::main() {
  local hook="${1-}"
  [[ -z $hook ]] && lib::abort "No hook specified"
  shift

  local bundles=()
  while [[ ${1-} == -* ]]; do
    case $1 in
    -b | --bundle) bundles+=("$2") && shift ;;
    -f | --force) app::set_force ;;
    -h | --help) cmd::usage "$hook" && exit 0 ;;
    -y | --yes) app::set_yes ;;
    *) lib::abort "Unknown option: $1" ;;
    esac
    shift
  done

  bundles::invoke \
    "$(lib::join_by "/" "${bundles[@]-}")" \
    "$hook"

  exit 0
}

cmd::main "$@"
