#!/usr/bin/env bats
#
# Tests for `tildepot self`

setup() {
  load ../test_lib.sh
}

@test "describes command" {
  lib::test_cmd self
}
