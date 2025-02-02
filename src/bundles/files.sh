#!/bin/bash
#
# Tildepot bundle for files.

FILES=""

function SNAPSHOT() {
  while IFS=$'\t' read -r target source target_name source_name; do
    mkdir -p "$(dirname "$target")"

    rm -rf "$target"
    [[ -e "$source" ]] && cp -R "$source" "$target"

    tilde::success "Stored [$source_name] in [$target_name]"
  done < <(tilde::files::list)
}

function APPLY() {
  while IFS=$'\t' read -r target source target_name source_name; do
    mkdir -p "$(dirname "$source")"

    rm -rf "$source"
    [[ -e "$target" ]] && cp -R "$target" "$source"

    tilde::success "Restored [$source_name] from [$target_name]"
  done < <(tilde::files::list)
}

function tilde::files::list() {
  local files="$FILES"
  files=${files// /$'\t'}
  files=${files//\\$'\t'/ }
  local target_group=
  local target source
  local target_name
  local source_name
  while IFS=$'\t' read -r target source; do
    [[ -z "$target" ]] && continue

    [[ "$target" =~ ^# ]] && continue # Ignore comments.

    # Handle groups.
    if [[ "$target" =~ ^\[ ]]; then
      target_group="$target"
      target_group=${target_group#'['}
      target_group=${target_group%']'}
      continue
    fi

    if [[ -z "$source" ]]; then
      tilde::warning "Ignoring files entry; missing source:" >&2
      echo "    $target" >&2
      continue
    fi

    target="${target%/}"
    source="${source%/}"

    [[ -n "$target_group" ]] && target="$target_group/$target"

    target_name="$target"
    target="$BUNDLE_DIR/$target"

    source_name="$source"
    source="${source/#\~\//$HOME/}"

    echo "$target"$'\t'"$source"$'\t'"$target_name"$'\t'"$source_name"
  done <<<"$files"
}
