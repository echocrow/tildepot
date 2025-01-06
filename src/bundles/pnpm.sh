#!/bin/bash
#
# Tildepot bundle for pnpm
# https://pnpm.io/

function INSTALL_SKIP() {
  cmd_exists pnpm && echo "Already installed"
}
function INSTALL() {
  curl -fsSL https://get.pnpm.io/install.sh | sh -
  ohai_success "pnpm installed."
}

function UPDATE() {
  pnpm self-update
  ohai_success "pnpm updated."
  pnpm env use --global lts
  ohai_success "Node LTS updated."
}
