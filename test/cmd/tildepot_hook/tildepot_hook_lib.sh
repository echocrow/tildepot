#!/usr/bin/env bash
#
# Bats helpers for tildepot hook tests

# Setup
export TILDEPOT_HOME="$BATS_TEST_TMPDIR/tildepot"
mkdir "$TILDEPOT_HOME"
mkdir "$TILDEPOT_HOME/bundles"

test::mock_hook() {
  local bundle="${1?}"
  local hook="${2?}"

  local bundle_file="$TILDEPOT_HOME/bundles/${bundle}.sh"
  if [[ ! -f $bundle_file ]]; then
    echo "#!/bin/bash" >"$bundle_file"
  fi

  local hook_fn
  hook_fn="$(echo "$hook" | tr '[:lower:]' '[:upper:]')"
  cat >>"$bundle_file" <<EOF
function ${hook_fn}() {
  echo "[TEST] Invoking hook [$bundle/$hook]"
}
EOF
}

test::assert_hook_invoked() {
  local bundle="${1?}"
  local hook="${2?}"
  assert_line "=> Running $bundle $hook..."
  assert_line "[TEST] Invoking hook [$bundle/$hook]"
}

test::mock_hook_skip() {
  local bundle="${1?}"
  local hook="${2?}"
  local skip_body="${3?}"

  test::mock_hook "$bundle" "$hook"

  local bundle_file="$TILDEPOT_HOME/bundles/${bundle}.sh"

  local hook_fn
  hook_fn="$(echo "$hook" | tr '[:lower:]' '[:upper:]')"
  cat >>"$bundle_file" <<EOF
function ${hook_fn}_SKIP() {
  $skip_body
}
EOF
}

test::assert_hook_skipped() {
  local bundle="${1?}"
  local hook="${2?}"
  local reason="${3-}"
  assert_line "=> Skipping $bundle $hook."
  [[ -n $reason ]] && assert_line "==> Reason: $reason."
  refute_line "=> Running $bundle $hook..."
  refute_line "[TEST] Invoking hook [$bundle/$hook]"
}
