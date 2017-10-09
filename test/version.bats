#!/usr/bin/env bats

load test_helper

bats_bin="${BATS_TEST_DIRNAME}/../bin/julia-build"
static_version="$(grep VERSION "$bats_bin" | head -1 | cut -d'"' -f 2)"

@test "julia-build static version" {
  stub git 'echo "ASPLODE" >&2; exit 1'
  run julia-build --version
  assert_success "julia-build ${static_version}"
  unstub git
}

@test "julia-build git version" {
  stub git \
    'remote -v : echo origin https://github.com/jlenv/julia-build.git' \
    "describe --tags HEAD : echo v1984-12-gSHA"
  run julia-build --version
  assert_success "julia-build 1984-12-gSHA"
  unstub git
}

@test "git describe fails" {
  stub git \
    'remote -v : echo origin https://github.com/jlenv/julia-build.git' \
    "describe --tags HEAD : echo ASPLODE >&2; exit 1"
  run julia-build --version
  assert_success "julia-build ${static_version}"
  unstub git
}

@test "git remote doesn't match" {
  stub git \
    'remote -v : echo origin https://github.com/Homebrew/homebrew.git' \
    "describe --tags HEAD : echo v1984-12-gSHA"
  run julia-build --version
  assert_success "julia-build ${static_version}"
}
