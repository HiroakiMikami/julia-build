#!/usr/bin/env bats

load test_helper
export JULIA_BUILD_SKIP_MIRROR=1
export JULIA_BUILD_CACHE_PATH=
export JULIA_BUILD_ARIA2_OPTS=

setup() {
  ensure_not_found_in_path aria2c
  export JULIA_BUILD_BUILD_PATH="${TMP}/source"
  mkdir -p "${JULIA_BUILD_BUILD_PATH}"
}

@test "failed download displays error message" {
  stub curl false

  install_fixture definitions/without-checksum
  assert_failure
  assert_output_contains "> http://example.com/packages/package-1.0.0.tar.gz"
  assert_output_contains "error: failed to download package-1.0.0.tar.gz"
}

@test "using aria2c if available" {
  stub aria2c "--allow-overwrite=true --no-conf=true -o * http://example.com/* : cp $FIXTURE_ROOT/\${5##*/} \$4"

  install_fixture definitions/without-checksum
  assert_success
  assert_output <<OUT
Downloading package-1.0.0.tar.gz...
-> http://example.com/packages/package-1.0.0.tar.gz
Installing package-1.0.0...
Installed package-1.0.0 to ${TMP}/install
OUT
  unstub aria2c
}

@test "fetching from git repository" {
  stub git "clone --depth 1 --branch master http://example.com/packages/package.git package-dev : mkdir package-dev"

  run_inline_definition <<DEF
install_git "package-dev" "http://example.com/packages/package.git" master copy
DEF
  assert_success
  assert_output <<OUT
Cloning http://example.com/packages/package.git...
Installing package-dev...
Installed package-dev to ${TMP}/install
OUT
  unstub git
}

@test "updating existing git repository" {
  mkdir -p "${JULIA_BUILD_BUILD_PATH}/package-dev"
  stub git \
    "fetch --depth 1 origin +master : true" \
    "checkout -q -B master origin/master : true"

  run_inline_definition <<DEF
install_git "package-dev" "http://example.com/packages/package.git" master copy
DEF
  assert_success
  assert_output <<OUT
Cloning http://example.com/packages/package.git...
Installing package-dev...
Installed package-dev to ${TMP}/install
OUT
  unstub git
}
