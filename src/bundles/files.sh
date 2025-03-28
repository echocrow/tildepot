#!/bin/bash
#
# Tildepot bundle for files.

# Override this variable to set tracked files.
export FILES=""

function SNAPSHOT() {
  while IFS=$'\t' read -r internal external io_name group internal_name external_name; do
    mkdir -p "$(dirname "$internal")"

    rm -rf "$internal"
    [[ -e "$external" ]] && cp -R "$external" "$internal"

    bundle::_process_file "$io_name" "$internal" --parse
    bundle::_process_file "$group" "$internal" --parse --silent
    bundle::_process_file "$internal_name" "$internal" --parse --silent

    tilde::success "Stored [$external_name] in [$internal]"
  done < <(bundle::list)
}

function APPLY() {
  while IFS=$'\t' read -r internal external io_name group internal_name external_name; do
    mkdir -p "$(dirname "$external")"

    rm -rf "$external"
    [[ -e "$internal" ]] && cp -R "$internal" "$external"

    bundle::_process_file "$io_name" "$external"
    bundle::_process_file "$group" "$external" --silent
    bundle::_process_file "$internal_name" "$external" --silent

    tilde::success "Restored [$external_name] from [$internal]"
  done < <(bundle::list)
}

function bundle::list() {
  local files="$FILES"
  files=${files// /$'\t'}
  files=${files//\\$'\t'/ }
  local internal external io_name
  local group=
  local group_io_name=
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

      group_io_name=
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
    external_name="$external"

    internal="$BUNDLE_DIR/$internal"
    external="${external/#\~\//$HOME/}"

    io_name="${io_name#'@'}"
    [[ ! "$io_name" ]] && io_name="$group_io_name"

    echo "$internal"$'\t'"$external"$'\t'"${io_name:--}"$'\t'"${group:--}"$'\t'"$internal_name"$'\t'"$external_name"
  done <<<"$files"
}

function bundle::_process_file() {
  local io_name="$1"
  local target="$2"

  local parse=
  local silent=
  for arg in "${@:3}"; do
    case "$arg" in
    --parse) parse=1 ;;
    --silent) silent=1 ;;
    '') ;;
    *) lib::abort "Unknown argument [$arg]" ;;
    esac
  done

  [[ "$io_name" == '-' ]] && return

  local io_fn="bundle::serialize::${io_name}"
  [[ "$parse" ]] && io_fn="bundle::parse::${io_name}"

  if ! command -v "$io_fn" >/dev/null; then
    [[ "$silent" ]] && return
    tilde::error "Failed to process files entry; unknown IO type [$io_name]:"
    rm -rf "$target"
    exit 1
  fi

  "$io_fn" "$target"
}

function bundle::serialize::plutil() {
  plutil -convert binary1 "$1"
}

function bundle::parse::plutil() {
  plutil -convert xml1 "$1"
}
