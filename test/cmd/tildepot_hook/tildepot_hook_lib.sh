#!/usr/bin/env bash
#
# Bats helpers for tildepot hook tests

# Setup
export TILDEPOT_HOME="$BATS_TEST_TMPDIR/tildepot"
mkdir "$TILDEPOT_HOME"
mkdir "$TILDEPOT_HOME/bundles"

test::test_hook_cmd() {
  local hook="${1?}"

  test::it "fails by default without any bundle files"
  run tildepot "$hook"
  assert_failure
  assert_output "Error: No bundle files found."

  test::it "prints usage on '--help'"
  run tildepot "$hook" --help
  test::_assert_hook_cmd_usage "$hook"

  test::it "prints usage on '-h'"
  run tildepot "$hook" -h
  test::_assert_hook_cmd_usage "$hook"
}

test::_assert_hook_cmd_usage() {
  local hook="$1"
  assert_line "tildepot $hook"
  assert_line "Usage: tildepot $hook [options]"
  assert_line "Options:"
}

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
