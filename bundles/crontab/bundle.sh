#!/bin/bash
#
# Tildepot bundle for crontab
# https://ss64.com/mac/crontab.html

CRONTAB="$BUNDLE_DIR/crontab.txt"

function SNAPSHOT() {
  crontab -l >"$CRONTAB"
  ohai_success "Stored crontab to [$CRONTAB]."
}

function APPLY_SKIP() {
  [ ! -f "$CRONTAB" ] && echo "No snapshot present"
}
function APPLY() {
  crontab "$CRONTAB"
  ohai_success "Restored crontab from [$CRONTAB]."
}
