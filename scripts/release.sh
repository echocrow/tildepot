#!/usr/bin/env bash
#
# Release tildepot & bundles.

# Enable strict mode
set -euo pipefail

ROOT="$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")"

source "$ROOT/src/lib.sh"

RELEASE_BUMP_PATCH=$((2#001))
RELEASE_BUMP_MINOR=$((2#010))
RELEASE_BUMP_MAJOR=$((2#100))

RELEASE_CONFIG_DEFAULTS='{
  "branches": {
    "full": ["main", "master"],
    "prerelease": ["next", "alpha", "beta", "nightly"]
  },
  "commits_types": {
    "patch": {"fix": "Bug Fixes", "perf": "Performance Improvements"},
    "minor": {"feat": "Features"}
  },
  "packages": []
}'

function release::config() {
  local root="${1?}"

  local config="{}"
  local has_config=
  if [[ -f "$root/.releaserc" ]]; then
    config="$(cat "$root/.releaserc")"
    has_config=1
  elif [[ -f "$root/.releaserc.json" ]]; then
    config="$(cat "$root/.releaserc.json")"
    has_config=1
  fi

  # Merge defaults.
  config="$(
    jq '
      .
      | .branches.full //= '"$(jq '.branches.full' <<<"$RELEASE_CONFIG_DEFAULTS")"'
      | .branches.prerelease //= '"$(jq '.branches.prerelease' <<<"$RELEASE_CONFIG_DEFAULTS")"'
      | .commits_types.patch //= '"$(jq '.commits_types.patch' <<<"$RELEASE_CONFIG_DEFAULTS")"'
      | .commits_types.minor //= '"$(jq '.commits_types.minor' <<<"$RELEASE_CONFIG_DEFAULTS")"'
      | .packages //= '"$(jq '.packages' <<<"$RELEASE_CONFIG_DEFAULTS")"'
    ' <<<"$config"
  )"

  # Process config.
  if [[ -f "$root/.releaserc.sh" ]]; then
    config="$(bash "$root/.releaserc.sh" "$config")"
    has_config=1
  fi

  [[ ! $has_config ]] && lib::abort "Config file not found in [$root]"

  # Validate config.
  if jq -e '.packages | length == 0' <<<"$config" >/dev/null; then
    lib::abort "Missing packages"
  fi
  if jq -e '.packages[] | select((.name // "") == "") | length > 0' <<<"$config" >/dev/null; then
    lib::abort "Missing or empty package name"
  fi

  echo "$config"
}

function release::log() {
  case $# in
  1)
    local msg="${1?}"
    lib::_fmt_msg "$msg"$'\n'
    ;;
  2)
    local pkg_name="${1?}"
    local msg="${2?}"
    lib::_fmt_msg "([$pkg_name]) $msg"$'\n'
    ;;
  *) lib::abort "Invalid number of 'release::log' arguments: [$#]" ;;
  esac
}

function release::fmt_yn() {
  local yn="${1?}"
  if [[ $yn ]]; then
    echo "✓"
  else
    echo "✘"
  fi
}

function release::fmt_version_bump() {
  local bump_mask="${1?}"
  if [[ $((bump_mask & RELEASE_BUMP_MAJOR)) -gt 0 ]]; then
    echo "major"
  elif [[ $((bump_mask & RELEASE_BUMP_MINOR)) -gt 0 ]]; then
    echo "minor"
  elif [[ $((bump_mask & RELEASE_BUMP_PATCH)) -gt 0 ]]; then
    echo "patch"
  elif [[ $bump_mask -eq 0 ]]; then
    echo ""
  else
    lib::abort "Invalid bump mask: [$bump_mask]"
  fi
}

function release::bump_version() {
  local curr_full_version="${1?}"
  local curr_version="${2?}"
  local is_prerelease="${3?}"
  local bump_type="${4?}"

  case $bump_type in
  major | minor | patch | '') ;;
  *) lib::abort "Invalid bump type: [$bump_type]" ;;
  esac

  if [[ -z $bump_type && ($is_prerelease || $curr_version == "$curr_full_version") ]]; then
    return
  fi

  if [[ -z $curr_version ]]; then
    curr_version="0.0.0"
    bump_type=major
  fi
  if [[ -z $curr_full_version ]]; then
    curr_full_version="0.0.0"
  fi

  [[ $curr_full_version =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]] ||
    lib::abort "Invalid full-release version format: [$curr_full_version]"
  local curr_full_major="${BASH_REMATCH[1]}"
  local curr_full_minor="${BASH_REMATCH[2]}"
  local curr_full_patch="${BASH_REMATCH[3]}"

  [[ $curr_version =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)(-next\.([0-9]+))?$ ]] ||
    lib::abort "Invalid version format: [$curr_version]"
  local curr_major="${BASH_REMATCH[1]}"
  local curr_minor="${BASH_REMATCH[2]}"
  local curr_patch="${BASH_REMATCH[3]}"
  local curr_next="${BASH_REMATCH[5]:-0}"

  local major="$curr_major"
  if [[ $bump_type == 'major' && ($curr_major == "$curr_full_major") ]]; then
    ((major++))
  fi

  local minor="$curr_minor"
  if [[ $major != "$curr_major" ]]; then
    minor=0
  elif [[ $bump_type == 'minor' && ($curr_major == "$curr_full_major" && $curr_minor == "$curr_full_minor") ]]; then
    ((minor++))
  fi

  local patch="$curr_patch"
  if [[ $major != "$curr_major" || $minor != "$curr_minor" ]]; then
    patch=0
  elif [[ $bump_type == 'patch' && ($curr_major == "$curr_full_major" && $curr_minor == "$curr_full_minor" && $curr_patch == "$curr_full_patch") ]]; then
    ((patch++))
  fi

  local next="$curr_next"
  if [[ ! $is_prerelease || $major != "$curr_major" || $minor != "$curr_minor" || $patch != "$curr_patch" ]]; then
    next=0
  fi
  [[ $is_prerelease ]] && ((next++))

  local version="${major}.${minor}.${patch}"
  [[ $next -gt 0 ]] && version="${version}-next.${next}"
  echo "$version"
}

function release::package() {
  local out_dir="${1?}"
  local config="${2?}"
  local package="${3?}"
  local is_prerelease="${4?}"
  local branch="${5?}"

  local pkg
  pkg="$(jq -r '.name' <<<"$package")"

  lib::ohai "Processing package [$pkg]..."

  # Create commit scope pattern.
  local commit_scope_grep
  local commit_scope_grep_negative=
  commit_scope_grep="$(jq -r --arg pkg "$pkg" '.scope // $pkg' <<<"$package")"
  if [[ $commit_scope_grep == '!'* ]]; then
    commit_scope_grep="${commit_scope_grep#'!'}"
    commit_scope_grep_negative=1
  fi

  # Prepare variables for changelog.
  declare "changelog_breaking="
  local commit_type
  local changelog_var
  while IFS= read -r commit_type; do
    changelog_var="changelog__${commit_type}"
    declare "$changelog_var="
  done < <(jq -r '.commits_types.patch + .commits_types.minor | keys[]' <<<"$config")

  release::log "$pkg" "==> Scanning commits..."
  local curr_version
  local curr_full_version
  local package_bump=0
  while read -r -d $'\0' commit_data; do
    # Get commit SHA.
    local commit="${commit_data%% *}"
    commit_data="${commit_data#* }"

    # Get version tags.
    local commit_version=
    local commit_full_version=
    if [[ ${commit_data:0:1} == '~' ]]; then
      commit_data="${commit_data:1}"
      local commit_tags_data=":${commit_data%%~*}:"
      while [[ $commit_tags_data =~ :@"$pkg"@([^:]+): ]]; do
        local match="${BASH_REMATCH[0]}"
        local tag_version="${BASH_REMATCH[1]}"
        commit_version="$tag_version"
        [[ $tag_version != *"-next."* ]] && commit_full_version="$tag_version"
        commit_tags_data=":${commit_tags_data#*"$match"}"
      done
      commit_data="${commit_data#*~}"
    fi
    curr_version="${curr_version:-$commit_version}"
    curr_full_version="${curr_full_version:-$commit_full_version}"

    commit_data="${commit_data#* }"

    # Get commit title & message.
    local commit_txt="$commit_data"$'\n'
    local commit_msg="${commit_txt%%$'\n'*}"
    local commit_desc="${commit_txt#*$'\n'}"
    commit_desc="${commit_desc%$'\n'}"

    # Break if we've found the previous release.
    [[ $is_prerelease && $commit_version ]] && break
    [[ ! $is_prerelease && $commit_full_version ]] && break

    local commit_bump=0

    # Get conventional commit type & scope.
    local commit_type
    local commit_scope
    local commit_title
    if [[ $commit_msg =~ ^([a-zA-Z0-9-]+)(\(([a-zA-Z0-9-]+)\))?(!)?': '*(.+)$ ]]; then
      commit_type="${BASH_REMATCH[1]}"
      commit_scope="${BASH_REMATCH[3]}"
      [[ ${BASH_REMATCH[4]} ]] && commit_bump=$((commit_bump | RELEASE_BUMP_MAJOR))
      commit_title="${BASH_REMATCH[5]}"
    else
      release::log "$pkg" "[$commit]: skipping: non-conventional"
      continue
    fi

    # Verify commit scope.
    local commit_scope_matches=
    [[ ! $commit_scope =~ ^($commit_scope_grep)$ ]] && commit_scope_matches=1
    if [[ $commit_scope_matches != "$commit_scope_grep_negative" ]]; then
      release::log "$pkg" "[$commit]: skipping: unrelated scope [$commit_scope]"
      continue
    fi

    # Check for breaking change in description.
    local commit_breaking_change_desc=
    if [[ $commit_desc == *"BREAKING CHANGE: "* ]]; then
      commit_bump=$((commit_bump | RELEASE_BUMP_MAJOR))
      commit_breaking_change_desc="${commit_desc##*BREAKING CHANGE: }"
      commit_breaking_change_desc="${commit_breaking_change_desc%%$'\n'*}"
    fi
    # Check for patch/minor version bump.
    if jq -e --arg commit_type "$commit_type" '.commits_types.patch | has($commit_type)' <<<"$config" >/dev/null; then
      commit_bump=$((commit_bump | RELEASE_BUMP_PATCH))
    elif jq -e --arg commit_type "$commit_type" '.commits_types.minor | has($commit_type)' <<<"$config" >/dev/null; then
      commit_bump=$((commit_bump | RELEASE_BUMP_MINOR))
    fi
    # Format version bump.
    local commit_bump_type
    commit_bump_type="$(release::fmt_version_bump "$commit_bump")"
    if [[ -z $commit_bump_type ]]; then
      release::log "$pkg" "[$commit]: skipping: non-release type [$commit_type]"
      continue
    fi

    release::log "$pkg" "[$commit]: [$commit_type] @ [${commit_scope:--}] bumps [$commit_bump_type]"
    package_bump=$((package_bump | commit_bump))

    # Extend changelog.
    local changelog_var="changelog__${commit_type}"
    ((commit_bump & RELEASE_BUMP_MAJOR)) && [[ ! $commit_breaking_change_desc ]] && changelog_var="changelog_breaking"
    local commit_change="- **${commit_scope:-$pkg}:** ${commit_title} (${commit})"
    declare "${changelog_var}=${commit_change}"$'\n'"${!changelog_var}"
    # Add dedicated breaking change description.
    if [[ $commit_breaking_change_desc ]]; then
      changelog_var="changelog_breaking"
      commit_change="- **${commit_scope:-$pkg}:** ${commit_breaking_change_desc} (${commit})"
      declare "${changelog_var}=${commit_change}"$'\n'"${!changelog_var}"
    fi
  done < <(git log --format="%h %(decorate:prefix=~,suffix=~,tag=@,separator=:) %s%n%b%x00")
  release::log "$pkg" "==> Completed scanning commits."

  local curr_version_is_prerelease=
  [[ $curr_version != "$curr_full_version" ]] && curr_version_is_prerelease=1

  release::log "$pkg" "curr version: [${curr_version:--}]"
  release::log "$pkg" "curr full version: [${curr_full_version:--}]"
  release::log "$pkg" "curr prerelease: [$(release::fmt_yn "$curr_version_is_prerelease")]"

  local package_bump_type
  package_bump_type="$(release::fmt_version_bump "$package_bump")"
  release::log "$pkg" "package bump: [${package_bump_type:--}]"

  local version
  version="$(release::bump_version "$curr_full_version" "$curr_version" "$is_prerelease" "$package_bump_type")"
  release::log "$pkg" "new version: [${version:--}]"

  if [[ -z $version ]]; then
    release::log "$pkg" "skipping package"
    return
  fi

  local build_command
  if build_command="$(jq -e -r '.buildCommand // ""' <<<"$package")" &&
    [[ -n $build_command ]]; then
    release::log "$pkg" "==> Running build command \"$build_command\"..."
    RELEASE_VERSION="$version" $build_command
    release::log "$pkg" "==> Completed build command."
  fi

  # Prepare output directory.
  out_dir="$out_dir/$pkg"
  mkdir -p "$out_dir"

  # Output changelog.
  release::log "$pkg" "==> Storing changelog..."
  local changelog=''
  local commit_type
  local commit_type_title
  local changelog_var
  # Add breaking changes.
  if [[ -n $changelog_breaking ]]; then
    changelog+="### BREAKING CHANGES"$'\n'
    changelog+="$changelog_breaking"$'\n'
  fi
  # Add other changes.
  while read -r commit_type commit_type_title; do
    changelog_var="changelog__${commit_type}"
    if [[ -n ${!changelog_var} ]]; then
      changelog+="### $commit_type_title"$'\n'
      changelog+="${!changelog_var}"$'\n'
    fi
  done < <(jq -r '.commits_types.minor + .commits_types.patch | to_entries[] | "\(.key) \(.value)"' <<<"$config")
  # Save changelog.
  changelog="${changelog%$'\n'}"
  echo "$changelog" >"$out_dir/CHANGELOG.md"

  # Output assets.
  release::log "$pkg" "==> Gathering assets..."
  while IFS= read -r asset; do
    local asset_path="$root/$asset"
    [[ ! -e $asset_path ]] && lib::abort "Asset not found: $asset_path"
    local asset_dir="$out_dir/assets"
    mkdir -p "$asset_dir"
    cp -r "$asset_path" "$asset_dir/"
  done < <(jq -r '.assets // [] | .[]' <<<"$package")

  # Create release.
  release::log "$pkg" "==> Creating release..."
  if [[ -z ${CI-} ]]; then
    release::log "$pkg" "skipping release creation: CI env not set"
  else
    local is_auxiliary=
    (jq -e '.auxiliary' <<<"$package" >/dev/null) && is_auxiliary=1
    local release_name="${pkg}@${version}"
    local release_args=()
    [[ $is_prerelease ]] && release_args+=(--prerelease)
    [[ $is_auxiliary ]] && release_args+=(--latest=false)
    gh release create "$release_name" \
      --title "$release_name" \
      --notes-file "$out_dir/CHANGELOG.md" \
      --target "$branch" \
      ${release_args+"${release_args[@]}"} \
      "$out_dir/assets/*"
  fi
}

function release::main() {
  local root="${1?}"

  release::log "Loading config..."
  local config
  config="$(release::config "$root")"

  lib::ohai "Validating branch..."
  local branch
  branch="$(git rev-parse --abbrev-ref HEAD)"
  local is_prerelease=
  release::log "current branch: [$branch]"
  if [[ $branch == HEAD ]]; then
    lib::abort "Detached repo mode is not supported"
  fi
  if jq -e --arg branch "$branch" '.branches.full | contains([$branch])' <<<"$config" >/dev/null; then
    release::log "release type: [full]"
  elif jq -e --arg branch "$branch" '.branches.prerelease | contains([$branch])' <<<"$config" >/dev/null; then
    release::log "release type: [next]"
    is_prerelease=1
  else
    lib::abort "Branch [$branch] is not a release branch"
  fi

  lib::ohai "Fetching tags..."
  git fetch --tags origin

  release::log "Preparing output directory..."
  local out_dir="$root/dist/release"
  rm -rf "$out_dir"

  lib::ohai "Processing packages..."
  local pkg_count
  pkg_count="$(jq -r '.packages | length' <<<"$config")"
  local package
  for ((p = 0; p < pkg_count; p++)); do
    package="$(jq --argjson p "$p" '.packages[$p]' <<<"$config")"
    release::package "$out_dir" "$config" "$package" "$is_prerelease" "$branch"
  done
}

if [[ ${BASH_SOURCE[0]} == "${0}" ]]; then
  release::main "$PWD" "$@"
fi
