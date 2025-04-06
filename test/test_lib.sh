#!/usr/bin/env bash
#
# Bats test helpers

# Setup
bats_load_library bats-support
bats_load_library bats-assert
bats_load_library bats-file
# Keep a reference of the initial PATH
export LIB_INITIAL_PATH="$PATH"
# Add tildepot to PATH
PATH="$BATS_CWD/dist:$PATH"
# Expose misc variables
export LIB_TILDEPOT_BIN="$BATS_CWD/dist/tildepot"
export LIB_TILDEPOT_DEFAULT_INSTALL_PATH="/usr/local/bin"
export LIB_TILDEPOT_TEST_VERSION='0.0.0-test'

# Assert that a command's usage output is correct
lib::_assert_cmd_usage() {
  local cmd="$1"
  assert_line "tildepot $cmd"
  assert_line --partial "Usage: tildepot $cmd "
  assert_line "Options:"
  assert_line "Commands:"
}

# Log a sub-test
lib::it() {
  echo "└─ $1"
}

# Test a sub-command
lib::test_cmd() {
  local cmd="$1"

  lib::it "errors and usage by default"
  run tildepot "$cmd"
  assert_failure
  lib::_assert_cmd_usage "$cmd"

  lib::it "prints usage on '--help'"
  run tildepot "$cmd" --help
  lib::_assert_cmd_usage "$cmd"

  lib::it "prints usage on '-h'"
  run tildepot "$cmd" -h
  lib::_assert_cmd_usage "$cmd"

  lib::it "errors on invalid option"
  run tildepot "$cmd" --my-invalid-command
  assert_failure
  assert_output --partial "Unknown option: --my-invalid-command"

  lib::it "errors on invalid command"
  run tildepot "$cmd" my_invalid_command
  assert_failure
  assert_output --partial "Unknown command: my_invalid_command"
}

# Run an interactive command, expecting output and responding to prompts
function lib::expect_prompt() {
  local expect=''
  local want
  local send
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --output)
      want="$2"
      shift
      expect+="
        expect {
          $want {}
          eof {send_error \"\\nexpected output: ${want//\"/\\\"}\"; exit 1}
          timeout {send_error \"\\nexpected output: ${want//\"/\\\"}\"; exit 1}
        }
      "
      ;;
    --prompt)
      want="$2"
      send="$3"
      shift 2
      expect+="
        expect {
          $want {send \"${send//\"/\\\"}\\r\"}
          eof {send_error \"\\nexpected prompt: ${want//\"/\\\"}\"; exit 1}
          timeout {send_error \"\\nexpected prompt: ${want//\"/\\\"}\"; exit 1}
        }
      "
      ;;
    -*) lib::abort "Unknown option: $1" ;;
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
