#!/bin/bash
#
# tildepot
# A command line tool to manage your home setup, including applications,
# dotfiles, preferences, and more.

# shellcheck source-path=../../

source "$(dirname "${BASH_SOURCE[0]}")/../txt.sh"

function cmd::usage() {
  cat <<EOS
tildepot $TILDEPOT_VERSION

Manage your home setup, including applications, dotfiles, preferences, and more.
Safe for human consumption.

Usage: tildepot [options] [command]

Options:
  -h, --help                Display this help message
  -R, --repo-dir <path>     Specify a custom tildepot repository path,
                            overriding the default (${txt_bold}${APP_REPO_ROOT}${txt_reset})

Commands:
  init                      Run first-time initialization
  install                   $(bundles::hook_description 'install')
  update                    $(bundles::hook_description 'update')
  snapshot                  $(bundles::hook_description 'snapshot')
  diff                      [TODO]
  apply                     $(bundles::hook_description 'apply')
  status                    [TODO]
  git                       Execute a git command in the tildepot repository
  dir                       [TODO]
  version                   Display the version of tildepot
  self                      Manage tildepot itself
EOS
}

function cmd::main() {
  while [[ ${1-} == -* ]]; do
    case $1 in
    -R | --repo-dir) APP_REPO_ROOT="$2" && shift ;;
    -h | --help) cmd::usage && exit 0 ;;
    *) abort "Unknown option: $1" ;;
    esac
    shift
  done

  case ${1-} in
  init)
    source "$APP_ROOT/src/cmd/tildepot_init.sh" "${@:2}"
    ;;
  install | update | snapshot | apply)
    source "$APP_ROOT/src/cmd/tildepot_hook.sh" "$@"
    ;;
  git)
    git -C "$APP_REPO_ROOT" "${@:2}"
    exit $?
    ;;
  version)
    echo "tildepot $TILDEPOT_VERSION"
    ;;
  self)
    source "$APP_ROOT/src/cmd/tildepot_self.sh" "${@:2}"
    ;;
  _exec-bundle)
    source "$APP_ROOT/src/cmd/tildepot_exec_bundle.sh" "${@:2}"
    ;;
  help | '') cmd::usage ;;
  *) abort "Unknown command: $1" ;;
  esac
}

cmd::main "$@"
