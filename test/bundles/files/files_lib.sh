#!/usr/bin/env bash
#
# Bats helpers for tildepot files-bundle tests

# Setup
# Set up files bundle.
export TILDEPOT_HOME="$BATS_TEST_TMPDIR/tildepot"
mkdir "$TILDEPOT_HOME"
mkdir "$TILDEPOT_HOME/bundles"
export TEST_FILES_STATE="$TILDEPOT_HOME/state/files"
# Set up home mock source dir.
export TEST_HOME_MOCK="$BATS_TEST_TMPDIR/mock"
mkdir "$TEST_HOME_MOCK"
# Set up temp dir as home.
_TEST_PREV_HOME="$HOME"
export HOME="$BATS_TEST_TMPDIR/home"
mkdir "$HOME"
# Set up state target dir.
export TEST_FILES_TARGET="$BATS_TEST_TMPDIR/state-target"
mkdir "$TEST_FILES_TARGET"

function test_files::teardown() {
  unset HOME
}

function test_files::reset_home() {
  test::cp "$TEST_HOME_MOCK" "$HOME"
}
function test_files::clear_home() {
  rm -rf "$HOME"
  mkdir "$HOME"
}

function test_files::mock_bundle() {
  local content="${1?}"

  local path="$TILDEPOT_HOME/bundles/files.sh"

  if [[ ! -f $path ]]; then
    {
      echo "#!/usr/bin/env bash"
      echo "# Mock files-bundle"
      echo ""
      echo "export EXTEND='$BATS_CWD/bundles/files.sh'"
      echo ""
    } >"$path"
  fi

  echo "$content" >>"$path"
}
function test_files::mock_setup() {
  local files_cfg=${1?}

  test_files::mock_bundle "export FILES='$files_cfg'"
}

function test_files::assert_dirs_equal() {
  local got_dir="${1?}"
  local want_dir="${2?}"

  assert_dir_exists "$got_dir"
  local got_sum
  got_sum="$(test_files::_scan_dir_contents "$got_dir")"
  local want_sum
  want_sum="$(test_files::_scan_dir_contents "$want_dir")"
  assert_equal "$got_sum" "$want_sum"
}

_TEST_FILES_BLANK_MD5SUM="                                "
function test_files::_scan_dir_contents() {
  local dir="${1?}"

  cd "$dir" || exit

  local path
  while IFS= read -r entry; do
    if [[ -f $entry ]]; then
      md5sum "$entry"
    else
      echo "$_TEST_FILES_BLANK_MD5SUM  $entry/"
    fi
  done < <(find . -mindepth 1 | sort)
}

function test_files::run_assert_save() {
  run tildepot save --bundle files
  assert_success
  test_files::assert_dirs_equal "$TEST_FILES_STATE" "$TEST_FILES_TARGET"
}
function test_files::run_assert_restore() {
  run tildepot restore --bundle files -y
  assert_success
  test_files::assert_dirs_equal "$HOME" "$TEST_HOME_MOCK"
}

function test_files::assert_invalid_config() {
  local msg="$1"

  test::it 'aborts on save'
  run tildepot save --bundle files
  assert_failure
  assert_line --partial "Invalid config"
  assert_line --partial "$msg"

  test::it 'aborts on restore'
  run tildepot restore --bundle files -y
  assert_failure
  assert_line --partial "Invalid config"
  assert_line --partial "$msg"
}
