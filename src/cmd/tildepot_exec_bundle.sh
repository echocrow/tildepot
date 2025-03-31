#!/bin/bash
#
# tildepot bundle execution CLI.

function cmd::usage() {
  cat <<EOS
tildepot

Execute one or more bundle hooks.
This command is intended for internal use only.

Usage: tildepot _exec-bundle [options] BUNDLE HOOK [HOOK...]

Options:
  -h, --help            Display this help message
  -f, --force           Force-run the given bundle hook(s), ignoring skip-checks
EOS
}

function cmd::main() {
  while [[ ${1-} == -* ]]; do
    case $1 in
    -f | --force) app::set_force ;;
    -h | --help) cmd::usage && exit 0 ;;
    *) lib::abort "Unknown option: $1" ;;
    esac
    shift
  done
  while [[ $# -gt 0 && -z $1 ]]; do shift; done

  local bundle_basename="${1-}"
  [[ -z $bundle_basename ]] && lib::abort "Missing bundle"
  shift

  local hooks=("$@")
  [[ ${#hooks[@]} -eq 0 ]] && lib::abort "Missing hooks"

  bundles::exec_hooks "$bundle_basename" "$(lib::join_by "/" "${hooks[@]-}")"

  exit 0
}

cmd::main "$@"
