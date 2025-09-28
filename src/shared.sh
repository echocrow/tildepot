#!/usr/bin/env bash
#
# A collection of shared helper functions for tildepot bundles.

source "$(dirname "${BASH_SOURCE[0]}")/txt.sh"

# Print a prefixed message
function tilde::_print_prefixed() {
  local prefix="$1"
  local messages=("${@:2}")

  local msg
  msg="$(lib::_fmt_msg "${messages[@]}")"

  if [[ $msg == *$'\n'* ]]; then
    printf "%s\n" "$prefix"
    printf "%s\n" "$msg"
  else
    printf "%s%s\n" "$prefix" "$msg"
  fi
}

# Print an info message to stdout
function tilde::info() {
  local title="${1?Missing title}"
  tilde::_print_prefixed "${txt_blue}==>${txt_reset} " "${txt_bold}${title}${txt_reset}"
}

# Print an log message to stdout
function tilde::echo() {
  local messages=("$@")
  tilde::_print_prefixed '' "${messages[@]}"
}

# Print a success message to stdout
function tilde::success() {
  local messages=("$@")
  tilde::_print_prefixed "${txt_green}==>${txt_reset} " "${messages[@]}"
}

# Print a warning message to stderr
function tilde::warning() {
  local messages=("$@")
  tilde::_print_prefixed "${txt_yellow}==>${txt_reset} " "${messages[@]}" >&2
}

# Print an error message to stderr
function tilde::error() {
  local messages=("$@")
  tilde::_print_prefixed "${txt_red}==>${txt_reset} " "${messages[@]}" >&2
}

# Print an error message to stderr and exit
function tilde::abort() {
  local messages=("$@")
  tilde::error "${messages[@]}"
  exit 1
}

# Check if a command is installed
function tilde::cmd_exists() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1
}
