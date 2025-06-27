#!/usr/bin/env bash
#
# Tildepot bundle for files.

# Override this variable to set tracked files.
export FILES=""

function SAVE() {
  # Keep previous state files.
  if [[ -d $BUNDLE_PREV_STATE_DIR ]]; then
    cp -r "$BUNDLE_PREV_STATE_DIR"/* "$BUNDLE_STATE_DIR/" 2>/dev/null || true
  fi

  while IFS=$'\t' read -r internal external io_name group internal_name external_name; do
    mkdir -p "$(dirname "$internal")"

    rm -rf "$internal"
    [[ -e $external ]] && cp -r "$external" "$internal"

    bundle::_process_file "$io_name" "$internal" --parse
    bundle::_process_file "$group" "$internal" --parse --silent
    bundle::_process_file "$internal_name" "$internal" --parse --silent

    tilde::success "Stored [$external_name] in [$internal_name]"
  done < <(bundle::list)
}

function RESTORE() {
  while IFS=$'\t' read -r internal external io_name group internal_name external_name; do
    mkdir -p "$(dirname "$external")"

    rm -rf "$external"
    [[ -e $internal ]] && cp -r "$internal" "$external"

    bundle::_process_file "$internal_name" "$external" --silent
    bundle::_process_file "$group" "$external" --silent
    bundle::_process_file "$io_name" "$external"

    tilde::success "Restored [$external_name] from [$internal_name]"
  done < <(bundle::list)
}

function bundle::list() {
  local files="$FILES"

  local cols=()
  local i col
  local internal external io_name
  local group=
  local group_io_name=
  local internal_name
  local external_name
  while read -r line; do
    line="${line//\\ / }"
    line="$line  "
    line="${line#"${line%%[![:space:]]*}"}"

    for i in {0..2}; do
      col="${line%%[[:space:]][[:space:]]*}"
      col="${col%%$'\t'*}"
      cols[i]="$col"

      line="${line#"$col"}"
      line="${line#"${line%%[![:space:]]*}"}"
    done
    [[ -n $line ]] && lib::abort "Too many columns in files config"

    # Ignore comment.
    if [[ ${cols[0]} =~ ^# ]]; then
      continue
    fi

    # Handle group.
    if [[ -z ${cols[0]} || ${cols[0]} =~ ^'[' ]]; then
      group="${cols[0]}"
      group="${group#'['}"
      group="${group%']'}"

      group_io_name=
      [[ ${cols[1]} =~ ^@ ]] && group_io_name="${cols[1]#'@'}"
      continue
    fi

    # Handle file.
    internal="${cols[0]}"
    external="${cols[1]}"
    io_name="${cols[2]}"

    if [[ -z $external ]]; then
      tilde::warning "Ignoring files entry; missing external:" >&2
      echo "    $internal" >&2
      continue
    fi

    internal="${internal%/}"
    external="${external%/}"

    [[ -n $group ]] && internal="$group/$internal"

    internal_name="$internal"
    external_name="$external"

    internal="$BUNDLE_STATE_DIR/$internal"
    external="${external/#\~\//$HOME/}"

    io_name="${io_name#'@'}"
    [[ ! $io_name ]] && io_name="$group_io_name"

    echo "$internal"$'\t'"$external"$'\t'"${io_name:--}"$'\t'"${group:--}"$'\t'"$internal_name"$'\t'"$external_name"
  done <<<"$files"
}

function bundle::_process_file() {
  local io_name="$1"
  local target="$2"

  local parse=
  local silent=
  local arg
  for arg in "${@:3}"; do
    case "$arg" in
    --parse) parse=1 ;;
    --silent) silent=1 ;;
    '') ;;
    *) lib::abort "Unknown argument [$arg]" ;;
    esac
  done

  [[ $io_name == - ]] && return

  local io_fn="bundle::serialize::${io_name}"
  [[ $parse ]] && io_fn="bundle::parse::${io_name}"

  if ! declare -F "$io_fn" >/dev/null; then
    [[ $silent ]] && return
    tilde::error "Failed to process files entry; unknown IO type [$io_name]"
    rm -rf "$target"
    exit 1
  fi

  "$io_fn" "$target"
}

function bundle::parse::plutil() {
  plutil -convert xml1 "$1"
}

function bundle::serialize::plutil() {
  plutil -convert binary1 "$1"
}
