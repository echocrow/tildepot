#!/usr/bin/env bats
#
# Tests for `tildepot repo download`

setup() {
  load ../test_lib.sh

  export _TEST_MOCK_REPO
  _TEST_MOCK_REPO="$(test::fixture_path 'my-tildepot-mock')"
  test::mock_download - < <(cd "$_TEST_MOCK_REPO/.." && zip -r - "$(basename "$_TEST_MOCK_REPO")")

  # Mock git.
  export _TEST_GIT_BIN
  _TEST_GIT_BIN="$(command -v git)"
  export _TEST_GIT_DISABLED=
  # shellcheck disable=SC2317,SC2329
  function git() {
    if [[ -n $_TEST_GIT_DISABLED ]]; then
      test::log "git disabled in this test"
      return 1
    fi

    local args=("$@")
    while [[ $# -gt 0 ]]; do
      case "$1" in
      -C | -c) shift 2 && continue ;;
      --quiet) shift && continue ;;
      clone | fetch | pull)
        test::log "git $1 not supported in test"
        return 1
        ;;
      -*) lib::abort "Unsupported git mock option: $1" ;;
      *) "$_TEST_GIT_BIN" "${args[@]}" ;;
      esac
      break
    done
  }
  export -f git
}

teardown() {
  test::mock_download_teardown

  unset _TEST_GIT_BIN
  unset _TEST_GIT_DISABLED
  unset -f git
}

function assert_repo() {
  local dir="$1"
  local no_git="${2-}"
  assert_dir_exist "$dir"
  [[ ! $no_git ]] && assert_dir_exist "$dir/.git"
  assert_output --partial "Downloaded tildepot repository to $dir"
}
function assert_mock_repo() {
  local dir="$1"
  local no_git="${2-}"
  assert_repo "$dir" "$no_git"
  assert_files_equal "$dir/README.md" "$_TEST_MOCK_REPO/README.md"
}

@test "downloads a github repo into the default repo location" {
  run tildepot repo download --origin "my/repo"
  assert_success
  assert_mock_repo "$TEST_APP_REPO"
  test::assert_git_origin_url "$TEST_APP_REPO" "https://github.com/my/repo.git"
  test::assert_mock_download_url https://github.com/my/repo/archive/refs/heads/main.zip
}

@test "aborts when custom repo cannot be downloaded" {
  test::mock_download --error

  run tildepot repo download --origin "https://invalid"
  assert_failure
  assert_output --partial "Failed to download repository"
}

@test "aborts when '--repo' origin does not match known format" {
  run tildepot repo download --origin "invalid://repo"
  assert_failure
  assert_output --partial "Invalid repository origin"
}

@test "succeeds without 'git' available" {
  export _TEST_GIT_DISABLED=1
  run tildepot repo download --origin "my/repo"
  assert_success
  assert_mock_repo "$TEST_APP_REPO" true
  assert_output --partial "Failed to initialize git repo"
}

@test "creates a new repo in '--repo-dir'" {
  local dir="$BATS_TEST_TMPDIR/my-tildepot"

  run tildepot repo download --origin "my/repo" --repo-dir "$dir"
  assert_success
  assert_mock_repo "$dir"
}
@test "creates a new repo in early-defined '--repo-dir'" {
  local dir="$BATS_TEST_TMPDIR/my-tildepot"
  mkdir "$dir"

  run tildepot --repo-dir "$dir" repo download --origin "my/repo"
  assert_success
  assert_mock_repo "$dir"
}

@test "creates new subdir for '--repo-dir'" {
  local dir="$BATS_TEST_TMPDIR/my-tildepot"

  run tildepot --repo-dir "$dir" repo download --origin "my/repo"
  assert_success
  assert_mock_repo "$dir"
}
@test "aborts when '--repo-dir' parent dir does not exist" {
  local dir="$BATS_TEST_TMPDIR/does-not-exist/my-tildepot"

  run tildepot repo download --origin "my/repo" --repo-dir "$dir"
  assert_failure
  assert_output --partial "does not exist"
}

@test "aborts when '--repo-dir' is not empty" {
  local dir="$BATS_TEST_TMPDIR/my-dir"
  test::put "$dir/foobar"

  run tildepot repo download --origin "my/repo" --repo-dir "$dir"
  assert_failure
  assert_output --partial "is not empty"
}

@test "prompts for origin without '--repo'" {
  # For some reason this test is flaky on GitHub Actions.
  export BATS_TEST_RETRIES=4

  local dir="$BATS_TEST_TMPDIR/my-tildepot"

  run test::expect_prompt \
    --prompt "Repository origin:" "some/repository" \
    tildepot repo download --repo-dir "$dir"
  assert_success
  assert_repo "$dir"
  test::assert_git_origin_url "$dir" "https://github.com/some/repository.git"
}
