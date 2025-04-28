#!/bin/bash
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
    "patch": {"fix": "Fixes", "perf": "Performance"},
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
    curr_full_version="0.0.0"
    curr_version="0.0.0"
    bump_type=major
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
  local config="${1?}"
  local package="${2?}"
  local is_prerelease="${3?}"

  local pkg
  pkg="$(jq -r '.name' <<<"$package")"

  lib::ohai "Processing package [$pkg]..."

  local curr_tags
  curr_tags="$(git tag -l "$pkg@*" --sort=-creatordate)"

  local curr_tag
  curr_tag="${curr_tags%%$'\n'*}"
  local curr_version="${curr_tag##*@}"

  local curr_full_tag
  curr_full_tag="$(grep -v -- '-next\.' <<<"$curr_tags" | head -n 1)"
  local curr_full_version="${curr_full_tag##*@}"

  local curr_version_is_prerelease=
  [[ $curr_version != "$curr_full_version" ]] && curr_version_is_prerelease=1

  local base_commit
  if [[ -n $curr_tag ]]; then
    base_commit="$(git rev-parse "$curr_tag")"
  else
    base_commit="$(git rev-list --max-parents=0 HEAD)"
  fi
  [[ -z $base_commit ]] && lib::abort "Failed to detect base commit"
  release::log "$pkg" "base commit: [${base_commit:0:7}]"
  release::log "$pkg" "curr tag: [${curr_tag:--}]"
  release::log "$pkg" "curr version: [${curr_version:--}]"
  release::log "$pkg" "curr full version: [${curr_full_version:--}]"
  release::log "$pkg" "curr prerelease: [$(release::fmt_yn "$curr_version_is_prerelease")]"

  local commit_scope_grep
  local commit_scope_grep_negative=
  commit_scope_grep="$(jq -r --arg pkg "$pkg" '.scope // $pkg' <<<"$package")"
  if [[ $commit_scope_grep == '!'* ]]; then
    commit_scope_grep="${commit_scope_grep#'!'}"
    commit_scope_grep_negative=1
  fi

  local log_grep=
  if [[ $commit_scope_grep_negative ]]; then
    log_grep=":"
  else
    log_grep="($commit_scope_grep)!\?:"
  fi

  release::log "$pkg" "==> Scanning commits..."
  local commit
  local commit_txt
  local commit_msg
  local commit_desc
  local commit_type
  local commit_scope
  local commit_bump
  local commit_bump_type
  local package_bump=0
  while read -r -d $'\0' commit_data; do
    commit_data="$commit_data"$'\n'

    commit="${commit_data%% *}"
    commit_txt="${commit_data#* }"
    commit_msg="${commit_txt%%$'\n'*}"
    commit_desc="${commit_txt#*$'\n'}"
    commit_desc="${commit_desc%$'\n'}"

    commit_bump=0

    if [[ $commit_msg =~ ^([a-zA-Z0-9-]+)(!)?(\(([a-zA-Z0-9-]+)\))?: ]]; then
      commit_type="${BASH_REMATCH[1]}"
      [[ ${BASH_REMATCH[2]} ]] && commit_bump=$((commit_bump | RELEASE_BUMP_MAJOR))
      commit_scope="${BASH_REMATCH[4]}"
    else
      release::log "$pkg" "==> [${commit:0:7}]: non-conventional; skipping"
      continue
    fi

    local commit_scope_matches=
    [[ ! $commit_scope =~ ^$commit_scope_grep$ ]] && commit_scope_matches=1
    if [[ $commit_scope_matches != "$commit_scope_grep_negative" ]]; then
      release::log "$pkg" "==> [${commit:0:7}]: unrelated scope [$commit_scope]; skipping"
      continue
    fi

    if [[ $commit_desc == *"BREAKING CHANGE: "* ]]; then
      commit_bump=$((commit_bump | RELEASE_BUMP_MAJOR))
      commit_desc="${commit_desc/'BREAKING CHANGE: '/}"
    fi

    if jq -e --arg commit_type "$commit_type" '.commits_types.patch | has($commit_type)' <<<"$config" >/dev/null; then
      commit_bump=$((commit_bump | RELEASE_BUMP_PATCH))
    elif jq -e --arg commit_type "$commit_type" '.commits_types.minor | has($commit_type)' <<<"$config" >/dev/null; then
      commit_bump=$((commit_bump | RELEASE_BUMP_MINOR))
    fi

    commit_bump_type="$(release::fmt_version_bump "$commit_bump")"
    if [[ -z $commit_bump_type ]]; then
      release::log "$pkg" "==> [${commit:0:7}]: non-release type [$commit_type]; skipping"
      continue
    fi

    release::log "$pkg" "==> [${commit:0:7}]: [$commit_type] @ [${commit_scope:--}] bumps [$commit_bump_type]"
    package_bump=$((package_bump | commit_bump))
  done < <(git log --grep="$log_grep" --format="%H %s%n%b%x00" --reverse "$base_commit"..HEAD)
  release::log "$pkg" "==> Completed scanning commits."

  local package_bump_type
  package_bump_type="$(release::fmt_version_bump "$package_bump")"
  release::log "$pkg" "package bump: [$package_bump_type]"

  local version
  version="$(release::bump_version "$curr_full_version" "$curr_version" "$is_prerelease" "$package_bump_type")"
  if [[ -z $version ]]; then
    release::log "$pkg" "skipping package"
    return
  fi
  release::log "$pkg" "new version: [$version]"

  # TODO...
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

  lib::ohai "Processing packages..."
  local pkg_count
  pkg_count="$(jq -r '.packages | length' <<<"$config")"
  local package
  for ((p = 0; p < pkg_count; p++)); do
    package="$(jq --argjson p "$p" '.packages[$p]' <<<"$config")"
    release::package "$config" "$package" "$is_prerelease"
  done
}

if [[ ${BASH_SOURCE[0]} == "${0}" ]]; then
  release::main "$PWD" "$@"
fi
