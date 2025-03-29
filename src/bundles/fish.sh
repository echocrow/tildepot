#!/bin/bash
#
# Tildepot bundle for the fish shell.
# https://fishshell.com/

function SKIP() {
  ! tilde::cmd_exists fish && echo "Fish is not installed"
  tilde::cmd_exists fish && echo "DEBUG"
}

function INSTALL() {
  local fish_cmd
  fish_cmd="$(which fish)"

  if grep -q "^$fish_cmd$" /etc/shells; then
    tilde::success "Fish already in [/etc/shells]."
  else
    sudo tee -a /etc/shells <<<"$fish_cmd"
    tilde::success "Added fish to [/etc/shells]."
  fi

  chsh -s "$fish_cmd"
  tilde::success "Set fish as default shell."
}

function UPDATE_SKIP() {
  ! tilde::cmd_exists fish && echo "Fish is not installed"
  ! fish -c 'type -q fisher' && echo "Fisher is not installed"
}
function UPDATE() {
  fish -c 'fisher update'
  tilde::success "Updated Fisher plugins."
}
