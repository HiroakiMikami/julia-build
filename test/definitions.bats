#!/usr/bin/env bats

load test_helper
NUM_DEFINITIONS="$(ls "$BATS_TEST_DIRNAME"/../share/julia-build | wc -l)"

@test "list built-in definitions" {
  run julia-build --definitions
  assert_success
  assert_output_contains "v0.6.0"
  assert_output_contains "v0.6.0-rc1"
  assert [ "${#lines[*]}" -eq "$NUM_DEFINITIONS" ]
}

@test "custom JULIA_BUILD_ROOT: nonexistent" {
  export JULIA_BUILD_ROOT="$TMP"
  refute [ -e "${JULIA_BUILD_ROOT}/share/julia-build" ]
  run julia-build --definitions
  assert_success ""
}

@test "custom JULIA_BUILD_ROOT: single definition" {
  export JULIA_BUILD_ROOT="$TMP"
  mkdir -p "${JULIA_BUILD_ROOT}/share/julia-build"
  touch "${JULIA_BUILD_ROOT}/share/julia-build/1.9.3-test"
  run julia-build --definitions
  assert_success "1.9.3-test"
}

@test "one path via JULIA_BUILD_DEFINITIONS" {
  export JULIA_BUILD_DEFINITIONS="${TMP}/definitions"
  mkdir -p "$JULIA_BUILD_DEFINITIONS"
  touch "${JULIA_BUILD_DEFINITIONS}/1.9.3-test"
  run julia-build --definitions
  assert_success
  assert_output_contains "1.9.3-test"
  assert [ "${#lines[*]}" -eq "$((NUM_DEFINITIONS + 1))" ]
}

@test "multiple paths via JULIA_BUILD_DEFINITIONS" {
  export JULIA_BUILD_DEFINITIONS="${TMP}/definitions:${TMP}/other"
  mkdir -p "${TMP}/definitions"
  touch "${TMP}/definitions/1.9.3-test"
  mkdir -p "${TMP}/other"
  touch "${TMP}/other/2.1.2-test"
  run julia-build --definitions
  assert_success
  assert_output_contains "1.9.3-test"
  assert_output_contains "2.1.2-test"
  assert [ "${#lines[*]}" -eq "$((NUM_DEFINITIONS + 2))" ]
}

@test "installing definition from JULIA_BUILD_DEFINITIONS by priority" {
  export JULIA_BUILD_DEFINITIONS="${TMP}/definitions:${TMP}/other"
  mkdir -p "${TMP}/definitions"
  echo true > "${TMP}/definitions/1.9.3-test"
  mkdir -p "${TMP}/other"
  echo false > "${TMP}/other/1.9.3-test"
  run bin/julia-build "1.9.3-test" "${TMP}/install"
  assert_success ""
}

@test "installing nonexistent definition" {
  run julia-build "nonexistent" "${TMP}/install"
  assert [ "$status" -eq 2 ]
  assert_output "julia-build: definition not found: nonexistent"
}

@test "sorting Julia versions" {
  export JULIA_BUILD_ROOT="$TMP"
  mkdir -p "${JULIA_BUILD_ROOT}/share/julia-build"
  expected="1.8.7
1.8.7-p72
1.8.7-p375
1.9.3-dev
1.9.3-preview1
1.9.3-rc1
1.9.3-p0
1.9.3-p125
2.1.0-dev
2.1.0-rc1
2.1.0
2.1.1
2.2.0-dev
jjulia-1.6.5
jjulia-1.6.5.1
jjulia-1.7.0-preview1
jjulia-1.7.0-rc1
jjulia-1.7.0
jjulia-1.7.1
jjulia-1.7.9
jjulia-1.7.10
jjulia-9000-dev
jjulia-9000"
  for ver in $expected; do
    touch "${JULIA_BUILD_ROOT}/share/julia-build/$ver"
  done
  run julia-build --definitions
  assert_success "$expected"
}

@test "removing duplicate Julia versions" {
  export JULIA_BUILD_ROOT="$TMP"
  export JULIA_BUILD_DEFINITIONS="${JULIA_BUILD_ROOT}/share/julia-build"
  mkdir -p "$JULIA_BUILD_DEFINITIONS"
  touch "${JULIA_BUILD_DEFINITIONS}/1.9.3"
  touch "${JULIA_BUILD_DEFINITIONS}/2.2.0"

  run julia-build --definitions
  assert_success
  assert_output <<OUT
1.9.3
2.2.0
OUT
}
