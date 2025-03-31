#!/bin/bash
#
# A collection of useful functions for tildepot.

# Handle repeated imports
[[ -n "${__TILDEPOT_LIB:-}" ]] && return # tildepot-build ignore
__TILDEPOT_LIB=1                         # tildepot-build ignore

source "$(dirname "${BASH_SOURCE[0]}")/txt.sh"

# Print optional error messages to stderr and exit
function lib::abort() {
  case $# in
  0) echo "${txt_red}Error.${txt_reset}" >&2 ;;
  1) echo "${txt_red}Error:${txt_reset}" "$(lib::_fmt_msg "$1")" >&2 ;;
  *)
    echo "${txt_red}Error:${txt_reset}" >&2
    for msg in "$@"; do
      echo "  $(lib::_fmt_msg "$msg")" >&2
    done
    ;;
  esac
  exit 1
}

# Print optional warning messages to stderr
function lib::warn() {
  case $# in
  0) echo "${txt_yellow}Warning.${txt_reset}" >&2 ;;
  1) echo "${txt_yellow}Warning:${txt_reset}" "$(lib::_fmt_msg "$1")" >&2 ;;
  *)
    echo "${txt_yellow}Warning:${txt_reset}" >&2
    for msg in "$@"; do
      echo "  $(lib::_fmt_msg "$msg")" >&2
    done
    ;;
  esac
}

# Print an app-level message to stdout
# Source: https://github.com/Homebrew/install/blob/master/install.sh
function lib::ohai() {
  local msg="$1"
  printf "${txt_bold}${txt_blue}=>${txt_bold} %s${txt_reset}\n" "$(lib::_fmt_msg "$msg")"
}

# Format a message for logs, simplifying paths and injecting highlights
function lib::_fmt_msg() {
  local line="$1"

  # Simplify repository paths.
  [ -n "${APP_REPO_ROOT+x}" ] && line="${line//$APP_REPO_ROOT\//}"

  # Highlight brackets.
  line="${line// \[/ $txt_blue}"
  line="${line//\]/$txt_reset}"

  echo -n "$line"
}

# Prompt for a yes/no confirmation
function lib::_confirm() {
  app::yes && return 0

  local default=
  case ${1-} in
  -y | --yes) default=y && shift ;;
  -n | --no) default=n && shift ;;
  esac

  while [[ $# -gt 1 ]]; do
    echo "${txt_bold}${txt_blue}!)${txt_reset} $(lib::_fmt_msg "$1")"
    shift
  done

  local msg
  msg="$(lib::_fmt_msg "$1")"

  local opts='[y/n]'
  [[ "$default" == 'y' ]] && opts='[Y/n]'
  [[ "$default" == 'n' ]] && opts='[y/N]'

  local yn
  while true; do
    read -r -p "${txt_bold}${txt_blue}?)${txt_reset} $msg $opts " yn
    [[ -z "$yn" ]] && yn="$default"
    case "$yn" in
    [Yy]*) return 0 ;;
    [Nn]*) return 1 ;;
    *) ;;
    esac
  done
}

# Require confirmation of a yes/no prompt
function lib::require_confirm() {
  lib::_confirm "$@" || lib::abort 'User aborted.'
}

# Check if an array contains a value
function lib::in_array() {
  local value="$1"
  local array=("${@:2}")
  for v in "${array[@]}"; do
    [[ "$v" == "$value" ]] && return 0
  done
  return 1
}

# Get the index of an array element
function lib::array_index() {
  local value="$1"
  local array=("${@:2}")
  for i in "${!array[@]}"; do
    [[ "${array[i]}" == "$value" ]] && echo "$i" && return
  done
  return 1
}

# Cross-platform `sed`
function lib::sed() {
  if [[ "$OSTYPE" == "linux-gnu" ]]; then
    sed -i "$@"
  else
    sed -i '' "$@"
  fi
}

# Join a list of arguments with a given separator
# Example:
#     lib::join_by "::" "${my_array[@]-}"
function lib::join_by() {
  local IFS="$1"
  shift
  echo "$*"
}

# Get the sole command from a list of arguments
# Example:
#     lib::get_cmd "${args[@]-}"
function lib::get_cmd() {
  local cmd=
  while [[ $# -gt 0 ]]; do
    case $1 in
    -* | '') ;;
    *)
      [[ -n $cmd ]] && lib::abort "Unexpected extra argument: $1"
      cmd="$1"
      ;;
    esac
    shift
  done
  echo "$cmd"
}

# Require that a directory exists
function lib::require_dir() {
  local path="$1"
  if [[ ! -d $path ]]; then
    lib::abort "Directory does not exist: [$path]"
  fi
}
