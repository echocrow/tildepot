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
export TEST_APP_REPO_URL="https://github.com/echocrow/tildepot"
export TEST_APP_REPO_ROOT="$HOME/.local/share/tildepot"
export TEST_VERSION='0.0.0-test'

# Assert that a command's usage output is correct
function test::_assert_cmd_usage() {
  local cmd="$1"
  assert_line "tildepot $cmd"
  assert_line --partial "Usage: tildepot $cmd "
  assert_line "Options:"
  assert_line "Commands:"
}

# Log a sub-test
function test::it() {
  echo "└─ $1"
}

# Log a message
function test::log() {
  echo "[TEST] $1" >&2
}
export -f test::log

# Abort a test
function test::abort() {
  test::log "ERROR: $1"
  exit 1
}
export -f test::abort

# Test a sub-command
function test::test_cmd() {
  local cmd="${1?}"

  test::it "errors and usage by default"
  run tildepot "$cmd"
  assert_failure
  test::_assert_cmd_usage "$cmd"

  test::it "prints usage on '--help'"
  run tildepot "$cmd" --help
  assert_success
  test::_assert_cmd_usage "$cmd"

  test::it "prints usage on '-h'"
  run tildepot "$cmd" -h
  assert_success
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
  # Run `expect`, and strip carriage returns created by it.
  {
    expect <<END
    set timeout 1
    spawn $@
    $expect
    expect eof
END
  } | tr -d '\r'
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

# Mock downloads
#
# This stores mock data in a temporary file for later one-time use. This
# function can be called multiple times to mock multiple downloads.
#
# Examples:
#   test::mock_download --fixture my_fixture.txt
#   test::mock_download --path path/to/my_file.txt
#   test::mock_download 'my contents'
#   test::mock_download - < <(my_command)
#   test::mock_download --error
#   test::mock_download --path data_1.txt --path data_2.txt
function test::mock_download() {
  local dir="$BATS_TEST_TMPDIR/__mock_downloads"
  mkdir -p "$dir"
  : >"$dir/_files"

  while [[ $# -gt 0 ]]; do
    local file
    file="$(mktemp -p "$dir")"
    echo "$file" >>"$dir/_files"

    case ${1?missing input} in
    --fixture)
      test::fixture "${2?missing fixture}" >"$file"
      shift
      ;;
    --path)
      cat "${2?missing path}" >"$file"
      shift
      ;;
    --error) rm -f "$file" ;;
    '-') cat >"$file" ;;
    '') test::abort "Missing contents for mock download" ;;
    *) echo "$1" >"$file" ;;
    esac
    shift

  done

  # Mock curl & wget.
  # shellcheck disable=SC2317
  function test::_mock_download() {
    test::log "Mocking download; args: wget $*"

    # Get next mock file.
    local dir="$BATS_TEST_TMPDIR/__mock_downloads"

    local next_file
    next_file="$(head -n1 "$dir/_files")"
    [[ -z $next_file ]] && test::abort "No more mock downloads"

    # Shift mock files.
    tail -n +2 "$dir/_files" >"$dir/_files.tmp"
    mv "$dir/_files.tmp" "$dir/_files"

    # Simulate download.
    if [[ ! -f $next_file ]]; then
      test::log "Simulating download error"
      return 1
    fi
    cat "$next_file"
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
  rm -rf "$BATS_TEST_TMPDIR/__mock_downloads"
}

function test::assert_log() {
  local msg="${1?}"
  assert_output --partial "[TEST] $msg"
}
function test::refute_log() {
  local msg="${1?}"
  refute_output --partial "[TEST] $msg"
}

function test::assert_mock_download_url() {
  local want_url="${1?}"
  test::assert_log "Mocking download"
  assert_output --partial "$want_url"
}
function test::refute_mock_download_url() {
  local want_url="${1:-}"
  test::refute_log "Mocking download"
  if [[ -n $want_url ]]; then
    refute_output --partial "$want_url"
  fi
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

function test::assert_dir_entries() {
  local dir="$1"
  local want_entries=("${@:2}")

  dir="${dir%/}"
  assert_dir_exists "$dir"

  local got_entries=''
  got_entries="$(ls -1F "$dir")"

  assert_equal "${got_entries}" "$(printf "%s\n" "${want_entries[@]}")"
}

function test::assert_dir_files() {
  local depth=1
  [[ $1 == --depth || $1 == -d ]] && depth="$2" && shift 2
  local dir="$1"
  local want_entries=("${@:2}")

  dir="${dir%/}"
  assert_dir_exists "$dir"

  local got_entries=''
  got_entries="$(find "$dir" -type f -maxdepth "$depth" | sort -f | cut -c "$((${#dir} + 2))-")"

  assert_equal "${got_entries}" "$(printf "%s\n" "${want_entries[@]}")"
}

function test::put() {
  local content="${1?}"
  local file="${2?}"

  mkdir -p "$(dirname "$file")"
  echo "$content" >"$file"
}

function test::cp() {
  local source_file="${1?}"
  local target_file="${2?}"

  mkdir -p "$(dirname "$target_file")"
  rm -rf "$target_file"
  cp -r "$source_file" "$target_file"
}
