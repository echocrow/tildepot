#!/bin/bash
#
# Tildepot bundle for Homebrew
# https://brew.sh/

BREWFILE="$BUNDLE_DIR/Brewfile"

function PRE_INSTALL_SKIP() {
  tilde::cmd_exists brew && echo "Already installed"
}
function PRE_INSTALL() {
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  tilde::success "Installed Homebrew."
}

function UPDATE() {
  brew update
  tilde::success "Updated Homebrew."
  brew upgrade
  tilde::success "Updated Homebrew installations."
  brew cleanup
  tilde::success "Cleaned up Homebrew installations."
}

function SNAPSHOT() {
  brew bundle dump --force --no-vscode --file "$BREWFILE"
  tilde::success "Stored Homebrew dependencies to [$BREWFILE]."
}

function APPLY_SKIP() {
  [ ! -f "$BREWFILE" ] && echo "No Brewfile present"
}
function APPLY() {
  brew bundle install --force --cleanup --zap --file "$BREWFILE"
  tilde::success "Restored Homebrew dependencies from [$BREWFILE]."
}
