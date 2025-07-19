#!/usr/bin/env bash
#
# Set up test environment

# Enable strict mode
set -euo pipefail

ROOT="$(dirname "${BASH_SOURCE[0]}")/.."

source "$ROOT/src/lib.sh"

PACKAGES=(
  expect
  git
  jq
  zip
)

function test_env_setup::main() {
  lib::ohai "Setting up test environment"

  local os
  os="$(uname -s)"

  case $os in
  Darwin) test_env_setup::macos ;;
  Linux) test_env_setup::linux ;;
  *) lib::abort "Unsupported platform: $os" ;;
  esac
}

function test_env_setup::linux() {
  lib::ohai "Setting up test environment (Linux)"

  # Install packages
  local missing_packages=()
  for pkg in "${PACKAGES[@]}"; do
    ! tilde::cmd_exists "$pkg" && missing_packages+=("$pkg")
  done
  echo "Missing packages: ${missing_packages[*]--}"
  # Speed up install by disabling man-db auto-update
  rm /var/lib/man-db/auto-update
  # Install with corresponding package manager
  if [[ ${#missing_packages[@]} == 0 ]]; then
    echo "All packages are already installed" >&2
  elif tilde::cmd_exists apk; then
    apk add \
      "${missing_packages[@]}"
  elif tilde::cmd_exists apt-get; then
    apt-get install -y --no-install-recommends \
      "${missing_packages[@]}"
  else
    lib::abort "No supported package manager found"
  fi
}

function test_env_setup::macos() {
  lib::ohai "Setting up test environment (macOS)"

  # Packages are presumed to be installed.
  for package in "${PACKAGES[@]}"; do
    test_env_setup::assert_cmd_exists "$package"
  done
}

function test_env_setup::assert_cmd_exists() {
  local cmd="${1?}"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    lib::abort "Command [$cmd] not found"
  fi
}

test_env_setup::main
