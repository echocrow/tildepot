#!/bin/bash
#
# A collection of useful functions for tildepot.

# Handle repeated imports
[[ -n "${__TILDEPOT_LIB:-}" ]] && return # tildepot-build ignore
__TILDEPOT_LIB=1                         # tildepot-build ignore

source "$(dirname "${BASH_SOURCE[0]}")/txt.sh"

# Print an error message to stderr and exit
# Source: https://github.com/Homebrew/install/blob/master/install.sh
function lib::abort() {
  local messages=("$@")
  printf "%s\n" "${messages[@]}" >&2
  exit 1
}

# Join a list of strings with a space
# Source: https://github.com/Homebrew/install/blob/master/install.sh
function lib::_shell_join() {
  local arg
  printf "%s" "$1"
  shift
  for arg in "$@"; do
    printf " "
    printf "%s" "${arg// /\ }"
  done
}

# Trim newlines from the end of a string
# Source: https://github.com/Homebrew/install/blob/master/install.sh
function lib::chomp() {
  local str="$1"
  printf "%s" "${str/"$'\n'"/}"
}

# Print an app-level message to stdout
# Source: https://github.com/Homebrew/install/blob/master/install.sh
function lib::ohai() {
  local messages=("$@")
  printf "${txt_bold}${txt_blue}=>${txt_bold} %s${txt_reset}\n" "$(lib::_ohai_fmt "${messages[@]}")"
}

# Format a message for ohai
function lib::_ohai_fmt() {
  local line
  line="$(lib::_shell_join "$@")"
  line="$(lib::chomp "$line")"

  # Simplify repository paths.
  [ -n "${APP_REPO_ROOT+x}" ] && line="${line//$APP_REPO_ROOT\//}"

  # Highlight brackets.
  line="${line// \[/ $txt_blue}"
  line="${line//\]/$txt_reset}"

  echo -n "$line"
}

# Print a warning message to stderr
# Source: https://github.com/Homebrew/install/blob/master/install.sh
function lib::warn() {
  local msg="$1"
  printf "${txt_yellow}Warning${txt_reset}: %s\n" "$(lib::chomp "$msg")" >&2
}

# Prompt for a yes/no confirmation
function lib::confirm() {
  local msg="$1"
  local default="${2:-n}"

  msg="$(lib::_ohai_fmt "$msg")"

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

# Check if an array contains a value
function lib::in_array() {
  local value="$1"
  local array=("${@:2}")

  for v in "${array[@]}"; do
    [[ "$v" == "$value" ]] && return 0
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
