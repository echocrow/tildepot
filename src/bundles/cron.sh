#!/bin/bash
#
# Tildepot bundle for crontab.
# https://ss64.com/mac/crontab.html

CRONTAB="$BUNDLE_DIR/crontab.txt"

function SNAPSHOT() {
  crontab -l >"$CRONTAB"
  tilde::success "Stored crontab to [$CRONTAB]."
}

function APPLY_SKIP() {
  [ ! -f "$CRONTAB" ] && echo "No snapshot present"
}
function APPLY() {
  crontab "$CRONTAB"
  tilde::success "Restored crontab from [$CRONTAB]."
}
