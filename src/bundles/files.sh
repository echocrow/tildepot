#!/bin/bash
#
# Tildepot bundle for files.

FILES=""

function SNAPSHOT() {
  while IFS=$'\t' read -r internal external io_name internal_name external_name; do
    mkdir -p "$(dirname "$internal")"

    rm -rf "$internal"
    [[ -e "$external" ]] && cp -R "$external" "$internal"

    bundle::_parse "$io_name" "$internal" true
    bundle::_parse "$internal_name" "$internal" true true

    tilde::success "Stored [$external_name] in [$internal]"
  done < <(bundle::list)
}

function APPLY() {
  while IFS=$'\t' read -r internal external io_name internal_name external_name; do
    mkdir -p "$(dirname "$external")"

    rm -rf "$external"
    [[ -e "$internal" ]] && cp -R "$internal" "$external"

    bundle::_parse "$io_name" "$external" false
    bundle::_parse "$internal_name" "$external" false true

    tilde::success "Restored [$external_name] from [$internal]"
  done < <(bundle::list)
}

function bundle::list() {
  local files="$FILES"
  files=${files// /$'\t'}
  files=${files//\\$'\t'/ }
  local internal external io_name
  local group=
  local group_io_name='-'
  local internal_name
  local external_name
  while IFS=$'\t' read -r internal external io_name; do
    [[ -z "$internal" ]] && continue

    [[ "$internal" =~ ^# ]] && continue # Ignore comments.

    # Handle groups.
    if [[ "$internal" =~ ^'[' ]]; then
      group="$internal"
      group=${group#'['}
      group=${group%']'}

      group_io_name='-'
      if [[ "$external" =~ ^@ ]]; then
        group_io_name="${external#'@'}"
      fi
      continue
    fi

    if [[ -z "$external" ]]; then
      tilde::warning "Ignoring files entry; missing external:" >&2
      echo "    $internal" >&2
      continue
    fi

    internal="${internal%/}"
    external="${external%/}"

    [[ -n "$group" ]] && internal="$group/$internal"

    internal_name="$internal"
    internal="$BUNDLE_DIR/$internal"

    external_name="$external"
    external="${external/#\~\//$HOME/}"

    io_name="${io_name#'@'}"
    [[ ! "$io_name" ]] && io_name="$group_io_name"

    echo "$internal"$'\t'"$external"$'\t'"$io_name"$'\t'"$internal_name"$'\t'"$external_name"
  done <<<"$files"
}

function bundle::_parse() {
  local io_name="$1"
  local target="$2"
  local decode="${3:-false}"
  local silent="${4:-false}"

  [[ "$io_name" == '-' ]] && return

  local io_fn="bundle::encode::${io_name}"
  [[ "$decode" == true ]] && io_fn="bundle::decode::${io_name}"

  if ! command -v "$io_fn" >/dev/null; then
    [[ "$silent" == true ]] && return
    tilde::error "Failed to process files entry; unknown IO type [$io_name]:" >&2
    rm -rf "$target"
    exit 1
  fi

  "$io_fn" "$target"
}

function bundle::encode::plutil() {
  plutil -convert binary1 "$1"
}

function bundle::decode::plutil() {
  plutil -convert xml1 "$1"
}
