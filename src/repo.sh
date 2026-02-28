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

function repo::init() {
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

  echo ".tildepot" >>"$root/.gitignore"

  if git config user.email >/dev/null; then
    git -C "$root" add .
    git -C "$root" commit -m "Initial commit"
  fi

  lib::ohai "Initialized tildepot repository at [$root]."
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

function repo::cleanup() {
  local cleanup_all=1
  local cleanup_bundles=
  local cleanup_temp=
  local cleanup_state=
  while [[ $# -gt 0 ]]; do
    cleanup_all=
    case "$1" in
    --bundles) cleanup_bundles=1 ;;
    --temp) cleanup_temp=1 ;;
    --state) cleanup_state=1 ;;
    -*) lib::abort "Unknown option: $1" ;;
    *) break ;;
    esac
    shift
  done

  local root="$_TILDEPOT_APP__REPO_ROOT"
  lib::require_dir "$root"

  if [[ $cleanup_all || $cleanup_bundles ]]; then
    lib::ohai "Cleaning up bundles..."
    repo::_cleanup_bundles "$root"
    echo
  fi
  if [[ $cleanup_all || $cleanup_temp ]]; then
    lib::ohai "Cleaning up temporary files..."
    repo::_cleanup_temp "$root"
    echo
  fi
  if [[ $cleanup_all || $cleanup_state ]]; then
    lib::ohai "Cleaning up state files..."
    repo::_cleanup_state "$root"
    echo
  fi

  lib::success "Cleaned up tildepot repository."
}

function repo::_cleanup_bundles() {
  local root="$1"

  local downloads_dir="$root/.tildepot/bundles"

  local basename
  local file
  local want_files=()
  local parent_files=
  parent_files="$(bundles::list_parent_files)"
  if [[ $parent_files ]]; then
    while read -r file; do
      [[ $file && $file == "${downloads_dir}/"* ]] && want_files+=("$(basename "$file")")
    done <<<"$parent_files"
  fi

  local file
  local deleted=
  if [[ -d $downloads_dir ]]; then
    for file in "$downloads_dir"/*; do
      if ! lib::in_array "$(basename "$file")" ${want_files+"${want_files[@]}"}; then
        rm -rf "$file"
        lib::print "- Deleted [$file]"
        deleted=1
      fi
    done
  fi
  if [[ ! $deleted ]]; then
    lib::print_subdued 'Nothing to delete.'
  fi
}

function repo::_cleanup_temp() {
  local root="$1"

  local temp_state_dir="$root/.tildepot/state"
  if [[ -d $temp_state_dir ]]; then
    rm -rf "$root/.tildepot/state"
    lib::print "- Deleted temporary state"
  else
    lib::print_subdued 'Nothing to delete.'
  fi
}

function repo::_cleanup_state() {
  local root="$1"

  local state_dir="$root/state"

  local basename
  local bundles=()
  while read -r basename; do
    bundles+=("$(bundle::fmt_bundle_name "$basename")")
  done < <(bundles::scan_bundles)

  local state_entry
  local deleted=
  if [[ -d $state_dir ]]; then
    for state_entry in "$state_dir"/*; do
      if ! lib::in_array "$(basename "$state_entry")" ${bundles+"${bundles[@]}"}; then
        rm -rf "$state_entry"
        lib::print "- Deleted [$state_entry]"
        deleted=1
      fi
    done
  fi
  if [[ ! $deleted ]]; then
    lib::print_subdued 'Nothing to delete.'
  fi
}

function repo::update() {
  local root="$_TILDEPOT_APP__REPO_ROOT"
  lib::require_dir "$root"

  lib::ohai "Fetching latest releases..."
  local bundle_releases=()
  IFS=$'\n' read -r -d '' -a bundle_releases < <(repo::_load_latest_bundle_releases && printf '\0')
  ((!${#bundle_releases[@]})) && lib::abort "Failed to fetch latest releases."
  lib::print_subdued "Found ${#bundle_releases[@]} official bundles."
  echo

  lib::ohai "Scanning & updating bundles..."
  local bundle_file
  local curr_release
  local remote_bundles=
  remote_bundles="$(bundles::list_remote_bundles)"
  local newer_release=
  local got_candidates=
  local updated=
  if [[ $remote_bundles ]]; then
    while IFS=: read -r bundle_file curr_release; do
      newer_release="$(repo::_find_newer_release "$curr_release" "${bundle_releases[@]}")"
      [[ ! $newer_release ]] && continue
      got_candidates=1

      lib::confirm \
        --yes \
        "Found newer bundle [$newer_release] (current version: [$curr_release])" \
        "Download and update?" ||
        continue

      bundle::require_bundle_download "$newer_release"

      repo::_update_bundle_extend "$bundle_file" "$curr_release" "$newer_release"

      lib::print "- Updated [$curr_release] to [$newer_release]"
      updated=1
    done <<<"$remote_bundles"
  fi
  if [[ ! $got_candidates ]]; then
    lib::print_subdued 'Nothing to update.'
    return
  fi
  if [[ ! $updated ]]; then
    lib::print_subdued 'Nothing updated.'
    return
  fi
  echo

  lib::ohai "Cleaning up bundles..."
  repo::_cleanup_bundles "$root"
  echo

  lib::success "Bundles updated."
}

function repo::_load_latest_bundle_releases() {
  local refs
  refs="$(
    lib::download "${_TILDEPOT_APP__REPO_URL}/refs" -H 'Accept: application/json' |
      jq -r .refs[]
  )"
  printf '%s\n' "$refs"

  # TODO: dedupe
}

function repo::_find_newer_release() {
  local curr_release="$1"
  local bundle_releases=("${@:2}")

  # TODO
  echo "${bundle_releases[0]}"
}

function repo::_update_bundle_extend() {
  local bundle_file="$1"
  local curr_release="$2"
  local newer_release="$3"

  local escaped_curr
  escaped_curr=$(echo "$curr_release" | sed 's/[\/&]/\\&/g')
  local escaped_newer
  escaped_newer=$(echo "$newer_release" | sed 's/[\/&]/\\&/g')
  lib::sed "s/^[[:space:]]*EXTEND=['\"]\{0,1\}${escaped_curr}['\"]\{0,1\}[[:space:]]*$/EXTEND=${escaped_newer}/g" "$bundle_file"
}
