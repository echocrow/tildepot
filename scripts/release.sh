#!/bin/bash
#
# Release tildepot & bundles.

# Enable strict mode
set -euo pipefail

ROOT="$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")"

source "$ROOT/src/lib.sh"

RELEASE_FULL_RELEASE_BRANCHES=(main)
RELEASE_PRERELEASE_BRANCHES=(alpha dev)

RELEASE_COMMIT_PATCH_TYPES=(fix perf)
RELEASE_COMMIT_MINOR_TYPES=(feat)

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

  jq -e '.packages | length == 0' <<<"$config" >/dev/null &&
    lib::abort "Missing packages in release config"

  echo "$config"
}

function release::get_packages() {
  echo "tildepot"

  while read -r filename; do
    local bundle
    bundle="$(basename "$filename" '.sh')"
    echo "${bundle}-bundle"
  done < <(find "$ROOT/bundles" -type f -name '*.sh' -mindepth 1 -maxdepth 1)
}

function release::log() {
  local msg="$1"
  lib::_fmt_msg "$msg"$'\n'
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
  local package="${1?}"
  local is_prerelease="${2?}"

  local curr_tags
  curr_tags="$(git tag -l "$package@*" --sort=-creatordate)"

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
  release::log "base commit: [${base_commit:0:7}]"
  release::log "curr tag: [${curr_tag:--}]"
  release::log "curr version: [${curr_version:--}]"
  release::log "curr full version: [${curr_full_version:--}]"
  release::log "curr prerelease: [$(release::fmt_yn "$curr_version_is_prerelease")]"

  local log_grep=
  case $package in
  tildepot) log_grep=':' ;;
  *) log_grep="($package)!\?:" ;;
  esac

  release::log "==> Scanning commits..."
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
      release::log "==> [${commit:0:7}]: non-conventional; skipping"
      continue
    fi

    if [[ 
      $commit_scope != "$package" &&
      ! ($package == 'tildepot' && $commit_scope != *'-bundle') ]] \
      ; then
      release::log "==> [${commit:0:7}]: unrelated scope [$commit_scope]; skipping"
      continue
    fi

    if [[ $commit_desc == *"BREAKING CHANGE: "* ]]; then
      commit_bump=$((commit_bump | RELEASE_BUMP_MAJOR))
      commit_desc="${commit_desc/'BREAKING CHANGE: '/}"
    fi

    if lib::in_array "$commit_type" "${RELEASE_COMMIT_PATCH_TYPES[@]}"; then
      commit_bump=$((commit_bump | RELEASE_BUMP_PATCH))
    elif lib::in_array "$commit_type" "${RELEASE_COMMIT_MINOR_TYPES[@]}"; then
      commit_bump=$((commit_bump | RELEASE_BUMP_MINOR))
    fi

    commit_bump_type="$(release::fmt_version_bump "$commit_bump")"
    if [[ -z $commit_bump_type ]]; then
      release::log "==> [${commit:0:7}]: non-release type [$commit_type]; skipping"
      continue
    fi

    release::log "==> [${commit:0:7}]: [$commit_type] @ [${commit_scope:--}] bumps [$commit_bump_type]"
    package_bump=$((package_bump | commit_bump))
  done < <(git log --grep="$log_grep" --format="%H %s%n%b%x00" --reverse "$base_commit"..HEAD)
  release::log "==> Completed scanning commits."

  local package_bump_type
  package_bump_type="$(release::fmt_version_bump "$package_bump")"
  release::log "package bump: [$package_bump_type]"

  local version
  version="$(release::bump_version "$curr_full_version" "$curr_version" "$is_prerelease" "$package_bump_type")"
  if [[ -z $version ]]; then
    release::log "commits do not bump version; skipping"
    return
  fi
  release::log "new version: [$version]"

  # TODO...
}

function release::main() {
  lib::ohai "Validating branch..."
  local branch
  branch="$(git rev-parse --abbrev-ref HEAD)"
  local is_prerelease=
  release::log "current branch: [$branch]"
  if [[ $branch == HEAD ]]; then
    lib::abort "Detached repo mode is not supported"
  fi
  if lib::in_array "$branch" "${RELEASE_PRERELEASE_BRANCHES[@]}"; then
    is_prerelease=1
    release::log "release type: [next]"
  elif lib::in_array "$branch" "${RELEASE_FULL_RELEASE_BRANCHES[@]}"; then
    release::log "release type: [full]"
  else
    lib::abort "Branch [$branch] is not a release branch"
  fi

  lib::ohai "Fetching tags..."
  git fetch --tags origin

  lib::ohai "Processing packages..."
  while read -r pkg; do
    lib::ohai "Processing package [$pkg]..."
    release::package "$pkg" "$is_prerelease"
  done < <(release::get_packages)
}

if [[ ${BASH_SOURCE[0]} == "${0}" ]]; then
  release::main "$@"
fi
