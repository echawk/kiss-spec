## Package Format

This section of the document will document and specify the different files
that go into defining a KISS package port.

### version

The `version` file is a plain text file (or a symbolic link to such a
file) whose first line contains the version and release of the port.

For example, a file containing the following:

```
1.0.4 3
```

Would be read to mean that the package is on version 1.0.4, with 3 signifying
the third release.

Generally, releases only ought to occur if a dependency of the package in
question breaks the installed package, thus necessitating a rebuild. Or
if there is additional functionality enabled/disabled.

### sources

The `sources` file is a plain text file (or a symbolic link to such a
file) whose text contains a *source* that the package needs for it to
build.

The sources file will be divided on a line by line basis. Each line
indicates a unique source. Each source can optionally specify a directory
that it will then be extracted or copied into during the build of the package.

Package source types are split into two general categories: remote & local.

Local sources can either be an absolute path on the file system, such as
`/path/to/package/source.file_extension` or can be a relative path
such as `files/source-file`.

Remote sources can either be URL to a remote file, or can be the link
to a git repo, provided that the URL is appropriately prefixed with the
string `git+`.

The `@` and `#` are used to separate the url of the repository
from either the commit or branch that should be checked out. Otherwise, if
that part of the source is blank, the HEAD of the repository is fetched instead.

It should be noted that there is no difference between `@` and `#`
when it comes to the internals of the package manager, it is merely a stylistic
choice.

Here is an example sources file:

```
https://github.com/godotengine/godot/archive/refs/tags/4.2.0-stable.tar.gz
git+https://github.com/SCons/scons scons/
patches/gcc.patch
```

### depends

The `depends` file contains a list of all of the dependencies for
the port, separated by newlines. Dependencies in this package can be marked
as a "make" dependency, indicating that the package is only required by
the port at build time, and can be removed after the package has been built.
Otherwise, dependencies are assumed to be runtime dependencies, which cannot
be removed when the package is installed.

It is important to note that there is no way to indicate optional dependencies
in this scheme.

Here is an example depends file:

```
python
meson make
util-linux
```

### checksums

The `checksums` file contains the b3sums for each source in the
sources file.

Each line in the checksums file corresponds to a line in the sources file.

If you would like to skip the checksumming of a source, you can replace
the corresponding line with `SKIP` and the package manager will not
validate the checksum of that source.

### pre-remove

The `pre-remove` file is an optional file and is executed
immediately before a package is removed. It's only requirement is that
it be marked as executable.

There is one argument provided, the package name.

### post-install

The `post-install` file is an optional file and is executed
immediately after a package is installed. It's only requirement is that
it be marked as executable.

There is one argument provided, the package name.

### build

The `build` file is responsible for building the port.
The only requirement of the build file is that it be marked as an executable.

The build file is given to arguments when executed:

1. A temporary DESTDIR to install the package contents to.
2. The version of the package being built.
