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

test::mock_bundle() {
  local bundle="${1?}"
  local body
  local path
  if [[ $# -lt 3 ]]; then
    body="${2-}"
    path=""
  else
    path="$2"
    body="$3"
  fi

  if [[ $path != *.sh ]]; then
    if [[ $path == */ || -z $path ]]; then
      path+="$bundle.sh"
    elif [[ $path == */* ]]; then
      path+="/$bundle.sh"
    else
      path+=".sh"
    fi
  fi
  if [[ $path != */* ]]; then
    path="$TILDEPOT_HOME/bundles/$path"
  fi

  if [[ ! -f $path ]]; then
    echo "#!/bin/bash" >"$path"
    echo "# Mock bundle file" >>"$path"
  fi

  if [[ -n $body ]]; then
    echo "${body//'<BUNDLE>'/$bundle}" >>"$path"
  fi
}

test::mock_hook_fn() {
  local hook="${1?}"
  local body="${2:-"echo \"[TEST] Invoking hook [<BUNDLE>/$hook]\""}"
  local extra_body="${3-}"

  local hook_fn
  hook_fn="$(echo "$hook" | tr '[:lower:]' '[:upper:]')"
  cat <<EOF
function ${hook_fn}() {
  $body
  $extra_body
}
EOF
}

test::mock_hook() {
  local bundle="${1?}"
  local hook="${2?}"
  local body="${3-}"

  test::mock_bundle "$bundle" "
    $(test::mock_hook_fn "$hook")
    $body
  "
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

  test::mock_hook "$bundle" "$hook" "
    $(test::mock_hook_fn "${hook}_skip" "$skip_body")
  "
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

  test::mock_bundle "$bundle" "
    function SKIP() {
      $skip_body
    }
  "
}

test::assert_bundle_skipped() {
  local bundle="${1?}"
  local hook="${2?}"
  local reason="${3-}"
  assert_line "=> Skipping $bundle."
  [[ -n $reason ]] && assert_line "==> Reason: $reason."
  test::refute_hook_called "$bundle" "$hook"
}
