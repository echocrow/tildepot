#!/usr/bin/env bash
#
# Internal tildepot bundle execution CLI.

function cmd::usage() {
  cat <<EOS
tildepot

Execute one or more bundle hooks.
This command is intended for internal use only.

Usage: tildepot _exec-bundle [options] BUNDLE HOOK [HOOK...]

Options:
  -f, --force           Force-run the given bundle hook(s), ignoring skip-checks
  -h, --help            Display this help message
  -y, --yes             Answer yes to all prompts
EOS
}

function cmd::main() {
  while [[ ${1-} == -* ]]; do
    case $1 in
    -f | --force) app::set_force ;;
    -h | --help) cmd::usage && exit 0 ;;
    -y | --yes) app::set_yes ;;
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

  bundle::exec_hooks "$bundle_basename" "${hooks[@]}"

  exit 0
}

cmd::main "$@"
