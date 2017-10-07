#!/usr/bin/env bats

load test_helper

setup() {
  export JLENV_ROOT="${TMP}/jlenv"
  export HOOK_PATH="${TMP}/i has hooks"
  mkdir -p "$HOOK_PATH"
}

@test "jlenv-install hooks" {
  cat > "${HOOK_PATH}/install.bash" <<OUT
before_install 'echo before: \$PREFIX'
after_install 'echo after: \$STATUS'
OUT
  stub jlenv-hooks "install : echo '$HOOK_PATH'/install.bash"
  stub jlenv-rehash "echo rehashed"

  definition="${TMP}/2.0.0"
  cat > "$definition" <<<"echo julia-build"
  run jlenv-install "$definition"

  assert_success
  assert_output <<-OUT
before: ${JLENV_ROOT}/versions/2.0.0
julia-build
after: 0
rehashed
OUT
}

@test "jlenv-uninstall hooks" {
  cat > "${HOOK_PATH}/uninstall.bash" <<OUT
before_uninstall 'echo before: \$PREFIX'
after_uninstall 'echo after.'
rm() {
  echo "rm \$@"
  command rm "\$@"
}
OUT
  stub jlenv-hooks "uninstall : echo '$HOOK_PATH'/uninstall.bash"
  stub jlenv-rehash "echo rehashed"

  mkdir -p "${JLENV_ROOT}/versions/2.0.0"
  run jlenv-uninstall -f 2.0.0

  assert_success
  assert_output <<-OUT
before: ${JLENV_ROOT}/versions/2.0.0
rm -rf ${JLENV_ROOT}/versions/2.0.0
rehashed
after.
OUT

  refute [ -d "${JLENV_ROOT}/versions/2.0.0" ]
}
