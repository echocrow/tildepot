#!/bin/bash
#
# A collection of shared helper functions for tildepot bundles.

source "$(dirname "${BASH_SOURCE[0]}")/txt.sh"

# Print a success message to stdout
function tilde::success() {
  local messages=("$@")
  printf "${txt_green}==>${txt_reset} %s\n" "$(lib::_ohai_fmt "${messages[@]}")"
}

# Print a warning message to stdout
function tilde::warning() {
  local messages=("$@")
  printf "${txt_yellow}==>${txt_reset} %s\n" "$(lib::_ohai_fmt "${messages[@]}")" >&2
}

# Print a error message to stdout
function tilde::error() {
  local messages=("$@")
  printf "${txt_red}==>${txt_reset} %s\n" "$(lib::_ohai_fmt "${messages[@]}")" >&2
}

# Check if a command is installed
function tilde::cmd_exists() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1
}
