#!/bin/bash
#
# A collection of shared helper functions for tildepot bundles.

source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# Print a success message to stdout
function tilde::success() {
  local messages=("$@")
  printf "${tty_green}==>${tty_reset} %s\n" "$(lib::_ohai_fmt "${messages[@]}")"
}

# Print a warning message to stdout
function tilde::warning() {
  local messages=("$@")
  printf "${tty_yellow}==>${tty_reset} %s\n" "$(lib::_ohai_fmt "${messages[@]}")"
}

# Print a error message to stdout
function tilde::error() {
  local messages=("$@")
  printf "${tty_red}==>${tty_reset} %s\n" "$(lib::_ohai_fmt "${messages[@]}")"
}

# Check if a command is installed
function tilde::cmd_exists() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1
}
