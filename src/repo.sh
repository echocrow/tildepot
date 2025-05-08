#!/usr/bin/env bash
#
# tildepot repo helpers.

function repo::_get_origin_url() {
  local repo_origin="$1"

  while [[ -z $repo_origin ]]; do
    repo_origin="$(lib::prompt "Repository origin:")"
  done

  if [[ $repo_origin =~ ^https?:// || $repo_origin =~ ^.+@.+\..+:.+ ]]; then
    echo "$repo_origin"
    return
  fi

  if [[ $repo_origin =~ ^[[:alnum:]_-]+/[[:alnum:]_-]+$ ]]; then
    echo "https://github.com/${repo_origin}.git"
    return
  fi

  if [[ $repo_origin =~ ^[[:alnum:]_-]+$ ]]; then
    echo "https://github.com/${repo_origin}/tildepot.git"
    return
  fi

  lib::abort "Invalid repository origin: [$repo_origin]"
}

function repo::_prepare_repo_root() {
  local root="$1"

  if [[ $root != "$_TILDEPOT_APP__REPO_DEFAULT_ROOT" && ! -d "$(dirname "$root")" ]]; then
    lib::abort "Parent directory does not exist for [$root]"
  fi
  mkdir -p "$root"

  if [[ -n $(ls -A "$root") ]]; then
    lib::abort "Repository directory is not empty: [$root]"
  fi
}

function repo::create() {
  local repo_origin="$1"
  if [[ -n $repo_origin ]]; then
    repo_origin="$(repo::_get_origin_url "$repo_origin")"
  fi

  local root="$_TILDEPOT_APP__REPO_ROOT"
  repo::_prepare_repo_root "$root"

  git -C "$root" init --quiet
  if [[ -n $repo_origin ]]; then
    git -C "$root" remote add origin "$repo_origin"
  fi

  lib::ohai "Created tildepot repository at [$root]."
}

function repo::_optional_git_init() {
  local root="$1"
  local repo_origin="$2"
  local branch="$3"

  local remote="origin"
  local tmp_user_mail="temp@temp.temp"

  # This function is invoked inside of an `if` statement; `set -e` behavior is
  # therefore unavailable.
  true &&
    git -C "$root" init --quiet -b "$branch" &&
    git -C "$root" remote add "$remote" "$repo_origin" &&
    git -C "$root" add . &&
    git -C "$root" -c user.email="$tmp_user_mail" commit -m "Initial download" &&
    git -C "$root" fetch &&
    git -C "$root" branch -u "$remote"/"$branch" &&
    git -C "$root" -c user.email="$tmp_user_mail" pull --rebase ||
    return 1

  # Reset temporary commit.
  local last_committer
  last_committer=$(git -C "$root" log -1 --pretty=format:"%ae")
  if [[ $last_committer == "$tmp_user_mail" ]]; then
    git -C "$root" reset HEAD~1 ||
      return 1
  fi
}

function repo::download() {
  local repo_origin="$1"
  repo_origin="$(repo::_get_origin_url "$repo_origin")"

  local root="$_TILDEPOT_APP__REPO_ROOT"
  repo::_prepare_repo_root "$root"

  # Attempt to download via git.
  if ! tilde::cmd_exists git || ! git -C "$root" clone "$repo_origin" "$root"; then
    # Fallback to download
    lib::ohai "Could not clone repo via git; downloading instead..."
    local remote="origin"
    local branch="main"
    local repo_origin_zip="${repo_origin%.git}/archive/refs/heads/$branch.zip"
    local temp_file
    temp_file=$(mktemp)
    local temp_dir
    temp_dir=$(mktemp -d)
    lib::download "$repo_origin_zip" >"$temp_file" || lib::abort "Failed to download repository."
    unzip -d "$temp_dir" "$temp_file" || lib::abort "Failed to download repository."
    rm "$temp_file"
    mv "$temp_dir"/*/* "$root"
    rm -rf "$temp_dir"
    if tilde::cmd_exists git; then
      lib::ohai "Initializing downloaded git repo..."
      if ! repo::_optional_git_init "$root" "$repo_origin" "$branch"; then
        lib::warn "Failed to initialize git repo. Continuing without pulling."
      fi
    fi
  fi

  lib::ohai "Downloaded tildepot repository to [$root]."
}

function repo::open() {
  local root="$_TILDEPOT_APP__REPO_ROOT"
  lib::require_dir "$root"
  open -R "$root"
}
