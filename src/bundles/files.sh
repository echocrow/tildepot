#!/bin/bash
#
# Tildepot bundle for files.

FILES=""

function SNAPSHOT() {
  while IFS=$'\t' read -r target source io_name source_name; do
    mkdir -p "$(dirname "$target")"

    rm -rf "$target"
    [[ -e "$source" ]] && cp -R "$source" "$target"

    if [[ -n "$io_name" && "$io_name" != '-' ]]; then
      tilde::files::io::_exec "$io_name" "$target" true
    fi

    tilde::success "Stored [$source_name] in [$target]"
  done < <(tilde::files::list)
}

function APPLY() {
  while IFS=$'\t' read -r target source io_name source_name; do
    mkdir -p "$(dirname "$source")"

    rm -rf "$source"
    [[ -e "$target" ]] && cp -R "$target" "$source"

    if [[ -n "$io_name" && "$io_name" != '-' ]]; then
      tilde::files::io::_exec "$io_name" "$source" false
    fi

    tilde::success "Restored [$source_name] from [$target]"
  done < <(tilde::files::list)
}

function tilde::files::list() {
  local files="$FILES"
  files=${files// /$'\t'}
  files=${files//\\$'\t'/ }
  local target_group=
  local target source
  local target_group_io_name='-'
  local source_name
  while IFS=$'\t' read -r target source io_name; do
    [[ -z "$target" ]] && continue

    [[ "$target" =~ ^# ]] && continue # Ignore comments.

    # Handle groups.
    if [[ "$target" =~ ^\[ ]]; then
      target_group="$target"
      target_group=${target_group#'['}
      target_group=${target_group%']'}

      target_group_io_name='-'
      if [[ "$source" =~ ^@ ]]; then
        target_group_io_name="${source#'@'}"
      fi
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

    target="$BUNDLE_DIR/$target"

    source_name="$source"
    source="${source/#\~\//$HOME/}"

    io_name="${io_name#'@'}"
    [[ ! "$io_name" ]] && io_name="$target_group_io_name"

    echo "$target"$'\t'"$source"$'\t'"$io_name"$'\t'"$source_name"
  done <<<"$files"
}

function tilde::files::io::_exec() {
  local io_name="$1"
  local target="$2"
  local decode="$3"

  local io_fn="tilde::files::io::${io_name}::encode"
  [[ "$decode" == true ]] && io_fn="tilde::files::io::${io_name}::decode"

  if ! command -v "$io_fn" >/dev/null; then
    tilde::error "Failed to process files entry; unknown IO type [$io_name]:" >&2
    rm -rf "$target"
    exit 1
  fi

  "$io_fn" "$target"
}

function tilde::files::io::plutil::encode() {
  plutil -convert binary1 "$1"
}

function tilde::files::io::plutil::decode() {
  plutil -convert xml1 "$1"
}
