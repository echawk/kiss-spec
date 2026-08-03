# KISS package manager specification

## 1. Scope and conformance

This document specifies the observable behavior of the KISS package manager
implemented by `kiss/kiss`, version 6.2.0. It is intended to be sufficient for
implementing a compatible package manager without translating the reference
POSIX shell program line by line.

The exact analyzed reference artifact has SHA-256 digest:

```text
9874e2090290372156f5840c6b7b52d2101e3dae29e22b042831d1c6163633e4  kiss/kiss
```

The proposal documents in `proposals/` are not part of this specification.
They describe possible future behavior and MUST NOT be assumed by a conforming
implementation.

This document defines the package manager, not the broader meaning of a “KISS
System.” The latter is described by [the KISS system profile](kiss-system.md).
That profile refers back here for package-manager runtime requirements rather
than maintaining a second list of utilities.

Normative authority is divided by topic: the
[KISS port format](port-format.md) controls repository recipe files, the
[external hook interface](hooks.md) controls `KISS_HOOK`, and this document
controls package-manager operations and generated state. The invariant index,
history, system profile, and proposals do not override those normative
documents.

The key words **MUST**, **MUST NOT**, **REQUIRED**, **SHOULD**, **SHOULD NOT**,
and **MAY** are normative.

A conforming implementation MUST preserve, for valid inputs:

1. command selection, argument interpretation, and success or failure;
2. repository and installed-package resolution order;
3. source-cache, binary-cache, installed-database, and alternatives layouts;
4. generated package contents and metadata;
5. dependency ordering and the points at which packages are built or installed;
6. hook order, arguments, working directories, and failure behavior;
7. filesystem results of installation, upgrade, removal, and alternative swaps;
8. machine-consumable standard output described by this document.

Human-oriented log wording, color escape sequences, temporary filenames, and
the exact external commands used to perform an operation MAY differ. Logs MUST
go to standard error unless this document identifies output as command data or
build-script output.

“Conforming” means reference-exact behavior unless a paragraph explicitly
allows variation. An implementation MAY expose corrected or hardened behavior
for a documented compatibility quirk, but it MUST be opt-in; the default mode
used as a drop-in `kiss` replacement remains reference-exact.

Inputs expressly declared invalid have no compatibility requirements beyond
failing without intentionally modifying paths outside the configured root and
cache. An implementation MAY reject malformed archives, unsafe paths, invalid
UTF-8, and ambiguous package metadata earlier than the reference program. Such
hardening MUST NOT change behavior for valid inputs.

### 1.1 Execution model

The reference program is a POSIX shell program and operates on the filesystem
directly. A replacement need not be written in shell, but MUST expose the same
filesystem protocol and command behavior. Pathnames and metadata are sequences
of non-NUL bytes. Newline is the record separator in all KISS text formats.

Unless otherwise stated, a failed required filesystem operation, hook, build
script, downloader, checksum command, compressor, decompressor, `tar`, `git`,
or privilege-escalation command MUST make the command fail with a nonzero exit
status. A diagnostic SHOULD identify the package and failed operation.

The reference implementation is not a transactional package manager. It uses
temporary files and atomic renames for individual installed files, but a failed
multi-file install can leave the filesystem dirty. A compatible implementation
MAY provide stronger atomicity if its successful results and hook-visible state
remain compatible.

## 2. Terms and path notation

- **root**: `KISS_ROOT` after trailing slash removal. An unset value and `/`
  both normalize to the host root and are represented internally by an empty
  prefix.
- **repository**: one colon-separated directory in `KISS_PATH`.
- **port** or **repository package**: a directory named for a package inside a
  repository.
- **installed package**: a directory named for a package in the installed
  database.
- **recipe**: the package metadata files headed by `version` and `build`.
- **DESTDIR**: the private staging root passed as the first argument of a build
  script.
- **manifest path**: an absolute path relative to root, such as `/usr/bin/foo`.
- **explicit package**: a package named directly by the user.
- **implicit package**: a dependency discovered while processing explicit
  packages.
- **runtime dependency**: a one-field entry in `depends`.
- **make dependency**: an entry whose second field is exactly `make`.

The following symbolic paths are used throughout:

- **`DB`:** `${KISS_ROOT}/var/db/kiss/installed`.
- **`CHOICES`:** `${KISS_ROOT}/var/db/kiss/choices`.
- **`CACHE`:** `${XDG_CACHE_HOME}/kiss`, or `${HOME}/.cache/kiss` when
  `XDG_CACHE_HOME` is unset or empty.
- **`SOURCES`:** `${CACHE}/sources`.
- **`BINARIES`:** `${CACHE}/bin`.
- **`LOGS`:** `${CACHE}/logs/YYYY-MM-DD`.
- **`PROCESS`:** `${KISS_TMPDIR}/${KISS_PID}`, where `KISS_TMPDIR` defaults to
  `${CACHE}/proc`.
- **`BUILD`:** `${PROCESS}/build`.
- **`STAGE`:** `${PROCESS}/pkg`.
- **`EXTRACT`:** `${PROCESS}/extract`.
- **`TEMP`:** `${PROCESS}/tmp`.

`DB`, `CHOICES`, and all absolute manifest paths are beneath root. Cache and
temporary paths are not redirected by `KISS_ROOT`.

## 3. Process initialization and environment

Before dispatching a command, the implementation MUST:

1. normalize root by removing all trailing `/` characters;
2. attempt to create root, permitting failure when it already denotes the host
   root or cannot be created by the current user;
3. select configured or available helper programs;
4. create `SOURCES`, the date-specific `LOGS`, `BINARIES`, `BUILD`, `STAGE`,
   `EXTRACT`, and `TEMP`;
5. install interrupt and exit cleanup handling; and
6. record the invocation working directory for resolving relative archive
   arguments.

This initialization occurs even for read-only commands such as `version`.

### 3.1 Public environment variables

Values are not generally validated in advance. “Enabled” below means the
exact string shown; other nonempty strings are not synonyms.

- **`KISS_CHK`:** SHA-256 utility used only for legacy 64-character `etcsums`
  and migration support. If unset, choose the first of `openssl`, `sha256sum`,
  `sha256`, `shasum`, or `digest`. New source and configuration hashes use
  `b3sum`, not this variable.
- **`KISS_CHOICE`:** Controls automatic conflict-to-alternative conversion. In
  the 6.2.0 reference behavior, conversion occurs when this value is not
  exactly `1`; `1` makes an otherwise convertible conflict fatal. This
  counterintuitive behavior, including the contradictory reference diagnostic,
  is compatibility-significant.
- **`KISS_COLOR`:** `0` disables color. Otherwise color is used only when
  standard error is a terminal.
- **`KISS_COMPRESS`:** `gz`. Valid build-output methods are `bz2`, `gz`, `lz`,
  `lzma`, `xz`, and `zst`. The value is also the archive filename suffix.
- **`KISS_DEBUG`:** `0`. If exactly `0`, temporary process data is cleaned; any
  other value preserves it.
- **`KISS_ELF`:** Dynamic-section inspection command. If unset, choose
  `readelf`, `eu-readelf`, or `llvm-readelf`; otherwise fall back to `ldd` mode.
- **`KISS_FORCE`:** `1` enables the specific force exceptions documented for
  build, install, and remove. Other values do not.
- **`KISS_GET`:** Downloader. If unset, choose the first of `aria2c`, `axel`,
  `curl`, `wget`, or `wget2`. Absence is fatal at process initialization.
- **`KISS_HOOK`:** Colon-separated external hook executable paths. Empty
  elements are ignored.
- **`KISS_KEEPLOG`:** `1` retains successful build logs. Other values remove
  them after a successful build. Failed build logs are retained.
- **`KISS_PATH`:** Colon-separated, ordered repository directories. Empty
  elements are ignored. Portable configurations use absolute paths; relative
  entries are interpreted relative to the process working directory and can
  cease to resolve after an internal directory change.
- **`KISS_PROMPT`:** `0` makes ordinary confirmation points continue without
  reading input. Other values read one byte from standard input and fail on
  EOF. A special build rule in section 10.8 means `KISS_PROMPT=0` also
  suppresses the final offer to install explicitly built packages.
- **`KISS_ROOT`:** Unset means `/`. Redirects installed files, `DB`, and
  `CHOICES`, but not caches. A nonempty portable value is absolute.
- **`KISS_STRIP`:** `0` disables stripping. Other values enable it unless the
  build tree contains `nostrip`.
- **`KISS_SU`:** Privilege-escalation command. If unset, choose the first
  available of `ssu`, `sudo`, `doas`, or `su`, then fall back to `su`.
- **`KISS_TMPDIR`:** `${CACHE}/proc`. Base directory beneath which a
  per-process directory is created.

The standard variables `HOME`, `LOGNAME`, `PATH`, `XDG_CACHE_HOME`, locale
variables, and toolchain variables also affect operation. `LOGNAME` is
required. `AR`, `CC`, `CXX`, `NM`, and `RANLIB` are passed to build scripts,
with defaults described in section 10.4.

### 3.2 Internal environment variables

`KISS_PID`, `_KISS_DATE`, and `_KISS_LVL` coordinate recursive invocations.
They are not repository configuration interfaces, but a compatible executable
MUST tolerate them because recursive KISS calls export them.

- `KISS_PID` defaults to the process ID and names temporary files and the
  process directory.
- `_KISS_DATE` allows a child invocation to reuse the parent's log date/time.
- `_KISS_LVL` is incremented before dispatch. The top-level invocation owns
  process-directory cleanup; nested invocations clean only their extraction
  directory.

When cleanup traps are enabled and `KISS_DEBUG` is `0`, normal exit, error exit,
and handled `SIGINT` remove `PROCESS` in the top-level process. A nested process
removes only `EXTRACT`. With any other `KISS_DEBUG` value these paths are
preserved. Install and remove deliberately disable these traps across broader
critical regions described below; a failure inside such a region can therefore
leave process data even when `KISS_DEBUG=0`.

## 4. Filesystem databases and identity

### 4.1 Installed state

A package named `P` is installed if and only if `DB/P` is a directory. There
is no central database or index. `DB/P` is a copy of the repository recipe as
it existed at build time, possibly with a generated or repaired `depends`, and
with at least `manifest` and usually `etcsums`.

Commands that query a package version require `DB/P/version` to be readable and
`DB/P/build` to be executable. Thus an empty `DB/P` directory marks the package
as installed for dependency checks but is not sufficient for `list` or
`upgrade`.

### 4.2 Package name

The package name is the basename of its repository, database, or archive
identity directory. Valid portable package names MUST match:

```text
[A-Za-z0-9][A-Za-z0-9+_.-]*
```

This producer restriction prevents ambiguity in archive names, choice names,
shell word lists, and paths. Consumers MUST additionally reproduce the command
argument acceptance rules in section 7.2; the reference accepts some names
outside this portable set.

Package names MUST NOT contain `/`, newline, whitespace, `>`, `@`, glob
metacharacters, or NUL. Two packages with the same name are the same package
identity even when their recipes come from different repositories.

### 4.3 Ownership

An installed manifest is the sole ownership record. A non-directory path is
owned by package `P` when a line exactly equal to that path occurs in
`DB/P/manifest`.

The presence of an unowned file on the live filesystem does not make it a
package conflict. Conversely, a manifest claim remains authoritative when the
live file is missing. Valid installed state MUST NOT contain the same
non-directory path in two package manifests, except transiently within the
specified install or alternative operation. Directory records are deliberately
nonexclusive: many packages may list `/usr/` or `/usr/bin/`, and removal merely
attempts to remove such a directory when it has become empty.

## 5. Repository lookup and binary lookup

### 5.1 General lookup

For an exact package query `P`, search each nonempty element of `KISS_PATH` in
order for a directory named `P`, then search `DB/P`. The first matching
directory wins. Later matches are shadowed.

Directory existence, not the presence of `version`, determines a raw match.
Any operation needing a recipe version MUST then:

1. read the first line of `version` into `VERSION` and `RELEASE`;
2. fail if the read fails or `RELEASE` is empty; and
3. require `build` to exist and be executable.

The installed-database fallback permits installed or orphaned recipes to be
resolved even when no repository contains the package.

Pseudocode:

```text
resolve(P, search_path = KISS_PATH, test = is_directory):
    for base in split_colon(search_path):
        if base is not empty and test(base / P): return base / P
    if test(DB / P): return DB / P
    fail "not found"
```

### 5.2 Search queries

`search` performs pathname-pattern expansion of `BASE/QUERY` for every
`KISS_PATH` element and then `DB`. It does **not** implicitly surround the
query with `*`. The user supplies and normally quotes any pattern:

```sh
kiss search 'lib*'
```

Every matching directory is printed, one path per line in the same lexical
form as its repository base, in repository order and pathname-expansion order.
Search does not deduplicate shadowed packages. With no query arguments, the
command produces no output. A literal nonmatching pattern is a failure (“not
found”), not an empty successful result.

### 5.3 Binary cache lookup

After resolving the current recipe version and release, the preferred archive
for `P` is:

```text
BINARIES/P@VERSION-RELEASE.tar.KISS_COMPRESS
```

If it does not exist, use the first pathname-expansion match of:

```text
BINARIES/P@VERSION-RELEASE.tar.*
```

If neither exists, the package is not cached. Lookup is tied to the currently
resolved recipe version and release; an archive for another version is not a
match.

## 6. Package metadata and binary archive format

Repository recipe files (`version`, `build`, `sources`, `checksums`, `depends`,
package-local hooks, and `nostrip`) are defined normatively in the
[KISS port format](port-format.md). This section defines only metadata generated
by the package manager and the resulting binary archive.

### 6.1 Generated `manifest`

Every binary package contains:

```text
/var/db/kiss/installed/P/manifest
```

The file lists every installed file, symlink, and directory, one absolute
root-relative path per line. Directory paths end in `/`. Records are unique
and reverse-sorted using the process locale so that contents precede their
parent directories during removal.

Generation MUST include the manifest itself and, if DESTDIR contains `/etc`,
the generated `etcsums`. It MUST include the copied recipe metadata. It MUST
exclude all non-directory entries whose basename is `charset.alias` or ends
in `.la`. The reference archive still contains these excluded staging files,
but manifest-driven installation does not install them.

Paths MUST be absolute, normalized, remain beneath root when joined, and MUST
NOT contain newline, NUL, `..` components, or an empty non-leading component.
An implementation SHOULD reject an unsafe manifest or archive before running
hooks or modifying root.

### 6.2 Generated `etcsums`

If the staged package contains `/etc`, metadata contains `etcsums`. It has one
checksum per non-directory manifest entry beneath `/etc`, in manifest order.
Each checksum is the 66-character BLAKE3 digest generated by `b3sum -l 33`.
The digest of `/dev/null` is used for a symlink entry.

Legacy installed `etcsums` records with length 64 are interpreted using
SHA-256. Digest length, not a database version marker, selects the algorithm.

### 6.3 Binary archive

A built archive is named:

```text
P@VERSION-RELEASE.tar.COMPRESSION
```

It is a compressed POSIX-compatible tar stream of `.` from DESTDIR, including
the embedded `var/db/kiss/installed/P` metadata tree. Supported compressors are:

| Value | Creation command behavior |
|---|---|
| `bz2` | `bzip2 -c` |
| `gz` | `gzip -c` |
| `lz` | `lzip -c` |
| `lzma` | `lzma -cT0` |
| `xz` | `xz -cT0` |
| `zst` | `zstd -cT0` |

Installation recognizes `.tar` as uncompressed, `.tbz`/`.bz2`, `.lz`,
`.tgz`/`.gz`, `.lzma`, `.xz`/`.txz`, and `.zst` by filename suffix.

The archive filename determines package identity during direct archive
installation: take its basename and remove the suffix beginning with the last
`@`. The embedded metadata directory and manifest paths MUST use that same
identity. The reference does not otherwise verify filename version against the
embedded `version` file.

## 7. Command-line interface

### 7.1 Actions

- **`a`, `alternatives`** (0, 2, or stdin mode): List or swap alternatives.
- **`b`, `build`** (0+): Build packages and dependencies.
- **`c`, `checksum`** (0+): Download eligible sources and regenerate
  checksums.
- **`d`, `download`** (0+): Acquire sources.
- **`H`, `help-ext`** (arguments ignored): List executable extensions.
- **`i`, `install`** (0+): Install cached or explicitly named archives.
- **`l`, `list`** (0+): List installed package versions.
- **`p`, `preferred`** (0 or 1 effective): Show active owners of paths having
  alternatives.
- **`r`, `remove`** (0+): Remove installed packages.
- **`s`, `search`** (0+): Search repository and database paths.
- **`u`, `update`** (arguments ignored): Update repositories.
- **`U`, `upgrade`** (arguments ignored): Build and install changed packages.
- **`v`, `version`** (arguments ignored): Print `6.2.0`.

With no action, usage information is printed and the command succeeds. Extra
arguments to actions marked “ignored” do not alter reference behavior.

### 7.2 Argument validation and current-directory default

For `build`, `checksum`, `download`, `list`, and `remove`, package arguments
MUST reject `!`, `*`, `[`, `]`, space, `/`, and newline. `install` rejects the
same set except that `/` is allowed so archive paths can be supplied.

For `alternatives` and `preferred`, only the first argument is checked and it
rejects `*`, `!`, `[`, `]`, space, `/`, and newline. The alternative path is
therefore allowed to contain `/`.

`search` deliberately accepts pathname patterns and receives no such
validation.

When `build`, `checksum`, `download`, `install`, or `remove` has no package
argument, the basename of the current directory is used as the package and its
parent directory is prepended to `KISS_PATH`. `list` with no arguments instead
lists all installed packages.

Before removal resolution, `DB` is prepended to `KISS_PATH`, ensuring removal
uses installed dependency metadata rather than a changed repository recipe.

### 7.3 Ordering explicit arguments

For package-taking commands, explicit package names are topologically ordered
using their resolved `depends` files. Only packages explicitly present on the
command line remain in this initial command list; discovered dependencies are
used to order them, not automatically added here. Removal traverses the
resulting explicit list in reverse, so explicit dependents are removed before
their dependencies.

A standard archive argument containing `@` and matching `*@*.tar.*` is treated
as an archive during ordering. A relative standard archive argument is
converted to an absolute path using the invocation working directory. An
absolute or relative argument containing `/` but not matching that pattern is
rejected. A bare current-directory filename matching `*.tar.*` but lacking `@`
survives ordering as a package-shaped argument and is nevertheless recognized
as an archive by the installer; its whole basename becomes its package identity.

### 7.4 Privilege escalation

`alternatives` in swap mode, `install`, and `remove` require the identity that
owns root. If `LOGNAME` is not the owner reported for root, the whole action is
re-executed using the selected `KISS_SU` command as that owner.

The child receives a restricted environment containing `LOGNAME`, `HOME`,
`XDG_CACHE_HOME`, the relevant KISS variables, recursion variables, and the
original action and arguments. Read-only alternatives listing does not
escalate.

An implementation MAY use native privilege APIs instead, but hooks and all
root mutations MUST execute with equivalent authority.

### 7.5 Extensions

An unrecognized action `X` resolves the first executable matching `kiss-X*`
by searching `PATH` in order, then executes it with the remaining arguments.
The action name itself is not passed. The child receives `_KISS_LVL=0` and an
empty `KISS_PID` so it can invoke KISS as a new top-level operation.

`help-ext` finds executable `kiss-*` files in `PATH`, keeps the first of each
basename, and prints the extension name with the comment text from its second
line.

## 8. Dependency resolution

Use a depth-first, postorder traversal. Repository shadowing applies to every
node. Missing dependency recipes are fatal when their version or build is
eventually required.

```text
visit(P, ancestors):
    if P is already emitted: return
    if P is in ancestors: fail with a circular-dependency error
    if dependency filtering is active and P is implicit and installed: return
    for each noncomment dependency D in P/depends, in file order:
        visit(D, ancestors + P)
    emit P
```

The implementation MUST deduplicate packages by package name. Given a valid
DAG, dependencies appear before dependents and the relative order is the
postorder induced by explicit argument order and each `depends` file.

Build resolution differs from the initial command-ordering pass:

- without `KISS_FORCE=1`, recursively add missing implicit dependencies;
- an installed implicit dependency is filtered out;
- an explicit package is never filtered merely because it is installed;
- `KISS_FORCE=1` skips the build dependency-resolution pass entirely;
- dependencies shared by multiple explicit packages are emitted once;
- an explicit package that is also a dependency of another explicit package is
  treated as implicit for the final explicit-install prompt.

The installed status check is directory existence only. Dependency versions
are not constrained by the format.

## 9. Source acquisition, verification, and extraction

### 9.1 Resolution and cache names

For package `P` and optional destination `D`:

- a remote file URL `U` is cached as `SOURCES/P/D/basename(U)`;
- a git URL `git+U[@REF|#REF]` is cached as the directory
  `SOURCES/P/D/basename(U-without-ref)/`;
- an already cached remote file is treated as a local cached file;
- local relative paths resolve against the recipe directory;
- local directories resolve as their contents (`DIR/.`).

The destination hierarchy is created as needed. Cache writes for remote files
MUST download to a temporary file and rename only after success, so an
interruption does not leave a seemingly valid partial cache entry.

Downloader mappings are:

| Downloader basename | Arguments before destination and URL |
|---|---|
| `aria2c` | `-d / -o` |
| `axel` | `-o` |
| `curl` | `-fLo` |
| `wget`, `wget2` | `-O` |

A git cache is initialized when necessary, its `origin` URL is set, and these
operations are performed:

```sh
git fetch --depth=1 origin REF
git reset --hard FETCH_HEAD
```

An empty `REF` requests the remote default head.

### 9.2 Source hooks

For every physical line of `sources`, including blank and comment records, run:

1. external `pre-source P SOURCE_FIELD`;
2. acquisition if applicable;
3. external `post-source P SOURCE_FIELD RESOLVED_SOURCE`.

`SOURCE_FIELD` is the parsed first field, not the complete physical line; the
optional destination is not passed to these hooks.

For a newly fetched source, `RESOLVED_SOURCE` is the destination cache path.
For an already local or cached source it is the resolved local path. A hook
failure is fatal.

### 9.3 Command differences

- `download` fetches both remote files and git sources and validates that local
  sources exist. It does not verify checksums.
- `checksum` fetches remote files, does not fetch git repositories, hashes all
  eligible file sources, and replaces `checksums` when at least one digest
  exists. The reference writes this file directly rather than through an
  atomic rename.
- `build` first acquires sources for every queued package, then verifies every
  queued package, before starting the first build. This prevents a late source
  failure after earlier packages have already built.

Verification recomputes all eligible BLAKE3 digests and compares source and
checksum record counts as well as values. Any missing, extra, obsolete
SHA-256, or mismatching record is fatal unless the expected record is `SKIP`.
When there are no checksum-eligible sources, verification does not read or
validate an existing `checksums` file.

### 9.4 Extraction

Before extracting a package with `sources`, run external:

```text
pre-extract P STAGE/P
```

Each source is then placed into `BUILD/P/DESTINATION`:

- git cache contents are recursively copied;
- local directory contents are recursively copied;
- non-archive files are copied as entries;
- recognized tar archives are decompressed and extracted.

Archive recognition covers `.tar`, `.tar.??`, `.tar.???`, `.tar.????`, and
`.t?z`. After extraction, every top-level directory in the source archive is
stripped by moving or copying its children one level upward. This is equivalent
to applying `--strip-components=1` independently to top-level directories,
while retaining top-level files. Multiple sources accumulate in the same
build tree in source order and later copies may replace earlier entries.

## 10. Build command and package production

### 10.1 Queue formation

`build` accepts explicit packages, resolves missing dependencies as section 8
specifies, and reports explicit and implicit sets. If implicit packages enlarge
the queue, it requests confirmation. `KISS_PROMPT=0` auto-continues.

Queue order is deepest dependencies first, then dependents. Before downloading,
for each implicit package whose current archive exists in `BINARIES`, install
that archive with `KISS_FORCE=1` and remove the package from the build queue.
Explicit packages are rebuilt even when cached, except during `upgrade`, which
sets cache preference for every changed package.

### 10.2 Per-queue preparation

For all remaining queue entries, in order:

1. acquire sources;
2. verify sources when `sources` exists.

Only after every queued package passes these steps does compilation begin.

### 10.3 Per-package build pipeline

For each remaining package, in queue order:

1. resolve and validate its recipe version and executable build file;
2. run external `queue-status P INDEX TOTAL`;
3. if `sources` exists, run the extraction procedure;
4. create `BUILD/P` and `STAGE/P/var/db/kiss/installed`;
5. run external `pre-build P BUILD/P`;
6. create the build log and run the build script;
7. recursively copy the recipe directory into
   `STAGE/P/var/db/kiss/installed/P`;
8. run external `post-build P STAGE/P`;
9. generate the manifest;
10. strip eligible objects unless disabled;
11. repair runtime dependency metadata;
12. generate `etcsums`;
13. create the binary archive;
14. run external `post-package P ARCHIVE`;
15. install the archive immediately when `P` is implicit or the build is part
    of an upgrade.

There is no independent “DESTDIR must contain a payload file” check. Metadata
itself makes the archive nonempty; a package with no non-metadata payload can
therefore build successfully.

### 10.4 Build process environment

The build script runs from `BUILD/P`, with standard output and standard error
combined, displayed on the terminal, and copied to the build log. It receives:

```text
AR=${AR:-ar}
CC=${CC:-cc}
CXX=${CXX:-c++}
NM=${NM:-nm}
RANLIB=${RANLIB:-ranlib}
RUSTFLAGS="--remap-path-prefix=$PWD=. ${RUSTFLAGS}"
GOFLAGS="-trimpath -modcacherw ${GOFLAGS}"
GOPATH=$PWD/go
KISS_ROOT=<normalized root>
```

Other inherited variables remain available. On failure, run external
`build-fail P BUILD/P`; failure of this failure hook is ignored. Retain the log,
clean according to `KISS_DEBUG`, and fail the build.

On success, remove the log unless `KISS_KEEPLOG=1`.

### 10.5 Manifest and stripping

Manifest generation follows section 6.1. Stripping then examines only
non-symlink entries matching a descendant of `bin`, `sbin`, `lib`, or a
`lib` directory with two through four additional characters. It identifies
ELF/AR type from the first 18 bytes:

- relocatable ELF objects and AR archives: `strip -g -R .comment -R .note`;
- executable or shared-object ELF: `strip -s -R .comment -R .note`.

Stripping changes payload files but not manifest membership. `nostrip` in
`BUILD/P` or `KISS_STRIP=0` skips the operation.

### 10.6 Automatic runtime dependency repair

The package manager scans manifested, non-symlink files in the same `bin`,
`sbin`, and `lib*` locations. It obtains dynamic dependencies with configured
`readelf` plus `ldd`, or with `ldd` alone.

Files with an absolute `RPATH` or `RUNPATH` are ignored. Paths beginning with
literal `$ORIGIN` or `${ORIGIN}` are relative and do not trigger this ignore.
For each unique required library:

1. resolve its root-relative path, canonicalizing an existing parent;
2. ignore a library supplied by the package being built;
3. ignore loader, libc, libc++, GCC runtime, and POSIX library names enumerated
   by the reference implementation;
4. find its owner by exact match across installed manifests;
5. append that owner as a runtime dependency if found.

The exact ignored basenames are:

```text
ld-* lib[cm].so* libc++.so* libc++abi.so* libcrypt.so* libdl.so*
libgcc_s.so* libmvec.so* libpthread.so* libresolv.so* librt.so*
libstdc++.so* libtrace.so* libunwind.so* libutil.so* libxnet.so* ldd
```

Existing recipe dependencies and discovered owners are combined, sorted by
their first field, and deduplicated by that field. A nonempty result always
replaces the embedded `depends`, and the manifest is regenerated so a newly
created file is included. A textual diff is displayed only when content
changed.

### 10.7 Archive creation

Archive creation and naming follow section 6.3. A compression or archive error
is fatal. After success, `post-package` observes the final archive path.

### 10.8 Installation after build

Every built implicit dependency is immediately installed with
`KISS_FORCE=1`. During upgrade, every built changed package is likewise
installed immediately.

After an ordinary build, explicitly built packages are offered for installation
only when both of the following are true:

- build-install mode is enabled (ordinary `build`, not `upgrade`); and
- `KISS_PROMPT` is exactly `1` after applying its default of `1`.

If so, a successful confirmation installs all remaining explicit packages.
If `KISS_PROMPT=0`, this final install offer and install are skipped; the
explicit archives remain in `BINARIES`.

## 11. Installation and upgrade of an archive

### 11.1 Archive selection and staging

A package-name argument selects its current binary cache entry as in section
5.3. An argument ending in `.tar.*` names that file directly. Missing files or
uncached packages are fatal.

The archive is decompressed into `EXTRACT/P`. Before any root mutation, a
regular file at:

```text
EXTRACT/P/var/db/kiss/installed/P/manifest
```

is required. Without `KISS_FORCE=1`, every manifest record MUST name an entry
that exists in the extracted tree (symlinks count even when dangling), and all
runtime dependencies MUST already be installed.

Make dependencies are not required at binary-install time. The reference
line matcher also fails to recognize a runtime dependency whose package name
is only one character; portable repositories SHOULD avoid such names when
binary dependency enforcement is required. With
`KISS_FORCE=1`, manifest-entry validation and dependency validation are
skipped. Archive extraction and the presence of the manifest remain required.

Before failing dependency validation, the reference prints each missing
runtime dependency to standard output as `PACKAGE TYPE`; `TYPE` is empty for
the valid runtime form, so the line contains a trailing space.

Run external `pre-install P EXTRACT/P` after validation and before conflicts or
root mutation.

### 11.2 Conflict detection

Conflict detection compares the new archive's non-directory manifest paths to
all installed manifests except `DB/P/manifest`. Before comparison, each path's
parent directory is physically canonicalized when it exists, so ownership
through a symlinked directory is detected.

Only manifest ownership conflicts count. An unowned live file does not cause a
conflict and may be overwritten. A missing file still conflicts when an
installed manifest claims it.

When conflicts exist:

- conflicts involving a path under `/var/db/kiss/installed/` are never safely
  convertible and MUST fail;
- if `KISS_CHOICE` is exactly `1`, installation MUST fail;
- otherwise each conflicting new payload file is moved inside the extracted
  package to `var/db/kiss/choices/P>path>components`, and the new manifest is
  regenerated. The currently installed provider remains active.

The reference conflict scanner depends on `grep` prefixing matches with their
manifest filename. With exactly one other installed manifest to compare,
`grep` omits that prefix; automatic conversion then cannot split the owner from
the path and aborts before root mutation. Reference-exact mode MUST reproduce
this single-comparison-manifest failure. Two or more comparison manifests use
the conversion algorithm above.

`KISS_FORCE` does not disable conflict handling.

### 11.3 Install/update algorithm

Interrupt and normal-exit cleanup traps are disabled immediately after archive
selection, before extraction, manifest/dependency validation, `pre-install`,
and conflict processing. They remain disabled through root mutation. Thus an
interrupt is ignored in this entire region, and a validation, hook, conflict,
or file-operation failure in it can leave `EXTRACT` or other process data.

Save copies of the old manifest and `etcsums`, using empty files for a new
install. Compute `OLD_ONLY` as exact old-manifest records absent from the new
manifest. Sort the new manifest in ascending order so parent directories are
created before children.

Then perform exactly these logical passes:

```text
install_or_replace(all new manifest entries)
remove(old entries not in new manifest)
install_if_missing(all new manifest entries)
```

The third pass repairs paths inadvertently removed by the old/new difference.
Directories already present are retained. New directories are created with the
staged directory's ordinary rwx and sticky permissions; setuid/setgid bits are
not reproduced by the reference permission conversion.

For a non-symlink file, copy to a unique temporary name in the destination
directory, preserve its timestamp, then atomically rename it over the target.
For a symlink target, use a non-dereferencing copy that replaces the existing
entry. File copies use the effective process umask, do not preserve archive
ownership, and may clear setuid/setgid bits; normal installs run with enough
authority that the resulting owner is normally root. A directory at a required
file path is not overwritten or treated as fatal; it is left in place even
though the new manifest claims that path.

The metadata tree is installed by the same manifest-driven process. There is
no later independent database registration step.

If any pass fails, report that the filesystem is dirty and fail; automatic
rollback is not required. On success, restore traps, run the package-local
`post-install`, then external `post-install P DB/P`.

### 11.4 `/etc` three-way merge

For each new non-directory `/etc` entry, compare:

- `OLD`: the next checksum from the previously installed `etcsums`, if any;
- `SYS`: the current live file checksum, if any;
- `NEW`: the extracted package file checksum.

`etcsums` does not store pathnames. The reference consumes its old records
positionally while traversing the **new** manifest's `/etc` entries. Therefore
`OLD` is the checksum for the same path only when the old and new ordered
`/etc` path sequences remain aligned. A reference-exact implementation MUST
preserve this positional behavior; an implementation offering a safer merge
mode MAY instead zip the old manifest's `/etc` paths to its checksums and look
up by path, but that mode is not reference-exact.

Use the algorithm selected by the old checksum length: 64 means SHA-256;
otherwise BLAKE3. Apply the first matching rule:

1. If `OLD == NEW`, keep the live file and do not copy the packaged file.
2. If `SYS == OLD`, install `NEW` over the live file.
3. If `SYS == NEW`, install `NEW` as an idempotent replacement.
4. If there is no `OLD` and no live file, install `NEW`.
5. If there is no `OLD` and the live file equals `NEW`, install `NEW`.
6. Otherwise, keep the live file and install the package copy as `PATH.new`.

This protects a locally modified configuration when the package also changes
its version. A pre-existing `.new` is replaced. The old checksum stream is
consumed in manifest `/etc` entry order.

## 12. Alternatives and preferred providers

### 12.1 Storage representation

An inactive alternative for package `P` and absolute path `/usr/bin/x` is
stored as:

```text
CHOICES/P>usr>bin>x
```

Every `/` in `P + PATH` is replaced with `>`, except the leading slash is
represented by the separator after the package name. Choice-eligible package
names and paths MUST NOT contain `>` or newline.

The package manifest owning an inactive choice contains its choice database
path:

```text
/var/db/kiss/choices/P>usr>bin>x
```

The active provider's manifest contains `/usr/bin/x`.

### 12.2 Listing

`kiss alternatives` with no argument prints each stored choice as:

```text
P /usr/bin/x
```

one per entry in pathname-expansion order. When `CHOICES` is absent or empty,
the reference's unmatched pathname pattern is treated literally and it prints
the compatibility quirk `* /*`. A reference-exact implementation MUST
reproduce this record. An implementation MAY suppress it only in an explicitly
documented corrected-behavior mode.

### 12.3 Swapping

Swap mode is either:

```sh
kiss alternatives P /usr/bin/x
```

or `kiss alternatives -`, which reads whitespace-separated `P PATH` records
from standard input and swaps each in order.

The requested package MUST be installed and its encoded choice file MUST exist
as a regular file or symlink. If an active regular file or symlink-to-file is
present:

1. find its current manifest owner; an unowned active file is fatal;
2. copy it without dereferencing to the current owner's encoded choice path,
   preserving timestamps for non-symlinks;
3. replace the active path in the current owner's manifest with the choice
   path.

Then move the requested choice to the active root path and replace its choice
path in the requested package's manifest with the active path. Rewritten
manifests are reverse-sorted.

### 12.4 Preferred command

`preferred` lists active paths that also have at least one inactive choice,
joined against installed manifests. Output records are:

```text
P /usr/bin/x
```

With a package argument, only that installed package's manifest is inspected;
the package must exist. With no argument, every installed manifest is
inspected. Extra arguments are ignored. With an empty `DB`, the reference
succeeds with no data records but may emit a `grep` diagnostic for the literal
unmatched `*/manifest` pattern. If `DB` itself is absent, changing into it
fails and so does the command.

## 13. Removal

Removal uses installed recipes and processes explicitly requested packages in
reverse dependency order. After confirming that `DB/P` exists, it disables
interrupt and exit traps **before** removability checks and keeps them disabled
through hooks and file removal. A removability or hook failure can therefore
leave process data, and interrupts are ignored. Traps are restored only after
the manifest traversal succeeds.

Unless `KISS_FORCE=1`, package `P` is removable only when:

1. no installed `depends` file contains a line exactly equal to `P`; entries
   `P make` do not block removal; and
2. `preferred P` produces no records, because removing an active provider with
   inactive alternatives would leave those alternatives orphaned.

Then:

1. run package-local `pre-remove`;
2. run external `pre-remove P DB/P`;
3. copy installed `etcsums` for aligned reading;
4. traverse `DB/P/manifest` in its stored order;
5. remove unmodified files and empty directories;
6. restore traps and report success.

There is no post-remove hook.

For each non-directory `/etc` path, hash the live file using the algorithm
selected by its installed checksum record. Remove it only if the digest equals
the recorded package digest. A modified configuration is retained and a
message is printed. Other files and symlinks are removed without checking live
content. Directories are removed only if empty.

As during installation, removal consumes checksum records positionally. Full
package removal normally aligns with the installed manifest. During upgrade,
however, removal is given only the old-only manifest subset but starts at the
first old checksum, so old-only configuration paths can be compared with the
wrong record. In addition, the reference's removal pattern does not recognize
a one-character path directly beneath `/etc` (for example `/etc/a`) as a
configuration file; it removes that path without a checksum check and does not
advance the checksum stream. These behaviors are required for reference-exact
mode and SHOULD be covered by compatibility tests.

Directory symlinks below the first path level are queued until other entries
have been processed, then removed only if broken. Because the manifest includes
the installed metadata tree, normal removal deletes `DB/P` and thereby clears
installed state. Inactive choice files owned by the package are also removed
through the manifest.

`KISS_FORCE=1` skips both reverse-dependency and orphaned-alternative checks; it
does not change file or configuration removal rules.

## 14. Remaining commands

### 14.1 `checksum`

For each ordered explicit package, acquire non-git sources, generate the
eligible BLAKE3 records defined in section 6 of the KISS port format, and
replace the repository `checksums`. A package with no `sources`, or with no
eligible sources, succeeds without creating or changing a checksum file.

### 14.2 `download`

For each ordered explicit package, resolve its recipe and acquire all sources.
Cached remote files are not redownloaded. Git caches are fetched/reset each
time. Checksums are not verified.

### 14.3 `list`

With no arguments, expand `DB/*` and process entries in pathname-expansion
order. With arguments, process their dependency-ordered explicit list. For each
package, resolve only in `DB`, validate `version` and executable `build`, and
print:

```text
P VERSION-RELEASE
```

A requested package that is not installed is fatal; it is not printed as a
soft “not installed” result. When `DB` exists but contains no package
directories, the reference treats the unmatched `DB/*` pattern as a literal
package named `*` and fails with “not found”; reference-exact mode MUST retain
that quirk. An absent `DB` fails in the same way.

### 14.4 `update`

Split `KISS_PATH` on `:`. For each nonempty entry:

1. if it is within a Git worktree with a configured upstream, resolve it to the
   superproject worktree when present, otherwise to the top-level worktree;
2. if it is a non-Git existing directory, retain it for hooks and MOTD but do
   not run an update command;
3. skip nonexistent entries;
4. canonicalize by changing into the resulting root and process each distinct
   root once.

For each retained repository root:

1. determine its filesystem owner;
2. run external `pre-update NEED_SU OWNER` with the repository as working
   directory, where `NEED_SU` is `0` for the current owner and `1` otherwise;
3. for Git, print whether `merge.verifySignatures=true`, then run `git pull`
   and `git submodule update --remote --init -f`, as the owner when needed;
4. run external `post-update` in the repository;
5. if readable `MOTD` exists, print it.

The command does not run `upgrade` automatically.

### 14.5 `upgrade`

For every directory in `DB`, resolve the installed version from `DB` and the
available version through normal `KISS_PATH` lookup. If no repository contains
the package, fallback resolution selects its installed recipe and it is
reported as an orphan.

An available package is changed when:

```text
INSTALLED_VERSION-INSTALLED_RELEASE != REPO_VERSION-REPO_RELEASE
```

There is no greater-than comparison: repository downgrades and release changes
are processed. For each changed package print:

```text
P OLD_VERSION-OLD_RELEASE => NEW_VERSION-NEW_RELEASE
```

If `kiss` itself is changed, confirm, build/install it first, stop, and instruct
the user to rerun update. Otherwise dependency-order all changed packages,
confirm the list, and invoke the build pipeline with cache preference and
immediate installation enabled. If no package changed, succeed without a build.

### 14.6 `version`

Print exactly:

```text
6.2.0
```

followed by newline.

## 15. External hooks

The complete external event names, argument vectors, failure behavior, and
working-directory rules are defined by the [external hook interface](hooks.md).
Sections 9 through 14 of this document define where those events occur in each
operation. The hook interface controls if a summary here or an algorithmic
comment is ambiguous.

## 16. Error, output, and safety requirements

### 16.1 Exit status

Successful commands return zero. A lookup, validation, dependency, conflict,
checksum, hook, build, download, archive, update, permission, or required
filesystem failure returns nonzero. Multi-package commands stop at the first
fatal error; already completed earlier operations are not rolled back.

### 16.2 Data output

These standard-output formats are stable and MUST be reproduced:

- `list`: `P VERSION-RELEASE`;
- `search`: one matching directory path;
- `alternatives`: `P PATH`;
- `preferred`: `P PATH`;
- `upgrade`: `P OLD => NEW` for each changed package;
- `version`: `6.2.0`.

Build-script output is both displayed and logged. Helper commands such as
`strip` may also be echoed to standard output. All ordinary progress, warning,
and error messages SHOULD use standard error.

### 16.3 Security baseline

Although the reference predates several common package-hardening expectations,
a new implementation SHOULD:

- open archive entries without following paths outside `EXTRACT/P`;
- reject absolute archive member names and `..` traversal;
- validate every manifest join remains beneath root;
- avoid following a hostile symlink when creating destination parents;
- use exclusive temporary files and same-directory atomic rename;
- avoid shell evaluation of recipe fields, package names, source URLs, and
  manifest records;
- retain the reference behavior only for valid, non-hostile package archives.

These checks are compatible because unsafe archives and metadata are invalid
inputs under this specification.

## 17. High-level implementation architecture

A practical implementation can be divided into the following components:

1. **Configuration and paths**: normalize environment values once and expose
   typed paths for database, choices, caches, and the per-process workspace.
2. **Repository resolver**: perform ordered, non-indexed lookup. Do not cache a
   result across an operation that can update repositories.
3. **Metadata parser**: implement line-oriented parsers that retain source-file
   order and distinguish runtime from `make` dependencies.
4. **Dependency planner**: use a three-color DFS (`unseen`, `visiting`, `done`)
   for deterministic postorder and immediate cycle detection.
5. **Source store**: key cache entries by package, optional destination, and
   source basename; download through temporary files and rename.
6. **Build runner**: use separate build and DESTDIR trees, stream combined build
   output to terminal and log, then produce metadata in the required order.
7. **Archive reader/writer**: stage before installation, validate containment,
   and drive installation from the embedded manifest rather than walking the
   archive.
8. **Ownership view**: build an in-memory `path -> package` map by scanning
   manifests for conflict and alternative operations. The filesystem manifests
   remain authoritative; the map is disposable, not a new database.
9. **Installer**: model new entries, old-only entries, and positional `etcsums`
   as explicit streams. Use atomic replacement per regular file.
10. **Hook runner**: centralize event argument construction and test the exact
    event sequence independently.

Do not introduce a persistent resolver index, dependency database, or ownership
database as a source of truth. Such caches MAY exist only when they can always
be discarded and rebuilt from repository and installed files.

## 18. Conformance verification matrix

An implementation claiming conformance MUST be tested in an isolated root and
cache. At minimum, the suite SHOULD cover the following independent cases:

- **Repository shadowing:** First `KISS_PATH` recipe wins; installed recipe is
  fallback only.
- **Search:** User glob is honored, no implicit substring wildcards, and
  duplicates are retained.
- **Installed identity:** Directory existence satisfies dependency checks;
  `list` additionally requires valid recipe metadata.
- **Dependency DAG:** A diamond graph deduplicates, file order is deterministic,
  a cycle fails, and installed implicit dependencies are filtered.
- **Explicit ordering:** Multiple explicit packages are topologically ordered;
  removal reverses them.
- **Sources:** Remote, cached, git ref, relative and absolute files and
  directories, destination, comment, and blank records.
- **Checksums:** 66-hex success, `SKIP`, missing and extra records, mismatch,
  and legacy 64-character rejection.
- **Extraction:** Top-level archive directory stripping, retained top-level
  file, multiple sources, and destination subdirectories.
- **Build environment:** Two build arguments, working directory, tool defaults,
  log retention, failure hook, and `nostrip`.
- **Manifest:** Metadata and self inclusion, directory suffixes, reverse order,
  and `.la` and `charset.alias` exclusion.
- **Runtime dependency repair:** An owned shared library is added once;
  self-owned, system-library, and absolute-RPATH cases are ignored.
- **Binary cache:** Preferred compressor match, fallback compressor match, and
  wrong-version miss.
- **Initial install:** Manifest-driven files and metadata appear, with correct
  post-install hook order and arguments.
- **Missing dependency:** A runtime dependency blocks non-forced install, a
  `make` dependency does not, and force bypasses validation.
- **Upgrade:** Common files replace atomically, old-only files disappear, and
  the second pass restores required paths.
- **`/etc` merge:** Unchanged old, locally modified, package modified, both
  modified, pre-existing unowned, absent, `.new`, positional misalignment, and
  one-character removal cases.
- **Ownership conflict:** An owned conflict fails at `KISS_CHOICE=1`; other
  values create an inactive choice when at least two manifests are compared.
  Verify the one-manifest quirk and unowned-live-file replacement.
- **Alternative swap:** Both manifests and physical representations exchange
  correctly; an unowned active path fails.
- **Preferred/removal:** The active provider is reported and blocks removal;
  force bypasses the block.
- **Removal:** A runtime dependent blocks removal, a make dependent does not,
  modified configuration remains, and unmodified configuration and metadata
  disappear.
- **Update:** Git roots and superprojects deduplicate, a non-Git repository
  receives hooks and MOTD, and the ownership-escalation flag is correct.
- **Upgrade comparison:** Any version/release inequality, including downgrade,
  is selected; orphans are not rebuilt, and `kiss` updates alone first.
- **Prompts:** `KISS_PROMPT=0` auto-continues dependency prompts but leaves
  ordinary explicit build results uninstalled.
- **Hooks:** Every external event, argument vector, working directory, order,
  and fatal or nonfatal failure path.
- **Cleanup:** Top-level, recursive, debug, success, failure, and `SIGINT`
  temporary-directory behavior.
- **Extensions:** The first executable `PATH` match runs without the action
  argument; help deduplicates names.
- **Empty databases:** `list` fails on literal `*`, `alternatives` emits `* /*`,
  and `preferred` emits no data record.

A strong black-box harness should snapshot root, cache, hook trace, stdout,
stderr category, and exit status before and after each case. Run filesystem-order
sensitive tests under `LC_ALL=C`; separately verify that the implementation
does not hard-code a different collation when another locale is inherited.
