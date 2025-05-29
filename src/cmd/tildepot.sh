#!/usr/bin/env bash
#
# tildepot
# A command line tool to manage your home setup, including applications,
# dotfiles, preferences, and more.

function cmd::usage() {
  cat <<EOS
tildepot $TILDEPOT_VERSION

Manage your home setup, including applications, dotfiles, preferences, and more.
Safe for human consumption.

Usage: tildepot [options] [command]

Options:
  -h, --help                Display this help message
  -R, --repo-dir <path>     Specify a custom tildepot repository path,
                            overriding the default (${txt_bold}${_TILDEPOT_APP__REPO_ROOT}${txt_reset})
  -v, --version             Display the version of tildepot

Commands:
  apply                     $(bundles::hook_description 'apply')
  diff                      [TODO]
  git                       Execute a git command in the tildepot repository
  init                      Run first-time initialization
  install                   $(bundles::hook_description 'install')
  repo                      Manage your tildepot repository
  self                      Manage tildepot itself
  save                      $(bundles::hook_description 'save')
  status                    [TODO]
  update                    $(bundles::hook_description 'update')
  version                   Display the version of tildepot
EOS
}

function cmd::main() {
  while [[ ${1-} == -* ]]; do
    case $1 in
    -h | --help) cmd::usage && exit 0 ;;
    -R | --repo-dir) _TILDEPOT_APP__REPO_ROOT="$2" && shift ;;
    -v | --version) echo "$TILDEPOT_VERSION" && exit 0 ;;
    *) lib::abort "Unknown option: $1" ;;
    esac
    shift
  done

  [[ -z ${1-} ]] && cmd::usage && exit 1

  case ${1-} in
  apply | install | save | update)
    source "src/cmd/tildepot_hook.sh" "$@"
    ;;
  git)
    git -C "$_TILDEPOT_APP__REPO_ROOT" "${@:2}"
    exit $?
    ;;
  init)
    source "src/cmd/tildepot_init.sh" "${@:2}"
    ;;
  repo)
    source "src/cmd/tildepot_repo.sh" "${@:2}"
    ;;
  self)
    source "src/cmd/tildepot_self.sh" "${@:2}"
    ;;
  version)
    echo "$TILDEPOT_VERSION"
    ;;
  _exec-bundle)
    source "src/cmd/tildepot_exec_bundle.sh" "${@:2}"
    ;;
  help)
    cmd::usage
    ;;
  *)
    lib::abort "Unknown command: $1"
    ;;
  esac
}

cmd::main "$@"
