#!/usr/bin/env bash
#
# tildepot command entrypoint & helpers.

source "$(dirname "${BASH_SOURCE[0]}")/txt.sh"

# Command config: Skip arg processing and forwarding all args as-is instead.
CMD_CFG_ARGS_FWD_ALL=

# Command config: Tuple-list of option definitions, containing:
#   - Short-option name
#   - Long-option name
#   - Parameter placeholder (or empty string for no parameter)
#   - Option description
CMD_CFG_OPTS=()

# Command config: Placeholder(s) for additional parameters.
CMD_CFG_PARAMS_HELP=''

# Command config: Count or range of additional parameters. Can be one of:
#   - 0: No additional parameters
#   - n: Exactly n (required) parameters
#   - n-m: Between n and m (inclusive) parameters
#   - n-: At least n parameters (no upper limit)
#   - -n: At most n parameters (no lower limit)
CMD_CFG_PARAMS_COUNT=0

_CMD_CFG_OPTS_IDX_SHORT=0
_CMD_CFG_OPTS_IDX_LONG=1
_CMD_CFG_OPTS_IDX_PARAM=2
_CMD_CFG_OPTS_IDX_DESC=3
_CMD_CFG_OPTS_TUPLE_LEN=4

_CMD_CFG_OPTS_GLOBAL=()
_CMD_CFG_OPTS_GLOBAL+=(h help '' 'Display help for this command.')
_CMD_CFG_OPTS_GLOBAL+=(R repo-dir 'PATH' "Specify a custom tildepot repository path, overriding the default (${_TILDEPOT_APP__REPO_ROOT/#${HOME:-_}/~}).")
_CMD_CFG_OPTS_GLOBAL+=(y yes '' 'Answer yes to all prompts.')

_CMD_CFG_OPTS_PRELIM=()
_CMD_CFG_OPTS_PRELIM+=(v version '' 'Display the version of tildepot.')

_CMD_HELP_LEFT_COL_WIDTH=28
_CMD_HELP_MAX_WIDTH=120
_CMD_TERMINAL_COLUMNS=

_CMD_OPTS=()
_CMD_REST_ARGS=()
function cmd::_process_args() {
  local is_preliminary="${1-}"
  shift

  local params=()
  local arg=
  local opt_cfg opt val opt_long opt_multi
  while [[ $# -gt 0 ]]; do
    arg="$1"
    shift

    opt_cfg=()
    case "$arg" in
    --)
      break
      ;;
    --*)
      opt="${arg:2}"
      for ((i = 0; i < ${#CMD_CFG_OPTS[@]}; i += _CMD_CFG_OPTS_TUPLE_LEN)); do
        [[ $opt != "${CMD_CFG_OPTS[i + _CMD_CFG_OPTS_IDX_LONG]}" ]] && continue
        opt_cfg=("${CMD_CFG_OPTS[@]:i:i+_CMD_CFG_OPTS_TUPLE_LEN}")
      done
      ;;
    -*)
      opt="${arg:1}"
      for ((i = 0; i < ${#CMD_CFG_OPTS[@]}; i += _CMD_CFG_OPTS_TUPLE_LEN)); do
        [[ $opt != "${CMD_CFG_OPTS[i + _CMD_CFG_OPTS_IDX_SHORT]}" ]] && continue
        opt_cfg=("${CMD_CFG_OPTS[@]:i:i+_CMD_CFG_OPTS_TUPLE_LEN}")
      done
      ;;
    *)
      params+=("$arg")
      [[ $is_preliminary ]] && break
      continue
      ;;
    esac

    ((!${#opt_cfg[@]})) && lib::abort "Unknown option: $arg"

    val=1
    if [[ -n ${opt_cfg[$_CMD_CFG_OPTS_IDX_PARAM]} ]]; then
      val="${1-}"
      (($#)) && shift
    fi
    [[ -z $val ]] && lib::abort "Missing value for option: $arg"

    opt_long="${opt_cfg[$_CMD_CFG_OPTS_IDX_LONG]}"
    opt_multi=
    [[ ${opt_cfg[$_CMD_CFG_OPTS_IDX_PARAM]} == *'[]' ]] && opt_multi=1
    _CMD_OPTS+=("$opt_long" "$val" "$opt_multi")
  done
  params+=("$@")

  _CMD_REST_ARGS=(${params+"${params[@]}"})
}

function cmd::_find_cmd() {
  local cmd=
  local maybe_cmds=("$1")
  [[ ${2-} && ${2:0:1} != '-' ]] && maybe_cmds+=("${1}_${2}")
  for maybe_cmd in "${maybe_cmds[@]}"; do
    maybe_cmd="${maybe_cmd// /_}"
    if declare -F "cmds::$maybe_cmd" >/dev/null; then
      cmd="$maybe_cmd"
      break
    fi
  done

  # Verify command.
  if [[ ! $cmd ]]; then
    local msg="Unknown command: $1"
    [[ ${2-} && ${2:0:1} != '-' ]] && msg+=" | \"$1 $2\""
    lib::abort "$msg"
  fi

  printf '%s\n' "$cmd"
}

function cmd::main() {
  # Reset args results.
  _CMD_OPTS=()
  _CMD_REST_ARGS=()

  # Reset args config.
  CMD_CFG_ARGS_FWD_ALL=
  CMD_CFG_OPTS=("${_CMD_CFG_OPTS_GLOBAL[@]}" "${_CMD_CFG_OPTS_PRELIM[@]}")
  CMD_CFG_PARAMS_HELP=''
  CMD_CFG_PARAMS_COUNT=0

  local args=()

  # Process preliminary args.
  cmd::_process_args 1 "$@"
  args=(${_CMD_REST_ARGS+"${_CMD_REST_ARGS[@]}"})

  # Process preliminary options.
  declare opt_long val
  for ((i = 0; i < ${#_CMD_OPTS[@]}; i += 3)); do
    opt_long="${_CMD_OPTS[i]}"
    val="${_CMD_OPTS[i + 1]}"
    case "$opt_long" in
    help) cmd::help ${args+"${args[@]}"} && exit 0 ;;
    version) cmd::version ${args+"${args[@]}"} && exit 0 ;;
    esac
  done

  # Abort if no args.
  ((!${#args[@]})) && cmd::help && exit 1

  # Determine command.
  local cmd
  cmd="$(cmd::_find_cmd "${args[@]:0:2}")"

  # Shift command from args.
  if [[ $cmd == "${args[0]}" ]]; then
    args=("${args[@]:1}")
  else
    args=("${args[@]:2}")
  fi

  # Update args config.
  CMD_CFG_OPTS=("${_CMD_CFG_OPTS_GLOBAL[@]}")
  declare -F "cmds::$cmd:args" >/dev/null &&
    "cmds::$cmd:args"

  # Process remaining args.
  if [[ ! $CMD_CFG_ARGS_FWD_ALL ]]; then
    cmd::_process_args '' ${args+"${args[@]}"}
    args=(${_CMD_REST_ARGS+"${_CMD_REST_ARGS[@]}"})
  fi

  # Verify parameters count.
  local min_args=${CMD_CFG_PARAMS_COUNT%-*}
  local max_args=${CMD_CFG_PARAMS_COUNT#*-}
  [[ -z $min_args ]] && min_args=0
  local args_range_err=
  ((min_args > ${#args[@]})) && args_range_err='Too few'
  ((max_args < ${#args[@]})) && [[ $max_args ]] && args_range_err='Too many'
  if [[ $args_range_err ]]; then
    local args_expect_range="${min_args}-${max_args}"
    [[ -z $max_args ]] && args_expect_range="${min_args}+"
    [[ $min_args == "$max_args" ]] && args_expect_range="${min_args}"
    lib::abort "$args_range_err parameters for [$cmd]; Expected [$args_expect_range] parameters, got [${#args[@]}]."
  fi

  # Flush options: Reset vars.
  declare opt_long
  for ((i = 0; i < ${#CMD_CFG_OPTS[@]}; i += _CMD_CFG_OPTS_TUPLE_LEN)); do
    opt_long="${CMD_CFG_OPTS[i + _CMD_CFG_OPTS_IDX_LONG]}"
    opt_long="${opt_long//-/_}"
    unset "_CMD_OPT_${opt_long}"
  done
  # Flush options: Set vars.
  declare opt_long val opt_multi cmd_opt_var cmd_opt_var_tmp
  for ((i = 0; i < ${#_CMD_OPTS[@]}; i += 3)); do
    opt_long="${_CMD_OPTS[i]}"
    val="${_CMD_OPTS[i + 1]}"
    opt_multi="${_CMD_OPTS[i + 2]}"

    cmd_opt_var="_CMD_OPT_${opt_long//-/_}"
    if [[ ! $opt_multi ]]; then
      # Set value: String.
      declare "${cmd_opt_var}=${val}"
    else
      # Set value: Array.
      cmd_opt_var_tmp="${cmd_opt_var}[@]"
      cmd_opt_var_tmp=(${!cmd_opt_var_tmp+"${!cmd_opt_var_tmp}"})
      declare "${cmd_opt_var}[${#cmd_opt_var_tmp[@]}]=$val"
    fi
  done

  # Process global options.
  [[ -n ${_CMD_OPT_help-} ]] && {
    args=("$cmd")
    cmd='help'
  }
  [[ -n ${_CMD_OPT_repo_dir-} ]] && _TILDEPOT_APP__REPO_ROOT="$_CMD_OPT_repo_dir"
  [[ -n ${_CMD_OPT_yes-} ]] && app::set_yes

  # Execute command.
  "cmds::$cmd" ${args+"${args[@]}"}
}

function cmd::version() {
  echo "$TILDEPOT_VERSION"
}

function cmd::help() {
  local cmd="${1-}"
  [[ -n ${2-} ]] && cmd="${1}_${2}"

  if [[ -n $cmd ]]; then
    cmd::_print_cmd_help "$cmd"
    return
  fi

  echo "tildepot $TILDEPOT_VERSION"
  echo

  cmd::_print_wrap "Manage your home setup, including applications, dotfiles, preferences, and more."
  cmd::_print_wrap "Safe for human consumption."
  echo
  echo 'Usage: tildepot [command] [options] [arguments]'

  echo
  echo 'Global options:'
  cmd::_print_opts_help "${_CMD_CFG_OPTS_GLOBAL[@]}"

  echo
  echo 'Options:'
  cmd::_print_opts_help "${_CMD_CFG_OPTS_PRELIM[@]}"

  if declare -F "cmds::list" >/dev/null; then
    while read -r cmd; do
      if [[ $cmd == *: ]]; then
        echo
        echo "$cmd"
      else
        cmd_help=
        if declare -F "cmds::$cmd:help" >/dev/null; then
          cmd_help="$("cmds::$cmd:help")"
        fi
        cmd::_print_two_col "  $(cmd::_fmt_cmd_str "$cmd")" "$cmd_help"
      fi
    done < <(cmds::list)
  fi
}

function cmd::_fmt_cmd_str() {
  local cmd_str="${1?}"
  cmd_str="${cmd//_/ }"
  cmd_str="${cmd_str/# /_}"
  cmd_str="${cmd_str//  / _}"
  echo "$cmd_str"
}

function cmd::_print_opts_help() {
  local opts=("$@")

  local opt_short opt_long opt_param opt_desc
  local opt_tpl
  for ((i = 0; i < ${#opts[@]}; i += _CMD_CFG_OPTS_TUPLE_LEN)); do
    local opt_short="${opts[i + _CMD_CFG_OPTS_IDX_SHORT]}"
    local opt_long="${opts[i + _CMD_CFG_OPTS_IDX_LONG]}"
    local opt_param="${opts[i + _CMD_CFG_OPTS_IDX_PARAM]}"
    local opt_desc="${opts[i + _CMD_CFG_OPTS_IDX_DESC]}"

    local opt_tpl="-${opt_short}, --${opt_long}"
    [[ -n $opt_param ]] && opt_tpl+=" ${opt_param}"
    cmd::_print_two_col "  $opt_tpl" "$opt_desc"
  done
}

function cmd::_print_cmd_help() {
  local cmd="${1?}"
  cmd="${cmd// /_}"

  local cmd_str
  cmd_str="$(cmd::_fmt_cmd_str "$cmd")"

  if ! declare -F "cmds::$cmd" >/dev/null; then
    lib::abort "Unknown command: $cmd_str"
  fi

  echo "tildepot $cmd_str"

  local cmd_help=
  if declare -F "cmds::$cmd:help" >/dev/null; then
    cmd_help="$("cmds::$cmd:help" --long)"
  fi
  if [[ $cmd_help ]]; then
    echo
    cmd::_print_wrap -- "$cmd_help"
  fi

  # Reset args config.
  CMD_CFG_ARGS_FWD_ALL=
  CMD_CFG_OPTS=()
  CMD_CFG_PARAMS_HELP=''
  CMD_CFG_PARAMS_COUNT=0
  # Update args config.
  declare -F "cmds::$cmd:args" >/dev/null &&
    "cmds::$cmd:args"

  echo
  local cmd_usage="$cmd_str [options]"
  [[ $CMD_CFG_ARGS_FWD_ALL ]] && cmd_usage="[options] $cmd_str"
  [[ $CMD_CFG_PARAMS_HELP ]] && cmd_usage+=" $CMD_CFG_PARAMS_HELP"
  echo "Usage: tildepot ${cmd_usage[*]}"

  echo
  echo 'Global options:'
  cmd::_print_opts_help "${_CMD_CFG_OPTS_GLOBAL[@]}"

  if [[ ${#CMD_CFG_OPTS[@]} -gt 0 && ! $CMD_CFG_ARGS_FWD_ALL ]]; then
    echo
    echo 'Options:'
    cmd::_print_opts_help "${CMD_CFG_OPTS[@]}"
  fi
}

function cmd::_print_two_col() {
  local left="${1?}"
  local right="${2?}"
  local col_w="${3-$_CMD_HELP_LEFT_COL_WIDTH}"

  cmd::_print_wrap -n "$left" ''

  local right_first_offset=
  if ((${#left} >= col_w)); then
    printf '\n'
  else
    right_first_offset="${#left}"
  fi

  cmd::_print_wrap -- "$right" '' "$col_w" "$right_first_offset"
}

function cmd::_print_wrap() {
  local skip_newline=
  case $1 in
  -n) skip_newline=1 && shift ;;
  --) shift ;;
  esac

  if [[ ! $_CMD_TERMINAL_COLUMNS ]] && tilde::cmd_exists tput; then
    _CMD_TERMINAL_COLUMNS="$(tput cols)"
    ((_CMD_TERMINAL_COLUMNS < _CMD_HELP_MAX_WIDTH)) && _CMD_HELP_MAX_WIDTH=$_CMD_TERMINAL_COLUMNS
  fi

  local text="${1?}"
  local max_w="${2:-$_CMD_HELP_MAX_WIDTH}"
  local indent="${3:-0}"
  local first_pre_indent="${4:-0}"

  local col_w_plus=$((max_w - indent + 1))

  local queue="$text "
  local is_first=1
  local safe_cut next_cut len i j c force_cut
  while ((${#queue})); do
    # Determine safe cut index.
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
        if [[ "${queue:i:2}" == $'\033[' ]]; then
          for ((j = i + 2; j < ${#queue}; j++)); do
            [[ "${queue:j:1}" != [0-9\;] ]] && i=j && break
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
