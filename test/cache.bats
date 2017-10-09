#!/usr/bin/env bats

load test_helper
export JULIA_BUILD_SKIP_MIRROR=1
export JULIA_BUILD_CACHE_PATH="$TMP/cache"
export JULIA_BUILD_CURL_OPTS=

setup() {
  ensure_not_found_in_path aria2c
  mkdir "$JULIA_BUILD_CACHE_PATH"
}


@test "packages are saved to download cache" {
  stub curl "-q -o * -*S* http://example.com/* : cp $FIXTURE_ROOT/\${5##*/} \$3"

  install_fixture definitions/without-checksum

  assert_success
  assert [ -e "${JULIA_BUILD_CACHE_PATH}/package-1.0.0.tar.gz" ]

  unstub curl
}


@test "cached package without checksum" {
  stub curl

  cp "${FIXTURE_ROOT}/package-1.0.0.tar.gz" "$JULIA_BUILD_CACHE_PATH"

  install_fixture definitions/without-checksum

  assert_success
  assert [ -e "${JULIA_BUILD_CACHE_PATH}/package-1.0.0.tar.gz" ]

  unstub curl
}


@test "cached package with valid checksum" {
  stub shasum true "echo ba988b1bb4250dee0b9dd3d4d722f9c64b2bacfc805d1b6eba7426bda72dd3c5"
  stub curl

  cp "${FIXTURE_ROOT}/package-1.0.0.tar.gz" "$JULIA_BUILD_CACHE_PATH"

  install_fixture definitions/with-checksum

  assert_success
  assert [ -x "${INSTALL_ROOT}/bin/package" ]
  assert [ -e "${JULIA_BUILD_CACHE_PATH}/package-1.0.0.tar.gz" ]

  unstub curl
  unstub shasum
}


@test "cached package with invalid checksum falls back to mirror and updates cache" {
  export JULIA_BUILD_SKIP_MIRROR=
  local checksum="ba988b1bb4250dee0b9dd3d4d722f9c64b2bacfc805d1b6eba7426bda72dd3c5"

  stub shasum true "echo invalid" "echo $checksum"
  stub curl "-*I* : true" \
    "-q -o * -*S* https://?*/$checksum : cp $FIXTURE_ROOT/package-1.0.0.tar.gz \$3"

  touch "${JULIA_BUILD_CACHE_PATH}/package-1.0.0.tar.gz"

  install_fixture definitions/with-checksum

  assert_success
  assert [ -x "${INSTALL_ROOT}/bin/package" ]
  assert [ -e "${JULIA_BUILD_CACHE_PATH}/package-1.0.0.tar.gz" ]
  assert diff -q "${JULIA_BUILD_CACHE_PATH}/package-1.0.0.tar.gz" "${FIXTURE_ROOT}/package-1.0.0.tar.gz"

  unstub curl
  unstub shasum
}


@test "nonexistent cache directory is ignored" {
  stub curl "-q -o * -*S* http://example.com/* : cp $FIXTURE_ROOT/\${5##*/} \$3"

  export JULIA_BUILD_CACHE_PATH="${TMP}/nonexistent"

  install_fixture definitions/without-checksum

  assert_success
  assert [ -x "${INSTALL_ROOT}/bin/package" ]
  refute [ -d "$JULIA_BUILD_CACHE_PATH" ]

  unstub curl
}
