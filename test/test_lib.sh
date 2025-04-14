#!/usr/bin/env bash
#
# Bats test helpers

# Setup
set -euo pipefail
bats_load_library bats-support
bats_load_library bats-assert
bats_load_library bats-file
# Keep a reference of the initial PATH
export TEST_INITIAL_PATH="$PATH"
# Add tildepot to PATH
PATH="$BATS_CWD/dist:$PATH"
# Expose misc variables
export TEST_BIN="$BATS_CWD/dist/tildepot"
export TEST_APP_REPO_ROOT="$HOME/.local/share/tildepot"
export TEST_VERSION='0.0.0-test'

# Assert that a command's usage output is correct
test::_assert_cmd_usage() {
  local cmd="$1"
  assert_line "tildepot $cmd"
  assert_line --partial "Usage: tildepot $cmd "
  assert_line "Options:"
  assert_line "Commands:"
}

# Log a sub-test
test::it() {
  echo "└─ $1"
}

# Log a message
test::log() {
  echo "[TEST] $1" >&2
}
export -f test::log

# Abort a test
test::abort() {
  test::log "ERROR: $1"
  exit 1
}
export -f test::abort

# Test a sub-command
test::test_cmd() {
  local cmd="$1"

  test::it "errors and usage by default"
  run tildepot "$cmd"
  assert_failure
  test::_assert_cmd_usage "$cmd"

  test::it "prints usage on '--help'"
  run tildepot "$cmd" --help
  test::_assert_cmd_usage "$cmd"

  test::it "prints usage on '-h'"
  run tildepot "$cmd" -h
  test::_assert_cmd_usage "$cmd"

  test::it "errors on invalid option"
  run tildepot "$cmd" --my-invalid-command
  assert_failure
  assert_output --partial "Unknown option: --my-invalid-command"

  test::it "errors on invalid command"
  run tildepot "$cmd" my_invalid_command
  assert_failure
  assert_output --partial "Unknown command: my_invalid_command"
}

# Run an interactive command, expecting output and responding to prompts
function test::expect_prompt() {
  local expect=''
  local want
  local send
  local want_quot_esc
  local send_quot_esc
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --output)
      want="$2"
      want_quot_esc="${want//\"/\\\"}"
      shift
      expect+="
        expect {
          \"$want_quot_esc\" {}
          eof {send_error \"\\nexpected output: $want_quot_esc\"; exit 1}
          timeout {send_error \"\\nexpected output: $want_quot_esc\"; exit 1}
        }
      "
      ;;
    --prompt)
      want="$2"
      send="$3"
      want_quot_esc="${want//\"/\\\"}"
      send_quot_esc="${send//\"/\\\"}"
      shift 2
      expect+="
        expect {
          \"$want_quot_esc\" {send \"$send_quot_esc\\r\"}
          eof {send_error \"\\nexpected prompt: $want_quot_esc\"; exit 1}
          timeout {send_error \"\\nexpected prompt: $want_quot_esc\"; exit 1}
        }
      "
      ;;
    -*) test::abort "Unknown option: $1" ;;
    *) break ;;
    esac
    shift
  done
  expect <<END
    set timeout 1
    spawn $@
    $expect
    expect eof
END
}

# Get path to a fixture file
function test::fixture_path() {
  local file="$1"
  local path="$BATS_CWD/test/fixtures/$file"
  [[ ! -f $path && ! -d $path ]] && test::abort "Fixture not found: \"$path\""
  echo "$path"
}

# Print contents of a fixture file
function test::fixture() {
  local file="$1"
  cat "$(test::fixture_path "$file")"
}

# Mock download
# Examples:
#   test::mock_download --fixture my_fixture.txt
#   test::mock_download --path path/to/my_file.txt
#   test::mock_download 'my contents'
#   test::mock_download - < <(my_command)
#   test::mock_download --error
function test::mock_download() {
  # Store mock in temp file.
  local tmp="$BATS_TEST_TMPDIR/__mock_download"
  case ${1?missing input} in
  --fixture) test::fixture "${2?missing fixture}" >"$tmp" ;;
  --error) rm -f "$tmp" ;;
  --path) cat "${2?missing path}" >"$tmp" ;;
  '-') cat >"$tmp" ;;
  '') test::abort "Missing contents for mock download" ;;
  *) echo "$1" >"$tmp" ;;
  esac

  # Mock curl & wget.
  # shellcheck disable=SC2317
  function test::_mock_download() {
    test::log "Mocking download; args: wget $*"
    if [[ ! -f "$BATS_TEST_TMPDIR/__mock_download" ]]; then
      test::log "Simulating download error"
      return 1
    fi
    cat "$BATS_TEST_TMPDIR/__mock_download"
  }
  export -f test::_mock_download
  # shellcheck disable=SC2317
  function curl() {
    test::_mock_download "$@"
  }
  export -f curl
  # shellcheck disable=SC2317
  function wget() {
    test::_mock_download "$@"
  }
  export -f wget
}

# Unset mock download
function test::mock_download_teardown() {
  unset -f curl
  unset -f wget
  rm -f "$BATS_TEST_TMPDIR/mock_download"
}

function test::assert_mock_download_url() {
  local want_url="$1"
  assert_output --partial "[TEST] Mocking download"
  assert_output --partial "$want_url"
}

function test::assert_git_origin_url() {
  local dir="$1"
  local want_url="$2"

  local git_config="$dir/.git/config"
  assert_file_exist "$git_config"
  local got_url
  got_url="$(grep -A3 '^\[remote "origin"\]' "$git_config" | grep "url = " | cut -d" " -f3)"
  assert_equal "$got_url" "$want_url"
}
