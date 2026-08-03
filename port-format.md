# KISS port format

## 1. Scope and authority

This document is the normative definition of the repository recipe files that
form a KISS port. The package-manager specification defines how recipes are
resolved, built into archives, installed, and recorded; it refers here instead
of repeating these file formats.

All paths in this document are beneath a repository package directory whose
basename is the package name. The complete recipe directory is copied into the
binary package's installed metadata during a build.

## 2. Common text rules

KISS metadata is line-oriented. Newline separates records and shell whitespace
separates fields. Blank and comment records have the file-specific behavior
defined below. Portable metadata uses no NUL bytes, embedded newlines, or
whitespace within a field.

The current format performs no variable or marker substitution. The obsolete
syntax is documented only in the historical VERSION-markers document.

## 3. `version`

`version` is REQUIRED. Its first line has exactly two whitespace-separated
fields:

```text
VERSION RELEASE
```

`RELEASE` MUST be a nonempty decimal integer for portable repositories.
`VERSION` MUST be nonempty and MUST NOT contain whitespace, `/`, or `@`.

The package manager treats both fields as opaque strings. It performs no
semantic version ordering. An upgrade is detected by string inequality of the
combined `VERSION-RELEASE` value.

For example, `1.0.4 3` denotes upstream version `1.0.4`, package release `3`.
A release is conventionally incremented when packaging changes require a
rebuild without a new upstream version.

## 4. `build`

`build` is REQUIRED and executable. It is run directly, not through an
implicitly selected shell, with two arguments:

1. the absolute package DESTDIR;
2. `VERSION`.

`RELEASE` is not passed. The working directory is the package's private build
directory after source extraction. A build script MUST install only beneath
DESTDIR and MUST return zero on success.

The build process environment and the surrounding build pipeline are defined
in sections 10.3 and 10.4 of the package-manager specification.

## 5. `sources`

`sources` is optional. Each line is read as two fields:

```text
SOURCE [DESTINATION]
```

Leading and separating shell whitespace is ignored by field parsing. The
second field receives the remainder of the line. Valid producer files SHOULD
use no whitespace within either value. Trailing `/` characters are removed
from `DESTINATION`. A line whose first field begins with `#`, and a blank line,
has no source payload.

Source forms, tested in this order, are:

1. `git+URL`, optionally ending in `@REF` or `#REF`;
2. any string containing `://`, treated as a remote file URL;
3. a directory relative to the recipe;
4. an absolute directory;
5. a regular file relative to the recipe;
6. an absolute regular file.

An unrecognized local path is fatal. `@` and `#` have identical meaning for a
git source; the suffix is fetched as the shallow ref. With no suffix, the
remote default `HEAD` is fetched.

`DESTINATION`, when present, selects a subdirectory inside the package build
directory and participates in the persistent source-cache path.

Example:

```text
https://example.org/project-1.0.tar.gz
git+https://example.org/project.git#v1.0 project
files/config.h config
```

Source resolution, caching, hooks, verification, and extraction are defined in
section 9 of the package-manager specification.

## 6. `checksums`

`checksums` is required when `sources` contains at least one
checksum-eligible source. It contains one record for each checksum-eligible
source, in source order. Git sources, directory sources, comments, and blank
lines have no record. A record is either:

- a lowercase 66-hex-character BLAKE3 digest (33 output bytes); or
- `SKIP`.

Only the first whitespace-separated field is compared. New checksums are
generated using:

```sh
b3sum -l 33 FILE...
```

Sixty-four-character checksum records are recognized as obsolete SHA-256 and
cause source verification to fail with a migration diagnostic. `SKIP` skips
the comparison but does not skip acquiring the corresponding source.

The `checksum` command regenerates the whole file and does not preserve
existing `SKIP` records. If there are no eligible sources, an existing
`checksums` file is left unchanged.

## 7. `depends`

`depends` is optional. Each nonblank, noncomment line is:

```text
PACKAGE [make]
```

One-field entries are runtime dependencies. A second field exactly equal to
`make` is a build-only dependency. Other second-field values are reserved and
MUST NOT be produced.

Dependencies are mandatory; the format has no optional-dependency syntax.
Package repositories MUST form a directed acyclic graph. The package-manager
dependency algorithm is defined in section 8 of its specification.

Example:

```text
python
meson make
util-linux
```

## 8. Package-local hooks and marker files

- `post-install`, when a regular executable file in installed metadata, runs
  after a successful install.
- `pre-remove`, when a regular executable file in installed metadata, runs
  before removal.
- A non-executable file of either name is skipped with a warning.
- `nostrip` disables stripping only when it exists at the top level of the
  extracted build directory. A repository-side `nostrip` is normally copied
  there as a local source; its mere presence beside `build` does not disable
  stripping.

Package-local hooks are run inside a `chroot` rooted at `KISS_ROOT` (or `/`),
with `KISS_ROOT` set to the empty string, as user `root`, and with no command
arguments. Their path inside the chroot is the corresponding path under
`/var/db/kiss/installed/P`.

These package-local hooks are distinct from the external events configured by
`KISS_HOOK`, whose complete interface is defined in the hooks document.
