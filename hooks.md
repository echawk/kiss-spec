# External hook interface

## 1. Scope

This document is the normative interface for external hooks configured through
the colon-separated `KISS_HOOK` environment variable. Package-local
`post-install` and `pre-remove` recipe files are a different mechanism defined
by section 8 of the KISS port format.

Every nonempty `KISS_HOOK` entry is invoked in list order. The first argument
is the event type. Hook standard input, output, and error are inherited. A
nonzero status aborts the operation, except that failure of a `build-fail` hook
is ignored because the build is already failing.

Hook entries are expected to be absolute executable paths. The reference does
not prevalidate them; attempted execution failure is fatal.

## 2. Events

- **`pre-source P SOURCE_FIELD`** - Before each source acquisition.
- **`post-source P SOURCE_FIELD RESOLVED_SOURCE`** - After each source
  acquisition.
- **`pre-extract P STAGE/P`** - Before extracting sources.
- **`pre-build P BUILD/P`** - Immediately before the build script.
- **`build-fail P BUILD/P`** - After build-script failure.
- **`post-build P STAGE/P`** - After recipe copy and before manifest
  generation.
- **`queue-status P INDEX TOTAL`** - At the start of a queued package build.
- **`post-package P ARCHIVE`** - After final archive creation.
- **`pre-install P EXTRACT/P`** - After archive validation and before conflict
  conversion.
- **`post-install P DB/P`** - After files and the package-local hook are
  installed.
- **`pre-remove P DB/P`** - After removability checks and before file deletion.
- **`pre-update NEED_SU OWNER`** - In each repository before update.
- **`post-update`** - In each repository after update.
- **`SIGINT`** - On a handled interrupt while traps are enabled.
- **`SIGEXIT`** - On process exit while traps are enabled, after cleanup.

`SOURCE_FIELD` is the parsed first field from a `sources` record; the optional
destination is not passed. `RESOLVED_SOURCE` is the cache destination for a
new download and the local resolved path for an existing source.

The `pre-update` and `post-update` hooks run with the repository as the current
directory. `NEED_SU` is `0` when the current user owns the repository and `1`
when privilege escalation is needed to update as `OWNER`.

## 3. Ordering guarantees

The operation algorithms in sections 9 through 14 of the package-manager
specification define the complete hook sequence. In particular:

- `post-install` runs after the package-local `post-install` hook;
- both pre-remove hooks run before any manifest entry is deleted;
- `post-package` observes the final archive path; and
- `SIGEXIT` runs after temporary-directory cleanup.
