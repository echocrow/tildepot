#!/bin/bash
#
# Tildepot bundle for Homebrew.
# https://brew.sh/

BREWFILE="$BUNDLE_DIR/Brewfile"

function INSTALL_SKIP() {
  tilde::cmd_exists brew && echo "Already installed"
}
function INSTALL() {
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  tilde::success "Installed Homebrew."
}

function UPDATE() {
  bundle::_brew update
  tilde::success "Updated Homebrew."
  bundle::_brew upgrade
  tilde::success "Updated Homebrew installations."
  bundle::_brew cleanup
  tilde::success "Cleaned up Homebrew installations."
}

function SNAPSHOT() {
  bundle::_brew bundle dump --force --no-vscode --file "$BREWFILE"
  tilde::success "Stored Homebrew dependencies to [$BREWFILE]."
}

function APPLY_SKIP() {
  [ ! -f "$BREWFILE" ] && echo "No Brewfile present"
}
function APPLY() {
  bundle::_brew bundle install --force --cleanup --zap --file "$BREWFILE"
  tilde::success "Restored Homebrew dependencies from [$BREWFILE]."
}

BUNDLE_BREW_CMD=""
function bundle::_brew() {
  if [ -z "$BUNDLE_BREW_CMD" ]; then
    BUNDLE_BREW_CMD="$(bundle::brew_cmd)"
  fi
  "$BUNDLE_BREW_CMD" "$@"
}

function bundle::brew_cmd() {
  tilde::cmd_exists brew && echo brew && return

  # Determine brew bin path.
  # @source https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh
  if [[ "$(uname)" == "Darwin" ]]; then
    if [[ "$(uname -m)" == "arm64" ]]; then
      HOMEBREW_PREFIX="/opt/homebrew"
    else
      HOMEBREW_PREFIX="/usr/local"
    fi
  elif [[ "$(uname)" == "Linux" ]]; then
    HOMEBREW_PREFIX="/home/linuxbrew/.linuxbrew"
  else
    tilde::error "Unknown platform." && exit 1
  fi

  local cmd="${HOMEBREW_PREFIX}/bin/brew"
  if ! tilde::cmd_exists "$cmd"; then
    tilde::error "Failed to determine Homebrew bin path." && exit 1
  fi

  echo "$cmd"
}
