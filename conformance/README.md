# KISS differential conformance suite

`run.sh` compares two KISS-compatible command-line implementations against
fresh, independent fixtures.  It never uses the live package database, caller
cache, network, or privilege escalation.

```sh
./conformance/run.sh /tmp/kiss/kiss /path/to/other-kiss
./conformance/run.sh /tmp/kiss/kiss /path/to/other-kiss version
```

Each implementation must be an executable path that honors the standard KISS
CLI and these environment variables: `KISS_ROOT`, `KISS_PATH`,
`XDG_CACHE_HOME`, `HOME`, and `KISS_PROMPT=0`.  Hook cases additionally set a
single fixture-local `KISS_HOOK`.  It compares command exit status,
specification-defined stdout, normalized hook traces, and a normalized snapshot
of the resulting `KISS_ROOT`.  Stderr is retained for diagnostics but is not
compared, because progress wording is intentionally non-normative.

Every run ends with a `PASS` or `FAIL` summary, its passed/failed/skipped
counts, and—on failure—the stable names of every failed case.

Built-in cases are deliberately small and portable:

- `version`: command output and status;
- `list-installed`: an installed recipe yields the specified list record.
- `list-all` and `list-empty`: no-argument listing is stable for populated
  and empty installed databases;
- `search-shadowing`: ordered `KISS_PATH` search retains the first match;
- `search-pattern`: a literal wildcard reaches the implementation and selects
  repository names using its documented lookup grammar;
- `search-nonmatch` and `search-installed-fallback`: lookup reports an absent
  name consistently and searches the installed database after repositories;
- `list-missing`: an unresolved installed-package query fails without state
  mutation;
- `remove-missing`: removal of an absent package fails without state mutation;
- `remove-installed`: manifest-driven package removal deletes payload and
  package database state.
- `remove-missing-live-file` and `remove-shared-directory`: removal remains
  safe when an owned file was already deleted and preserves directories still
  owned by another package;
- `remove-blocked-dependent`: a runtime dependency prevents removal without
  mutating the installed package;
- `remove-make-dependent`: a make-only dependency does not block removal of
  an installed provider;
- `remove-active-alternative`: removal of an active provider with an inactive
  choice is refused, preventing an orphaned alternative;
- `alternatives-list` and `preferred-active`: choice-store records resolve to
  stable active-provider output;
- `etc-install-*`, `etc-upgrade-*`, and `etc-remove-*`: the BLAKE3 `/etc`
  checksum handshake covers new, unowned, unchanged, and locally modified
  configuration. These cases skip when `b3sum` is unavailable;
- `install-archive`: a locally generated binary archive installs payload and
  embedded metadata;
- `install-invalid-archive`: a non-archive with an archive-like name fails
  without mutating the redirected root;
- `install-missing-manifest`: a syntactically valid tar without KISS package
  metadata fails without mutating the redirected root;
- `install-gzip`, `install-bzip2`, `install-xz`, `install-lzma`, and
  `install-zstd`: supported compressed forms install with the same observable
  result. Each skips when its compressor is unavailable;
- `install-missing-dependency`: a required runtime dependency blocks archive
  installation before root mutation;
- `install-conflict-choice-zero`: an archive conflict does not overwrite an
  installed provider when the portable noninteractive `KISS_CHOICE=0` policy
  is selected;
- `build-recipe`: a no-source local recipe stages deterministic payload and
  exercises build lifecycle hooks without a sandbox, network, or live root;
- `upgrade-payload`: installation of a newer archive replaces common payload
  and removes old-only manifest entries;
- `install-hooks` and `remove-hooks`: fixture-local traces compare external
  hook event order, arguments, and working directory.
- `install-hook-failure` and `remove-hook-failure`: a failing external hook is
  observable and its failure handling leaves the same state as the reference.

To add a case, extend `setup_case` in `run.sh` with only temporary fixture
files, select its argument vector, and rely on the existing comparison loop.
Add root snapshots for mutations and exact stdout only when the KISS spec makes
that output machine-consumable.  Avoid network URLs, host paths, interactive
prompts, and implementation-specific extensions.

The public runner combines a portable core suite (`core.sh`) with the extended
suite (`extended.sh`).  Run one or more stable case names to select only those
cases; with no case names it runs their complete union.  The internal runners
remain separately executable for fixture-engine development, but new callers
should always use `run.sh`.

The extended suite incorporates the former Hiss cases: named-package archive
handling, cache lookup, source/download/checksum paths, dependency graphs,
configuration merge edge cases, conflict resolution, alternatives, command
aliases, extensions, and local Git update fixtures. Its fixtures also compare
repository and cache state where those commands make it observable.

The suite is opt-in.  Implementation-local unit tests remain standalone and
do not require a reference KISS executable.
