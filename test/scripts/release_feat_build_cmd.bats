#!/usr/bin/env bats
#
# Tests for `release` script (build command)

setup() {
  load release_lib.sh
}

teardown() {
  test::release_lib_teardown

  unset -f my_build_cmd
}

@test "skips build command on non-release" {
  # shellcheck disable=SC2317
  function my_build_cmd() {
    echo "[TEST] build command"
    echo '1' >>"$BATS_TEST_TMPDIR/my_build.txt"
  }
  export -f my_build_cmd
  test::extend_cfg '.packages[0].buildCommand' 'my_build_cmd'

  run release
  assert_success
  refute_line --partial "Running build command"
  refute_line "[TEST] build command"
  assert_file_not_exist "$BATS_TEST_TMPDIR/my_build.txt"
}

@test "skips empty build command" {
  test::extend_cfg '.packages[0].buildCommand' ''

  test::git_commit -m "feat(foo): my title"

  run release
  assert_success
  refute_line --partial "Running build command"
}

@test "runs build command once on release" {
  # shellcheck disable=SC2317
  function my_build_cmd() {
    echo "[TEST] build command"
    echo '1' >>"$BATS_TEST_TMPDIR/my_build.txt"
  }
  export -f my_build_cmd
  test::extend_cfg '.packages[0].buildCommand' 'my_build_cmd'
  echo '1' >"$BATS_TEST_TMPDIR/my_build_want.txt"

  test::git_commit -m "feat(foo): my title"

  run release
  assert_success
  assert_line --partial "Running build command"
  assert_line "[TEST] build command"
  assert_line --partial "Completed build command"

  test::it "only called the command once"
  assert_files_equal "$BATS_TEST_TMPDIR/my_build.txt" "$BATS_TEST_TMPDIR/my_build_want.txt"
}

@test "runs multi-args build command" {
  # shellcheck disable=SC2317
  function my_build_cmd() {
    local my_arg1="$1"
    local my_arg2="$2"
    echo "[TEST] build command; args: [$my_arg1] [$my_arg2]"
  }
  export -f my_build_cmd
  test::extend_cfg '.packages[0].buildCommand' 'my_build_cmd foo bar'

  test::git_commit -m "feat(foo): my title"

  run release
  assert_success
  assert_line "[TEST] build command; args: [foo] [bar]"
  assert_line --partial "Completed build command"
}

@test "aborts on invalid build command" {
  test::extend_cfg '.packages[0].buildCommand' 'my_invalid_build_cmd'

  test::git_commit -m "feat(foo): my title"

  # Require min version to support `run -127`.
  bats_require_minimum_version 1.5.0

  run -127 release
  assert_failure
  assert_line --partial "Running build command"
  refute_line --partial "Completed build command"
}

@test "aborts on failed build command" {
  # shellcheck disable=SC2317
  function my_build_cmd() {
    exit 1
  }
  export -f my_build_cmd
  test::extend_cfg '.packages[0].buildCommand' 'my_build_cmd'

  test::git_commit -m "feat(foo): my title"

  run release
  assert_failure
  assert_line --partial "Running build command"
  refute_line --partial "Completed build command"
}

@test "runs build command in strict mode" {
  # shellcheck disable=SC2317
  function my_build_cmd() {
    false
    echo '[TEST] late exec'
  }
  export -f my_build_cmd
  test::extend_cfg '.packages[0].buildCommand' 'my_build_cmd'

  test::git_commit -m "feat(foo): my title"

  run release
  assert_failure
  assert_line --partial "Running build command"
  refute_line --partial "[TEST] follow-up exec"
  refute_line --partial "[TEST] late exec"
  refute_line --partial "Completed build command"
}

@test "sets RELEASE_VERSION env var to next release version" {
  # shellcheck disable=SC2317
  function my_build_cmd() {
    local version="${RELEASE_VERSION:-}"
    echo "[TEST] build command; version: [$version]"
  }
  export -f my_build_cmd
  test::extend_cfg '.packages[0].buildCommand' 'my_build_cmd'

  test::git_commit -m "feat(foo): prev release"
  git tag -a 'foo@2.2.2' -m ''
  test::git_commit -m "feat(foo): my feat"

  run release
  assert_success
  assert_line "[TEST] build command; version: [2.3.0]"
}
