#!/bin/bash
#
# Tildepot bundle for Homebrew
# https://brew.sh/

BREWFILE="$BUNDLE_DIR/Brewfile"

export WEIGHT=0

function INSTALL_SKIP() {
  cmd_exists brew && echo "Already installed"
}
function INSTALL() {
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  ohai_success "Installed Homebrew."
}

function UPDATE() {
  brew update
  ohai_success "Updated Homebrew."
  brew upgrade
  ohai_success "Updated Homebrew installations."
  brew cleanup
  ohai_success "Cleaned up Homebrew installations."
}

function SNAPSHOT() {
  brew bundle dump --force --no-vscode --file "$BREWFILE"
  ohai_success "Stored Homebrew dependencies to [$BREWFILE]."
}

function APPLY_SKIP() {
  [ ! -f "$BREWFILE" ] && echo "No Brewfile present"
}
function APPLY() {
  brew bundle install --force --cleanup --zap --file "$BREWFILE"
  ohai_success "Restored Homebrew dependencies from [$BREWFILE]."
}
