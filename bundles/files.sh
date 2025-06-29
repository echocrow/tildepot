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

  local actions
  actions="$(bundle::actions)"

  local internal_existed op
  while IFS=$'\t' read -r op internal external io_name group internal_name external_name; do
    case "$op" in

    cp)
      internal_existed=
      if [[ -e $internal ]]; then
        internal_existed=1
        rm -rf "$internal"
      fi

      if [[ -e $external ]]; then
        mkdir -p "$(dirname "$internal")"
        cp -r "$external" "$internal"

        bundle::_process_file --parse "$internal" \
          "$io_name" "$group" "$internal_name"
      fi

      if [[ -e $internal ]]; then
        tilde::success "Stored [$external_name] in [$internal_name]"
      else
        op='skipped'
        [[ $internal_existed ]] && op='deleted'
        tilde::success "No [$external_name] present; $op [$internal_name]"
      fi
      ;;

    '') continue ;;
    *) lib::abort "Unknown file action [$op]" ;;
    esac

  done <<<"$actions"
}

function RESTORE() {
  local actions
  actions="$(bundle::actions)"

  # Process files first (in case process fails).
  while IFS=$'\t' read -r op internal external io_name group internal_name external_name; do
    case "$op" in

    cp)
      if [[ -e $internal ]]; then
        bundle::_process_file --serialize "$internal" \
          "$internal_name" "$group" "$io_name"
      fi
      ;;

    '') continue ;;
    *) lib::abort "Unknown file action [$op]" ;;
    esac
  done <<<"$actions"

  # Restore files.
  local external_existed op
  while IFS=$'\t' read -r op internal external io_name group internal_name external_name; do
    [[ $op != 'cp' ]] && continue

    external_existed=
    if [[ -e $external ]]; then
      external_existed=1
      rm -rf "$external"
    fi

    if [[ -e $internal ]]; then
      mkdir -p "$(dirname "$external")"
      cp -r "$internal" "$external"
    fi

    if [[ -e $internal ]]; then
      tilde::success "Restored [$external_name] from [$internal_name]"
    else
      op='Skipped'
      [[ $external_existed ]] && op='Deleted'
      tilde::success "[$op] [$external_name]; no [$internal_name] present"
    fi

  done <<<"$actions"
}

function bundle::actions() {
  local files="$FILES"

  local cols=()
  local i col
  local op
  local internal external io_name
  local group=
  local group_io_name=
  local internal_name
  local external_name
  local t=$'\t'
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

    # Ignore comment.
    if [[ ${cols[0]:0:1} == '#' ]]; then
      continue
    fi

    [[ -n $line ]] && lib::abort "Invalid config: too many columns"

    # Handle group.
    if [[ -z ${cols[0]} || ${cols[0]:0:1} == '[' ]]; then
      group="${cols[0]}"
      group="${group#'['}"
      group="${group%']'}"

      group_io_name=
      [[ ${cols[1]:0:1} == '@' ]] && group_io_name="${cols[1]#'@'}"
      continue
    fi

    # Handle file.
    op='cp'
    internal="${cols[0]}"
    external="${cols[1]}"
    io_name="${cols[2]}"

    if [[ -z $external ]]; then
      tilde::warning "Ignoring files entry; missing external for [$internal]:"
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

    echo "${op}$t${internal}$t${external}$t${io_name:--}$t${group:--}$t${internal_name}$t${external_name}"
  done <<<"$files"
}

function bundle::_process_file() {
  local op="${1?}"
  local file="${2?}"
  local io_names=("${@:3}")

  local serialize
  case "$op" in
  --parse) serialize= ;;
  --serialize) serialize=1 ;;
  *) lib::abort "Unknown file process op [$op]" ;;
  esac

  local required_io_idx=0
  [[ $serialize ]] && required_io_idx=$((${#io_names[@]} - 1))

  local io_fn_ns="bundle::parse"
  [[ $serialize ]] && io_fn_ns="bundle::serialize"

  local io_name io_fn
  for ((i = 0; i < ${#io_names[@]}; i++)); do
    io_name="${io_names[$i]}"
    [[ $io_name == - ]] && continue

    io_fn="${io_fn_ns}::${io_name}"
    if ! declare -F "$io_fn" >/dev/null; then
      ((i != required_io_idx)) && continue
      tilde::error "Failed to process files entry; unknown IO type [$io_name]"
      rm -rf "$file"
      exit 1
    fi

    "$io_fn" "$file"
  done
}

function bundle::parse::plutil() {
  plutil -convert xml1 "$1"
}

function bundle::serialize::plutil() {
  plutil -convert binary1 "$1"
}
