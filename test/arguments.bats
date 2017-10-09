#!/usr/bin/env bats

load test_helper

@test "not enough arguments for julia-build" {
  # use empty inline definition so nothing gets built anyway
  local definition="${TMP}/build-definition"
  echo '' > "$definition"

  run julia-build "$definition"
  assert_failure
  assert_output_contains 'Usage: julia-build'
}

@test "extra arguments for julia-build" {
  # use empty inline definition so nothing gets built anyway
  local definition="${TMP}/build-definition"
  echo '' > "$definition"

  run julia-build "$definition" "${TMP}/install" ""
  assert_failure
  assert_output_contains 'Usage: julia-build'
}
