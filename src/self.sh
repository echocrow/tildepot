#!/usr/bin/env bash
#
# tildepot self helpers.

_TILDEPOT_SELF__DOWNLOAD_URL="$_TILDEPOT_APP__REPO_URL/releases/latest/download/tildepot"

_TILDEPOT_SELF__DEFAULT_PATH="/usr/local/bin"

function self::_get_installed_bin() {
  which tildepot || true
}

function self::_sudo_unless_writable() {
  local path_to_check="$1"
  local args=("${@:2}")

  if [[ -w $path_to_check ]]; then
    "${args[@]}"
  else
    sudo "${args[@]}"
  fi
}

function self::install() {
  local path="${1:-$_TILDEPOT_SELF__DEFAULT_PATH}"

  lib::require_dir "$path"

  local current_bin="$0"

  local installed_bin
  installed_bin="$(self::_get_installed_bin)"

  local target_bin="$path/tildepot"
  if [[ $target_bin == "$current_bin" ]]; then
    lib::ohai "Tildepot is already installed at [$target_bin]."
    return
  fi

  if [[ -n $installed_bin && $installed_bin != "$target_bin" ]]; then
    lib::require_confirm \
      "Tildepot is already installed at [$installed_bin]" \
      "Continue installing to [$target_bin]?"
  fi

  if [[ -f $target_bin ]]; then
    lib::require_confirm "Replace existing [$target_bin] with [$current_bin]?"
    rm "$target_bin"
  fi

  self::_sudo_unless_writable "$path" cp "$current_bin" "$target_bin"
  chmod +x "$target_bin"

  lib::ohai "Installed Tildepot to [$target_bin]."
}

function self::update() {
  local path="$1"

  local target_bin
  if [[ -z $path ]]; then
    target_bin="$0"
  else
    target_bin="$path/tildepot"
  fi
  path="$(dirname "$target_bin")"

  lib::require_dir "$path"
  [[ ! -f $target_bin ]] && lib::abort "Tildepot is not installed at [$target_bin]."

  local temp_file
  temp_file=$(mktemp)

  lib::download "$_TILDEPOT_SELF__DOWNLOAD_URL" >"$temp_file"
  chmod +x "$temp_file"

  local current_version="$TILDEPOT_VERSION"
  local new_version
  if ! new_version="$("$temp_file" version --short)"; then
    lib::abort "Failed to update Tildepot: Could not determine new version."
  fi
  if [[ $new_version == "$current_version" ]]; then
    rm "$temp_file"
    lib::ohai "Tildepot is already up to date."
  else
    self::_sudo_unless_writable "$path" mv "$temp_file" "$target_bin"
    lib::ohai "Updated Tildepot from [$current_version] to [$new_version]."
  fi
}

function self::uninstall() {
  local path="$1"

  local target_bin
  if [[ -z $path ]]; then
    target_bin="$0"
  else
    target_bin="$path/tildepot"
  fi
  path="$(dirname "$target_bin")"

  lib::require_dir "$path"
  [[ ! -f $target_bin ]] && lib::abort "Tildepot is not installed at [$target_bin]."

  lib::require_confirm "Uninstall tildepot from [$target_bin]?"

  self::_sudo_unless_writable "$path" rm -f "$target_bin"

  lib::ohai "Uninstalled tildepot from [$target_bin]."
}
