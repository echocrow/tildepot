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
_CMD_CFG_OPTS_GLOBAL+=(R repo-dir 'PATH' "Specify a custom tildepot repository path, overriding the default (${txt_bold}${_TILDEPOT_APP__REPO_ROOT}${txt_reset}).")
_CMD_CFG_OPTS_GLOBAL+=(y yes '' 'Answer yes to all prompts.')

_CMD_CFG_OPTS_PRELIM=()
_CMD_CFG_OPTS_PRELIM+=(v version '' 'Display the version of tildepot.')

_CMD_OPTS=()
_CMD_REST_ARGS=()
function cmd::_process_args() {
  local is_preliminary="${1-}"
  shift

  local params=()
  local arg=
  local opt_cfg opt val opt_long
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
    _CMD_OPTS+=("$opt_long" "$val")
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
  for ((i = 0; i < ${#_CMD_OPTS[@]}; i += 2)); do
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
  declare opt_long val
  for ((i = 0; i < ${#_CMD_OPTS[@]}; i += 2)); do
    opt_long="${_CMD_OPTS[i]}"
    opt_long="${opt_long//-/_}"
    val="${_CMD_OPTS[i + 1]}"
    declare "_CMD_OPT_${opt_long}=${val:-''}"
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
  echo "TODO: cmd help [$*]"
}
