#!/usr/bin/env bash
#
# tildepot self CLI.

source "$(dirname "${BASH_SOURCE[0]}")/../txt.sh"

function cmd::usage() {
  cat <<EOS
tildepot self

Manage tildepot itself.

Usage: tildepot self [options] [command]

Options:
  -h, --help            Display this help message
  -p, --path            Specify a custom tildepot path
  -y, --yes             Answer yes to all prompts

Commands:
  install               Add tildepot in your PATH
  uninstall             Remove tildepot from your PATH
  update                Update tildepot
EOS
}

function cmd::main() {
  local path=
  local args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help) cmd::usage && exit 0 ;;
    -p | --path) path="$2" && shift ;;
    -y | --yes) app::set_yes ;;
    -*) lib::abort "Unknown option: $1" ;;
    *) args+=("$1") ;;
    esac
    shift
  done

  local cmd
  cmd="$(lib::get_cmd "${args[@]-}")"
  [[ -z $cmd ]] && cmd::usage && exit 1

  case "$cmd" in
  install) self::install "$path" ;;
  uninstall) self::uninstall "$path" ;;
  update) self::update "$path" ;;
  *) lib::abort "Unknown command: $cmd" ;;
  esac
}

cmd::main "$@"
