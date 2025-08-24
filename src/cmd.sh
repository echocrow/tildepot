#!/usr/bin/env bash
#
# tildepot command entrypoint & helpers.

source "$(dirname "${BASH_SOURCE[0]}")/txt.sh"
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# Command config: Skip arg processing and forwarding all args as-is instead.
CMD_CFG_ARGS_FWD_ALL=

# Command config: Tuple-list of option definitions, containing:
# - Short-option name
# - Long-option name
# - Parameter placeholder (or empty string for no parameter)
# - Option description
CMD_CFG_OPTS=()

# Command config: Placeholder(s) for additional parameters.
CMD_CFG_PARAMS_HELP=''

# Command config: Count or range of additional parameters. Can be one of:
# - 0: No additional parameters
# - n: Exactly n (required) parameters
# - n-m: Between n and m (inclusive) parameters
# - n-: At least n parameters (no upper limit)
# - -n: At most n parameters (no lower limit)
CMD_CFG_PARAMS_COUNT=0

_CMD_CFG_OPTS_IDX_SHORT=0
_CMD_CFG_OPTS_IDX_LONG=1
_CMD_CFG_OPTS_IDX_PARAM=2
_CMD_CFG_OPTS_IDX_DESC=3
_CMD_CFG_OPTS_TUPLE_LEN=4

_CMD_HELP_LEFT_COL_WIDTH=28

_CMD_OPTS=()
_CMD_OPTS_IDX_NAME=0
_CMD_OPTS_IDX_VALUE=1
_CMD_OPTS_IDX_LIST=2
_CMD_OPTS_TUPLE_LEN=3

_CMD_REST_ARGS=()

function cmd::_process_args() {
  local is_preliminary="${1-}"
  shift

  local params=()
  local arg=
  local opt_cfg opt val opt_long opt_is_list
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
    opt_is_list=
    [[ ${opt_cfg[$_CMD_CFG_OPTS_IDX_PARAM]} == *'[]' ]] && opt_is_list=1
    _CMD_OPTS+=("$opt_long" "$val" "$opt_is_list")
  done
  params+=("$@")

  _CMD_REST_ARGS=(${params+"${params[@]}"})
}

function cmd::_find_cmd() {
  local cmd=
  local maybe_cmds=("$1")
  [[ ${2-} && ${2:0:1} != '-' ]] && maybe_cmds+=("${1}_${2}")
  for cmd in "${maybe_cmds[@]}"; do
    cmd="${cmd// /_}"
    if declare -F "cmds::cmd:$cmd" >/dev/null; then
      printf '%s\n' "$cmd"
      break
    fi
  done
}

function cmd::_flush_opts_ops() {
  declare opt_long opt_val opt_is_list cmd_opt_var cmd_opt_arr_len_var cmd_opt_arr_idx
  for ((i = 0; i < ${#_CMD_OPTS[@]}; i += _CMD_OPTS_TUPLE_LEN)); do
    opt_long="${_CMD_OPTS[i + _CMD_OPTS_IDX_NAME]}"
    opt_val="${_CMD_OPTS[i + _CMD_OPTS_IDX_VALUE]}"
    opt_is_list="${_CMD_OPTS[i + _CMD_OPTS_IDX_LIST]}"

    cmd_opt_var="CMD_OPT_${opt_long//-/_}"
    if [[ ! $opt_is_list ]]; then
      # Handle string.
      echo "${cmd_opt_var}=${opt_val}"
    else
      # Handle array.
      cmd_opt_arr_len_var="__CMD_OPT_ARR_LEN_${cmd_opt_var}"
      cmd_opt_arr_idx="${!cmd_opt_arr_len_var-0}"
      echo "${cmd_opt_var}[${cmd_opt_arr_idx}]=$opt_val"

      declare "${cmd_opt_arr_len_var}=$((cmd_opt_arr_idx + 1))"
    fi
  done
}

function cmd::main() {
  # Reset args results.
  _CMD_OPTS=()
  _CMD_REST_ARGS=()

  # Reset args config.
  CMD_CFG_ARGS_FWD_ALL=
  CMD_CFG_OPTS=()
  CMD_CFG_PARAMS_HELP=''
  CMD_CFG_PARAMS_COUNT=0

  # Update args config.
  CMD_CFG_OPTS=()
  declare -F "cmds::global_args" >/dev/null &&
    cmds::global_args
  declare -F "cmds::root_args" >/dev/null &&
    cmds::root_args

  local args=()

  # Process preliminary args.
  cmd::_process_args 1 "$@"
  args=(${_CMD_REST_ARGS+"${_CMD_REST_ARGS[@]}"})

  # Process preliminary options.
  if declare -F "cmds::handle_prelim_arg" >/dev/null; then
    declare opt_long val
    for ((i = 0; i < ${#_CMD_OPTS[@]}; i += _CMD_OPTS_TUPLE_LEN)); do
      opt_long="${_CMD_OPTS[i + _CMD_OPTS_IDX_NAME]}"
      opt_val="${_CMD_OPTS[i + _CMD_OPTS_IDX_VALUE]}"
      cmds::handle_prelim_arg "$opt_long" "$opt_val" ${args+"${args[@]}"}
    done
  fi

  # Handle root command.
  if ((!${#args[@]})); then
    # Flush options.
    while read -r decl; do
      [[ $decl ]] && declare "$decl"
    done <<<"$(cmd::_flush_opts_ops)"

    if declare -F "cmds::root_cmd" >/dev/null; then
      cmds::root_cmd
      exit 0
    else
      cmd::help && exit 1
    fi
  fi

  # Determine command.
  local cmd
  cmd="$(cmd::_find_cmd "${args[@]:0:2}")"
  if [[ ! $cmd ]]; then
    local msg="Unknown command: $1"
    [[ ${2-} && ${2:0:1} != '-' ]] && msg+=" | \"$1 $2\""
    lib::abort "$msg"
  fi

  # Shift command from args.
  local args_start=1
  [[ $cmd != "${args[0]}" ]] && args_start=2
  args=("${args[@]:args_start}")

  # Update args config.
  CMD_CFG_OPTS=()
  declare -F "cmds::global_args" >/dev/null &&
    cmds::global_args
  declare -F "cmds::cmd:$cmd:args" >/dev/null &&
    "cmds::cmd:$cmd:args"

  # Process remaining args.
  if [[ ! $CMD_CFG_ARGS_FWD_ALL ]]; then
    cmd::_process_args '' ${args+"${args[@]}"}
    args=(${_CMD_REST_ARGS+"${_CMD_REST_ARGS[@]}"})
  fi

  # Flush options.
  while read -r decl; do
    [[ $decl ]] && declare "$decl"
  done <<<"$(cmd::_flush_opts_ops)"

  # Verify parameters count.
  if [[ -z ${CMD_OPT_help-} ]]; then
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
      lib::abort "$args_range_err parameters for [$cmd]; expected [$args_expect_range], got [${#args[@]}]."
    fi
  fi

  # Invoke pre-command hook.
  declare -F "cmds::handle_pre_cmd" >/dev/null &&
    cmds::handle_pre_cmd "$cmd"

  # Execute command.
  "cmds::cmd:$cmd" ${args+"${args[@]}"}
}

function cmd::app_name() {
  ! declare -F "cmds::app_name" >/dev/null && lib::abort "Missing app name"
  cmds::app_name
}
function cmd::app_version() {
  ! declare -F "cmds::app_version" >/dev/null && lib::abort "Missing app version"
  cmds::app_version
}

function cmd::version() {
  printf '%s %s\n' "$(cmd::app_name)" "$(cmd::app_version)"
}

# shellcheck disable=SC2120
function cmd::help() {
  local cmd="${1-}"
  [[ ${2-} ]] && cmd="${1}_${2}"

  if [[ $cmd ]]; then
    cmd::_print_cmd_help "$cmd"
    return
  fi

  cmd::version

  if declare -F "cmds::app_help" >/dev/null; then
    echo
    cmds::app_help
  fi

  echo
  echo "Usage: $(cmd::app_name) [command] [options] [arguments]"

  cmd::_print_global_opts --with-root

  local printed_category=
  if declare -F "cmds::list" >/dev/null; then
    while read -r cmd; do
      if [[ $cmd == *: ]]; then
        echo
        echo "$cmd"
        printed_category=1
      else
        if [[ ! $printed_category ]]; then
          echo
          echo 'Commands:'
          printed_category=1
        fi
        cmd_help=
        declare -F "cmds::cmd:$cmd:help" >/dev/null &&
          cmd_help="$("cmds::cmd:$cmd:help")"
        lib::print_two_col "  $(cmd::_fmt_cmd_str "$cmd")" "$cmd_help" "$_CMD_HELP_LEFT_COL_WIDTH"
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
  local title="${1?}"
  shift
  local opts=("$@")

  ((!${#opts[@]})) && return

  printf '\n%s:\n' "$title"

  local opt_short opt_long opt_param opt_desc
  local opt_tpl
  for ((i = 0; i < ${#opts[@]}; i += _CMD_CFG_OPTS_TUPLE_LEN)); do
    local opt_short="${opts[i + _CMD_CFG_OPTS_IDX_SHORT]}"
    local opt_long="${opts[i + _CMD_CFG_OPTS_IDX_LONG]}"
    local opt_param="${opts[i + _CMD_CFG_OPTS_IDX_PARAM]}"
    local opt_desc="${opts[i + _CMD_CFG_OPTS_IDX_DESC]}"

    local opt_tpl="-${opt_short}, --${opt_long}"
    [[ -n $opt_param ]] && opt_tpl+=" ${opt_param}"
    lib::print_two_col "  $opt_tpl" "$opt_desc" "$_CMD_HELP_LEFT_COL_WIDTH"
  done
}

function cmd::_print_cmd_help() {
  local cmd="${1?}"
  cmd="${cmd// /_}"

  local cmd_str
  cmd_str="$(cmd::_fmt_cmd_str "$cmd")"

  ! declare -F "cmds::cmd:$cmd" >/dev/null &&
    lib::abort "Unknown command: $cmd_str"

  echo "$(cmd::app_name) $cmd_str"

  local cmd_help=
  declare -F "cmds::cmd:$cmd:help" >/dev/null &&
    cmd_help="$("cmds::cmd:$cmd:help" --long)"
  if [[ $cmd_help ]]; then
    echo
    lib::print_wrap -- "$cmd_help"
  fi

  # Reset args config.
  CMD_CFG_ARGS_FWD_ALL=
  CMD_CFG_OPTS=()
  CMD_CFG_PARAMS_HELP=''
  CMD_CFG_PARAMS_COUNT=0

  # Update args config.
  CMD_CFG_OPTS=()
  declare -F "cmds::global_args" >/dev/null &&
    cmds::global_args
  declare -F "cmds::cmd:$cmd:args" >/dev/null &&
    "cmds::cmd:$cmd:args"

  echo
  local cmd_usage="$cmd_str"
  if [[ ${#CMD_CFG_OPTS[@]} -gt 0 ]]; then
    if [[ $CMD_CFG_ARGS_FWD_ALL ]]; then
      cmd_usage="[options] $cmd_str"
    else
      cmd_usage="$cmd_str [options]"
    fi
  fi

  if [[ $CMD_CFG_PARAMS_HELP ]]; then
    cmd_usage+=" $CMD_CFG_PARAMS_HELP"
  elif [[ $CMD_CFG_PARAMS_COUNT != 0 ]]; then
    cmd_usage+=" [arguments]"
  fi

  echo "Usage: $(cmd::app_name) $cmd_usage"

  cmd::_print_global_opts

  if declare -F "cmds::cmd:$cmd:args" >/dev/null && [[ ! $CMD_CFG_ARGS_FWD_ALL ]]; then
    CMD_CFG_OPTS=()
    "cmds::cmd:$cmd:args"
    cmd::_print_opts_help 'Options' "${CMD_CFG_OPTS[@]}"
  fi
}

function cmd::_print_global_opts() {
  local with_root= && [[ ${1-} == '--with-root' ]] && with_root=1

  if declare -F "cmds::global_args" >/dev/null; then
    CMD_CFG_OPTS=()
    cmds::global_args
    cmd::_print_opts_help 'Global options' "${CMD_CFG_OPTS[@]}"
  fi

  if [[ $with_root ]] && declare -F "cmds::root_args" >/dev/null; then
    CMD_CFG_OPTS=()
    cmds::root_args
    cmd::_print_opts_help 'Options' "${CMD_CFG_OPTS[@]}"
  fi
}
