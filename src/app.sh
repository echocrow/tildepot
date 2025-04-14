#!/bin/bash
#
# App initialization script for tildepot.

# Handle repeated imports
[[ -n ${__TILDEPOT_APP:-} ]] && return # tildepot-build ignore
__TILDEPOT_APP=1                       # tildepot-build ignore

export APP_VERSION=${__TILDEPOT_BUILD_VERSION:-0.0.0-dev}
export APP_DEV=${__TILDEPOT_BUILD_DEV-}

export APP_REPO_DEFAULT_ROOT="$HOME/.local/share/tildepot"
export APP_REPO_ROOT="${TILDEPOT_HOME:-$APP_REPO_DEFAULT_ROOT}"

# Fail fast with a concise message when not using bash
# Source: https://github.com/Homebrew/install/blob/master/install.sh
if [[ -z ${BASH_VERSION:-} ]]; then
  printf "Bash is required to interpret this script.\n" >&2
  exit 1
fi

_APP_YES=
function app::yes() { [[ -n $_APP_YES ]]; }
function app::set_yes() { _APP_YES=1; }

_APP_FORCE=
function app::force() { [[ -n $_APP_FORCE ]]; }
function app::set_force() { _APP_FORCE=1; }

source "$(dirname "${BASH_SOURCE[0]}")/txt.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/shared.sh"
source "$(dirname "${BASH_SOURCE[0]}")/bundles.sh"

# Check if running in dev mode; if so, print a message
function app::dev() {
  local msg="$1"
  [[ -n $APP_DEV ]] && echo "[DEV] $msg" >&2
}
