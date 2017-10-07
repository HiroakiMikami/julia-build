#!/usr/bin/env bats

load test_helper
export JULIA_BUILD_CACHE_PATH="$TMP/cache"
export MAKE=make
export MAKE_OPTS="-j 2"
export CC=cc
export -n JULIA_CONFIGURE_OPTS

setup() {
  ensure_not_found_in_path aria2c
  mkdir -p "$INSTALL_ROOT"
  stub md5 false
  stub curl false
}

executable() {
  local file="$1"
  mkdir -p "${file%/*}"
  cat > "$file"
  chmod +x "$file"
}

cached_tarball() {
  mkdir -p "$JULIA_BUILD_CACHE_PATH"
  pushd "$JULIA_BUILD_CACHE_PATH" >/dev/null
  tarball "$@"
  popd >/dev/null
}

tarball() {
  local name="$1"
  local path="$PWD/$name"
  local configure="$path/configure"
  shift 1

  executable "$configure" <<OUT
#!$BASH
echo "$name: \$@" \${JULIAOPT:+JULIAOPT=\$JULIAOPT} >> build.log
OUT

  for file; do
    mkdir -p "$(dirname "${path}/${file}")"
    touch "${path}/${file}"
  done

  tar czf "${path}.tar.gz" -C "${path%/*}" "$name"
}

stub_make_install() {
  stub "$MAKE" \
    " : echo \"$MAKE \$@\" >> build.log" \
    "install : echo \"$MAKE \$@\" >> build.log && cat build.log >> '$INSTALL_ROOT/build.log'"
}

assert_build_log() {
  run cat "$INSTALL_ROOT/build.log"
  assert_output
}

@test "yaml is installed for julia" {
  cached_tarball "yaml-0.1.6"
  cached_tarball "julia-2.0.0"

  stub uname '-s : echo Linux'
  stub brew false
  stub_make_install
  stub_make_install

  install_fixture definitions/needs-yaml
  assert_success

  unstub uname
  unstub make

  assert_build_log <<OUT
yaml-0.1.6: --prefix=$INSTALL_ROOT
make -j 2
make install
julia-2.0.0: --prefix=$INSTALL_ROOT
make -j 2
make install
OUT
}

@test "apply julia patch before building" {
  cached_tarball "yaml-0.1.6"
  cached_tarball "julia-2.0.0"

  stub uname '-s : echo Linux'
  stub brew false
  stub_make_install
  stub_make_install
  stub patch ' : echo patch "$@" | sed -E "s/\.[[:alnum:]]+$/.XXX/" >> build.log'

  TMPDIR="$TMP" install_fixture --patch definitions/needs-yaml <<<""
  assert_success

  unstub uname
  unstub make
  unstub patch

  assert_build_log <<OUT
yaml-0.1.6: --prefix=$INSTALL_ROOT
make -j 2
make install
patch -p0 --force -i $TMP/julia-patch.XXX
julia-2.0.0: --prefix=$INSTALL_ROOT
make -j 2
make install
OUT
}

@test "apply julia patch from git diff before building" {
  cached_tarball "yaml-0.1.6"
  cached_tarball "julia-2.0.0"

  stub uname '-s : echo Linux'
  stub brew false
  stub_make_install
  stub_make_install
  stub patch ' : echo patch "$@" | sed -E "s/\.[[:alnum:]]+$/.XXX/" >> build.log'

  TMPDIR="$TMP" install_fixture --patch definitions/needs-yaml <<<"diff --git a/script.rb"
  assert_success

  unstub uname
  unstub make
  unstub patch

  assert_build_log <<OUT
yaml-0.1.6: --prefix=$INSTALL_ROOT
make -j 2
make install
patch -p1 --force -i $TMP/julia-patch.XXX
julia-2.0.0: --prefix=$INSTALL_ROOT
make -j 2
make install
OUT
}

@test "yaml is linked from Homebrew" {
  cached_tarball "julia-2.0.0"

  brew_libdir="$TMP/homebrew-yaml"
  mkdir -p "$brew_libdir"

  stub uname '-s : echo Linux'
  stub brew "--prefix libyaml : echo '$brew_libdir'" false
  stub_make_install

  install_fixture definitions/needs-yaml
  assert_success

  unstub uname
  unstub brew
  unstub make

  assert_build_log <<OUT
julia-2.0.0: --prefix=$INSTALL_ROOT --with-libyaml-dir=$brew_libdir
make -j 2
make install
OUT
}

@test "readline is linked from Homebrew" {
  cached_tarball "julia-2.0.0"

  readline_libdir="$TMP/homebrew-readline"
  mkdir -p "$readline_libdir"

  stub brew "--prefix readline : echo '$readline_libdir'"
  stub_make_install

  run_inline_definition <<DEF
install_package "julia-2.0.0" "http://julia-lang.org/julia/2.0/julia-2.0.0.tar.gz"
DEF
  assert_success

  unstub brew
  unstub make

  assert_build_log <<OUT
julia-2.0.0: --prefix=$INSTALL_ROOT --with-readline-dir=$readline_libdir
make -j 2
make install
OUT
}

@test "readline is not linked from Homebrew when explicitly defined" {
  cached_tarball "julia-2.0.0"

  stub brew
  stub_make_install

  export JULIA_CONFIGURE_OPTS='--with-readline-dir=/custom'
  run_inline_definition <<DEF
install_package "julia-2.0.0" "http://julia-lang.org/julia/2.0/julia-2.0.0.tar.gz"
DEF
  assert_success

  unstub brew
  unstub make

  assert_build_log <<OUT
julia-2.0.0: --prefix=$INSTALL_ROOT --with-readline-dir=/custom
make -j 2
make install
OUT
}

@test "number of CPU cores defaults to 2" {
  cached_tarball "julia-2.0.0"

  stub uname '-s : echo Darwin' false
  stub sysctl false
  stub_make_install

  export -n MAKE_OPTS
  run_inline_definition <<DEF
install_package "julia-2.0.0" "http://julia-lang.org/julia/2.0/julia-2.0.0.tar.gz"
DEF
  assert_success

  unstub uname
  unstub make

  assert_build_log <<OUT
julia-2.0.0: --prefix=$INSTALL_ROOT
make -j 2
make install
OUT
}

@test "number of CPU cores is detected on Mac" {
  cached_tarball "julia-2.0.0"

  stub uname '-s : echo Darwin' false
  stub sysctl '-n hw.ncpu : echo 4'
  stub_make_install

  export -n MAKE_OPTS
  run_inline_definition <<DEF
install_package "julia-2.0.0" "http://julia-lang.org/julia/2.0/julia-2.0.0.tar.gz"
DEF
  assert_success

  unstub uname
  unstub sysctl
  unstub make

  assert_build_log <<OUT
julia-2.0.0: --prefix=$INSTALL_ROOT
make -j 4
make install
OUT
}

@test "number of CPU cores is detected on FreeBSD" {
  cached_tarball "julia-2.0.0"

  stub uname '-s : echo FreeBSD' false
  stub sysctl '-n hw.ncpu : echo 1'
  stub_make_install

  export -n MAKE_OPTS
  run_inline_definition <<DEF
install_package "julia-2.0.0" "http://julia-lang.org/julia/2.0/julia-2.0.0.tar.gz"
DEF
  assert_success

  unstub uname
  unstub sysctl
  unstub make

  assert_build_log <<OUT
julia-2.0.0: --prefix=$INSTALL_ROOT
make -j 1
make install
OUT
}

@test "setting JULIA_MAKE_INSTALL_OPTS to a multi-word string" {
  cached_tarball "julia-2.0.0"

  stub uname '-s : echo Linux'
  stub_make_install

  export JULIA_MAKE_INSTALL_OPTS="DOGE=\"such wow\""
  run_inline_definition <<DEF
install_package "julia-2.0.0" "http://julia-lang.org/julia/2.0/julia-2.0.0.tar.gz"
DEF
  assert_success

  unstub uname
  unstub make

  assert_build_log <<OUT
julia-2.0.0: --prefix=$INSTALL_ROOT
make -j 2
make install DOGE="such wow"
OUT
}

@test "setting MAKE_INSTALL_OPTS to a multi-word string" {
  cached_tarball "julia-2.0.0"

  stub uname '-s : echo Linux'
  stub_make_install

  export MAKE_INSTALL_OPTS="DOGE=\"such wow\""
  run_inline_definition <<DEF
install_package "julia-2.0.0" "http://julia-lang.org/julia/2.0/julia-2.0.0.tar.gz"
DEF
  assert_success

  unstub uname
  unstub make

  assert_build_log <<OUT
julia-2.0.0: --prefix=$INSTALL_ROOT
make -j 2
make install DOGE="such wow"
OUT
}

@test "custom relative install destination" {
  export JULIA_BUILD_CACHE_PATH="$FIXTURE_ROOT"

  cd "$TMP"
  install_fixture definitions/without-checksum ./here
  assert_success
  assert [ -x ./here/bin/package ]
}

@test "make on FreeBSD 9 defaults to gmake" {
  cached_tarball "julia-2.0.0"

  stub uname "-s : echo FreeBSD" "-r : echo 9.1" false
  MAKE=gmake stub_make_install

  MAKE= install_fixture definitions/vanilla-julia
  assert_success

  unstub gmake
  unstub uname
}

@test "make on FreeBSD 10" {
  cached_tarball "julia-2.0.0"

  stub uname "-s : echo FreeBSD" "-r : echo 10.0-RELEASE" false
  stub_make_install

  MAKE= install_fixture definitions/vanilla-julia
  assert_success

  unstub uname
}

@test "make on FreeBSD 11" {
  cached_tarball "julia-2.0.0"

  stub uname "-s : echo FreeBSD" "-r : echo 11.0-RELEASE" false
  stub_make_install

  MAKE= install_fixture definitions/vanilla-julia
  assert_success

  unstub uname
}

@test "can use JULIA_CONFIGURE to apply a patch" {
  cached_tarball "julia-2.0.0"

  executable "${TMP}/custom-configure" <<CONF
#!$BASH
apply -p1 -i /my/patch.diff
exec ./configure "\$@"
CONF

  stub uname '-s : echo Linux'
  stub apply 'echo apply "$@" >> build.log'
  stub_make_install

  export JULIA_CONFIGURE="${TMP}/custom-configure"
  run_inline_definition <<DEF
install_package "julia-2.0.0" "http://julia-lang.org/pub/julia-2.0.0.tar.gz"
DEF
  assert_success

  unstub uname
  unstub make
  unstub apply

  assert_build_log <<OUT
apply -p1 -i /my/patch.diff
julia-2.0.0: --prefix=$INSTALL_ROOT
make -j 2
make install
OUT
}

@test "copy strategy forces overwrite" {
  export JULIA_BUILD_CACHE_PATH="$FIXTURE_ROOT"

  mkdir -p "$INSTALL_ROOT/bin"
  touch "$INSTALL_ROOT/bin/package"
  chmod -w "$INSTALL_ROOT/bin/package"

  install_fixture definitions/without-checksum
  assert_success

  run "$INSTALL_ROOT/bin/package" "world"
  assert_success "hello world"
}

@test "mjulia strategy overwrites non-writable files" {
  cached_tarball "mjulia-1.0" build/host/bin/{mjulia,mirb}

  mkdir -p "$INSTALL_ROOT/bin"
  touch "$INSTALL_ROOT/bin/mjulia"
  chmod -w "$INSTALL_ROOT/bin/mjulia"

  stub gem false
  stub rake '--version : echo 1' true

  run_inline_definition <<DEF
install_package "mjulia-1.0" "http://julia-lang.org/pub/mjulia-1.0.tar.gz" mjulia
DEF
  assert_success

  unstub rake

  assert [ -w "$INSTALL_ROOT/bin/mjulia" ]
  assert [ -e "$INSTALL_ROOT/bin/julia" ]
  assert [ -e "$INSTALL_ROOT/bin/irb" ]
}

@test "mjulia strategy fetches rake if missing" {
  cached_tarball "mjulia-1.0" build/host/bin/mjulia

  stub rake '--version : false' true
  stub gem 'install rake -v *10.1.0 : true'

  run_inline_definition <<DEF
install_package "mjulia-1.0" "http://julia-lang.org/pub/mjulia-1.0.tar.gz" mjulia
DEF
  assert_success

  unstub gem
  unstub rake
}

@test "rbx uses bundle then rake" {
  cached_tarball "rubinius-2.0.0" "Gemfile"

  stub gem false
  stub rake false
  stub bundle \
    '--version : echo 1' \
    ' : echo bundle "$@" >> build.log' \
    '--version : echo 1' \
    " exec rake install : { cat build.log; echo bundle \"\$@\"; } >> '$INSTALL_ROOT/build.log'"

  run_inline_definition <<DEF
install_package "rubinius-2.0.0" "http://releases.rubini.us/rubinius-2.0.0.tar.gz" rbx
DEF
  assert_success

  unstub bundle

  assert_build_log <<OUT
bundle --path=vendor/bundle
rubinius-2.0.0: --prefix=$INSTALL_ROOT JULIAOPT=-juliagems
bundle exec rake install
OUT
}

@test "fixes rbx binstubs" {
  executable "${JULIA_BUILD_CACHE_PATH}/rubinius-2.0.0/gems/bin/rake" <<OUT
#!rbx
puts 'rake'
OUT
  executable "${JULIA_BUILD_CACHE_PATH}/rubinius-2.0.0/gems/bin/irb" <<OUT
#!rbx
print '>>'
OUT
  cached_tarball "rubinius-2.0.0" bin/julia

  stub bundle false
  stub rake \
    '--version : echo 1' \
    "install : mkdir -p '$INSTALL_ROOT'; cp -fR . '$INSTALL_ROOT'"

  run_inline_definition <<DEF
install_package "rubinius-2.0.0" "http://releases.rubini.us/rubinius-2.0.0.tar.gz" rbx
DEF
  assert_success

  unstub rake

  run ls "${INSTALL_ROOT}/bin"
  assert_output <<OUT
irb
rake
julia
OUT

  run $(type -p greadlink readlink | head -1) "${INSTALL_ROOT}/gems/bin"
  assert_success '../bin'

  assert [ -x "${INSTALL_ROOT}/bin/rake" ]
  run cat "${INSTALL_ROOT}/bin/rake"
  assert_output <<OUT
#!${INSTALL_ROOT}/bin/julia
puts 'rake'
OUT

  assert [ -x "${INSTALL_ROOT}/bin/irb" ]
  run cat "${INSTALL_ROOT}/bin/irb"
  assert_output <<OUT
#!${INSTALL_ROOT}/bin/julia
print '>>'
OUT
}

@test "JRuby build" {
  executable "${JULIA_BUILD_CACHE_PATH}/jjulia-1.7.9/bin/jjulia" <<OUT
#!${BASH}
echo jjulia "\$@" >> ../build.log
OUT
  executable "${JULIA_BUILD_CACHE_PATH}/jjulia-1.7.9/bin/gem" <<OUT
#!/usr/bin/env jjulia
nice gem things
OUT
  cached_tarball "jjulia-1.7.9" bin/foo.exe bin/bar.dll bin/baz.bat

  run_inline_definition <<DEF
install_package "jjulia-1.7.9" "http://jjulia.org/downloads/jjulia-bin-1.7.9.tar.gz" jjulia
DEF
  assert_success

  assert_build_log <<OUT
jjulia gem install jjulia-launcher
OUT

  run ls "${INSTALL_ROOT}/bin"
  assert_output <<OUT
gem
jjulia
julia
OUT

  assert [ -x "${INSTALL_ROOT}/bin/gem" ]
  run cat "${INSTALL_ROOT}/bin/gem"
  assert_output <<OUT
#!${INSTALL_ROOT}/bin/jjulia
nice gem things
OUT
}

@test "JRuby Java 7 missing" {
  cached_tarball "jjulia-9000.dev" bin/jjulia

  stub java false

  run_inline_definition <<DEF
require_java7
install_package "jjulia-9000.dev" "http://ci.jjulia.org/jjulia-dist-9000.dev-bin.tar.gz" jjulia
DEF
  assert_failure
  assert_output_contains "ERROR: Java 7 required. Please install a 1.7-compatible JRE."
}

@test "JRuby Java is outdated" {
  cached_tarball "jjulia-9000.dev" bin/jjulia

  stub java '-version : echo java version "1.6.0_21" >&2'

  run_inline_definition <<DEF
require_java7
install_package "jjulia-9000.dev" "http://ci.jjulia.org/jjulia-dist-9000.dev-bin.tar.gz" jjulia
DEF
  assert_failure
  assert_output_contains "ERROR: Java 7 required. Please install a 1.7-compatible JRE."
}

@test "JRuby Java 7 up-to-date" {
  cached_tarball "jjulia-9000.dev" bin/jjulia

  stub java '-version : echo java version "1.7.0_21" >&2'

  run_inline_definition <<DEF
require_java7
install_package "jjulia-9000.dev" "http://ci.jjulia.org/jjulia-dist-9000.dev-bin.tar.gz" jjulia
DEF
  assert_success
}

@test "Java version string not on first line" {
  cached_tarball "jjulia-9000.dev" bin/jjulia

  stub java "-version : echo 'Picked up JAVA_TOOL_OPTIONS' >&2; echo 'java version \"1.8.0_31\"' >&2"

  run_inline_definition <<DEF
require_java7
install_package "jjulia-9000.dev" "http://ci.jjulia.org/jjulia-dist-9000.dev-bin.tar.gz" jjulia
DEF
  assert_success
}

@test "Java version string on OpenJDK" {
  cached_tarball "jjulia-9000.dev" bin/jjulia

  stub java "-version : echo 'openjdk version \"1.8.0_40\"' >&2"

  run_inline_definition <<DEF
require_java7
install_package "jjulia-9000.dev" "http://ci.jjulia.org/jjulia-dist-9000.dev-bin.tar.gz" jjulia
DEF
  assert_success
}

@test "non-writable TMPDIR aborts build" {
  export TMPDIR="${TMP}/build"
  mkdir -p "$TMPDIR"
  chmod -w "$TMPDIR"

  touch "${TMP}/build-definition"
  run julia-build "${TMP}/build-definition" "$INSTALL_ROOT"
  assert_failure "julia-build: TMPDIR=$TMPDIR is set to a non-accessible location"
}

@test "non-executable TMPDIR aborts build" {
  export TMPDIR="${TMP}/build"
  mkdir -p "$TMPDIR"
  chmod -x "$TMPDIR"

  touch "${TMP}/build-definition"
  run julia-build "${TMP}/build-definition" "$INSTALL_ROOT"
  assert_failure "julia-build: TMPDIR=$TMPDIR is set to a non-accessible location"
}

@test "initializes LDFLAGS directories" {
  cached_tarball "julia-2.0.0"

  export LDFLAGS="-L ${BATS_TEST_DIRNAME}/what/evs"
  run_inline_definition <<DEF
install_package "julia-2.0.0" "http://julia-lang.org/julia/2.0/julia-2.0.0.tar.gz" ldflags_dirs
DEF
  assert_success

  assert [ -d "${INSTALL_ROOT}/lib" ]
  assert [ -d "${BATS_TEST_DIRNAME}/what/evs" ]
}
