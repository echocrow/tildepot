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
  assert_output "Error: No bundles found."

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

test::_mock_bundle_path() {
  local bundle="${1?}"
  echo "$TILDEPOT_HOME/bundles/${bundle}.sh"
}

test::mock_bundle() {
  local bundle="${1?}"

  local bundle_file
  bundle_file="$(test::_mock_bundle_path "$bundle")"
  if [[ ! -f $bundle_file ]]; then
    echo "#!/bin/bash" >"$bundle_file"
    echo "# Mock bundle file" >>"$bundle_file"
  fi
  echo "$bundle_file"
}

test::mock_hook() {
  local bundle="${1?}"
  local hook="${2?}"

  local bundle_file
  bundle_file="$(test::mock_bundle "$bundle")"

  local hook_fn
  hook_fn="$(echo "$hook" | tr '[:lower:]' '[:upper:]')"
  cat >>"$bundle_file" <<EOF
function ${hook_fn}() {
  echo "[TEST] Invoking hook [$bundle/$hook]"
}
EOF

  echo "$bundle_file"
}

test::hook_run_msg() {
  local bundle="${1?}"
  local hook="${2?}"
  echo "=> Running $bundle $hook..."
}
test::hook_exec_msg() {
  local bundle="${1?}"
  local hook="${2?}"
  echo "[TEST] Invoking hook [$bundle/$hook]"
}
test::assert_hook_invoked() {
  local index=
  [[ $1 == '--index' ]] && index="$2" && shift 2
  local bundle="${1?}"
  local hook="${2?}"

  local opts=()
  [[ -n $index ]] && opts=("--index" "$index")
  assert_line "${opts[@]}" "$(test::hook_run_msg "$bundle" "$hook")"
  [[ -n $index ]] && index=$((index + 1)) && opts=("--index" "$index")
  assert_line "${opts[@]}" "$(test::hook_exec_msg "$bundle" "$hook")"
}

test::mock_hook_skip() {
  local bundle="${1?}"
  local hook="${2?}"
  local skip_body="${3?}"

  local bundle_file
  bundle_file="$(test::mock_hook "$bundle" "$hook")"

  local hook_fn
  hook_fn="$(echo "$hook" | tr '[:lower:]' '[:upper:]')"
  cat >>"$bundle_file" <<EOF
function ${hook_fn}_SKIP() {
  $skip_body
}
EOF

  echo "$bundle_file"
}

test::refute_hook_called() {
  local bundle="${1?}"
  local hook="${2?}"
  refute_line "=> Running $bundle $hook..."
  refute_line "[TEST] Invoking hook [$bundle/$hook]"
}

test::assert_hook_skipped() {
  local bundle="${1?}"
  local hook="${2?}"
  local reason="${3-}"
  assert_line "=> Skipping $bundle $hook."
  [[ -n $reason ]] && assert_line "==> Reason: $reason."
  test::refute_hook_called "$bundle" "$hook"
}

test::mock_bundle_skip() {
  local bundle="${1?}"
  local skip_body="${2?}"

  local bundle_file
  bundle_file="$(test::mock_bundle "$bundle")"

  cat >>"$bundle_file" <<EOF
function SKIP() {
  $skip_body
}
EOF

  echo "$bundle_file"
}

test::assert_bundle_skipped() {
  local bundle="${1?}"
  local hook="${2?}"
  local reason="${3-}"
  assert_line "=> Skipping $bundle."
  [[ -n $reason ]] && assert_line "==> Reason: $reason."
  test::refute_hook_called "$bundle" "$hook"
}

test::mock_inherited_bundle() {
  local bundle="${1?}"
  local inherit="${2?}"

  local bundle_file
  bundle_file="$(test::mock_bundle "$bundle")"

  echo "export EXTEND=$inherit" >>"$bundle_file"

  echo "$bundle_file"
}
