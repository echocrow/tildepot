#!/bin/bash
#
# tildepot hook CLI.

source "$(dirname "${BASH_SOURCE[0]}")/../txt.sh"

function cmd::usage() {
  cat <<EOS
tildepot init

Run first-time initialization, performing the following actions:
- Invoke bundles, executing hooks for ${txt_bold}install${txt_reset}, ${txt_bold}apply${txt_reset}, and${txt_bold}update${txt_reset}
$(bundles::print_apply_warning)

Usage: tildepot init [options]

Options:
  -y, --yes             Answer yes to all prompts
  -f, --force           Force-run hooks, ignoring skip-checks
  --bundle BUNDLE       Limit command to one or more bundles
  -h, --help            Display this help message
EOS
}

function cmd::main() {
  local bundles=()
  while [[ ${1-} == -* ]]; do
    case $1 in
    -y | --yes) app::set_yes ;;
    -f | --force) app::set_force ;;
    --bundle) bundles+=("$2") && shift ;;
    -h | --help) cmd::usage && exit 0 ;;
    *) lib::abort "Unknown option: $1" ;;
    esac
    shift
  done

  local hooks=(install apply update)
  bundles::invoke \
    "$(lib::join_by "/" "${bundles[@]-}")" \
    "$(lib::join_by "/" "${hooks[@]-}")"

  exit 0
}

cmd::main "$@"
