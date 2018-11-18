![](https://travis-ci.org/HiroakiMikami/julia-build.svg?branch=master)

# julia-build

This project was forked from [ruby-build](https://github.com/rbenv/ruby-build), and modified for [julia](https://github.com/JuliaLang/julia).

---

julia-build is a command-line utility that makes it easy to install virtually any
version of Julia, from source.

It is available as a plugin for [jlenv](https://github.com/HiroakiMikami/julia-build) that
provides the `jlenv install` command, or as a standalone program.

## Installation

```sh
# As an jlenv plugin
$ mkdir -p "$(jlenv root)"/plugins
$ git clone https://github.com/HiroakiMikami/julia-build.git "$(jlenv root)"/plugins/julia-build

# As a standalone program
$ git clone https://github.com/HiroakiMikami/julia-build.git
$ PREFIX=/usr/local ./julia-build/install.sh
```

### Upgrading

```sh
# As an jlenv plugin
$ cd "$(jlenv root)"/plugins/julia-build && git pull
```

## Usage

### Basic Usage

```sh
# As an jlenv plugin
$ jlenv install --list                 # lists all available versions of Julia
$ jlenv install v0.6.0                  # installs Julia v0.6.0 to ~/.jlenv/versions

# As a standalone program
$ julia-build --definitions             # lists all available versions of Julia
$ julia-build 0.6.0 ~/local/julia-v0.6.0  # installs Julia v0.6.0 to ~/local/julia-0.6.0
```

julia-build does not check for system dependencies before downloading and
attempting to compile the Julia source. Please ensure that [all required
libraries](https://github.com/JuliaLang/julia#required-build-tools-and-external-libraries) are available on your system.

### Advanced Usage

#### Custom Build Definitions

If you wish to develop and install a version of Julia that is not yet supported
by julia-build, you may specify the path to a custom “build definition file” in
place of a Julia version number.

Use the [default build definitions][definitions] as a template for your custom
definitions.

#### Custom Build Configuration

The build process may be configured through the following environment variables:

| Variable                 | Function                                                                                         |
| ------------------------ | ------------------------------------------------------------------------------------------------ |
| `TMPDIR`                 | Where temporary files are stored.                                                                |
| `JULIA_BUILD_BUILD_PATH`  | Where sources are downloaded and built. (Default: a timestamped subdirectory of `TMPDIR`)        |
| `JULIA_BUILD_CACHE_PATH`  | Where to cache downloaded package files. (Default: `~/.jlenv/cache` if invoked as jlenv plugin)  |
| `JULIA_BUILD_MIRROR_URL`  | Custom mirror URL root.                                                                          |
| `JULIA_BUILD_SKIP_MIRROR` | Always download from official sources, not mirrors. (Default: unset)                             |
| `JULIA_BUILD_ROOT`        | Custom build definition directory. (Default: `share/julia-build`)                                 |
| `JULIA_BUILD_DEFINITIONS` | Additional paths to search for build definitions. (Colon-separated list)                         |
| `CC`                     | Path to the C compiler.                                                                          |
| `JULIA_CFLAGS`            | Additional `CFLAGS` options (_e.g.,_ to override `-O3`).                                         |
| `CONFIGURE_OPTS`         | Additional `./configure` options.                                                                |
| `MAKE`                   | Custom `make` command (_e.g.,_ `gmake`).                                                         |
| `MAKE_OPTS` / `MAKEOPTS` | Additional `make` options.                                                                       |
| `MAKE_INSTALL_OPTS`      | Additional `make install` options.                                                               |
| `JULIA_CONFIGURE_OPTS`    | Additional `./configure` options (applies only to Julia source).                                 |
| `JULIA_MAKE_OPTS`         | Additional `make` options (applies only to Julia source).                                        |
| `JULIA_MAKE_INSTALL_OPTS` | Additional `make install` options (applies only to Julia source).                                |

#### Applying Patches

Both `jlenv install` and `julia-build` support the `--patch` (`-p`) flag to apply
a patch to the Julia source code before building. Patches are
read from `STDIN`:

```sh
# applying a single patch
$ jlenv install --patch 1.9.3-p429 < /path/to/julia.patch

# applying a patch from HTTP
$ jlenv install --patch 1.9.3-p429 < <(curl -sSL http://git.io/julia.patch)

# applying multiple patches
$ cat fix1.patch fix2.patch | jlenv install --patch 1.9.3-p429
```

#### Checksum Verification

If you have the `shasum`, `openssl`, or `sha256sum` tool installed, julia-build will
automatically verify the SHA2 checksum of each downloaded package before
installing it.

Checksums are optional and specified as anchors on the package URL in each
definition. (All bundled definitions include checksums.)

#### Keeping the build directory after installation

Both `julia-build` and `jlenv install` accept the `-k` or `--keep` flag, which
tells julia-build to keep the downloaded source after installation. This can be
useful if you need to use `gdb` and `memprof` with Julia.

Source code will be kept in a parallel directory tree `~/.jlenv/sources` when
using `--keep` with the `jlenv install` command. You should specify the
location of the source code with the `JULIA_BUILD_BUILD_PATH` environment
variable when using `--keep` with `julia-build`.

## Getting Help

Please see Julia-Build wiki for solutions to common problems.

  [jlenv]: https://github.com/HiroakiMikami/jlenv
  [definitions]: https://github.com/HiroakiMikami/julia-build/tree/master/share/julia-build
  [wiki]: https://github.com/HiroakiMikami/julia-build/wiki
