#!/bin/sh
# Differential conformance harness for KISS-compatible command-line programs.
#
# Internal portable-core runner.  Use conformance/run.sh instead.
# CASE is `version', `list-installed', `list-all', `list-empty',
# `search-shadowing', `search-pattern', `list-missing', `remove-missing',
# `remove-installed', `remove-missing-live-file', `remove-shared-directory',
# `remove-blocked-dependent', `remove-make-dependent',
# `remove-active-alternative',
# `install-archive', `install-missing-dependency', `upgrade-payload',
# `install-hooks', `remove-hooks', `alternatives-list', or `preferred-active'.
# Implementations are executable paths (not shell fragments).  They receive
# KISS_ROOT, KISS_PATH, XDG_CACHE_HOME, HOME, and KISS_PROMPT=0.

set -u

usage() {
    echo "usage: $0 REFERENCE CANDIDATE [CASE ...]" >&2
    exit 2
}

[ "$#" -ge 2 ] || usage
reference=$1
candidate=$2
shift 2

[ -x "$reference" ] || { echo "reference is not executable: $reference" >&2; exit 2; }
[ -x "$candidate" ] || { echo "candidate is not executable: $candidate" >&2; exit 2; }

if [ "$#" -eq 0 ]; then
    set -- version list-installed list-all list-empty search-shadowing \
        search-pattern search-nonmatch search-installed-fallback list-missing \
        remove-missing remove-installed \
        remove-missing-live-file remove-shared-directory \
        remove-blocked-dependent remove-active-alternative install-archive \
        install-invalid-archive install-missing-manifest \
        install-missing-dependency \
        install-conflict-choice-zero build-recipe upgrade-payload \
        install-hooks remove-hooks \
        install-hook-failure remove-hook-failure \
        alternatives-list preferred-active
    if command -v b3sum >/dev/null 2>&1; then
        set -- "$@" etc-install-first etc-install-unowned \
            etc-upgrade-unmodified etc-upgrade-modified \
            etc-remove-unmodified etc-remove-modified
    fi
    if command -v gzip >/dev/null 2>&1; then
        set -- "$@" install-gzip
    fi
    if command -v bzip2 >/dev/null 2>&1; then
        set -- "$@" install-bzip2
    fi
    if command -v xz >/dev/null 2>&1; then
        set -- "$@" install-xz
    fi
    if command -v lzma >/dev/null 2>&1; then
        set -- "$@" install-lzma
    fi
    if command -v zstd >/dev/null 2>&1; then
        set -- "$@" install-zstd
    fi
fi

make_recipe() {
    recipe=$1
    version=$2
    mkdir -p "$recipe"
    printf '%s 1\n' "$version" > "$recipe/version"
    printf '#!/bin/sh\nexit 0\n' > "$recipe/build"
    chmod 755 "$recipe/build"
}

make_build_recipe() {
    recipe=$1
    mkdir -p "$recipe"
    printf '1 1\n' > "$recipe/version"
    cat > "$recipe/build" <<'EOF'
#!/bin/sh
set -eu
mkdir -p "$1/usr/bin"
printf 'built payload\n' > "$1/usr/bin/demo"
EOF
    chmod 755 "$recipe/build"
}

make_installed_demo() {
    root=$1
    db="$root/var/db/kiss/installed/demo"
    mkdir -p "$root/usr/bin" "$db"
    printf 'payload\n' > "$root/usr/bin/demo"
    printf '1 1\n' > "$db/version"
    printf '#!/bin/sh\nexit 0\n' > "$db/build"
    chmod 755 "$db/build"
    # Manifest order is children before directories, as required by removal.
    cat > "$db/manifest" <<'EOF'
/var/db/kiss/installed/demo/version
/var/db/kiss/installed/demo/manifest
/var/db/kiss/installed/demo/build
/var/db/kiss/installed/demo/
/var/db/kiss/installed/
/var/db/kiss/
/var/db/
/var/
/usr/bin/demo
/usr/bin/
/usr/
EOF
}

make_archive() {
    fixture=$1
    name=$2
    version=$3
    payload=$4
    dependency=${5-}
    stage="$fixture/stage-$name"
    db="$stage/var/db/kiss/installed/$name"
    archive="$fixture/$name.tar"
    mkdir -p "$stage/usr/bin" "$db"
    printf '%s\n' "$payload" > "$stage/usr/bin/$name"
    printf '%s 1\n' "$version" > "$db/version"
    printf '#!/bin/sh\nexit 0\n' > "$db/build"
    chmod 755 "$db/build"
    if [ -n "$dependency" ]; then
        printf '%s\n' "$dependency" > "$db/depends"
    fi
    # The manifest is generated from precisely the tar staging tree, including
    # metadata.  Depth-first order puts children before parent directories.
    (
        cd "$stage" || exit 1
        find . -depth -print | while IFS= read -r path; do
            [ "$path" = . ] && continue
            relative=${path#./}
            if [ -d "$path" ]; then
                printf '/%s/\n' "$relative"
            else
                printf '/%s\n' "$relative"
            fi
        done > "$db/manifest"
        tar -cf "$archive" .
    )
}

make_conflict_archive() {
    fixture=$1
    stage="$fixture/stage-alpha"
    db="$stage/var/db/kiss/installed/alpha"
    archive="$fixture/alpha.tar"
    mkdir -p "$stage/usr/bin" "$db"
    printf 'alpha\n' > "$stage/usr/bin/tool"
    printf '1 1\n' > "$db/version"
    printf '#!/bin/sh\nexit 0\n' > "$db/build"
    chmod 755 "$db/build"
    write_manifest "$stage" "$db/manifest"
    (cd "$stage" && tar -cf "$archive" .)
}

make_missing_manifest_archive() {
    fixture=$1
    stage="$fixture/stage-incomplete"
    mkdir -p "$stage/usr/bin"
    printf 'not a KISS package\n' > "$stage/usr/bin/demo"
    (cd "$stage" && tar -cf "$fixture/incomplete.tar" .)
}

make_conflict_owner() {
    root=$1
    db="$root/var/db/kiss/installed/beta"
    mkdir -p "$root/usr/bin" "$db"
    printf 'beta\n' > "$root/usr/bin/tool"
    printf '1 1\n' > "$db/version"
    printf '#!/bin/sh\nexit 0\n' > "$db/build"
    chmod 755 "$db/build"
    write_manifest "$root" "$db/manifest"
}

make_trace_hook() {
    fixture=$1
    cat > "$fixture/hook" <<'EOF'
#!/bin/sh
printf '%s|%s\n' "$*" "$PWD" >> "$KISS_CONFORMANCE_HOOK_TRACE"
EOF
    chmod 755 "$fixture/hook"
    : > "$fixture/hook.trace"
}

make_failing_hook() {
    fixture=$1
    cat > "$fixture/hook" <<'EOF'
#!/bin/sh
printf '%s|%s\n' "$*" "$PWD" >> "$KISS_CONFORMANCE_HOOK_TRACE"
exit 1
EOF
    chmod 755 "$fixture/hook"
    : > "$fixture/hook.trace"
}

make_shared_directory_state() {
    root=$1
    alpha="$root/var/db/kiss/installed/alpha"
    beta="$root/var/db/kiss/installed/beta"
    mkdir -p "$root/usr/share/common" "$alpha" "$beta"
    printf 'alpha\n' > "$root/usr/share/common/alpha"
    printf 'beta\n' > "$root/usr/share/common/beta"
    for db in "$alpha" "$beta"; do
        printf '1 1\n' > "$db/version"
        printf '#!/bin/sh\nexit 0\n' > "$db/build"
        chmod 755 "$db/build"
    done
    cat > "$alpha/manifest" <<'EOF'
/var/db/kiss/installed/alpha/version
/var/db/kiss/installed/alpha/manifest
/var/db/kiss/installed/alpha/build
/var/db/kiss/installed/alpha/
/var/db/kiss/installed/
/var/db/kiss/
/var/db/
/var/
/usr/share/common/alpha
/usr/share/common/
/usr/share/
/usr/
EOF
    cat > "$beta/manifest" <<'EOF'
/var/db/kiss/installed/beta/version
/var/db/kiss/installed/beta/manifest
/var/db/kiss/installed/beta/build
/var/db/kiss/installed/beta/
/var/db/kiss/installed/
/var/db/kiss/
/var/db/
/var/
/usr/share/common/beta
/usr/share/common/
/usr/share/
/usr/
EOF
}

write_manifest() {
    tree=$1
    manifest=$2
    (
        cd "$tree" || exit 1
        find . -depth -print | while IFS= read -r path; do
            [ "$path" = . ] && continue
            relative=${path#./}
            if [ -d "$path" ]; then
                printf '/%s/\n' "$relative"
            else
                printf '/%s\n' "$relative"
            fi
        done > "$manifest"
    )
}

make_etc_archive() {
    fixture=$1
    version=$2
    contents=$3
    stage="$fixture/stage-demo"
    db="$stage/var/db/kiss/installed/demo"
    archive="$fixture/demo.tar"
    mkdir -p "$stage/etc" "$db"
    printf '%s\n' "$contents" > "$stage/etc/demo.conf"
    printf '%s 1\n' "$version" > "$db/version"
    printf '#!/bin/sh\nexit 0\n' > "$db/build"
    chmod 755 "$db/build"
    b3sum -l 33 "$stage/etc/demo.conf" | awk '{print $1}' > "$db/etcsums"
    write_manifest "$stage" "$db/manifest"
    (cd "$stage" && tar -cf "$archive" .)
}

make_installed_etc() {
    root=$1
    contents=$2
    db="$root/var/db/kiss/installed/demo"
    mkdir -p "$root/etc" "$db"
    printf '%s\n' "$contents" > "$root/etc/demo.conf"
    printf '1 1\n' > "$db/version"
    printf '#!/bin/sh\nexit 0\n' > "$db/build"
    chmod 755 "$db/build"
    b3sum -l 33 "$root/etc/demo.conf" | awk '{print $1}' > "$db/etcsums"
    write_manifest "$root" "$db/manifest"
}

make_orphan_alternative_state() {
    root=$1
    provider="$root/var/db/kiss/installed/provider"
    other="$root/var/db/kiss/installed/other"
    choice="$root/var/db/kiss/choices/provider>usr>bin>tool"
    mkdir -p "$root/usr/bin" "$provider" "$other" "$(dirname "$choice")"
    printf 'provider\n' > "$root/usr/bin/tool"
    printf 'other\n' > "$choice"
    for db in "$provider" "$other"; do
        printf '1 1\n' > "$db/version"
        printf '#!/bin/sh\nexit 0\n' > "$db/build"
        chmod 755 "$db/build"
    done
    cat > "$provider/manifest" <<'EOF'
/var/db/kiss/installed/provider/version
/var/db/kiss/installed/provider/manifest
/var/db/kiss/installed/provider/build
/var/db/kiss/installed/provider/
/usr/bin/tool
/usr/bin/
/usr/
EOF
    cat > "$other/manifest" <<'EOF'
/var/db/kiss/choices/provider>usr>bin>tool
/var/db/kiss/installed/other/version
/var/db/kiss/installed/other/manifest
/var/db/kiss/installed/other/build
/var/db/kiss/installed/other/
EOF
}

setup_case() {
    fixture=$1
    case_name=$2
    root=$fixture/root
    cache=$fixture/cache
    repo_a=$fixture/repo-a
    repo_b=$fixture/repo-b
    mkdir -p "$root" "$cache" "$repo_a" "$repo_b"
    : > "$fixture/hook.trace"
    case "$case_name" in
        version)
            case_args=version
            ;;
        list-installed)
            # `list' resolves only the installed database.  Put a complete
            # installed recipe in its redirected root and compare its stable
            # machine-readable output.
            make_recipe "$root/var/db/kiss/installed/demo" 1
            case_args='list demo'
            ;;
        list-all)
            make_recipe "$root/var/db/kiss/installed/alpha" 1
            make_recipe "$root/var/db/kiss/installed/demo" 2
            case_args=list
            ;;
        list-empty)
            case_args=list
            ;;
        search-shadowing)
            make_recipe "$repo_a/demo" 1
            make_recipe "$repo_b/demo" 2
            case_args='search demo'
            ;;
        search-pattern)
            make_recipe "$repo_a/demo" 1
            make_recipe "$repo_a/delta" 1
            make_recipe "$repo_a/other" 1
            # This must reach the implementation as a literal argv element,
            # rather than being expanded by the harness shell.
            case_args='search d*'
            ;;
        search-nonmatch)
            make_recipe "$repo_a/demo" 1
            case_args='search absent'
            ;;
        search-installed-fallback)
            make_recipe "$root/var/db/kiss/installed/demo" 1
            case_args='search demo'
            ;;
        list-missing)
            case_args='list missing'
            ;;
        remove-missing)
            case_args='remove missing'
            ;;
        remove-installed)
            make_installed_demo "$root"
            case_args='remove demo'
            ;;
        remove-missing-live-file)
            make_installed_demo "$root"
            rm -f "$root/usr/bin/demo"
            case_args='remove demo'
            ;;
        remove-shared-directory)
            make_shared_directory_state "$root"
            case_args='remove alpha'
            ;;
        remove-blocked-dependent)
            make_installed_demo "$root"
            consumer="$root/var/db/kiss/installed/consumer"
            mkdir -p "$consumer"
            printf '1 1\n' > "$consumer/version"
            printf '#!/bin/sh\nexit 0\n' > "$consumer/build"
            chmod 755 "$consumer/build"
            printf 'demo\n' > "$consumer/depends"
            case_args='remove demo'
            ;;
        remove-make-dependent)
            make_installed_demo "$root"
            consumer="$root/var/db/kiss/installed/consumer"
            mkdir -p "$consumer"
            printf '1 1\n' > "$consumer/version"
            printf '#!/bin/sh\nexit 0\n' > "$consumer/build"
            chmod 755 "$consumer/build"
            # Build-time dependencies do not keep an installed provider live.
            printf 'demo make\n' > "$consumer/depends"
            case_args='remove demo'
            ;;
        remove-active-alternative)
            make_orphan_alternative_state "$root"
            case_args='remove provider'
            ;;
        alternatives-list)
            make_orphan_alternative_state "$root"
            case_args=alternatives
            ;;
        preferred-active)
            make_orphan_alternative_state "$root"
            case_args='preferred provider'
            ;;
        etc-upgrade-unmodified)
            command -v b3sum >/dev/null 2>&1 || return 77
            make_installed_etc "$root" old
            make_etc_archive "$fixture" 2 new
            case_args="install $fixture/demo.tar"
            ;;
        etc-install-first)
            command -v b3sum >/dev/null 2>&1 || return 77
            make_etc_archive "$fixture" 1 initial
            case_args="install $fixture/demo.tar"
            ;;
        etc-install-unowned)
            command -v b3sum >/dev/null 2>&1 || return 77
            mkdir -p "$root/etc"
            printf 'administrator\n' > "$root/etc/demo.conf"
            make_etc_archive "$fixture" 1 initial
            case_args="install $fixture/demo.tar"
            ;;
        etc-upgrade-modified)
            command -v b3sum >/dev/null 2>&1 || return 77
            make_installed_etc "$root" old
            printf 'local\n' > "$root/etc/demo.conf"
            make_etc_archive "$fixture" 2 new
            case_args="install $fixture/demo.tar"
            ;;
        etc-remove-unmodified)
            command -v b3sum >/dev/null 2>&1 || return 77
            make_installed_etc "$root" old
            case_args='remove demo'
            ;;
        etc-remove-modified)
            command -v b3sum >/dev/null 2>&1 || return 77
            make_installed_etc "$root" old
            printf 'local\n' > "$root/etc/demo.conf"
            case_args='remove demo'
            ;;
        install-archive)
            make_archive "$fixture" demo 1 payload
            case_args="install $fixture/demo.tar"
            ;;
        install-invalid-archive)
            printf 'not a package archive\n' > "$fixture/bad.tar"
            case_args="install $fixture/bad.tar"
            ;;
        install-missing-manifest)
            make_missing_manifest_archive "$fixture"
            case_args="install $fixture/incomplete.tar"
            ;;
        install-gzip)
            command -v gzip >/dev/null 2>&1 || return 77
            make_archive "$fixture" demo 1 payload
            gzip -c "$fixture/demo.tar" > "$fixture/demo.tar.gz"
            case_args="install $fixture/demo.tar.gz"
            ;;
        install-bzip2)
            command -v bzip2 >/dev/null 2>&1 || return 77
            make_archive "$fixture" demo 1 payload
            bzip2 -c "$fixture/demo.tar" > "$fixture/demo.tar.bz2"
            case_args="install $fixture/demo.tar.bz2"
            ;;
        install-xz)
            command -v xz >/dev/null 2>&1 || return 77
            make_archive "$fixture" demo 1 payload
            xz -c "$fixture/demo.tar" > "$fixture/demo.tar.xz"
            case_args="install $fixture/demo.tar.xz"
            ;;
        install-lzma)
            command -v lzma >/dev/null 2>&1 || return 77
            make_archive "$fixture" demo 1 payload
            lzma -c "$fixture/demo.tar" > "$fixture/demo.tar.lzma"
            case_args="install $fixture/demo.tar.lzma"
            ;;
        install-zstd)
            command -v zstd >/dev/null 2>&1 || return 77
            make_archive "$fixture" demo 1 payload
            zstd -q -c "$fixture/demo.tar" > "$fixture/demo.tar.zst"
            case_args="install $fixture/demo.tar.zst"
            ;;
        install-missing-dependency)
            make_archive "$fixture" dependent 1 payload required
            case_args="install $fixture/dependent.tar"
            ;;
        install-conflict-choice-zero)
            make_conflict_owner "$root"
            make_conflict_archive "$fixture"
            printf '0\n' > "$fixture/choice"
            case_args="install $fixture/alpha.tar"
            ;;
        build-recipe)
            make_build_recipe "$repo_a/demo"
            make_trace_hook "$fixture"
            case_args='build demo'
            ;;
        upgrade-payload)
            make_installed_demo "$root"
            mkdir -p "$root/usr/share/demo"
            printf 'obsolete\n' > "$root/usr/share/demo/obsolete"
            # Add old-only payload and directories to the old manifest.
            cat >> "$root/var/db/kiss/installed/demo/manifest" <<'EOF'
/usr/share/demo/obsolete
/usr/share/demo/
/usr/share/
EOF
            make_archive "$fixture" demo 2 replacement
            case_args="install $fixture/demo.tar"
            ;;
        install-hooks)
            make_archive "$fixture" demo 1 payload
            make_trace_hook "$fixture"
            case_args="install $fixture/demo.tar"
            ;;
        install-hook-failure)
            make_archive "$fixture" demo 1 payload
            make_failing_hook "$fixture"
            case_args="install $fixture/demo.tar"
            ;;
        remove-hooks)
            make_installed_demo "$root"
            make_trace_hook "$fixture"
            case_args='remove demo'
            ;;
        remove-hook-failure)
            make_installed_demo "$root"
            make_failing_hook "$fixture"
            case_args='remove demo'
            ;;
        *)
            echo "unknown conformance case: $case_name" >&2
            return 2
            ;;
    esac
    printf '%s\n' "$case_args" > "$fixture/args"
}

snapshot_tree() {
    tree=$1
    [ -d "$tree" ] || return 0
    (
        cd "$tree" || exit 1
        # Case fixtures intentionally use portable pathnames without newlines.
        # Record entry type, mode, link target, and file checksum; directory
        # timestamps and archive byte layout are deliberately not observable.
        find . -print | LC_ALL=C sort | while IFS= read -r path; do
            if [ -L "$path" ]; then
                printf 'link %s %s %s\n' "$path" "$(ls -ld "$path" | awk '{print $1}')" "$(readlink "$path")"
            elif [ -d "$path" ]; then
                printf 'dir %s %s\n' "$path" "$(ls -ld "$path" | awk '{print $1}')"
            elif [ -f "$path" ]; then
                set -- $(cksum "$path")
                printf 'file %s %s %s %s\n' "$path" "$(ls -ld "$path" | awk '{print $1}')" "$1" "$2"
            else
                printf 'other %s\n' "$path"
            fi
        done
    )
}

run_implementation() {
    implementation=$1
    fixture=$2
    physical_fixture=$(cd "$fixture" && pwd -P)
    args=$(cat "$fixture/args")
    # Cases use only arguments without whitespace.  This is intentional: the
    # harness operates at the executable argv boundary, not through eval.
    # Disable pathname expansion while decoding the deliberately
    # whitespace-free fixture argv representation.  Pattern tests therefore
    # exercise the implementation's lookup grammar, not the harness shell.
    set -f
    set -- $args
    if [ -x "$fixture/hook" ]; then
        hook_path=$fixture/hook
    else
        hook_path=
    fi
    if [ -f "$fixture/choice" ]; then
        choice=$(cat "$fixture/choice")
    else
        choice=
    fi
    KISS_ROOT="$fixture/root" \
    KISS_PATH="$fixture/repo-a:$fixture/repo-b" \
    XDG_CACHE_HOME="$fixture/cache" \
    HOME="$fixture/home" \
    KISS_PROMPT=0 \
    KISS_CHOICE="$choice" \
    KISS_HOOK="$hook_path" \
    KISS_CONFORMANCE_HOOK_TRACE="$fixture/hook.trace" \
    "$implementation" "$@" >"$fixture/stdout" 2>"$fixture/stderr"
    printf '%s\n' "$?" > "$fixture/status"
    # Path-producing commands necessarily mention their fixture.  Normalize
    # that private prefix only; implementations must still agree on all path
    # components and output ordering beneath it.
    # Build workspaces include a process identifier.  It is intentionally
    # private to each invocation, so normalize just that component after
    # replacing the fixture prefix; all stable hook arguments still compare
    # exactly.
    sed -E -e "s|$physical_fixture|<fixture>|g" \
        -e "s|$fixture|<fixture>|g" \
        -e 's|<fixture>/cache/kiss/proc/[0-9]+|<fixture>/cache/kiss/proc/<pid>|g' \
        "$fixture/stdout" > "$fixture/stdout.normalized"
    sed -E -e "s|$physical_fixture|<fixture>|g" \
        -e "s|$fixture|<fixture>|g" \
        -e 's|<fixture>/cache/kiss/proc/[0-9]+|<fixture>/cache/kiss/proc/<pid>|g' \
        "$fixture/hook.trace" > "$fixture/hook.trace.normalized"
    snapshot_tree "$fixture/root" > "$fixture/root.snapshot"
}

tmp_parent=${TMPDIR:-/tmp}
tmp_parent=${tmp_parent%/}
temporary_base=$(mktemp -d "$tmp_parent/kiss-conformance.XXXXXX") || exit 1
trap 'rm -rf "$temporary_base"' EXIT HUP INT TERM
failed=0
passed=0
skipped=0
failed_cases=

for case_name do
    ref_fixture=$temporary_base/reference-$case_name
    cand_fixture=$temporary_base/candidate-$case_name
    setup_case "$ref_fixture" "$case_name"
    setup_status=$?
    if [ "$setup_status" -eq 77 ]; then
        printf 'skip %s (missing capability)\n' "$case_name"
        skipped=$((skipped + 1))
        continue
    fi
    [ "$setup_status" -eq 0 ] || exit "$setup_status"
    setup_case "$cand_fixture" "$case_name" || exit $?
    run_implementation "$reference" "$ref_fixture"
    run_implementation "$candidate" "$cand_fixture"

    if cmp -s "$ref_fixture/status" "$cand_fixture/status" &&
       cmp -s "$ref_fixture/stdout.normalized" "$cand_fixture/stdout.normalized" &&
       cmp -s "$ref_fixture/hook.trace.normalized" "$cand_fixture/hook.trace.normalized" &&
       cmp -s "$ref_fixture/root.snapshot" "$cand_fixture/root.snapshot"; then
        printf 'ok %s\n' "$case_name"
        passed=$((passed + 1))
    else
        printf 'not ok %s\n' "$case_name" >&2
        diff -u "$ref_fixture/status" "$cand_fixture/status" || true
        diff -u "$ref_fixture/stdout.normalized" "$cand_fixture/stdout.normalized" || true
        diff -u "$ref_fixture/hook.trace.normalized" "$cand_fixture/hook.trace.normalized" || true
        diff -u "$ref_fixture/root.snapshot" "$cand_fixture/root.snapshot" || true
        printf '%s\n' "  reference stderr: $ref_fixture/stderr" >&2
        printf '%s\n' "  candidate stderr: $cand_fixture/stderr" >&2
        failed=$((failed + 1))
        failed_cases="${failed_cases}${failed_cases:+ }${case_name}"
    fi
done

printf '\nconformance: %d passed, %d failed, %d skipped\n' \
       "$passed" "$failed" "$skipped"
if [ "$failed" -eq 0 ]; then
    printf 'conformance: PASS\n'
else
    printf 'conformance: FAIL (failed cases: %s)\n' "$failed_cases" >&2
fi

exit "$failed"
