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

  crontab -l >"$crontab_path"
  tilde::success "Stored crontab to [$crontab_path]."
}

function APPLY_SKIP() {
  local crontab_path
  crontab_path="$(bundle::_crontab_path)"

  [[ ! -f $crontab_path ]] && echo "No snapshot present"
}
function APPLY() {
  local crontab_path
  crontab_path="$(bundle::_crontab_path)"

  crontab "$crontab_path"
  tilde::success "Restored crontab from [$crontab_path]."
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
