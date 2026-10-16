#!/bin/sh
# Unified differential conformance entry point for KISS implementations.
#
# Usage: conformance/run.sh REFERENCE CANDIDATE [CASE ...]
# With no CASE arguments, runs both the portable core and extended suites.

set -u

usage() {
    echo "usage: $0 REFERENCE CANDIDATE [CASE ...]" >&2
    exit 2
}

[ "$#" -ge 2 ] || usage
reference=$1
candidate=$2
shift 2

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

# Keep the individual fixture engines small and independently useful, while
# presenting their union as one conformance suite.  Case names are stable API.
core_cases='version list-installed list-all list-empty search-shadowing search-pattern search-nonmatch search-installed-fallback list-missing remove-missing remove-installed remove-missing-live-file remove-shared-directory remove-blocked-dependent remove-make-dependent remove-active-alternative alternatives-list preferred-active etc-install-first etc-install-unowned etc-upgrade-unmodified etc-upgrade-modified etc-remove-unmodified etc-remove-modified install-archive install-invalid-archive install-missing-manifest install-gzip install-bzip2 install-xz install-lzma install-zstd install-missing-dependency install-conflict-choice-zero build-recipe upgrade-payload install-hooks remove-hooks install-hook-failure remove-hook-failure'
extended_cases='usage-no-action version-alias list-alias list-multiple list-order invalid-argument search-multi search-empty-args install-named install-plain-tar install-named-gz install-named-bz2 install-named-xz install-named-zst install-relative install-hooks-named install-cache-name install-cache-fallback install-not-built install-force-missing-dep install-make-dep install-one-char-dep install-manifest-missing-file install-multiple-order upgrade-named upgrade-common-dir etc-first-named etc-unowned-named etc-same-old-new etc-upgrade-unmodified-named etc-upgrade-modified-named etc-new-replaced etc-symlink conflict-two-manifests conflict-choice-one conflict-single-manifest conflict-db-path conflict-unowned-live-file alternatives-swap alternatives-swap-stdin alternatives-missing alternatives-empty preferred-all preferred-missing remove-force remove-multiple-order remove-dir-symlink remove-etc-one-char remove-pre-remove-pkg-hook-skip build-deps build-deps-installed build-cached-dep build-circular build-force-nodeps build-sources-local build-sources-tar build-checksum-skip build-checksum-mismatch build-checksum-sha256 build-checksum-missing-file build-depends-sorted build-nostrip build-default-cwd build-prompt-install build-etc build-la-exclusion checksum-generate checksum-no-sources download-local download-comment-lines upgrade-command upgrade-nothing upgrade-orphan update-plain-repo extension extension-missing help-ext build-remote-source download-remote-cached checksum-remote build-git-source download-git-ref update-git-repo'

contains_case() {
    case " $1 " in *" $2 "*) return 0 ;; *) return 1 ;; esac
}

run_suite() {
    runner=$1
    shift
    [ "$#" -eq 0 ] && return 0
    "$script_dir/$runner" "$reference" "$candidate" "$@"
}

if [ "$#" -eq 0 ]; then
    # Pass the inventories explicitly: the core runner's historical default
    # predates `remove-make-dependent`, which must be part of this suite too.
    set -f
    set -- $core_cases
    "$script_dir/core.sh" "$reference" "$candidate" "$@" || exit $?
    set -- $extended_cases
    exec "$script_dir/extended.sh" "$reference" "$candidate" "$@"
fi

core_selected=
extended_selected=
for case_name do
    if contains_case "$core_cases" "$case_name"; then
        core_selected="${core_selected}${core_selected:+ }${case_name}"
    elif contains_case "$extended_cases" "$case_name"; then
        extended_selected="${extended_selected}${extended_selected:+ }${case_name}"
    else
        echo "unknown conformance case: $case_name" >&2
        exit 2
    fi
done

# Fixture arguments are intentionally whitespace-free, so this preserves the
# executable argv boundary used by both runners.
set -f
if [ -n "$core_selected" ]; then
    set -- $core_selected
    run_suite core.sh "$@" || exit $?
fi
if [ -n "$extended_selected" ]; then
    set -- $extended_selected
    run_suite extended.sh "$@" || exit $?
fi
