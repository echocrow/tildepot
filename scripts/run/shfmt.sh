#!/bin/bash
#
# Download and run shfmt.

# Enable strict mode
set -euo pipefail

BINS_DIR="$ROOT/scripts/.bin"
SHFMT_VERSION=v3.11.0

SHFMT_DIR="$BINS_DIR/shfmt-$SHFMT_VERSION"
SHFMT_BIN="$SHFMT_DIR/shfmt"

function shfmt::install() {
  lib::ohai "Installing [shfmt] $SHFMT_VERSION..."

  local os
  os="$(uname -s)"
  local machine
  machine="$(uname -m)"

  local platform
  case $os in
  Darwin)
    case $machine in
    x86_64) platform=darwin_amd64 ;;
    arm64) platform=darwin_arm64 ;;
    esac
    ;;
  Linux)
    case $machine in
    x86_64) platform=linux_amd64 ;;
    aarch64) platform=linux_arm64 ;;
    esac
    ;;
  esac
  if [[ -z $platform ]]; then
    lib::abort "Unsupported platform: $os/$machine"
  fi

  rm -rf "$SHFMT_DIR"
  mkdir -p "$BINS_DIR"

  local bin_url="https://github.com/mvdan/sh/releases/download/${SHFMT_VERSION}/shfmt_${SHFMT_VERSION}_{$platform}"
  mkdir "$SHFMT_DIR"
  lib::download "$bin_url" >"$SHFMT_BIN"
  chmod +x "$SHFMT_BIN"
}

function shfmt() {
  [[ ! -f $SHFMT_BIN ]] && shfmt::install
  "$SHFMT_BIN" "$@"
}
