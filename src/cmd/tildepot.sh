#!/bin/bash
#
# tildepot
# A command line tool to manage your home setup, including applications,
# dotfiles, preferences, and more.

# shellcheck source-path=../../

source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

function usage() {
  local status="${1:-0}"
  cat <<EOS
tildepot

Manage your home setup, including applications, dotfiles, preferences, and more.
Safe for human consumption.

Usage: tildepot [command] [options]

Available Commands:
  init                      $(bundles_hook_description 'init')
  install                   $(bundles_hook_description 'install')
  update                    $(bundles_hook_description 'update')
  snapshot                  $(bundles_hook_description 'snapshot')
  diff                      [TODO]
  apply                     $(bundles_hook_description 'apply')
  status                    [TODO]
  git                       [TODO]
  dir                       [TODO]

Flags:
  -h, --help                Display this help message
  -C, --repo-dir <path>     Specify a custom tildepot repository path,
                            overriding the default (${tty_bold}${REPO_ROOT}${tty_reset}).
EOS
  exit "$status"
}

function main() {
  if [[ $# -eq 0 ]]; then
    usage 1
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help | help)
      usage
      ;;
    -C | --repo-dir)
      REPO_ROOT="$2"
      shift
      ;;
    -C=* | --repo-dir=*)
      REPO_ROOT="${1#*=}"
      ;;
    init | install | update | snapshot | apply)
      source "$APP_ROOT/src/cmd/tildepot_hook.sh" "$@"
      ;;
    *)
      warn "Unrecognized option: '$1'"
      usage 1
      ;;
    esac
  done

  exit 0
}

main "$@"
