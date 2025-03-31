#!/bin/bash
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
  -y, --yes             Answer yes to all prompts
  -p, --path            Specify a custom tildepot path

Available Commands:
  install               Add tildepot in your PATH.
  update                Update tildepot.
  uninstall             Remove tildepot from your PATH.
EOS
}

function cmd::main() {
  local yes=
  local path=
  local args=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -y | --yes) yes=1 ;;
    -p | --path) path="$2" && shift ;;
    -h | --help | help) cmd::usage && exit 0 ;;
    -*) lib::fatal "Unknown option: $1" ;;
    *) args+=("$1") ;;
    esac
    shift
  done

  local cmd
  cmd="$(lib::get_cmd "${args[@]-}")"
  [[ -z $cmd ]] && cmd::usage && exit

  case "$cmd" in
  install) self::install "$path" "$yes" ;;
  update) self::update "$path" "$yes" ;;
  uninstall) self::uninstall "$path" "$yes" ;;
  *) lib::fatal "Unknown command: $cmd" ;;
  esac
}

cmd::main "$@"
