#!/usr/bin/env bash
#
# Tildepot bundle for crontab.
# https://ss64.com/mac/crontab.html

function SKIP() {
  ! tilde::cmd_exists crontab && echo "Crontab is not installed"
}

function SNAPSHOT() {
  local crontab_path
  crontab_path="$(bundle::_crontab_path)"

  if crontab -l >"$crontab_path"; then
    tilde::success "Stored crontab to [$crontab_path]."
  else
    rm -f "$crontab_path"
    tilde::success "Skipped crontab; nothing to snapshot."
  fi
}

function APPLY() {
  local crontab_path
  crontab_path="$(bundle::_crontab_path)"

  if [[ -f $crontab_path ]]; then
    crontab "$crontab_path"
    tilde::success "Restored crontab from [$crontab_path]."
  elif crontab -r 2>/dev/null; then
    tilde::success "Removed crontab."
  else
    tilde::success "Skipped crontab; nothing to remove."
  fi
}

function bundle::crontab_name() {
  # e.g. `hostname -s`
  return
}

function bundle::_crontab_path() {
  local name
  name="$(bundle::crontab_name)"
  if [[ -n $name ]]; then
    echo "$BUNDLE_DIR/crontab_$(bundle::crontab_name).txt"
  else
    echo "$BUNDLE_DIR/crontab.txt"
  fi

}
