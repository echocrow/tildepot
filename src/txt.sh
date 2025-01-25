#!/bin/bash
#
# A collection of TTY color helpers for tildepot.
# shellcheck disable=SC2155

# Handle repeated imports
[[ -n "${__TILDEPOT_TXT:-}" ]] && return # tildepot-build ignore
__TILDEPOT_TXT=1                         # tildepot-build ignore

# TTY Text Formatters
# Source: https://github.com/Homebrew/install/blob/master/install.sh
function txt::_escape() { printf "\033[%sm" "$1"; }
[[ ! -t 1 ]] && function txt::_escape() { :; }

function txt::_mkbold() { txt::_escape "1;$1"; }

export txt_underline="$(txt::_escape "4;39")"
export txt_blue="$(txt::_escape 34)"
export txt_red="$(txt::_escape 31)"
export txt_green="$(txt::_escape 32)"
export txt_yellow="$(txt::_escape 33)"
export txt_bold="$(txt::_mkbold 39)"
export txt_reset="$(txt::_escape 0)"
