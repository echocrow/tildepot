#!/usr/bin/env bats
#
# Tests for `tildepot` bundles: SUPER functions
#
# These tests use the `install` hook as stand-in for all hook commands. The same
# tests are assumed to also pass for all other hook commands.

setup() {
  load ../../test_lib.sh
  load ./tildepot_hook_lib.sh
}

###
# Test SKIP
###

@test "runs parent SKIP (returning 1) and runs bundle" {
  test::mock_bundle parent "$TILDEPOT_HOME" "
    function SKIP() {
      echo '[TEST] PARENT SKIP' >&2
      return 1
    }
  "
  test::mock_bundle child "
    EXTEND='../parent.sh'
    function SKIP() {
      echo '[TEST] CHILD SKIP' >&2
      SUPER
    }
    $(test::mock_hook_fn install)
  "

  run tildepot install
  assert_success
  test::assert_bundle_output \
    "[TEST] CHILD SKIP" \
    "[TEST] PARENT SKIP" \
    --hook child install
}
@test "runs parent SKIP (returning 0) and skips bundle" {
  test::mock_bundle parent "$TILDEPOT_HOME" "
    function SKIP() {
      echo '[TEST] PARENT SKIP' >&2
      return 0
    }
  "
  test::mock_bundle child "
    EXTEND='../parent.sh'
    function SKIP() {
      echo '[TEST] CHILD SKIP' >&2
      SUPER
    }
    $(test::mock_hook_fn install)
  "

  run tildepot install
  assert_success
  test::assert_bundle_output \
    "[TEST] CHILD SKIP" \
    "[TEST] PARENT SKIP" \
    --skip child
}
@test "runs parent SKIP (echoing reason) and skips bundle" {
  test::mock_bundle parent "$TILDEPOT_HOME" "
    function SKIP() {
      echo '[TEST] PARENT SKIP' >&2
      echo 'mock reason'
    }
  "
  test::mock_bundle child "
    EXTEND='../parent.sh'
    function SKIP() {
      echo '[TEST] CHILD SKIP' >&2
      SUPER
    }
    $(test::mock_hook_fn install)
  "

  run tildepot install
  assert_success
  test::assert_bundle_output \
    "[TEST] CHILD SKIP" \
    "[TEST] PARENT SKIP" \
    --skip child \
    --skip-reason "mock reason"
}

@test "runs chained SKIPs" {
  test::mock_bundle top "$TILDEPOT_HOME" "
    function SKIP() {
      echo '[TEST] TOP SKIP' >&2
      return 1
    }
  "
  test::mock_bundle middle "$TILDEPOT_HOME" "
    EXTEND='./top.sh'
    function SKIP() {
      echo '[TEST] MIDDLE SKIP' >&2
      SUPER
    }
  "
  test::mock_bundle bottom "
    EXTEND='../middle.sh'
    function SKIP() {
      echo '[TEST] BOTTOM SKIP' >&2
      SUPER
    }
    $(test::mock_hook_fn install)
  "

  run tildepot install
  assert_success
  test::assert_bundle_output \
    "[TEST] BOTTOM SKIP" \
    "[TEST] MIDDLE SKIP" \
    "[TEST] TOP SKIP" \
    --hook bottom install
}

@test "runs parent's parent SKIP" {
  test::mock_bundle top "$TILDEPOT_HOME" "
    function SKIP() {
      echo '[TEST] TOP SKIP' >&2
      return 1
    }
  "
  test::mock_bundle middle "$TILDEPOT_HOME" "
    EXTEND='./top.sh'
  "
  test::mock_bundle bottom "
    EXTEND='../middle.sh'
    function SKIP() {
      echo '[TEST] BOTTOM SKIP' >&2
      SUPER
    }
    $(test::mock_hook_fn install)
  "

  run tildepot install
  assert_success
  test::assert_bundle_output \
    "[TEST] BOTTOM SKIP" \
    "[TEST] TOP SKIP" \
    --hook bottom install
}

@test "runs inherited parent SKIP (returning 1) and runs bundle" {
  test::mock_bundle top "$TILDEPOT_HOME" "
    function SKIP() {
      echo '[TEST] TOP SKIP' >&2
      return 1
    }
  "
  test::mock_bundle middle "$TILDEPOT_HOME" "
    EXTEND='./top.sh'
    function SKIP() {
      echo '[TEST] MIDDLE SKIP' >&2
      SUPER
    }
  "
  test::mock_bundle bottom "
    EXTEND='../middle.sh'
    $(test::mock_hook_fn install)
  "

  run tildepot install
  assert_success
  test::assert_bundle_output \
    "[TEST] MIDDLE SKIP" \
    "[TEST] TOP SKIP" \
    --hook bottom install
}
@test "runs inherited parent SKIP (returning 0) and skips bundle" {
  test::mock_bundle top "$TILDEPOT_HOME" "
    function SKIP() {
      echo '[TEST] TOP SKIP' >&2
      return 0
    }
  "
  test::mock_bundle middle "$TILDEPOT_HOME" "
    EXTEND='./top.sh'
    function SKIP() {
      echo '[TEST] MIDDLE SKIP' >&2
      SUPER
    }
  "
  test::mock_bundle bottom "
    EXTEND='../middle.sh'
    $(test::mock_hook_fn install)
  "

  run tildepot install
  assert_success
  test::assert_bundle_output \
    "[TEST] MIDDLE SKIP" \
    "[TEST] TOP SKIP" \
    --skip bottom
}

###
# Test ${HOOK}_SKIP
###

@test "runs parent HOOK_SKIP (returning 1) and runs hook" {
  test::mock_bundle parent "$TILDEPOT_HOME" "
    function INSTALL_SKIP() {
      echo '[TEST] PARENT SKIP' >&2
      return 1
    }
  "
  test::mock_bundle child "
    EXTEND='../parent.sh'
    function INSTALL_SKIP() {
      echo '[TEST] CHILD SKIP' >&2
      SUPER
    }
    $(test::mock_hook_fn install)
  "

  run tildepot install
  assert_success
  test::assert_bundle_output \
    "[TEST] CHILD SKIP" \
    "[TEST] PARENT SKIP" \
    --hook child install
}
@test "runs parent HOOK_SKIP (returning 0) and skips hook" {
  test::mock_bundle parent "$TILDEPOT_HOME" "
    function INSTALL_SKIP() {
      echo '[TEST] PARENT SKIP' >&2
      return 0
    }
  "
  test::mock_bundle child "
    EXTEND='../parent.sh'
    function INSTALL_SKIP() {
      echo '[TEST] CHILD SKIP' >&2
      SUPER
    }
    $(test::mock_hook_fn install)
  "

  run tildepot install
  assert_success
  test::assert_bundle_output \
    "[TEST] CHILD SKIP" \
    "[TEST] PARENT SKIP" \
    --hook-skip child install
}
@test "runs parent HOOK_SKIP (echoing reason) and skips hook" {
  test::mock_bundle parent "$TILDEPOT_HOME" "
    function INSTALL_SKIP() {
      echo '[TEST] PARENT SKIP' >&2
      echo 'mock reason'
    }
  "
  test::mock_bundle child "
    EXTEND='../parent.sh'
    function INSTALL_SKIP() {
      echo '[TEST] CHILD SKIP' >&2
      SUPER
    }
    $(test::mock_hook_fn install)
  "

  run tildepot install
  assert_success
  test::assert_bundle_output \
    "[TEST] CHILD SKIP" \
    "[TEST] PARENT SKIP" \
    --hook-skip child install \
    --skip-reason "mock reason"
}

@test "runs chained HOOK_SKIPs" {
  test::mock_bundle top "$TILDEPOT_HOME" "
    function INSTALL_SKIP() {
      echo '[TEST] TOP SKIP' >&2
      return 1
    }
  "
  test::mock_bundle middle "$TILDEPOT_HOME" "
    EXTEND='./top.sh'
    function INSTALL_SKIP() {
      echo '[TEST] MIDDLE SKIP' >&2
      SUPER
    }
  "
  test::mock_bundle bottom "
    EXTEND='../middle.sh'
    function INSTALL_SKIP() {
      echo '[TEST] BOTTOM SKIP' >&2
      SUPER
    }
    $(test::mock_hook_fn install)
  "

  run tildepot install
  assert_success
  test::assert_bundle_output \
    "[TEST] BOTTOM SKIP" \
    "[TEST] MIDDLE SKIP" \
    "[TEST] TOP SKIP" \
    --hook bottom install
}

@test "runs parent's parent HOOK_SKIP" {
  test::mock_bundle top "$TILDEPOT_HOME" "
    function INSTALL_SKIP() {
      echo '[TEST] TOP SKIP' >&2
      return 1
    }
  "
  test::mock_bundle middle "$TILDEPOT_HOME" "
    EXTEND='./top.sh'
  "
  test::mock_bundle bottom "
    EXTEND='../middle.sh'
    function INSTALL_SKIP() {
      echo '[TEST] BOTTOM SKIP' >&2
      SUPER
    }
    $(test::mock_hook_fn install)
  "

  run tildepot install
  assert_success
  test::assert_bundle_output \
    "[TEST] BOTTOM SKIP" \
    "[TEST] TOP SKIP" \
    --hook bottom install
}

@test "runs inherited parent HOOK_SKIP (returning 1) and runs hook" {
  test::mock_bundle top "$TILDEPOT_HOME" "
    function INSTALL_SKIP() {
      echo '[TEST] TOP SKIP' >&2
      return 1
    }
  "
  test::mock_bundle middle "$TILDEPOT_HOME" "
    EXTEND='./top.sh'
    function INSTALL_SKIP() {
      echo '[TEST] MIDDLE SKIP' >&2
      SUPER
    }
  "
  test::mock_bundle bottom "
    EXTEND='../middle.sh'
    $(test::mock_hook_fn install)
  "

  run tildepot install
  assert_success
  test::assert_bundle_output \
    "[TEST] MIDDLE SKIP" \
    "[TEST] TOP SKIP" \
    --hook bottom install
}
@test "runs inherited parent HOOK_SKIP (returning 0) and skips hook" {
  test::mock_bundle top "$TILDEPOT_HOME" "
    function INSTALL_SKIP() {
      echo '[TEST] TOP SKIP' >&2
      return 0
    }
  "
  test::mock_bundle middle "$TILDEPOT_HOME" "
    EXTEND='./top.sh'
    function INSTALL_SKIP() {
      echo '[TEST] MIDDLE SKIP' >&2
      SUPER
    }
  "
  test::mock_bundle bottom "
    EXTEND='../middle.sh'
    $(test::mock_hook_fn install)
  "

  run tildepot install
  assert_success
  test::assert_bundle_output \
    "[TEST] MIDDLE SKIP" \
    "[TEST] TOP SKIP" \
    --hook-skip bottom install
}

###
# Test ${HOOK}
###

@test "runs parent HOOK" {
  test::mock_bundle parent "$TILDEPOT_HOME" "
    function INSTALL() {
      echo '[TEST] PARENT HOOK' >&2
    }
  "
  test::mock_bundle child "
    EXTEND='../parent.sh'
    function INSTALL() {
      SUPER
      echo '[TEST] CHILD HOOK' >&2
    }
  "

  run tildepot install
  assert_success
  test::assert_bundle_output \
    --hook-run child install \
    "[TEST] PARENT HOOK" \
    "[TEST] CHILD HOOK"
}

@test "runs chained HOOKs" {
  test::mock_bundle top "$TILDEPOT_HOME" "
    function INSTALL() {
      echo '[TEST] TOP HOOK' >&2
    }
  "
  test::mock_bundle middle "$TILDEPOT_HOME" "
    EXTEND='./top.sh'
    function INSTALL() {
      SUPER
      echo '[TEST] MIDDLE HOOK' >&2
    }
  "
  test::mock_bundle bottom "
    EXTEND='../middle.sh'
    function INSTALL() {
      SUPER
      echo '[TEST] BOTTOM HOOK' >&2
    }
  "

  run tildepot install
  assert_success
  test::assert_bundle_output \
    --hook-run bottom install \
    "[TEST] TOP HOOK" \
    "[TEST] MIDDLE HOOK" \
    "[TEST] BOTTOM HOOK"
}

@test "runs parent's parent HOOK" {
  test::mock_bundle top "$TILDEPOT_HOME" "
    function INSTALL() {
      echo '[TEST] TOP HOOK' >&2
    }
  "
  test::mock_bundle middle "$TILDEPOT_HOME" "
    EXTEND='./top.sh'
  "
  test::mock_bundle bottom "
    EXTEND='../middle.sh'
    function INSTALL() {
      SUPER
      echo '[TEST] BOTTOM HOOK' >&2
    }
  "

  run tildepot install
  assert_success
  test::assert_bundle_output \
    --hook-run bottom install \
    "[TEST] TOP HOOK" \
    "[TEST] BOTTOM HOOK"
}

@test "runs inherited parent HOOK" {
  test::mock_bundle top "$TILDEPOT_HOME" "
    function INSTALL() {
      echo '[TEST] TOP HOOK' >&2
    }
  "
  test::mock_bundle middle "$TILDEPOT_HOME" "
    EXTEND='./top.sh'
    function INSTALL() {
      SUPER
      echo '[TEST] MIDDLE HOOK' >&2
    }
  "
  test::mock_bundle bottom "
    EXTEND='../middle.sh'
  "

  run tildepot install
  assert_success
  test::assert_bundle_output \
    --hook-run bottom install \
    "[TEST] TOP HOOK" \
    "[TEST] MIDDLE HOOK"
}

###
# Test miscellaneous
###

@test "calls correct SUPER function based on current function" {
  test::mock_bundle top "$TILDEPOT_HOME" "
    function SKIP() {
      echo '[TEST] TOP SKIP' >&2
    }
    function INSTALL_SKIP() {
      echo '[TEST] TOP HOOK_SKIP' >&2
    }
    function INSTALL() {
      echo '[TEST] TOP HOOK' >&2
    }
  "
  test::mock_bundle middle "$TILDEPOT_HOME" "
    EXTEND='./top.sh'
    function SKIP() {
      SUPER
      echo '[TEST] MIDDLE SKIP' >&2
    }
    function INSTALL_SKIP() {
      SUPER
      echo '[TEST] MIDDLE HOOK_SKIP' >&2
    }
    function INSTALL() {
      SUPER
      echo '[TEST] MIDDLE HOOK' >&2
    }
  "
  test::mock_bundle bottom "
    EXTEND='../middle.sh'
    function SKIP() {
      SUPER
      echo '[TEST] BOTTOM SKIP' >&2
      [[ 0 -eq 1 ]] && echo 'mock reason'
    }
    function INSTALL_SKIP() {
      SUPER
      echo '[TEST] BOTTOM HOOK_SKIP' >&2
      [[ 0 -eq 1 ]] && echo 'mock reason'
    }
    function INSTALL() {
      SUPER
      echo '[TEST] BOTTOM HOOK' >&2
    }
  "

  run tildepot install
  assert_success
  test::assert_bundle_output \
    "[TEST] TOP SKIP" \
    "[TEST] MIDDLE SKIP" \
    "[TEST] BOTTOM SKIP" \
    "[TEST] TOP HOOK_SKIP" \
    "[TEST] MIDDLE HOOK_SKIP" \
    "[TEST] BOTTOM HOOK_SKIP" \
    --hook-run bottom install \
    "[TEST] TOP HOOK" \
    "[TEST] MIDDLE HOOK" \
    "[TEST] BOTTOM HOOK"
}
