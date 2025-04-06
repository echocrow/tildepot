#!/bin/bash
#
# tildepot self CLI.

source "$(dirname "${BASH_SOURCE[0]}")/../txt.sh"

function cmd::usage() {
  cat <<EOS
tildepot self

Manage your tildepot repository.

Usage: tildepot self [options] [command]

Options:
  -h, --help              Display this help message
  -O, --repo <path>       Specify a tildepot repository origin URL.
  -R, --repo-dir <path>   Specify a custom tildepot repository path,
                          overriding the default (${txt_bold}${APP_REPO_ROOT}${txt_reset})

Commands:
  create                  Create a new tildepot repository
  download                Download tildepot repository
  open                    Open the tildepot repository in your file browser
EOS
}

function cmd::main() {
  local repo_origin=
  local args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help | help) cmd::usage && exit 0 ;;
    -O | --repo) repo_origin="$2" && shift ;;
    -R | --repo-dir) APP_REPO_ROOT="$2" && shift ;;
    -*) lib::abort "Unknown option: $1" ;;
    *) args+=("$1") ;;
    esac
    shift
  done

  local cmd
  cmd="$(lib::get_cmd "${args[@]-}")"
  [[ -z $cmd ]] && cmd::usage && exit 1

  case "$cmd" in
  create) repo::create "$repo_origin" ;;
  download) repo::download "$repo_origin" ;;
  open) repo::open ;;
  *) lib::abort "Unknown command: $cmd" ;;
  esac
}

cmd::main "$@"
