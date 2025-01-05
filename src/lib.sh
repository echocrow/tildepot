#!/bin/bash
#
# A collection of useful functions for tildepot.

# Enable strict mode
set -euo pipefail

# Handle repeated imports
[[ -n "${__TILDEPOT_LIB:-}" ]] && return
__TILDEPOT_LIB=1

APP_ROOT=$(realpath "${BASH_SOURCE[0]}" | xargs dirname | xargs dirname | xargs realpath)
export APP_ROOT

REPO_ROOT="$APP_ROOT"
export REPO_ROOT

# Path to module directory. This will be set by the module loader.
MOD_DIR=""
export MOD_DIR

# Print an error message to stderr and exit
# Source: https://github.com/Homebrew/install/blob/master/install.sh
function abort() {
  local messages=("$@")
  printf "%s\n" "${messages[@]}" >&2
  exit 1
}

# Fail fast with a concise message when not using bash
# Source: https://github.com/Homebrew/install/blob/master/install.sh
if [ -z "${BASH_VERSION:-}" ]; then
  abort "Bash is required to interpret this script."
fi

# String formatters
# Source: https://github.com/Homebrew/install/blob/master/install.sh
if [[ -t 1 ]]; then
  function tty_escape() { printf "\033[%sm" "$1"; }
else
  function tty_escape() { :; }
fi
function tty_mkbold() { tty_escape "1;$1"; }
tty_underline="$(tty_escape "4;39")"
export tty_underline
tty_blue="$(tty_escape 34)"
export tty_blue
tty_red="$(tty_escape 31)"
export tty_red
tty_green="$(tty_escape 32)"
export tty_green
tty_yellow="$(tty_escape 33)"
export tty_yellow
tty_bold="$(tty_mkbold 39)"
export tty_bold
tty_reset="$(tty_escape 0)"
export tty_reset

# Join a list of strings with a space
# Source: https://github.com/Homebrew/install/blob/master/install.sh
function shell_join() {
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
function chomp() {
  local str="$1"
  printf "%s" "${str/"$'\n'"/}"
}

# Print a message to stdout
# Source: https://github.com/Homebrew/install/blob/master/install.sh
function ohai() {
  local messages=("$@")
  printf "${tty_bold}${tty_blue}=>${tty_bold} %s${tty_reset}\n" "$(shell_join "${messages[@]}")"
}
# Print a success sub-message to stdout
function ohai_success() {
  local messages=("$@")
  printf "${tty_green}==>${tty_reset} %s\n" "$(shell_join "${messages[@]}")"
}
# Print a warning sub-message to stdout
function ohai_warning() {
  local messages=("$@")
  printf "${tty_yellow}==>${tty_reset} %s\n" "$(shell_join "${messages[@]}")"
}
# Print a error sub-message to stdout
function ohai_error() {
  local messages=("$@")
  printf "${tty_red}==>${tty_reset} %s\n" "$(shell_join "${messages[@]}")"
}

# Print a warning message to stderr
# Source: https://github.com/Homebrew/install/blob/master/install.sh
function warn() {
  local msg="$1"
  printf "${tty_yellow}Warning${tty_reset}: %s\n" "$(chomp "$msg")" >&2
}

# Check if a command is installed
function cmd_exists() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1
}

# Prompt for a yes/no confirmation
function confirm() {
  local msg="$1"
  local default="${2:-n}"

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
function in_array() {
  local value="$1"
  local array=("${@:2}")

  for v in "${array[@]}"; do
    [[ "$v" == "$value" ]] && return 0
  done
  return 1
}

# Get a path relative to the root
function relpath() {
  local path="$1"
  local root="${2:-$APP_ROOT}"
  echo "${path//$root\//}"
}
