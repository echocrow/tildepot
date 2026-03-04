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

function repo::add() {
  local name="${1-}"
  local parent_bundle="${2-}"

  local root="$_TILDEPOT_APP__REPO_ROOT"
  lib::require_dir "$root"
  mkdir -p "$root/bundles"

  local bundle_releases=()

  local prompt_inputs=
  [[ ! $name && ! $parent_bundle ]] && prompt_inputs=1

  # Prompt for official bundle to extend.
  local parent_bundle_release=
  if [[ $prompt_inputs ]]; then
    if lib::confirm "Extend an official bundle instead of starting from scratch?"; then
      ((!${#bundle_releases[@]})) && IFS=$'\n' read -r -d '' -a bundle_releases < <(repo::_load_latest_bundle_releases_once && printf '\0')
      lib::print_subdued "Available official bundles:"
      local release bundle_name_head bundle_name_tail
      for release in "${bundle_releases[@]}"; do
        bundle_name_head="${release%%-bundle@*}"
        bundle_name_tail="${release:${#bundle_name_head}}"
        lib::print_subdued "- [$bundle_name_head]$bundle_name_tail"
      done
      parent_bundle="$(lib::prompt "Official bundle to extend:")"
    fi
  fi

  # Resolve official bundle release.
  if [[ $parent_bundle ]]; then
    ((!${#bundle_releases[@]})) && IFS=$'\n' read -r -d '' -a bundle_releases < <(repo::_load_latest_bundle_releases_once && printf '\0')
    parent_bundle_release="$(repo::_resolve_official_bundle_release "$parent_bundle" "${bundle_releases[@]}")" ||
      lib::abort "Unknown official bundle: [$parent_bundle]"
    [[ ! $name ]] && name="${parent_bundle%-bundle}"
  fi

  # Prompt for bundle name.
  if [[ $prompt_inputs ]]; then
    name="$(lib::prompt --default "$name" "Bundle name:")"
  fi

  [[ $name =~ ^[A-Za-z0-9._-]+$ ]] || lib::abort "Invalid bundle name"

  local bundle_file="$root/bundles/$name.sh"
  [[ -f $bundle_file ]] && lib::abort "Bundle [$name] already exists at [$bundle_file]"

  lib::ohai "Creating bundle [$name] at [$bundle_file]..."
  repo::_print_new_bundle_contents "$name" "$parent_bundle_release" >"$bundle_file"

  if [[ $parent_bundle_release ]] &&
    ! bundle::check_remote_bundle_downloaded "$parent_bundle_release" &&
    lib::confirm --yes "Download ${parent_bundle_release}?"; then
    bundle::require_bundle_download "$parent_bundle_release"
  fi

  lib::success "Bundle created."
}

function repo::_print_new_bundle_contents() {
  local name="${1?}"
  local parent_bundle_release="${2-}"

  echo '#!/usr/bin/env bash'

  if [[ ! $parent_bundle_release ]]; then
    echo '#'
    echo "# Custom \"$name\" bundle."
  fi
  echo

  if [[ $parent_bundle_release ]]; then
    echo "export EXTEND='$parent_bundle_release'"
    echo
  fi
}

function repo::_resolve_official_bundle_release() {
  local target_name="${1?}"
  local bundle_releases=("${@:2}")

  local release bundle_name
  for release in "${bundle_releases[@]}"; do
    bundle_name="${release%%@*}"
    if [[ $bundle_name == "$target_name" || $bundle_name == "${target_name}-bundle" ]]; then
      echo "$release"
      return 0
    fi
  done
  return 1
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
  IFS=$'\n' read -r -d '' -a bundle_releases < <(repo::_load_latest_bundle_releases_once && printf '\0')
  lib::print_subdued "Found $(lib::print_plural_qty "${#bundle_releases[@]}" 'official bundle')."
  echo

  lib::ohai "Scanning & updating bundles..."
  local remote_bundles=()
  IFS=$'\n' read -r -d '' -a remote_bundles < <(bundles::list_remote_bundles && printf '\0')
  local remote_bundle
  local bundle_file
  local curr_release
  local newer_release=
  local got_candidates=
  local updated=
  if [[ ${#remote_bundles[@]} -gt 0 ]]; then
    for remote_bundle in "${remote_bundles[@]}"; do
      bundle_file="${remote_bundle%%:*}"
      curr_release="${remote_bundle#*:}"

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
    done
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
  )" || lib::abort "Failed to fetch latest releases."

  # Filter releases of distinct bundles, keeping only the latest version.
  local bundle_releases=()
  local ref bundle_name version
  local i prev_idx prev_version
  for ref in $refs; do
    bundle_name="${ref%%@*}"
    [[ $bundle_name != *-bundle ]] && continue
    version="${ref#*@}"

    prev_idx=
    for i in "${!bundle_releases[@]}"; do
      if [[ ${bundle_releases[i]} == "$bundle_name@"* ]]; then
        prev_idx="$i"
        break
      fi
    done

    if [[ -z $prev_idx ]]; then
      bundle_releases+=("$ref")
    else
      prev_version="${bundle_releases[prev_idx]#*@}"
      if repo::_check_version_is_newer "$prev_version" "$version"; then
        bundle_releases[prev_idx]="$bundle_name@$version"
      fi
    fi
  done

  if ((${#bundle_releases[@]})); then
    printf '%s\n' "${bundle_releases[@]}"
  fi
}

_TILDEPOT_REPO__BUNDLE_RELEASES=()
_TILDEPOT_REPO__BUNDLE_RELEASES_LOADED=

function repo::_load_latest_bundle_releases_once() {
  if [[ ! $_TILDEPOT_REPO__BUNDLE_RELEASES_LOADED ]]; then
    IFS=$'\n' read -r -d '' -a _TILDEPOT_REPO__BUNDLE_RELEASES < <(repo::_load_latest_bundle_releases && printf '\0') ||
      lib::abort "Failed to fetch latest releases."
    _TILDEPOT_REPO__BUNDLE_RELEASES_LOADED=1
  fi

  printf '%s\n' "${_TILDEPOT_REPO__BUNDLE_RELEASES[@]}"
}

function repo::_check_version_is_newer() {
  local base="$1"
  local newer="$2"

  local base_head
  local newer_head
  while [[ $base || $newer ]]; do
    base_head="${base%%.*}"
    newer_head="${newer%%.*}"

    base_head="${base%%.*}"
    newer_head="${newer%%.*}"
    [[ ! $base_head && ! $newer_head ]] && break
    base="${base:${#base_head}+1}"
    newer="${newer:${#newer_head}+1}"

    base_head="${base_head//[^0-9]/}"
    newer_head="${newer_head//[^0-9]/}"

    ((newer_head > base_head)) && return 0
    ((newer_head < base_head)) && return 1
  done
  return 0
}

function repo::_find_newer_release() {
  local curr_release="$1"
  local bundle_releases=("${@:2}")

  # Find (distinct) release for the given bundle.
  # (This assumes names in "$bundle_releases" are distinct.)
  local bundle_name="${curr_release%%@*}"
  local release
  for release in "${bundle_releases[@]}"; do
    if [[ $release == "$bundle_name"@* ]]; then
      [[ $release != "$curr_release" ]] && echo "$release"
      return 0
    fi
  done
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
