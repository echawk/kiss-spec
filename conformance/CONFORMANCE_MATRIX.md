# KISS conformance matrix

This is the portable, implementation-neutral test plan for the KISS command
line protocol.  The executable suite lives beside this matrix in
[`conformance/`](.).

Each **implemented** row is a named case in `run.sh`. The harness runs a
reference and candidate in separate temporary roots and caches, then compares
exit status, specified stdout, external-hook trace, and a normalized root
snapshot. **Planned** rows describe the next fixture needed. **Gated** rows
need an optional executable, a controlled privilege boundary, or a local
service. No default case may contact a public host or write outside its
temporary directory.

The normative sources are the [package-manager specification](https://github.com/echawk/kiss-spec/blob/master/kiss-package-manager.md),
[port format](https://github.com/echawk/kiss-spec/blob/master/port-format.md),
and [hook interface](https://github.com/echawk/kiss-spec/blob/master/hooks.md).

## Harness contract

| Observable | Comparison |
|---|---|
| Exit result | Exact status code |
| Data output | Exact stdout after replacing the private fixture prefix |
| Filesystem | Type, permissions, symlink target, and `cksum` for every root entry |
| External hooks | Normalized event arguments and working directory |
| Diagnostics | Retained on mismatch; not compared because ordinary wording is non-normative |

## Package-manager specification

| Spec section | Requirement / scenario | Status | Harness case or next fixture |
|---|---|---|---|
| 3 | Redirected root/cache and noninteractive environment | implemented | Every case |
| 4.1–4.3 | Installed directory, manifest ownership, shared directories | partial | Listing, missing-live-file removal, and shared-directory removal; add duplicate file ownership cases |
| 4.2 | Portable package identity | planned | Invalid archive names and command argument grammar |
| 5.1 | Ordered repository lookup and installed fallback | partial | `search-shadowing`, `search-installed-fallback`; add invalid recipe lookup |
| 5.2 | Search patterns and output order | partial | Exact, literal-glob, and literal-nonmatch search; add duplicate results and empty query |
| 5.3 | Binary-cache preferred/fallback archive lookup | planned | Compressor preference, fallback suffix, wrong-version miss |
| 6.1 | Manifest shape and unsafe archive rejection | partial | Install, corrupt archive, and missing-manifest rejection; add traversal, duplicate, and malformed manifest cases |
| 6.2 | Ordered `etcsums`, legacy digest handling | partial | `etc-install-*`, `etc-upgrade-*`, `etc-remove-*`; add positional misalignment and legacy SHA-256 |
| 6.3 | Archive names and supported compression | partial | `install-archive` plus gated gzip/bzip2/xz/lzma/zstd cases; add lzip and wrong-suffix fixtures |
| 7 | Commands, aliases, argument validation, current-directory defaults | partial | `version`, populated/empty list, search, install/remove; add aliases, defaults, bad arguments, help, extensions |
| 8 | Dependency DAG and explicit ordering | partial | Missing runtime dependency, removal block, and make-only removal; add diamond, cycle, and explicit-order cases |
| 9 | Sources, cache, checksum, extraction | planned | Local file/directory/tar fixtures, git ref fixture, checksum mismatch and `SKIP` |
| 10 | Build command, staged package, logs, strip, prompt | partial | Minimal no-source build and lifecycle-hook case; add failure hook, `nostrip`, cache use, and build/install prompt cases |
| 11.1–11.2 | Archive validation and ownership conflicts | partial | Invalid archive, missing dependency, and no-choice ownership conflict; add malformed metadata and interactive-choice fixtures |
| 11.3 | Install and upgrade passes | partial | `install-archive`, `upgrade-payload`; add common-file atomic replacement and directory/file edge cases |
| 11.4 | `/etc` three-way merge | partial | First/unowned install and unmodified/modified upgrade/removal; add `.new` and misalignment fixtures |
| 12 | Alternatives and preferred providers | partial | `alternatives-list`, `preferred-active`, removal blocker; add swap and stdin mode |
| 13 | Removal | partial | Remove success, missing live files, shared directories, runtime/make-only dependency behavior, active-alternative block, external hooks, `/etc`; add force and directory-symlink cases |
| 14.1 | Checksum command | planned | Local source regeneration and `SKIP` replacement |
| 14.2 | Download command | planned | Cached local/remote and local Git server fixture |
| 14.3 | List output and empty database behavior | partial | `list-installed`, `list-all`, `list-empty`, `list-missing`; add compatibility extensions if required |
| 14.4 | Repository update | planned | Local Git upstream, submodule, non-Git hooks/MOTD, owner flag |
| 14.5 | Upgrade selection | planned | Opaque version downgrade, release-only change, orphan, `kiss` first |
| 14.6 | Version output | implemented | `version` |
| 15 / hooks 2–3 | External event arguments, order, failure | partial | Install/remove event traces and failure paths; add all remaining event families |
| 16 | Failure exit, data output, path safety | partial | Every differential status/root comparison; add hostile paths and multi-package stop behavior |

## Port-format specification

| Section | Requirement / scenario | Status | Next fixture |
|---|---|---|---|
| 2 | Line-oriented metadata and whitespace rules | planned | Comments, blank records, invalid bytes, field whitespace |
| 3 | Opaque version plus decimal release | planned | Valid/invalid recipe and archive matrix |
| 4 | Executable build with DESTDIR and VERSION arguments | partial | `build-recipe` stages a payload; add explicit recorded-argument and working-directory fixture |
| 5 | Source forms and destination | planned | Relative/absolute file and directory, remote URL, Git ref, destination |
| 6 | BLAKE3 checksums and `SKIP` | gated | Requires `b3sum`; include length/mismatch/legacy tests |
| 7 | Runtime and `make` dependencies | partial | Runtime block covered; add make-only behavior and malformed records |
| 8 | Package-local hooks and `nostrip` | planned | Executable/non-executable hooks and top-level marker |

## Capability-gated cases

| Capability | Cases to add |
|---|---|
| `b3sum` | `etcsums`, source checksums, configuration removal |
| Compression tools | Each supported archive suffix and zstd magic |
| Git / Hg / Fossil | Local disposable source and update remotes |
| C toolchain and ELF inspector | Runtime dependency discovery fixture |
| Sandbox tool | `proot` / `bwrap` build execution |
| Privilege adapter | Foreign-owner update and install paths in a disposable namespace |

## Case admission rules

1. Give each scenario one stable case name and one primary spec citation.
2. Build every file, archive, repository, and hook inside the case fixture.
3. Compare only observables the specification makes stable.
4. Mark platform or helper requirements as gated and skip cleanly when absent.
5. Add a reference-versus-reference run before accepting a new case.
