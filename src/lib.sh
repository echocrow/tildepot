#!/usr/bin/env bash
#
# A collection of useful functions for tildepot.

[[ -n ${__TILDEPOT_LIB:-} ]] && return # tildepot-build ignore
__TILDEPOT_LIB=1                       # tildepot-build ignore

source "$(dirname "${BASH_SOURCE[0]}")/txt.sh"
source "$(dirname "${BASH_SOURCE[0]}")/shared.sh"

_LIB_PRINT_MAX_WIDTH=120

# Cached number of terminal columns.
_LIB_TERMINAL_COLUMNS=
_LIB_TERMINAL_COLUMNS_FALLBACK=80
function lib::_init_terminal_columns() {
  [[ $_LIB_TERMINAL_COLUMNS ]] && return
  if tilde::cmd_exists stty && [ -t 0 ]; then
    _LIB_TERMINAL_COLUMNS="$(stty size | cut -d' ' -f2)"
  fi
  if [[ ! $_LIB_TERMINAL_COLUMNS ]]; then
    _LIB_TERMINAL_COLUMNS=$_LIB_TERMINAL_COLUMNS_FALLBACK
  fi
}

# Print optional error messages to stderr and exit
function lib::abort() {
  case $# in
  0) echo "${txt_red}Error.${txt_reset}" >&2 ;;
  1) echo "${txt_red}Error:${txt_reset}" "$(lib::_fmt_msg "$1")" >&2 ;;
  *)
    echo "${txt_red}Error:${txt_reset}" >&2
    local msg
    for msg in "$@"; do
      echo "  $(lib::_fmt_msg "$msg")" >&2
    done
    ;;
  esac
  exit 1
}

# Print optional warning messages to stderr
function lib::warn() {
  case $# in
  0) echo "${txt_yellow}Warning.${txt_reset}" >&2 ;;
  1) echo "${txt_yellow}Warning:${txt_reset}" "$(lib::_fmt_msg "$1")" >&2 ;;
  *)
    echo "${txt_yellow}Warning:${txt_reset}" >&2
    local msg
    for msg in "$@"; do
      echo "  $(lib::_fmt_msg "$msg")" >&2
    done
    ;;
  esac
}

# Print an app-level message to stdout
# Source: https://github.com/Homebrew/install/blob/master/install.sh
function lib::ohai() {
  local msg="$1"
  printf "${txt_bold}${txt_blue}=>${txt_bold} %s${txt_reset}\n" "$(lib::_fmt_msg "$msg")"
}

# Format a message for logs, simplifying paths and injecting highlights
function lib::_fmt_msg() {
  local line="$1"

  # Simplify repository paths.
  [[ -n ${_TILDEPOT_APP__REPO_ROOT:-} ]] && line="${line//$_TILDEPOT_APP__REPO_ROOT\//}"

  # Highlight brackets.
  local tmp_ansi="##ANSI_CTRL##"
  # Temporarily replace ANSI control sequences.
  line="${line//$'\033['/$tmp_ansi}"
  # Replace regular brackets.
  line="${line//\[/$txt_blue}"
  line="${line//\]/$txt_reset}"
  # Restore escape sequences.
  line="${line//$tmp_ansi/$'\033['}"

  echo -n "$line"
}

# Print pre-prompt messages
function lib::_pre_prompt() {
  while [[ $# -gt 1 ]]; do
    echo "${txt_bold}${txt_blue}!)${txt_reset} $(lib::_fmt_msg "$1")"
    shift
  done
}

# Prompt for an answer
function lib::prompt() {
  lib::_pre_prompt "$@"
  local msg="${!#}"
  msg="$(lib::_fmt_msg "$msg")"

  local res
  read -r -p "${txt_bold}${txt_blue}?)${txt_reset} $msg " res
  echo "$res"
}

# Prompt for a yes/no confirmation
function lib::_confirm() {
  app::yes && return 0

  local default=
  case ${1-} in
  -y | --yes) default=y && shift ;;
  -n | --no) default=n && shift ;;
  esac

  lib::_pre_prompt "$@"
  local msg="${!#}"
  msg="$(lib::_fmt_msg "$msg")"

  local hint='y/n'
  [[ $default == y ]] && hint='Y/n'
  [[ $default == n ]] && hint='y/N'
  hint="${txt_grey}› ($hint)${txt_reset}"

  local res
  local prompt="${txt_bold}${txt_blue}?)${txt_reset} $msg $hint"
  while true; do
    # Set IFS to null so space is distinct from newline.
    IFS=$'\0' read -r -n1 -p "$prompt " res

    if [[ ! $res ]]; then
      res="$default"
    else
      printf '\n'
    fi

    case "$res" in
    [Yy]*) return 0 ;;
    [Nn]*) return 1 ;;
    esac
  done
}

# Require confirmation of a yes/no prompt
function lib::require_confirm() {
  lib::_confirm "$@" || lib::abort 'User aborted.'
}

# Check if an array contains a value
function lib::in_array() {
  local value="$1"
  local array=("${@:2}")
  local v
  for v in "${array[@]}"; do
    [[ $v == "$value" ]] && return 0
  done
  return 1
}

# Get the index of an array element
function lib::array_index() {
  local value="$1"
  local array=("${@:2}")
  local i
  for i in "${!array[@]}"; do
    [[ ${array[i]} == "$value" ]] && echo "$i" && return
  done
  return 1
}

# Cross-platform `sed`
function lib::sed() {
  if [[ $OSTYPE == linux-gnu ]]; then
    sed -i "$@"
  else
    sed -i '' "$@"
  fi
}

# Get the sole command from a list of arguments
# Example:
#     lib::get_cmd "${args[@]-}"
function lib::get_cmd() {
  local cmd=
  while [[ $# -gt 0 ]]; do
    case $1 in
    -* | '') ;;
    *)
      [[ -n $cmd ]] && lib::abort "Unexpected extra argument: $1"
      cmd="$1"
      ;;
    esac
    shift
  done
  echo "$cmd"
}

# Require that a directory exists
function lib::require_dir() {
  local path="$1"
  if [[ ! -d $path ]]; then
    lib::abort "Directory does not exist: [$path]"
  fi
}

# Download a file to stdout
function lib::download() {
  local url="$1"
  local timeout=10

  if tilde::cmd_exists curl; then
    curl -fsSL --connect-timeout "$timeout" "$url"
  elif tilde::cmd_exists wget; then
    wget -qO- -T "$timeout" "$url"
  else
    lib::abort "Cannot download file" "Either [curl] or [wget] is required to download [$url]"
  fi
}

# Print two-column text.
function lib::print_two_col() {
  local left="${1?}"
  local right="${2?}"
  local col_w="${3:-20}"

  lib::print_wrap -n "$left" ''
  [[ ! $right ]] && printf '\n' && return

  local right_first_offset=
  if ((${#left} >= col_w)); then
    printf '\n'
  else
    right_first_offset="${#left}"
  fi

  lib::print_wrap -- "$right" '' "$col_w" "$right_first_offset"
}

# Print flow text, wrapping on whitespace & newlines.
function lib::print_wrap() {
  local skip_newline=
  case $1 in
  -n) skip_newline=1 && shift ;;
  --) shift ;;
  esac

  local text="${1?}"
  local max_w="${2:-$_LIB_PRINT_MAX_WIDTH}"
  local indent="${3:-0}"
  local first_pre_indent="${4:-0}"

  lib::_init_terminal_columns
  ((_LIB_TERMINAL_COLUMNS < max_w)) && max_w=$_LIB_TERMINAL_COLUMNS

  local col_w_plus=$((max_w - indent + 1))

  local queue="$text "
  local is_first=1
  local safe_cut next_cut len i j c force_cut
  while ((${#queue})); do
    # Determine safe cut position.
    safe_cut=0
    next_cut=0
    len=0
    for ((i = 0; i < ${#queue}; i++)); do
      c="${queue:i:1}"
      force_cut=
      case "$c" in
      ' ')
        next_cut=$i
        ((++len))
        ;;
      $'\n')
        next_cut=$i
        force_cut=1
        ;;
      $'\033')
        # Skip escape sequences w/o incrementing text length.
        if [[ ${queue:i:2} == $'\033[' ]]; then
          for ((j = i + 2; j < ${#queue}; j++)); do
            [[ ${queue:j:1} != [0-9\;] ]] && i=j && break
          done
        fi
        ;;
      *)
        ((++len))
        ;;
      esac
      ((safe_cut && len > col_w_plus)) && break
      safe_cut=$next_cut
      ((force_cut)) && break
    done

    # Print line.
    if [[ $is_first ]]; then
      printf "%*s%s" $((indent - first_pre_indent)) '' "${queue:0:safe_cut}"
    else
      printf "\n%*s%s" "$indent" '' "${queue:0:safe_cut}"
    fi
    # Update state.
    queue="${queue:safe_cut+1}"
    is_first=
  done

  if [[ ! $skip_newline ]]; then
    printf '\n'
  fi
}
