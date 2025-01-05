#!/bin/bash
#
# Tildepot bundle for Homebrew
# https://brew.sh/

BREWFILE="$BUNDLE_DIR/Brewfile"

export WEIGHT=0

function INSTALL() {
  if ! cmd_exists brew; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  echo "✅ Homebrew installed."
}

function UPDATE() {
  brew update
  echo "✅ Homebrew updated."
  brew upgrade
  echo "✅ Homebrew installations updated."
  brew cleanup
  echo "✅ Homebrew installations cleaned up."
}

function SNAPSHOT() {
  brew bundle dump --force --no-vscode --file "$BREWFILE"
  echo "✅ Stored Homebrew dependencies to [$BREWFILE]."
}

function APPLY() {
  brew bundle install --force --cleanup --zap --file "$BREWFILE"
  echo "✅ Restored Homebrew dependencies from [$BREWFILE]."
}
