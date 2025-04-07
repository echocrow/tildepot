#!/usr/bin/env bats
#
# Tests for `tildepot repo`

setup() {
  load ../test_lib.sh
}

@test "describes command" {
  test::test_cmd repo
}
