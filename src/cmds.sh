#!/usr/bin/env bash
#
# tildepot command definitions.

source "$(dirname "${BASH_SOURCE[0]}")/txt.sh"
source "$(dirname "${BASH_SOURCE[0]}")/cmd.sh"

###
# Global commands setup.
###

function cmds::app_name() {
  echo 'tildepot'
}

function cmds::app_version() {
  echo "v${TILDEPOT_VERSION?}"
}

function cmds::app_help() {
  lib::print_wrap "Manage your home setup, including applications, dotfiles, preferences, and more."
  lib::print_wrap "Safe for human consumption."
}

function cmds::global_args() {
  CMD_CFG_OPTS+=(h help '' 'Display help for this command.')
  CMD_CFG_OPTS+=(R repo-dir 'PATH' "Specify a custom tildepot repository path, overriding the default (${_TILDEPOT_APP__REPO_ROOT/#${HOME:-_}/~}).")
  CMD_CFG_OPTS+=(y yes '' 'Answer yes to all prompts.')
}

function cmds::root_args() {
  CMD_CFG_OPTS+=(v version '' 'Display the version of this tildepot instance.')
}

function cmds::root_cmd() {
  if [[ -n ${CMD_OPT_version-} ]]; then
    cmd::version
  elif [[ -n ${CMD_OPT_help-} ]]; then
    cmd::help
  else
    cmd::help
    exit 1
  fi
}

function cmds::handle_prelim_arg() {
  local opt_long="${1?}"
  local _value="${2?}"
  local args=("${@:3}")
  case "$opt_long" in
  help) cmd::help ${args+"${args[@]}"} && exit 0 ;;
  version) cmds::cmd:version && exit 0 ;;
  esac
}

function cmds::handle_pre_cmd() {
  local cmd="${1?}"

  # Process global options.
  if [[ -n ${CMD_OPT_help-} ]]; then
    cmd::help ${cmd:+"$cmd"}
    exit 0
  fi

  if [[ -n ${CMD_OPT_repo_dir-} ]]; then
    _TILDEPOT_APP__REPO_ROOT="$CMD_OPT_repo_dir"
  fi

  if [[ -n ${CMD_OPT_yes-} ]]; then
    app::set_yes
  fi

}

function cmds::list() {
  echo 'First-time:'
  echo init
  # echo onboard

  echo 'Day-to-day:'
  echo restore
  echo save
  echo update

  echo 'Repository:'
  # echo repo add
  # echo repo diff
  echo repo_download
  echo repo_init
  echo repo_open
  # echo repo_status

  echo 'Binary:'
  echo self_install
  echo self_uninstall
  echo self_update

  echo 'Miscellaneous:'
  echo git
  echo help
  echo run
  echo version
}

###
# Command helpers.
###

function cmds::_hook_args() {
  CMD_CFG_OPTS+=(b bundle 'BUNDLE[]' 'Limit command to one or more bundles.')
  CMD_CFG_OPTS+=(f force '' 'Force-run the hook, ignoring skip-checks.')
}

###
# First-time commands.
###

function cmds::cmd:init:help() {
  local long= && [[ ${1-} == '--long' ]] && long=1
  if [[ $long ]]; then
    echo 'Run first-time initialization on a new machine, performing the following actions:'
    echo "- Invoke bundles, executing hooks for ${txt_bold}install${txt_reset}, ${txt_bold}restore${txt_reset}, and ${txt_bold}update${txt_reset}."
    echo
    echo "${txt_yellow}Warning:${txt_reset} This will overwrite any changes made to your system since your last save state."
  else
    echo 'Run first-time initialization on a new machine.'
  fi
}
function cmds::cmd:init:args() {
  cmds::_hook_args
}
function cmds::cmd:init() {
  local bundles=(${CMD_OPT_bundle+"${CMD_OPT_bundle[@]}"})
  [[ ${CMD_OPT_force-} ]] && app::set_force

  local hooks=(install restore update)
  bundles::invoke ${bundles+"${bundles[@]}"} -- "${hooks[@]}"
}

###
# Day-to-day commands.
###

function cmds::cmd:restore:help() {
  local long= && [[ ${1-} == '--long' ]] && long=1
  echo 'Restore data from your repository into your system.'
  if [[ $long ]]; then
    echo "${txt_yellow}Warning:${txt_reset} This will overwrite any changes made to your system since your last save state."
  fi
}
function cmds::cmd:restore:args() {
  cmds::_hook_args
}
function cmds::cmd:restore() {
  cmds::cmd:run restore
}

function cmds::cmd:save:help() {
  echo 'Save system data into your tildepot repository.'
}
function cmds::cmd:save:args() {
  cmds::_hook_args
}
function cmds::cmd:save() {
  cmds::cmd:run save
}

function cmds::cmd:update:help() {
  echo 'Update commands & applications.'
}
function cmds::cmd:update:args() {
  cmds::_hook_args
}
function cmds::cmd:update() {
  cmds::cmd:run update
}

###
# Repo commands.
###

function cmds::cmd:repo_download:help() {
  echo 'Download an existing tildepot repository.'
}
function cmds::cmd:repo_download:args() {
  CMD_CFG_OPTS+=(o origin URL 'Specify a tildepot repository origin URL.')
}
function cmds::cmd:repo_download() {
  local origin="${CMD_OPT_origin-}"
  repo::download "$origin"
}

function cmds::cmd:repo_init:help() {
  echo 'Initialize a new tildepot repository.'
}
function cmds::cmd:repo_init:args() {
  CMD_CFG_OPTS+=(o origin URL 'Specify a tildepot repository origin URL.')
}
function cmds::cmd:repo_init() {
  local origin="${CMD_OPT_origin-}"
  repo::init "$origin"
}

function cmds::cmd:repo_open:help() {
  echo 'Open the tildepot repository in your file browser.'
}
function cmds::cmd:repo_open:args() {
  true
}
function cmds::cmd:repo_open() {
  repo::open
}

###
# Self commands.
###

function cmds::cmd:self_install:help() {
  # shellcheck disable=SC2016
  echo 'Add tildepot to your $PATH.'
}
function cmds::cmd:self_install:args() {
  CMD_CFG_OPTS+=(p path PATH 'Specify a custom tildepot path.')
}
function cmds::cmd:self_install() {
  local path="${CMD_OPT_path-}"
  self::install "$path"
}

function cmds::cmd:self_uninstall:help() {
  # shellcheck disable=SC2016
  echo 'Remove tildepot from your $PATH.'
}
function cmds::cmd:self_uninstall:args() {
  CMD_CFG_OPTS+=(p path PATH 'Specify a custom tildepot path.')
}
function cmds::cmd:self_uninstall() {
  local path="${CMD_OPT_path-}"
  self::uninstall "$path"
}

function cmds::cmd:self_update:help() {
  echo 'Update tildepot.'
}
function cmds::cmd:self_update:args() {
  CMD_CFG_OPTS+=(p path PATH 'Specify a custom tildepot path.')
}
function cmds::cmd:self_update() {
  local path="${CMD_OPT_path-}"
  self::update "$path"
}

###
# Run commands.
###

function cmds::cmd:run:help() {
  echo 'Invoke a hook, e.g. install, update, save, or restore.'
}
function cmds::cmd:run:args() {
  cmds::_hook_args
  CMD_CFG_PARAMS_HELP='HOOK'
  CMD_CFG_PARAMS_COUNT=1
}
function cmds::cmd:run() {
  local bundles=(${CMD_OPT_bundle+"${CMD_OPT_bundle[@]}"})
  [[ ${CMD_OPT_force-} ]] && app::set_force

  local hook="${1?}"

  bundles::invoke ${bundles+"${bundles[@]}"} -- "$hook"
}

###
# Misc commands.
###

function cmds::cmd:git:help() {
  echo 'Execute a git command in the tildepot repository.'
}
function cmds::cmd:git:args() {
  CMD_CFG_ARGS_FWD_ALL=1
  CMD_CFG_PARAMS_HELP='ARGS'
  CMD_CFG_PARAMS_COUNT=1-
}
function cmds::cmd:git() {
  local root="$_TILDEPOT_APP__REPO_ROOT"
  lib::require_dir "$root"
  git -C "$root" "$@"
}

function cmds::cmd:help:help() {
  echo 'Display help for a specific command.'
}
function cmds::cmd:help:args() {
  CMD_CFG_PARAMS_HELP='COMMAND'
  CMD_CFG_PARAMS_COUNT=-2
}
function cmds::cmd:help() {
  cmd::help "$@"
}

function cmds::cmd:version:help() {
  echo 'Display the version of this tildepot instance.'
}
function cmds::cmd:version:args() {
  CMD_CFG_OPTS+=(s short '' 'Print only the version number.')
}
function cmds::cmd:version() {
  local short=
  [[ ${CMD_OPT_short-} ]] && short=1
  if [[ $short ]]; then
    echo "$TILDEPOT_VERSION"
  else
    cmd::version
  fi
}

###
# Internal commands.
###

function cmds::cmd:_exec-bundle:help() {
  echo 'Execute one or more hooks of a specific bundle.'
  echo 'This command is intended for internal use only.'
}
function cmds::cmd:_exec-bundle:args() {
  CMD_CFG_OPTS+=(f force '' 'Force-run the hook, ignoring skip-checks.')
  CMD_CFG_PARAMS_HELP='BUNDLE HOOK [HOOK...]'
  CMD_CFG_PARAMS_COUNT=1-
}
function cmds::cmd:_exec-bundle() {
  [[ ${CMD_OPT_force-} ]] && app::set_force

  local bundle_basename="${1-}"
  [[ -z $bundle_basename ]] && lib::abort "Missing bundle"
  shift

  local hooks=("$@")
  ((${#hooks[@]} == 0)) && lib::abort "Missing hooks"

  bundle::exec_hooks "$bundle_basename" "${hooks[@]}"
}
