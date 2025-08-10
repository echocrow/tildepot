#!/usr/bin/env bash
#
# Set up test environment

# Enable strict mode
set -euo pipefail

PACKAGES=(
  expect
  git
  jq
  zip
)

function test_env_setup::main() {
  echo "==> Setting up test environment"

  local os
  os="$(uname -s)"

  case $os in
  Darwin) test_env_setup::macos ;;
  Linux) test_env_setup::linux ;;
  *) test_env_setup::abort "Unsupported platform: $os" ;;
  esac
}

function test_env_setup::linux() {
  echo "==> Setting up test environment (Linux)"

  # Install packages
  local missing_packages=()
  for pkg in "${PACKAGES[@]}"; do
    ! test_env_setup::cmd_exists "$pkg" && missing_packages+=("$pkg")
  done
  echo "Missing packages: ${missing_packages[*]--}"
  # Speed up install by disabling man-db auto-update
  rm -rf /var/lib/man-db/auto-update
  # Install with corresponding package manager
  if ((!${#missing_packages[@]})); then
    echo "All packages are already installed" >&2
  elif test_env_setup::cmd_exists apk; then
    apk add \
      "${missing_packages[@]}"
  elif test_env_setup::cmd_exists apt-get; then
    apt-get install -y --no-install-recommends \
      "${missing_packages[@]}"
  else
    test_env_setup::abort "No supported package manager found"
  fi
}

function test_env_setup::macos() {
  echo "==> Setting up test environment (macOS)"

  # Packages are presumed to be installed.
  for package in "${PACKAGES[@]}"; do
    test_env_setup::assert_cmd_exists "$package"
  done
}

function test_env_setup::abort() {
  msg="${1?}"
  echo "Error: $msg"
  exit 1
}

function test_env_setup::cmd_exists() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1
}

function test_env_setup::assert_cmd_exists() {
  local cmd="${1?}"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    test_env_setup::abort "Command \"$cmd\" not found"
  fi
}

test_env_setup::main
