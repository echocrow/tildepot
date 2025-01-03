#!/bin/bash

# A collection of useful functions for tildepot.

# Enable strict mode
function strict_mode() {
  set -euo pipefail
}
strict_mode

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
tty_blue="$(tty_mkbold 34)"
tty_red="$(tty_mkbold 31)"
tty_bold="$(tty_mkbold 39)"
tty_reset="$(tty_escape 0)"

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
  printf "${tty_blue}==>${tty_bold} %s${tty_reset}\n" "$(shell_join "${messages[@]}")"
}

# Print a warning message to stderr
# Source: https://github.com/Homebrew/install/blob/master/install.sh
function warn() {
  local msg="$1"
  printf "${tty_red}Warning${tty_reset}: %s\n" "$(chomp "$msg")" >&2
}

# Check if a command is installed
function cmd_exists() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1
}
