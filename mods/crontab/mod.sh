#!/bin/bash
#
# Mod file for crontab
# https://ss64.com/mac/crontab.html

# shellcheck source=../../src/lib.sh
source /dev/null

MOD_DIR="$(dirname "${BASH_SOURCE[0]}")"
CRONTAB="$MOD_DIR/crontab.txt"

function SNAPSHOT() {
  crontab -l >"$CRONTAB"
  ohai_success "Stored crontab to ${tty_blue}$(relpath "$CRONTAB")${tty_reset}."
}

function APPLY() {
  crontab "$CRONTAB"
  ohai_success "Restored crontab from ${tty_blue}$(relpath "$CRONTAB")${tty_reset}."
}
