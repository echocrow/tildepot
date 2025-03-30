#!/bin/bash
#
# tildepot bundle execution CLI.

function cmd::usage() {
  local status="${1:-0}"

  cat <<EOS
tildepot

Execute a bundle hook.
This command is intended for internal use only.

Usage: tildepot _exec-bundle BUNDLE_BASENAME HOOK [HOOK...] [options]

Flags:
  -h, --help            Display this help message
  -f, --force           Force-run the given hook, ignoring skip-checks.
EOS
  exit "$status"
}

function cmd::main() {
  local bundle_basename="$1"
  shift

  local hooks=()

  local force=
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help | help)
      cmd::usage
      ;;
    -f | --force)
      force=1
      ;;
    '') ;;
    -*)
      lib::warn "Unrecognized option: '$1'"
      cmd::usage 1
      ;;
    *)
      hooks+=("$1")
      ;;
    esac
    shift
  done

  bundles::exec_hooks "$bundle_basename" "$(lib::join_by "/" "${hooks[@]-}")" "$force"

  exit 0
}

cmd::main "$@"
