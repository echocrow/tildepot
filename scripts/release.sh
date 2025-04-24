#!/bin/bash
#
# Release tildepot & bundles.

# Enable strict mode
set -euo pipefail

ROOT="$(realpath "$(dirname "${BASH_SOURCE[0]}")/..")"

source "$ROOT/src/lib.sh"

RELEASE_FULL_RELEASE_BRANCHES=(main)
RELEASE_PRE_RELEASE_BRANCHES=(alpha dev)

RELEASE_COMMIT_PATCH_TYPES=(fix perf)
RELEASE_COMMIT_MINOR_TYPES=(feat)

RELEASE_BUMP_PATCH=$((2#001))
RELEASE_BUMP_MINOR=$((2#010))
RELEASE_BUMP_MAJOR=$((2#100))

_RELEASE_IS_PRE_RELEASE=

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
  local prev_full_version="${1?}"
  local prev_version="${2?}"
  local is_pre_release="${3?}"
  local bump_type="${4?}"

  if [[ -z $prev_version ]]; then
    case $bump_type in
    major | minor | patch)
      if [[ $is_pre_release ]]; then
        echo "1.0.0-next.1"
      else
        echo "1.0.0"
      fi
      ;;
    '') ;;
    *) lib::abort "Invalid bump type: [$bump_type]" ;;
    esac
    return 0
  fi

  if [[ ! $prev_full_version =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    lib::abort "Invalid full-release version format: [$prev_full_version]"
  fi
  local prev_full_major="${BASH_REMATCH[1]}"
  local prev_full_minor="${BASH_REMATCH[2]}"
  # local prev_full_patch="${BASH_REMATCH[3]}"

  if [[ ! $prev_version =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)(-next\.([0-9]+))?$ ]]; then
    lib::abort "Invalid version format: [$prev_version]"
  fi
  local prev_major="${BASH_REMATCH[1]}"
  local prev_minor="${BASH_REMATCH[2]}"
  local prev_patch="${BASH_REMATCH[3]}"
  local prev_next="${BASH_REMATCH[5]:-0}"

  local new_major
  local new_minor
  local new_patch
  local new_next

  if [[ ! $is_pre_release && $prev_version == "$prev_full_version" ]]; then
    case $bump_type in
    major)
      new_major="$((prev_major + 1))"
      new_minor=0
      new_patch=0
      new_next=0
      ;;
    minor)
      new_major="${prev_major}"
      new_minor="$((prev_minor + 1))"
      new_patch=0
      new_next=0
      ;;
    patch)
      new_major="${prev_major}"
      new_minor="${prev_minor}"
      new_patch="$((prev_patch + 1))"
      new_next=0
      ;;
    '') return 0 ;;
    *) lib::abort "Invalid bump type: [$bump_type]" ;;
    esac
  elif [[ $prev_version == "$prev_full_version" ]]; then
    case $bump_type in
    major)
      new_major="$((prev_major + 1))"
      new_minor=0
      new_patch=0
      new_next=1
      ;;
    minor)
      new_major="${prev_major}"
      new_minor="$((prev_minor + 1))"
      new_patch=0
      new_next=1
      ;;
    patch)
      new_major="${prev_major}"
      new_minor="${prev_minor}"
      new_patch="$((prev_patch + 1))"
      new_next=1
      ;;
    '') return 0 ;;
    *) lib::abort "Invalid bump type: [$bump_type]" ;;
    esac
  elif [[ ! $is_pre_release ]]; then
    case $bump_type in
    major)
      if [[ $prev_full_major == "$prev_major" ]]; then
        new_major="$((prev_major + 1))"
        new_minor=0
        new_patch=0
        new_next=0
      else
        new_major="$prev_major"
        new_minor="$prev_minor"
        new_patch="$prev_patch"
        new_next=0
      fi
      ;;
    minor)
      if [[ $prev_full_major == "$prev_major" && $prev_full_minor == "$prev_minor" ]]; then
        new_major="$prev_major"
        new_minor="$((prev_minor + 1))"
        new_patch=0
        new_next=0
      else
        new_major="$prev_major"
        new_minor="$prev_minor"
        new_patch="$prev_patch"
        new_next=0
      fi
      ;;
    patch)
      new_major="$prev_major"
      new_minor="$prev_minor"
      new_patch="$prev_patch"
      new_next=0
      ;;
    '')
      new_major="$prev_major"
      new_minor="$prev_minor"
      new_patch="$prev_patch"
      new_next=0
      ;;
    *) lib::abort "Invalid bump type: [$bump_type]" ;;
    esac
  else
    case $bump_type in
    major)
      if [[ $prev_full_major == "$prev_major" ]]; then
        new_major="$((prev_major + 1))"
        new_minor=0
        new_patch=0
        new_next=1
      else
        new_major="$prev_major"
        new_minor="$prev_minor"
        new_patch="$prev_patch"
        new_next="$((prev_next + 1))"
      fi
      ;;
    minor)
      if [[ $prev_full_major == "$prev_major" && $prev_full_minor == "$prev_minor" ]]; then
        new_major="$prev_major"
        new_minor="$((prev_minor + 1))"
        new_patch=0
        new_next=1
      else
        new_major="$prev_major"
        new_minor="$prev_minor"
        new_patch="$prev_patch"
        new_next="$((prev_next + 1))"
      fi
      ;;
    patch)
      new_major="$prev_major"
      new_minor="$prev_minor"
      new_patch="$prev_patch"
      new_next="$((prev_next + 1))"
      ;;
    '') return 0 ;;
    *) lib::abort "Invalid bump type: [$bump_type]" ;;
    esac
  fi

  local new_version="${new_major}.${new_minor}.${new_patch}"
  [[ $new_next -gt 0 ]] && new_version="${new_version}-next.${new_next}"
  echo "$new_version"
}

function release::package() {
  local package="${1?}"

  local prev_tags
  prev_tags="$(git tag -l "$package@*" --sort=-creatordate)"

  local prev_tag
  prev_tag="${prev_tags%%$'\n'*}"
  local prev_version="${prev_tag##*@}"

  local prev_full_tag
  prev_full_tag="$(grep -v -- '-next\.' <<<"$prev_tags" | head -n 1)"
  local prev_full_version="${prev_full_tag##*@}"

  local prev_version_is_pre_release=
  [[ $prev_version != "$prev_full_version" ]] && prev_version_is_pre_release=1

  local base_commit
  if [[ -n $prev_tag ]]; then
    base_commit="$(git rev-parse "$prev_tag")"
  else
    base_commit="$(git rev-list --max-parents=0 HEAD)"
  fi
  [[ -z $base_commit ]] && lib::abort "Failed to detect base commit"
  release::log "base commit: [${base_commit:0:7}]"
  release::log "prev tag: [${prev_tag:--}]"
  release::log "prev version: [${prev_version:--}]"
  release::log "prev full version: [${prev_full_version:--}]"
  release::log "prev next: [$(release::fmt_yn "$prev_version_is_pre_release")]"

  local log_grep=
  case $package in
  tildepot) log_grep=':' ;;
  *) log_grep="($package)!\?:" ;;
  esac

  release::log "==> Scanning commits..."
  local commit
  local commit_msg
  local commit_desc
  local commit_type
  local commit_scope
  local commit_bump
  local commit_bump_type
  local package_bump=0
  while read -r commit_data; do
    commit="${commit_data%% *}"
    commit_msg="${commit_data#* }"
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

    commit_desc="$(git log -1 --format=%b "$commit")"
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
  done < <(git log --grep="$log_grep" --format="%H %s" --reverse "$base_commit"..HEAD)
  release::log "==> Completed scanning commits."

  local package_bump_type
  package_bump_type="$(release::fmt_version_bump "$package_bump")"
  release::log "package bump: [$package_bump_type]"

  local new_version
  new_version="$(release::bump_version "$prev_full_version" "$prev_version" "$_RELEASE_IS_PRE_RELEASE" "$package_bump_type")"
  if [[ -z $new_version ]]; then
    release::log "commits do not bump version; skipping"
    return
  fi
  release::log "new version: [$new_version]"

  # TODO...
}

function release::main() {
  lib::ohai "Validating branch..."
  local branch
  branch="$(git rev-parse --abbrev-ref HEAD)"
  release::log "current branch: [$branch]"
  if [[ $branch == HEAD ]]; then
    lib::abort "Detached repo mode is not supported"
  fi
  if lib::in_array "$branch" "${RELEASE_PRE_RELEASE_BRANCHES[@]}"; then
    _RELEASE_IS_PRE_RELEASE=1
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
    release::package "$pkg"
  done < <(release::get_packages)
}

if [[ ${BASH_SOURCE[0]} == "${0}" ]]; then
  release::main "$@"
fi
