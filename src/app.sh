#!/usr/bin/env bash
#
# App initialization script for tildepot.

[[ -n ${__TILDEPOT_APP:-} ]] && return # tildepot-build ignore
__TILDEPOT_APP=1                       # tildepot-build ignore

TILDEPOT_VERSION=${__TILDEPOT_BUILD_VERSION:-0.0.0-dev}

_TILDEPOT_APP__DEV=${__TILDEPOT_BUILD_DEV-}
_TILDEPOT_APP__TEST=${__TILDEPOT_BUILD_TEST-}

_TILDEPOT_APP__REPO_DEFAULT_ROOT="$HOME/.local/share/tildepot"
_TILDEPOT_APP__REPO_ROOT="${TILDEPOT_HOME:-$_TILDEPOT_APP__REPO_DEFAULT_ROOT}"

_TILDEPOT_APP__REPO_URL="https://github.com/echocrow/tildepot"

# Fail fast when not using Bash.
# Source: https://github.com/Homebrew/install/blob/master/install.sh
if [[ -z ${BASH_VERSION:-} ]]; then
	printf "Bash is required to interpret this script.\n" >&2
	exit 1
fi

# Set compatibility mode or fail fast when using outdated Bash.
if ((${BASH_VERSION%%.*} > 3)); then
	export BASH_COMPAT=32
	shopt -s compat32
elif [[ ${BASH_VERSION:0:3} != 3.2 ]]; then
	printf "Bash version 3.2 or higher is required to interpret this script.\n" >&2
	exit 1
fi

_TILDEPOT_APP__YES=
function app::yes() { [[ -n $_TILDEPOT_APP__YES ]]; }
function app::set_yes() { _TILDEPOT_APP__YES=1; }

_TILDEPOT_APP__FORCE=
function app::force() { [[ -n $_TILDEPOT_APP__FORCE ]]; }
function app::set_force() { _TILDEPOT_APP__FORCE=1; }

source "$(dirname "${BASH_SOURCE[0]}")/txt.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/shared.sh"

source "$(dirname "${BASH_SOURCE[0]}")/bundle.sh"
source "$(dirname "${BASH_SOURCE[0]}")/bundles.sh"
source "$(dirname "${BASH_SOURCE[0]}")/repo.sh"
source "$(dirname "${BASH_SOURCE[0]}")/self.sh"

source "$(dirname "${BASH_SOURCE[0]}")/cmd.sh"
source "$(dirname "${BASH_SOURCE[0]}")/cmds.sh"

# Check if running in dev mode; if so, print a message
function app::dev() {
	local msg="${1-}"
	[[ -n $_TILDEPOT_APP__DEV && $msg ]] && echo "[DEV] $msg" >&2
	[[ -n $_TILDEPOT_APP__DEV ]]
}
