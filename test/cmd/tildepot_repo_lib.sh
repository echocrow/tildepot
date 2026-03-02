#!/usr/bin/env bash
#
# Bats helpers for tildepot repo command tests

function test_repo::mock_fetch_releases() {
  local refs=''
  local ref
  for ref in "$@"; do
    [[ $ref ]] && refs+="\"$ref\","
  done
  refs="${refs%,}"
  test::mock_download "{\"refs\": [$refs]}"
}
