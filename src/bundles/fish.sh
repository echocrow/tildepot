#!/bin/bash
#
# Tildepot bundle for the fish shell
# https://fishshell.com/

function INSTALL_SKIP() {
  ! cmd_exists fish && echo "Fish not installed"
  [[ "$SHELL" == "$(which fish)" ]] && echo "Fish already set as default shell"
}
function INSTALL() {
  which fish | sudo tee -a /etc/shells
  ohai_success "Added fish to [/etc/shells]."
  chsh -s "$(which fish)"
  ohai_success "Set fish as default shell."
}

function UPDATE_SKIP() {
  ! cmd_exists fish && echo "Fish not installed"
  ! fish -c 'type -q fisher' && echo "Fisher not installed"
}
function UPDATE() {
  fish -c 'fisher update'
  ohai_success "Updated Fisher plugins."
}
