#!/bin/bash
#
# Tildepot bundle for the fish shell
# https://fishshell.com/

function INSTALL_SKIP() {
  ! tilde::cmd_exists fish && echo "Fish not installed"
  [[ "$SHELL" == "$(which fish)" ]] && echo "Fish already set as default shell"
}
function INSTALL() {
  which fish | sudo tee -a /etc/shells
  tilde::success "Added fish to [/etc/shells]."
  chsh -s "$(which fish)"
  tilde::success "Set fish as default shell."
}

function UPDATE_SKIP() {
  ! tilde::cmd_exists fish && echo "Fish not installed"
  ! fish -c 'type -q fisher' && echo "Fisher not installed"
}
function UPDATE() {
  fish -c 'fisher update'
  tilde::success "Updated Fisher plugins."
}
