#!/bin/bash
#
# Mod file for Homebrew
# https://brew.sh/

MOD_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "$MOD_DIR/../../scripts/lib.sh"

BREWFILE="$MOD_DIR/Brewfile"

export WEIGHT=0

function INSTALL() {
  if ! cmd_exists brew; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  ohai_success "Homebrew installed."
}

function UPDATE() {
  brew update
  ohai_success "Homebrew updated."
  brew upgrade
  ohai_success "Homebrew installations updated."
  brew cleanup
  ohai_success "Homebrew installations cleaned up."
}

function SNAPSHOT() {
  brew bundle dump --force --no-vscode --file "$BREWFILE"
  ohai_success "Stored Homebrew dependencies to ${tty_blue}$(relpath "$BREWFILE")${tty_reset}."
}

function APPLY() {
  brew bundle install --force --cleanup --zap --file "$BREWFILE"
  ohai_success "Restored Homebrew dependencies from ${tty_blue}$(relpath "$BREWFILE")${tty_reset}."
}
