#!/usr/bin/env bats

load test_helper

@test "installs julia-build into PREFIX" {
  cd "$TMP"
  PREFIX="${PWD}/usr" run "${BATS_TEST_DIRNAME}/../install.sh"
  assert_success ""

  cd usr

  assert [ -x bin/julia-build ]
  assert [ -x bin/jlenv-install ]
  assert [ -x bin/jlenv-uninstall ]

  assert [ -e share/julia-build/v0.6.0 ]
}

@test "build definitions don't have the executable bit" {
  cd "$TMP"
  PREFIX="${PWD}/usr" run "${BATS_TEST_DIRNAME}/../install.sh"
  assert_success ""

  run $BASH -c 'ls -l usr/share/julia-build | tail -2 | cut -c1-10'
  assert_output <<OUT
-rw-r--r--
-rw-r--r--
OUT
}

@test "overwrites old installation" {
  cd "$TMP"
  mkdir -p bin share/julia-build
  touch bin/julia-build
  touch share/julia-build/v0.6.0

  PREFIX="$PWD" run "${BATS_TEST_DIRNAME}/../install.sh"
  assert_success ""

  assert [ -x bin/julia-build ]
  run grep "install_git" share/julia-build/v0.6.0
  assert_success
}

@test "unrelated files are untouched" {
  cd "$TMP"
  mkdir -p bin share/bananas
  chmod g-w bin
  touch bin/bananas
  touch share/bananas/docs

  PREFIX="$PWD" run "${BATS_TEST_DIRNAME}/../install.sh"
  assert_success ""

  assert [ -e bin/bananas ]
  assert [ -e share/bananas/docs ]

  run ls -ld bin
  assert_equal "r-x" "${output:4:3}"
}
