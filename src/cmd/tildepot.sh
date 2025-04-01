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
  apply                     $(bundles::hook_description 'apply')
  diff                      [TODO]
  git                       Execute a git command in the tildepot repository
  init                      Run first-time initialization
  install                   $(bundles::hook_description 'install')
  repo                      Manage your tildepot repository
  self                      Manage tildepot itself
  snapshot                  $(bundles::hook_description 'snapshot')
  status                    [TODO]
  update                    $(bundles::hook_description 'update')
  version                   Display the version of tildepot
EOS
}

function cmd::main() {
  while [[ ${1-} == -* ]]; do
    case $1 in
    -h | --help) cmd::usage && exit 0 ;;
    -R | --repo-dir) APP_REPO_ROOT="$2" && shift ;;
    *) abort "Unknown option: $1" ;;
    esac
    shift
  done

  case ${1-} in
  apply | install | snapshot | update)
    source "$APP_ROOT/src/cmd/tildepot_hook.sh" "$@"
    ;;
  git)
    git -C "$APP_REPO_ROOT" "${@:2}"
    exit $?
    ;;
  init)
    source "$APP_ROOT/src/cmd/tildepot_init.sh" "${@:2}"
    ;;
  repo)
    source "$APP_ROOT/src/cmd/tildepot_repo.sh" "${@:2}"
    ;;
  self)
    source "$APP_ROOT/src/cmd/tildepot_self.sh" "${@:2}"
    ;;
  version)
    echo "tildepot $TILDEPOT_VERSION"
    ;;
  _exec-bundle)
    source "$APP_ROOT/src/cmd/tildepot_exec_bundle.sh" "${@:2}"
    ;;
  help | '') cmd::usage ;;
  *) abort "Unknown command: $1" ;;
  esac
}

cmd::main "$@"
