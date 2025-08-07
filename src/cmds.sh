#!/usr/bin/env bash
#
# tildepot command definitions.

source "$(dirname "${BASH_SOURCE[0]}")/txt.sh"
source "$(dirname "${BASH_SOURCE[0]}")/cmd.sh"

###
# Command helpers.
###

function cmds::_:hook_args() {
  CMD_CFG_OPTS+=(b bundle 'BUNDLE[]' 'Limit command to one or more bundles.')
  CMD_CFG_OPTS+=(f force '' 'Force-run the hook, ignoring skip-checks.')
}

###
# First-time commands.
###

function cmds::init:help() {
  echo 'Run first-time initialization, performing the following actions:'
  echo "- Invoke bundles, executing hooks for ${txt_bold}install${txt_reset}, ${txt_bold}restore${txt_reset}, and ${txt_bold}update${txt_reset}."
  bundles::print_restore_warning
}
function cmds::init:args() {
  cmds::_:hook_args
}
function cmds::init() {
  local bundles=(${_CMD_OPT_bundle+"${_CMD_OPT_bundle[@]}"})
  [[ ${_CMD_OPT_force-} ]] && app::set_force

  local hooks=(install restore update)
  bundles::invoke ${bundles+"${bundles[@]}"} -- "${hooks[@]}"
}

###
# Day-to-day commands.
###

function cmds::restore:help() {
  echo 'Restore data from your repository into your system, overriding current data.'
}
function cmds::restore:args() {
  cmds::_:hook_args
}
function cmds::restore() {
  cmds::run restore
}

function cmds::save:help() {
  echo 'Save system data to your tildepot repository.'
}
function cmds::save:args() {
  cmds::_:hook_args
}
function cmds::save() {
  cmds::run save
}

function cmds::update:help() {
  echo 'Update commands & applications.'
}
function cmds::update:args() {
  cmds::_:hook_args
}
function cmds::update() {
  cmds::run update
}

###
# Repo commands.
###

function cmds::repo_download:help() {
  echo 'Download existing tildepot repository.'
}
function cmds::repo_download:args() {
  CMD_CFG_OPTS+=(o origin URL 'Specify a tildepot repository origin URL.')
}
function cmds::repo_download() {
  local origin="${_CMD_OPT_origin-}"
  repo::download "$origin"
}

function cmds::repo_init:help() {
  echo 'Initialize a new tildepot repository.'
}
function cmds::repo_init:args() {
  CMD_CFG_OPTS+=(o origin URL 'Specify a tildepot repository origin URL.')
}
function cmds::repo_init() {
  local origin="${_CMD_OPT_origin-}"
  repo::init "$origin"
}

function cmds::repo_open:help() {
  echo 'Open the tildepot repository in your file browser.'
}
function cmds::repo_open:args() {
  true
}
function cmds::repo_open() {
  repo::open
}

###
# Self commands.
###

function cmds::self_install:help() {
  echo 'Add tildepot in your PATH.'
}
function cmds::self_install:args() {
  CMD_CFG_OPTS+=(p path PATH 'Specify a custom tildepot path.')
}
function cmds::self_install() {
  local path="${_CMD_OPT_path-}"
  self::install "$path"
}

function cmds::self_uninstall:help() {
  echo 'Remove tildepot from your PATH.'
}
function cmds::self_uninstall:args() {
  CMD_CFG_OPTS+=(p path PATH 'Specify a custom tildepot path.')
}
function cmds::self_uninstall() {
  local path="${_CMD_OPT_path-}"
  self::uninstall "$path"
}

function cmds::self_update:help() {
  echo 'Update tildepot.'
}
function cmds::self_update:args() {
  CMD_CFG_OPTS+=(p path PATH 'Specify a custom tildepot path.')
}
function cmds::self_update() {
  local path="${_CMD_OPT_path-}"
  self::update "$path"
}

###
# Run commands.
###

function cmds::run:help() {
  echo "Invoke a hook, such as ${txt_bold}install${txt_reset}, ${txt_bold}update${txt_reset}, ${txt_bold}save${txt_reset}, or ${txt_bold}restore${txt_reset}."
}
function cmds::run:args() {
  cmds::_:hook_args
  CMD_CFG_PARAMS_HELP='HOOK'
  CMD_CFG_PARAMS_COUNT=1
}
function cmds::run() {
  local bundles=(${_CMD_OPT_bundle+"${_CMD_OPT_bundle[@]}"})
  [[ ${_CMD_OPT_force-} ]] && app::set_force

  local hook="${1?}"

  bundles::invoke ${bundles+"${bundles[@]}"} -- "$hook"
}

###
# Misc commands.
###

function cmds::git:help() {
  echo 'Execute a git command in the tildepot repository.'
}
function cmds::git:args() {
  CMD_CFG_ARGS_FWD_ALL=1
  CMD_CFG_PARAMS_HELP='ARGS'
  CMD_CFG_PARAMS_COUNT=1-
}
function cmds::git() {
  git -C "$_TILDEPOT_APP__REPO_ROOT" "$@"
}

function cmds::help:help() {
  echo 'Display help for a specific command.'
}
function cmds::help:args() {
  CMD_CFG_PARAMS_HELP='COMMAND'
  CMD_CFG_PARAMS_COUNT=-2
}
function cmds::help() {
  cmd::help "$@"
}

function cmds::version:help() {
  echo 'Display the version of tildepot.'
}
function cmds::version:args() {
  true
}
function cmds::version() {
  cmd::version
}

###
# Internal commands.
###

function cmds::_exec-bundle:help() {
  echo 'Execute one or more hooks of a specific bundle.'
  echo 'This command is intended for internal use only.'
}
function cmds::_exec-bundle:args() {
  CMD_CFG_OPTS+=(f force '' 'Force-run the hook, ignoring skip-checks.')
  CMD_CFG_PARAMS_HELP='BUNDLE HOOK [HOOK...]'
  CMD_CFG_PARAMS_COUNT=1-
}
function cmds::_exec-bundle() {
  [[ ${_CMD_OPT_force-} ]] && app::set_force

  local bundle_basename="${1-}"
  [[ -z $bundle_basename ]] && lib::abort "Missing bundle"
  shift

  local hooks=("$@")
  ((${#hooks[@]} == 0)) && lib::abort "Missing hooks"

  bundle::exec_hooks "$bundle_basename" "${hooks[@]}"
}
