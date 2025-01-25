#!/bin/bash
#
# tildepot hook CLI.

source "$(dirname "${BASH_SOURCE[0]}")/../txt.sh"

function cmd::usage() {
  local status="${1:-0}"

  cat <<EOS
tildepot

Execute a bundle hook.
This command is intended for internal use only.

Usage: tildepot _exec-bundle BUNDLE HOOK [options]

Flags:
  -h, --help            Display this help message
  -f, --force           Force-run the given hook, ignoring skip-checks.
EOS
  exit "$status"
}

function cmd::main() {
  local bundle="$1"
  local hook="$2"
  shift 2

  local force=
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help)
      cmd::usage
      ;;
    -f | --force)
      force=1
      ;;
    '') ;;
    *)
      lib::warn "Unrecognized option: '$1'"
      cmd::usage "$hook" 1
      ;;
    esac
    shift
  done

  bundles::exec_hook "$bundle" "$hook" "$force"

  exit 0
}

cmd::main "$@"
