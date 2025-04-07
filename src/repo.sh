#!/bin/bash
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

  if [[ $root != "$APP_REPO_DEFAULT_ROOT" && ! -d "$(dirname "$root")" ]]; then
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

  local root="$APP_REPO_ROOT"
  repo::_prepare_repo_root "$root"

  git -C "$root" init --quiet
  if [[ -n $repo_origin ]]; then
    git -C "$root" remote add origin "$repo_origin"
  fi

  lib::ohai "Created tildepot repository at [$root]."
}

function repo::download() {
  local repo_origin="$1"
  repo_origin="$(repo::_get_origin_url "$repo_origin")"

  local root="$APP_REPO_ROOT"
  repo::_prepare_repo_root "$root"

  git -C "$root" clone "$repo_origin" "$root"

  lib::ohai "Downloaded tildepot repository to [$root]."
}

function repo::open() {
  local root="$APP_REPO_ROOT"
  lib::require_dir "$root"
  open -R "$root"
}
