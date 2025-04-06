#!/usr/bin/env bats
#
# Tests for `tildepot self`

setup() {
  load ../test_lib.sh
}

@test "describes command" {
  test::test_cmd self
}
