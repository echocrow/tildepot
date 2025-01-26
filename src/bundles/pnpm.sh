#!/bin/bash
#
# Tildepot bundle for pnpm.
# https://pnpm.io/

function INSTALL_SKIP() {
  tilde::cmd_exists pnpm && echo "Already installed"
}
function INSTALL() {
  curl -fsSL https://get.pnpm.io/install.sh | sh -
  tilde::success "pnpm installed."
}

function UPDATE() {
  pnpm self-update
  tilde::success "pnpm updated."
  pnpm env use --global lts
  tilde::success "Node LTS updated."
}
