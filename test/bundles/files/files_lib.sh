#!/usr/bin/env bash
#
# Bats helpers for tildepot files-bundle tests

# Setup
# Set up files bundle.
export TILDEPOT_HOME="$BATS_TEST_TMPDIR/tildepot"
mkdir "$TILDEPOT_HOME"
mkdir "$TILDEPOT_HOME/bundles"
export TEST_FILE_STATE="$TILDEPOT_HOME/state/files"
# Set up home mock source dir.
export TEST_HOME_MOCK="$BATS_TEST_TMPDIR/mock"
mkdir "$TEST_HOME_MOCK"
# Set up temp dir as home.
_TEST_PREV_HOME="$HOME"
export HOME="$BATS_TEST_TMPDIR/home"
mkdir "$HOME"

function test_bundle::teardown() {
  unset HOME
}

function test_bundle::load_home_mock_fixture() {
  rm -rf "$TEST_HOME_MOCK"
  cp -r "$(test::fixture_path 'home-mock')" "$TEST_HOME_MOCK"
}
function test_bundle::reload_home() {
  rm -rf "$HOME"
  cp -r "$TEST_HOME_MOCK" "$HOME"
}
function test_bundle::reset_home() {
  rm -rf "$HOME"
  mkdir "$HOME"
}

function test_bundle::mock_bundle() {
  local content="${1?}"

  local path="$TILDEPOT_HOME/bundles/files.sh"

  [[ -f $path ]] && test::abort "Mock files-bundle already exists"

  {
    echo "#!/usr/bin/env bash"
    echo "# Mock files-bundle"
    echo ""
    echo "export EXTEND='$BATS_CWD/bundles/files.sh'"
    echo ""
    echo "$content"
  } >"$path"
}
function test_bundle::mock_setup() {
  local files_cfg=${1?}

  test_bundle::mock_bundle "export FILES='$files_cfg'"
}

function test_bundle::assert_dirs_equal() {
  local got_dir="${1?}"
  local want_dir="${2?}"

  assert_dir_exists "$got_dir"
  local got_sum
  got_sum="$(test_bundle::_scan_dir_contents "$got_dir")"
  local want_sum
  want_sum="$(test_bundle::_scan_dir_contents "$want_dir")"
  assert_equal "$got_sum" "$want_sum"
}

_BLANK_MD5SUM="                                "
function test_bundle::_scan_dir_contents() {
  local dir="${1?}"

  cd "$dir" || exit

  local path
  while IFS= read -r entry; do
    if [[ -f $entry ]]; then
      md5sum "$entry"
    else
      echo "$_BLANK_MD5SUM  $entry/"
    fi
  done < <(find . -mindepth 1 | sort)
}
