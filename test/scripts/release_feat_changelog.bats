#!/usr/bin/env bats
#
# Tests for `release` script (changelog)

setup() {
  load release_lib.sh
}

teardown() {
  test::release_lib_teardown
}

function assert_changelog() {
  local pkg=""
  local want=""
  case $# in
  1)
    pkg="foo"
    want="$1"
    ;;
  2)
    pkg="$1"
    want="$2"
    ;;
  *) lib::abort "Invalid number of arguments: [$#]" ;;
  esac

  local changelog_path="$TEST_RELEASE_DIST_DIR/${pkg}/CHANGELOG.md"

  if [[ -z $want ]]; then
    test::it "does not have changelog for [$pkg]"
    assert_not_exists "$changelog_path"
    return
  fi

  # Dedent `want`:
  want="${want#$'\n'}"                  # Remove leading newline
  local indent="${want%%[![:space:]]*}" # Determine indent based on first line
  want=$'\n'"$want"                     # Re-prepend newline
  want="${want//$'\n'$indent/$'\n'}"    # Remove indent from lines
  want="${want#$'\n'}"                  # Re-remove leading newline
  want="${want%"${want##*[! ]}"}"       # Remove trailing whitespace
  want="${want%$'\n'}"                  # Remove trailing newline

  test::it "has changelog for [$pkg]"

  assert_file_exist "$changelog_path"

  local got
  got="$(cat "$changelog_path" && echo 'EOF')"
  got="${got%$'\nEOF'}"
  got="${got%$'\n'}"
  assert_equal "$got" "$want"
}

function refute_changelog() {
  local pkg=""
  case $# in
  0) pkg="foo" ;;
  1) pkg="$1" ;;
  *) lib::abort "Invalid number of arguments: [$#]" ;;
  esac

  local changelog_path="$TEST_RELEASE_DIST_DIR/${pkg}/CHANGELOG.md"
  assert_file_not_exists "$changelog_path"
}

@test "skips changelog on non-release" {
  run release
  assert_success
  refute_changelog
}

@test "prints fixes" {
  local shas=()
  shas+=("$(test::git_commit_print -m "fix(foo): my title")")

  run release
  assert_success
  assert_changelog "
    ### Bug Fixes
    - **foo:** my title (${shas[0]})
  "
}
@test "prints performance improvements" {
  local shas=()
  shas+=("$(test::git_commit_print -m "perf(foo): some improvement")")

  run release
  assert_success
  assert_changelog "
    ### Performance Improvements
    - **foo:** some improvement (${shas[0]})
  "
}
@test "prints feature changes" {
  local shas=()
  shas+=("$(test::git_commit_print -m "feat(foo): some new bling")")

  run release
  assert_success
  assert_changelog "
    ### Features
    - **foo:** some new bling (${shas[0]})
  "
}
@test "prints breaking changes" {
  local shas=()
  shas+=("$(test::git_commit_print -m "feat!(foo): some major bling")")

  run release
  assert_success
  assert_changelog "
    ### BREAKING CHANGES
    - **foo:** some major bling (${shas[0]})
  "
}

@test "includes multiple changes in order" {
  local shas=()
  shas+=("$(test::git_commit_print -m "feat(foo): f01")")
  shas+=("$(test::git_commit_print -m "feat(foo): f02")")
  shas+=("$(test::git_commit_print -m "feat(foo): f03")")

  run release
  assert_success
  assert_changelog "
    ### Features
    - **foo:** f01 (${shas[0]})
    - **foo:** f02 (${shas[1]})
    - **foo:** f03 (${shas[2]})
  "
}

@test "excludes non-release commits" {
  local shas=()
  shas+=("$(test::git_commit_print -m "fix(foo): some fix")")
  shas+=("$(test::git_commit_print -m "chore(foo): internal change")")

  run release
  assert_success
  assert_changelog "
    ### Bug Fixes
    - **foo:** some fix (${shas[0]})
  "
}
@test "excludes out-of-scope commits" {
  local shas=()
  shas+=("$(test::git_commit_print -m "fix(foo): some fix")")
  shas+=("$(test::git_commit_print -m "fix(bar): another package")")

  run release
  assert_success
  assert_changelog "
    ### Bug Fixes
    - **foo:** some fix (${shas[0]})
  "
}

@test "groups changes and lists most significant types first" {
  local shas=()
  shas+=("$(test::git_commit_print -m "perf(foo): internal improvement a")")
  shas+=("$(test::git_commit_print -m "fix(foo): some fix a")")
  shas+=("$(test::git_commit_print -m "feat(foo): some feat a")")
  shas+=("$(test::git_commit_print -m "fix!(foo): breaking change a")")
  shas+=("$(test::git_commit_print -m "feat(foo): some feat b")")
  shas+=("$(test::git_commit_print -m "fix(foo): some fix b")")
  shas+=("$(test::git_commit_print -m "perf(foo): internal improvement b")")
  shas+=("$(test::git_commit_print -m "fix!(foo): breaking change b")")

  run release
  assert_success
  assert_changelog "
    ### BREAKING CHANGES
    - **foo:** breaking change a (${shas[3]})
    - **foo:** breaking change b (${shas[7]})

    ### Features
    - **foo:** some feat a (${shas[2]})
    - **foo:** some feat b (${shas[4]})

    ### Bug Fixes
    - **foo:** some fix a (${shas[1]})
    - **foo:** some fix b (${shas[5]})

    ### Performance Improvements
    - **foo:** internal improvement a (${shas[0]})
    - **foo:** internal improvement b (${shas[6]})
  "
}

@test "matches the correct commit scope to packages" {
  test::extend_cfg '{
    "packages": [
      {"name": "pkg-a"},
      {"name": "pkg-b"},
      {"name": "main", "scope": "!pkg-.*"}
    ]
  }'

  local shas=()
  shas+=("$(test::git_commit_print -m "feat(pkg-a): aa 01")")
  shas+=("$(test::git_commit_print -m "feat(pkg-b): bb 01")")
  shas+=("$(test::git_commit_print -m "feat(main): m 01")")
  shas+=("$(test::git_commit_print -m "feat(main): m 02")")
  shas+=("$(test::git_commit_print -m "feat(pkg-c): cc 01")")
  shas+=("$(test::git_commit_print -m "feat(pkg-a): aa 02")")

  run release
  assert_success
  assert_changelog 'pkg-a' "
    ### Features
    - **pkg-a:** aa 01 (${shas[0]})
    - **pkg-a:** aa 02 (${shas[5]})
  "
  assert_changelog 'pkg-b' "
    ### Features
    - **pkg-b:** bb 01 (${shas[1]})
  "
  assert_changelog 'main' "
    ### Features
    - **main:** m 01 (${shas[2]})
    - **main:** m 02 (${shas[3]})
  "
  refute_changelog 'pkg-c'
}

@test "uses breaking change description" {
  local shas=()
  shas+=("$(test::git_commit_print -m "feat!(foo): some major bling" -m "BREAKING CHANGE: my desc")")
  shas+=("$(test::git_commit_print -m "feat!(foo): more major bling" -m "my body" -m "BREAKING CHANGE: my explanation")")

  run release
  assert_success
  assert_changelog "
    ### BREAKING CHANGES
    - **foo:** my desc (${shas[0]})
    - **foo:** my explanation (${shas[1]})
  "
}
@test "uses only the first line from breaking change description" {
  local shas=()
  shas+=("$(test::git_commit_print -m "feat!(foo): title" -m "BREAKING CHANGE: my desc" -m "my footer")")

  run release
  assert_success
  assert_changelog "
    ### BREAKING CHANGES
    - **foo:** my desc (${shas[0]})
  "
}

@test "honors custom commit type titles" {
  test::extend_cfg '{
    "commits_types": {
      "patch": {"fizz": "Fizz", "buzz": "Buzz"},
      "minor": {}
    }
  }'

  local shas=()
  shas+=("$(test::git_commit_print -m "buzz(foo): msg 00")")
  shas+=("$(test::git_commit_print -m "fizz(foo): msg 01")")
  shas+=("$(test::git_commit_print -m "foo(foo): msg 02")")
  shas+=("$(test::git_commit_print -m "fizz(foo): msg 03")")
  shas+=("$(test::git_commit_print -m "feat(foo): msg 04")")

  run release
  assert_success
  assert_changelog "
    ### Fizz
    - **foo:** msg 01 (${shas[1]})
    - **foo:** msg 03 (${shas[3]})

    ### Buzz
    - **foo:** msg 00 (${shas[0]})
  "
}
