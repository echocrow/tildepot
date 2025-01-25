#!/bin/bash
#
# A collection of useful functions for tildepot.

# Handle repeated imports
[[ -n "${__TILDEPOT_LIB:-}" ]] && return # tildepot-build ignore
__TILDEPOT_LIB=1                         # tildepot-build ignore

APP_ROOT=$(realpath "${BASH_SOURCE[0]}" | xargs dirname | xargs dirname | xargs realpath)
export APP_ROOT

REPO_ROOT="$HOME/.local/share/tildepot"
export REPO_ROOT

# Path to a bundle's directory. This will be set by the bundles loader.
BUNDLE_DIR=""
export BUNDLE_DIR

# Print an error message to stderr and exit
# Source: https://github.com/Homebrew/install/blob/master/install.sh
function lib::abort() {
  local messages=("$@")
  printf "%s\n" "${messages[@]}" >&2
  exit 1
}

# Fail fast with a concise message when not using bash
# Source: https://github.com/Homebrew/install/blob/master/install.sh
if [ -z "${BASH_VERSION:-}" ]; then
  lib::abort "Bash is required to interpret this script."
fi

# String formatters
# Source: https://github.com/Homebrew/install/blob/master/install.sh
function lib::_tty_escape() { printf "\033[%sm" "$1"; }
[[ ! -t 1 ]] && function lib::_tty_escape() { :; }
function lib::_tty_mkbold() { lib::_tty_escape "1;$1"; }
tty_underline="$(lib::_tty_escape "4;39")"
export tty_underline
tty_blue="$(lib::_tty_escape 34)"
export tty_blue
tty_red="$(lib::_tty_escape 31)"
export tty_red
tty_green="$(lib::_tty_escape 32)"
export tty_green
tty_yellow="$(lib::_tty_escape 33)"
export tty_yellow
tty_bold="$(lib::_tty_mkbold 39)"
export tty_bold
tty_reset="$(lib::_tty_escape 0)"
export tty_reset

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
  printf "${tty_bold}${tty_blue}=>${tty_bold} %s${tty_reset}\n" "$(lib::_ohai_fmt "${messages[@]}")"
}

# Format a message for ohai
function lib::_ohai_fmt() {
  local line
  line="$(lib::_shell_join "$@")"
  line="$(lib::chomp "$line")"

  # Simplify repository paths.
  line="${line//$REPO_ROOT\//}"

  # Highlight brackets.
  line="${line// \[/ $tty_blue}"
  line="${line//\]/$tty_reset}"

  echo -n "$line"
}

# Print a warning message to stderr
# Source: https://github.com/Homebrew/install/blob/master/install.sh
function lib::warn() {
  local msg="$1"
  printf "${tty_yellow}Warning${tty_reset}: %s\n" "$(lib::chomp "$msg")" >&2
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
    read -r -p "${tty_bold}${tty_blue}?)${tty_reset} $msg $opts " yn
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
