#!/bin/bash
#
# Tildepot bundle for crontab
# https://ss64.com/mac/crontab.html

CRONTAB="$BUNDLE_DIR/crontab.txt"

function SNAPSHOT() {
  crontab -l >"$CRONTAB"
  echo "✅ Stored crontab to [$CRONTAB]."
}

function APPLY() {
  crontab "$CRONTAB"
  echo "✅ Restored crontab from [$CRONTAB]."
}
