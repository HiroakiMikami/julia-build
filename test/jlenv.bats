#!/usr/bin/env bats

load test_helper
export JLENV_ROOT="${TMP}/jlenv"

setup() {
  stub jlenv-hooks 'install : true'
  stub jlenv-rehash 'true'
}

stub_julia_build() {
  stub julia-build "--lib : $BATS_TEST_DIRNAME/../bin/julia-build --lib" "$@"
}

@test "install proper" {
  stub_julia_build 'echo julia-build "$@"'

  run jlenv-install 2.1.2
  assert_success "julia-build 2.1.2 ${JLENV_ROOT}/versions/2.1.2"

  unstub julia-build
  unstub jlenv-hooks
  unstub jlenv-rehash
}

@test "install jlenv local version by default" {
  stub_julia_build 'echo julia-build "$1"'
  stub jlenv-local 'echo 2.1.2'

  run jlenv-install
  assert_success "julia-build 2.1.2"

  unstub julia-build
  unstub jlenv-local
}

@test "list available versions" {
  stub_julia_build \
    "--definitions : echo 1.8.7 1.9.3-p0 1.9.3-p194 2.1.2 | tr ' ' $'\\n'"

  run jlenv-install --list
  assert_success
  assert_output <<OUT
Available versions:
  1.8.7
  1.9.3-p0
  1.9.3-p194
  2.1.2
OUT

  unstub julia-build
}

@test "nonexistent version" {
  stub brew false
  stub_julia_build 'echo ERROR >&2 && exit 2' \
    "--definitions : echo 1.8.7 1.9.3-p0 1.9.3-p194 2.1.2 | tr ' ' $'\\n'"

  run jlenv-install 1.9.3
  assert_failure
  assert_output <<OUT
ERROR

The following versions contain \`1.9.3' in the name:
  1.9.3-p0
  1.9.3-p194

See all available versions with \`jlenv install --list'.

If the version you need is missing, try upgrading julia-build:

  cd ${BATS_TEST_DIRNAME}/.. && git pull && cd -
OUT

  unstub julia-build
}

@test "Homebrew upgrade instructions" {
  stub brew "--prefix : echo '${BATS_TEST_DIRNAME%/*}'"
  stub_julia_build 'echo ERROR >&2 && exit 2' \
    "--definitions : true"

  run jlenv-install 1.9.3
  assert_failure
  assert_output <<OUT
ERROR

See all available versions with \`jlenv install --list'.

If the version you need is missing, try upgrading julia-build:

  brew update && brew upgrade julia-build
OUT

  unstub brew
  unstub julia-build
}

@test "no build definitions from plugins" {
  refute [ -e "${JLENV_ROOT}/plugins" ]
  stub_julia_build 'echo $JULIA_BUILD_DEFINITIONS'

  run jlenv-install 2.1.2
  assert_success ""
}

@test "some build definitions from plugins" {
  mkdir -p "${JLENV_ROOT}/plugins/foo/share/julia-build"
  mkdir -p "${JLENV_ROOT}/plugins/bar/share/julia-build"
  stub_julia_build "echo \$JULIA_BUILD_DEFINITIONS | tr ':' $'\\n'"

  run jlenv-install 2.1.2
  assert_success
  assert_output <<OUT

${JLENV_ROOT}/plugins/bar/share/julia-build
${JLENV_ROOT}/plugins/foo/share/julia-build
OUT
}

@test "list build definitions from plugins" {
  mkdir -p "${JLENV_ROOT}/plugins/foo/share/julia-build"
  mkdir -p "${JLENV_ROOT}/plugins/bar/share/julia-build"
  stub_julia_build "--definitions : echo \$JULIA_BUILD_DEFINITIONS | tr ':' $'\\n'"

  run jlenv-install --list
  assert_success
  assert_output <<OUT
Available versions:
  
  ${JLENV_ROOT}/plugins/bar/share/julia-build
  ${JLENV_ROOT}/plugins/foo/share/julia-build
OUT
}

@test "completion results include build definitions from plugins" {
  mkdir -p "${JLENV_ROOT}/plugins/foo/share/julia-build"
  mkdir -p "${JLENV_ROOT}/plugins/bar/share/julia-build"
  stub julia-build "--definitions : echo \$JULIA_BUILD_DEFINITIONS | tr ':' $'\\n'"

  run jlenv-install --complete
  assert_success
  assert_output <<OUT
--list
--force
--skip-existing
--keep
--patch
--verbose
--version

${JLENV_ROOT}/plugins/bar/share/julia-build
${JLENV_ROOT}/plugins/foo/share/julia-build
OUT
}

@test "not enough arguments for jlenv-install" {
  stub_julia_build
  stub jlenv-help 'install : true'

  run jlenv-install
  assert_failure
  unstub jlenv-help
}

@test "too many arguments for jlenv-install" {
  stub_julia_build
  stub jlenv-help 'install : true'

  run jlenv-install 2.1.1 2.1.2
  assert_failure
  unstub jlenv-help
}

@test "show help for jlenv-install" {
  stub_julia_build
  stub jlenv-help 'install : true'

  run jlenv-install -h
  assert_success
  unstub jlenv-help
}

@test "jlenv-install has usage help preface" {
  run head "$(which jlenv-install)"
  assert_output_contains 'Usage: jlenv install'
}

@test "not enough arguments jlenv-uninstall" {
  stub jlenv-help 'uninstall : true'

  run jlenv-uninstall
  assert_failure
  unstub jlenv-help
}

@test "too many arguments for jlenv-uninstall" {
  stub jlenv-help 'uninstall : true'

  run jlenv-uninstall 2.1.1 2.1.2
  assert_failure
  unstub jlenv-help
}

@test "show help for jlenv-uninstall" {
  stub jlenv-help 'uninstall : true'

  run jlenv-uninstall -h
  assert_success
  unstub jlenv-help
}

@test "jlenv-uninstall has usage help preface" {
  run head "$(which jlenv-uninstall)"
  assert_output_contains 'Usage: jlenv uninstall'
}
