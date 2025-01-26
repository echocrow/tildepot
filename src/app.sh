#!/bin/bash
#
# App initialization script for tildepot.

# Handle repeated imports
[[ -n "${__TILDEPOT_APP:-}" ]] && return # tildepot-build ignore
__TILDEPOT_APP=1                         # tildepot-build ignore

APP_ROOT=$(realpath "${BASH_SOURCE[0]}" | xargs dirname | xargs dirname | xargs realpath) # tildepot-build ignore
export APP_ROOT                                                                           # tildepot-build ignore

APP_REPO_ROOT="$HOME/.local/share/tildepot"
export APP_REPO_ROOT

# Fail fast with a concise message when not using bash
# Source: https://github.com/Homebrew/install/blob/master/install.sh
if [ -z "${BASH_VERSION:-}" ]; then
  printf "Bash is required to interpret this script.\n" >&2
  exit 1
fi

source "$(dirname "${BASH_SOURCE[0]}")/txt.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/shared.sh"
source "$(dirname "${BASH_SOURCE[0]}")/bundles.sh"
