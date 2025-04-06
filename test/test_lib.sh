#!/usr/bin/env bash
#
# Bats test helpers

# Setup
bats_load_library bats-support
bats_load_library bats-assert
bats_load_library bats-file
# Add tildepot to PATH
PATH="$BATS_CWD/dist:$PATH"
