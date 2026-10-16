#!/bin/sh
# Extended differential conformance cases for KISS implementations.
#
# Internal extended runner.  Use conformance/run.sh instead.
#
# This follows the shared conformance contract (fresh fixtures,
# redirected root and cache, KISS_PROMPT=0, comparison of exit status,
# stdout, hook trace, and a root snapshot) and extends it to paths that
# harness does not reach: correctly named archives, real installs and
# upgrades, /etc merges, ownership conflicts, builds with dependencies and
# sources, checksums, alternative swaps, upgrade, update, and extensions.
# In addition to the root, each case snapshots the repositories and the
# cache (sources, and the member list of every binary archive).

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
absolute() { case $1 in /*) printf '%s\n' "$1" ;; *) printf '%s/%s\n' "$PWD" "$1" ;; esac; }
reference=$(absolute "$reference")
candidate=$(absolute "$candidate")

all_cases="
usage-no-action version-alias list-alias list-multiple list-order invalid-argument
search-multi search-empty-args
install-named install-plain-tar install-named-gz install-named-bz2 install-named-xz install-named-zst
install-relative install-hooks-named install-cache-name install-cache-fallback
install-not-built install-force-missing-dep install-make-dep install-one-char-dep
install-manifest-missing-file install-multiple-order
upgrade-named upgrade-common-dir
etc-first-named etc-unowned-named etc-same-old-new etc-upgrade-unmodified-named
etc-upgrade-modified-named etc-new-replaced etc-symlink
conflict-two-manifests conflict-choice-one conflict-single-manifest conflict-db-path
conflict-unowned-live-file
alternatives-swap alternatives-swap-stdin alternatives-missing alternatives-empty
preferred-all preferred-missing
remove-force remove-multiple-order remove-dir-symlink remove-etc-one-char
remove-pre-remove-pkg-hook-skip
build-deps build-deps-installed build-cached-dep build-circular build-force-nodeps
build-sources-local build-sources-tar build-checksum-skip build-checksum-mismatch
build-checksum-sha256 build-checksum-missing-file build-depends-sorted
build-nostrip build-default-cwd build-prompt-install build-etc build-la-exclusion
checksum-generate checksum-no-sources download-local download-comment-lines
upgrade-command upgrade-nothing upgrade-orphan
update-plain-repo extension extension-missing help-ext
build-remote-source download-remote-cached checksum-remote build-git-source
download-git-ref update-git-repo
"

if [ "$#" -eq 0 ]; then
    # shellcheck disable=2086
    set -- $all_cases
fi

write_manifest() {
    tree=$1
    manifest=$2
    (
        cd "$tree" || exit 1
        find . -depth -print | while IFS= read -r path; do
            [ "$path" = . ] && continue
            relative=${path#./}
            if [ -d "$path" ] && ! [ -h "$path" ]; then
                printf '/%s/\n' "$relative"
            else
                printf '/%s\n' "$relative"
            fi
        done | LC_ALL=C sort -r > "$manifest"
    )
}

make_recipe() {
    recipe=$1
    version=$2
    mkdir -p "$recipe"
    printf '%s 1\n' "$version" > "$recipe/version"
    printf '#!/bin/sh\nexit 0\n' > "$recipe/build"
    chmod 755 "$recipe/build"
}

# make_stage FIXTURE NAME VERSION: create an archive staging tree with
# recipe metadata; payload is added by the caller before pack_stage.
make_stage() {
    stage="$1/stage-$2-$3"
    db="$stage/var/db/kiss/installed/$2"
    mkdir -p "$db"
    printf '%s 1\n' "$3" > "$db/version"
    printf '#!/bin/sh\nexit 0\n' > "$db/build"
    chmod 755 "$db/build"
}

# pack_stage FIXTURE NAME VERSION [SUFFIX] [DEST]: generate manifest and
# etcsums, then write NAME@VERSION-1.tar[SUFFIX].
pack_stage() {
    stage="$1/stage-$2-$3"
    db="$stage/var/db/kiss/installed/$2"
    out=${5:-$1}
    : > "$db/manifest"
    if [ -d "$stage/etc" ]; then
        : > "$db/etcsums"
    fi
    write_manifest "$stage" "$db/manifest"
    if [ -d "$stage/etc" ]; then
        grep '^/etc/.*[^/]$' "$db/manifest" | while IFS= read -r f; do
            if [ -h "$stage$f" ]; then
                b3sum -l 33 /dev/null
            else
                b3sum -l 33 "$stage$f"
            fi
        done | awk '{print $1}' > "$db/etcsums"
    fi
    archive="$out/$2@$3-1.tar"
    (cd "$stage" && tar -cf "$archive" .)
    case ${4:-.gz} in
        .gz) gzip -c "$archive" > "$archive.gz" && rm "$archive" ;;
        .bz2) bzip2 -c "$archive" > "$archive.bz2" && rm "$archive" ;;
        .xz) xz -c "$archive" > "$archive.xz" && rm "$archive" ;;
        .zst) zstd -q -c "$archive" > "$archive.zst" && rm "$archive" ;;
        none) ;;
    esac
}

simple_archive() {
    # simple_archive FIXTURE NAME VERSION PAYLOAD [DEPENDS] [SUFFIX]
    make_stage "$1" "$2" "$3"
    mkdir -p "$stage/usr/bin"
    printf '%s\n' "$4" > "$stage/usr/bin/$2"
    if [ -n "${5-}" ]; then
        printf '%s\n' "$5" > "$db/depends"
    fi
    pack_stage "$1" "$2" "$3" "${6-}"
}

# install_state ROOT NAME VERSION: an installed package owning /usr/bin/NAME.
install_state() {
    root=$1
    tree=$root.tmp-$2
    db="$tree/var/db/kiss/installed/$2"
    mkdir -p "$tree/usr/bin" "$db"
    printf '%s\n' "$2" > "$tree/usr/bin/$2"
    printf '%s 1\n' "$3" > "$db/version"
    printf '#!/bin/sh\nexit 0\n' > "$db/build"
    chmod 755 "$db/build"
    if [ -n "${4-}" ]; then
        printf '%s\n' "$4" > "$db/depends"
    fi
    : > "$db/manifest"
    write_manifest "$tree" "$db/manifest"
    (cd "$tree" && tar -cf - .) | (cd "$root" && tar -xf -)
    rm -rf "$tree"
}

etc_state() {
    # etc_state ROOT CONTENTS: installed demo owning /etc/demo.conf.
    root=$1
    tree=$root.tmp-etc
    db="$tree/var/db/kiss/installed/demo"
    mkdir -p "$tree/etc" "$db"
    printf '%s\n' "$2" > "$tree/etc/demo.conf"
    printf '1 1\n' > "$db/version"
    printf '#!/bin/sh\nexit 0\n' > "$db/build"
    chmod 755 "$db/build"
    : > "$db/manifest"
    : > "$db/etcsums"
    write_manifest "$tree" "$db/manifest"
    b3sum -l 33 "$tree/etc/demo.conf" | awk '{print $1}' > "$db/etcsums"
    (cd "$tree" && tar -cf - .) | (cd "$root" && tar -xf -)
    rm -rf "$tree"
}

etc_archive() {
    # etc_archive FIXTURE VERSION CONTENTS
    make_stage "$1" demo "$2"
    mkdir -p "$stage/etc"
    printf '%s\n' "$3" > "$stage/etc/demo.conf"
    pack_stage "$1" demo "$2"
}

trace_hook() {
    cat > "$1/hook" <<'EOF'
#!/bin/sh
printf '%s|%s\n' "$*" "$PWD" >> "$KISS_CONFORMANCE_HOOK_TRACE"
EOF
    chmod 755 "$1/hook"
}

build_recipe() {
    # build_recipe DIR VERSION [DEPENDS]: installs /usr/bin/NAME.
    mkdir -p "$1"
    printf '%s 1\n' "$2" > "$1/version"
    cat > "$1/build" <<'EOF'
#!/bin/sh
set -eu
name=$(basename "$(dirname "$0")")
mkdir -p "$1/usr/bin"
printf '%s %s\n' "$name" "$2" > "$1/usr/bin/$name"
printf 'cwd=%s args=%s\n' "${PWD##*/}" "$#"
EOF
    chmod 755 "$1/build"
    if [ -n "${3-}" ]; then
        printf '%s\n' "$3" > "$1/depends"
    fi
}

setup_case() {
    fixture=$1
    case_name=$2
    root=$fixture/root
    cache=$fixture/cache
    repo_a=$fixture/repo-a
    repo_b=$fixture/repo-b
    mkdir -p "$root" "$cache" "$repo_a" "$repo_b" "$fixture/bin" "$fixture/work"
    : > "$fixture/hook.trace"
    trace_hook "$fixture"
    case_cwd=$fixture/work
    case_env=
    case_stdin=/dev/null
    case "$case_name" in
        usage-no-action) case_args= ;;
        version-alias) case_args=v ;;
        list-alias)
            make_recipe "$root/var/db/kiss/installed/demo" 3
            case_args='l demo' ;;
        list-multiple)
            make_recipe "$root/var/db/kiss/installed/alpha" 1
            make_recipe "$root/var/db/kiss/installed/beta" 2
            case_args='list beta alpha' ;;
        list-order)
            # Explicit arguments are ordered with repository dependencies.
            make_recipe "$root/var/db/kiss/installed/alpha" 1
            make_recipe "$root/var/db/kiss/installed/beta" 2
            make_recipe "$repo_a/alpha" 1
            make_recipe "$repo_a/beta" 2
            printf 'beta\n' > "$repo_a/alpha/depends"
            case_args='list alpha beta' ;;
        invalid-argument) case_args='list de*mo' ;;
        search-multi)
            make_recipe "$repo_a/demo" 1
            make_recipe "$repo_b/demo" 2
            make_recipe "$repo_b/delta" 2
            make_recipe "$root/var/db/kiss/installed/demo" 1
            case_args='s demo de?ta' ;;
        search-empty-args) case_args=search ;;
        install-named)
            simple_archive "$fixture" demo 1 payload
            case_args="install $fixture/demo@1-1.tar.gz" ;;
        install-plain-tar)
            # *@*.tar.* is required: a bare .tar is "Not a package".
            simple_archive "$fixture" demo 1 payload '' none
            case_args="install $fixture/demo@1-1.tar" ;;
        install-named-gz)
            simple_archive "$fixture" demo 1 payload '' .gz
            case_args="i $fixture/demo@1-1.tar.gz" ;;
        install-named-bz2)
            simple_archive "$fixture" demo 1 payload '' .bz2
            case_args="i $fixture/demo@1-1.tar.bz2" ;;
        install-named-xz)
            simple_archive "$fixture" demo 1 payload '' .xz
            case_args="i $fixture/demo@1-1.tar.xz" ;;
        install-named-zst)
            simple_archive "$fixture" demo 1 payload '' .zst
            case_args="i $fixture/demo@1-1.tar.zst" ;;
        install-relative)
            simple_archive "$fixture" demo 1 payload
            mv "$fixture/demo@1-1.tar.gz" "$fixture/work/"
            case_args="install demo@1-1.tar.gz" ;;
        install-hooks-named)
            simple_archive "$fixture" demo 1 payload
            make_stage "$fixture" demo 1
            printf '#!/bin/sh\necho local-hook\n' > "$db/post-install"
            chmod 644 "$db/post-install"
            pack_stage "$fixture" demo 1
            case_args="install $fixture/demo@1-1.tar.gz" ;;
        install-cache-name)
            make_recipe "$repo_a/demo" 1
            mkdir -p "$cache/kiss/bin"
            simple_archive "$fixture" demo 1 payload '' .gz
            simple_archive "$fixture" demo 1 other '' .xz
            mv "$fixture/demo@1-1.tar.gz" "$fixture/demo@1-1.tar.xz" "$cache/kiss/bin/"
            case_args='install demo' ;;
        install-cache-fallback)
            make_recipe "$repo_a/demo" 1
            mkdir -p "$cache/kiss/bin"
            simple_archive "$fixture" demo 1 payload '' .xz
            simple_archive "$fixture" demo 2 wrong '' .xz
            mv "$fixture/demo@1-1.tar.xz" "$fixture/demo@2-1.tar.xz" "$cache/kiss/bin/"
            case_args='install demo' ;;
        install-not-built)
            make_recipe "$repo_a/demo" 1
            case_args='install demo' ;;
        install-force-missing-dep)
            simple_archive "$fixture" demo 1 payload required
            case_env='KISS_FORCE=1'
            case_args="install $fixture/demo@1-1.tar.gz" ;;
        install-make-dep)
            simple_archive "$fixture" demo 1 payload 'meson make'
            case_args="install $fixture/demo@1-1.tar.gz" ;;
        install-one-char-dep)
            simple_archive "$fixture" demo 1 payload 'z'
            case_args="install $fixture/demo@1-1.tar.gz" ;;
        install-manifest-missing-file)
            make_stage "$fixture" demo 1
            mkdir -p "$stage/usr/bin"
            printf 'x\n' > "$stage/usr/bin/demo"
            pack_stage "$fixture" demo 1
            rm -rf "$stage/usr/bin/demo"
            printf '/usr/bin/ghost\n' >> "$db/manifest"
            (cd "$stage" && tar -cf - . | gzip -c > "$fixture/demo@1-1.tar.gz")
            case_args="install $fixture/demo@1-1.tar.gz" ;;
        install-multiple-order)
            simple_archive "$fixture" lib 1 lib
            simple_archive "$fixture" app 1 app lib
            case_args="install $fixture/app@1-1.tar.gz $fixture/lib@1-1.tar.gz" ;;
        upgrade-named)
            install_state "$root" demo 1
            mkdir -p "$root/usr/share/demo"
            printf 'old\n' > "$root/usr/share/demo/obsolete"
            m="$root/var/db/kiss/installed/demo/manifest"
            { cat "$m"; printf '/usr/share/demo/obsolete\n/usr/share/demo/\n/usr/share/\n'; } \
                | LC_ALL=C sort -r > "$m.new" && mv "$m.new" "$m"
            simple_archive "$fixture" demo 2 new
            case_args="install $fixture/demo@2-1.tar.gz" ;;
        upgrade-common-dir)
            install_state "$root" demo 1
            install_state "$root" other 1
            make_stage "$fixture" demo 2
            mkdir -p "$stage/usr/lib/demo"
            printf 'lib\n' > "$stage/usr/lib/demo/lib.so"
            ln -s lib.so "$stage/usr/lib/demo/link.so"
            pack_stage "$fixture" demo 2
            case_args="install $fixture/demo@2-1.tar.gz" ;;
        etc-first-named)
            etc_archive "$fixture" 1 initial
            case_args="install $fixture/demo@1-1.tar.gz" ;;
        etc-unowned-named)
            mkdir -p "$root/etc"
            printf 'admin\n' > "$root/etc/demo.conf"
            etc_archive "$fixture" 1 initial
            case_args="install $fixture/demo@1-1.tar.gz" ;;
        etc-same-old-new)
            etc_state "$root" same
            printf 'local\n' > "$root/etc/demo.conf"
            etc_archive "$fixture" 2 same
            case_args="install $fixture/demo@2-1.tar.gz" ;;
        etc-upgrade-unmodified-named)
            etc_state "$root" old
            etc_archive "$fixture" 2 new
            case_args="install $fixture/demo@2-1.tar.gz" ;;
        etc-upgrade-modified-named)
            etc_state "$root" old
            printf 'local\n' > "$root/etc/demo.conf"
            etc_archive "$fixture" 2 new
            case_args="install $fixture/demo@2-1.tar.gz" ;;
        etc-new-replaced)
            etc_state "$root" old
            printf 'local\n' > "$root/etc/demo.conf"
            printf 'stale\n' > "$root/etc/demo.conf.new"
            etc_archive "$fixture" 2 new
            case_args="install $fixture/demo@2-1.tar.gz" ;;
        etc-symlink)
            make_stage "$fixture" demo 1
            mkdir -p "$stage/etc"
            printf 'conf\n' > "$stage/etc/real.conf"
            ln -s real.conf "$stage/etc/link.conf"
            pack_stage "$fixture" demo 1
            case_args="install $fixture/demo@1-1.tar.gz" ;;
        conflict-two-manifests)
            install_state "$root" beta 1
            install_state "$root" gamma 1
            make_stage "$fixture" alpha 1
            mkdir -p "$stage/usr/bin"
            printf 'alpha\n' > "$stage/usr/bin/beta"
            printf 'alpha\n' > "$stage/usr/bin/alpha"
            pack_stage "$fixture" alpha 1
            case_args="install $fixture/alpha@1-1.tar.gz" ;;
        conflict-choice-one)
            install_state "$root" beta 1
            install_state "$root" gamma 1
            make_stage "$fixture" alpha 1
            mkdir -p "$stage/usr/bin"
            printf 'alpha\n' > "$stage/usr/bin/beta"
            pack_stage "$fixture" alpha 1
            case_env='KISS_CHOICE=1'
            case_args="install $fixture/alpha@1-1.tar.gz" ;;
        conflict-single-manifest)
            install_state "$root" beta 1
            make_stage "$fixture" alpha 1
            mkdir -p "$stage/usr/bin"
            printf 'alpha\n' > "$stage/usr/bin/beta"
            pack_stage "$fixture" alpha 1
            case_args="install $fixture/alpha@1-1.tar.gz" ;;
        conflict-db-path)
            install_state "$root" beta 1
            install_state "$root" gamma 1
            make_stage "$fixture" alpha 1
            mkdir -p "$stage/var/db/kiss/installed/beta"
            printf 'x\n' > "$stage/var/db/kiss/installed/beta/version"
            pack_stage "$fixture" alpha 1
            case_args="install $fixture/alpha@1-1.tar.gz" ;;
        conflict-unowned-live-file)
            install_state "$root" beta 1
            install_state "$root" gamma 1
            mkdir -p "$root/usr/bin"
            printf 'stray\n' > "$root/usr/bin/alpha"
            simple_archive "$fixture" alpha 1 alpha
            case_args="install $fixture/alpha@1-1.tar.gz" ;;
        alternatives-swap|alternatives-swap-stdin)
            install_state "$root" provider 1
            other="$root/var/db/kiss/installed/other"
            make_recipe "$other" 1
            mkdir -p "$root/var/db/kiss/choices"
            printf 'other\n' > "$root/var/db/kiss/choices/other>usr>bin>provider"
            printf '/var/db/kiss/installed/other/version\n/var/db/kiss/installed/other/manifest\n/var/db/kiss/installed/other/build\n/var/db/kiss/installed/other/\n/var/db/kiss/choices/other>usr>bin>provider\n' \
                | LC_ALL=C sort -r > "$other/manifest"
            if [ "$case_name" = alternatives-swap ]; then
                case_args='alternatives other /usr/bin/provider'
            else
                printf 'other /usr/bin/provider\n' > "$fixture/stdin"
                case_stdin=$fixture/stdin
                case_args='a -'
            fi ;;
        alternatives-missing)
            install_state "$root" provider 1
            case_args='alternatives provider /usr/bin/none' ;;
        alternatives-empty)
            mkdir -p "$root/var/db/kiss/choices"
            case_args=alternatives ;;
        preferred-all)
            install_state "$root" provider 1
            install_state "$root" second 1
            mkdir -p "$root/var/db/kiss/choices"
            printf 'x\n' > "$root/var/db/kiss/choices/other>usr>bin>provider"
            printf 'x\n' > "$root/var/db/kiss/choices/other>usr>bin>second"
            case_args=preferred ;;
        preferred-missing)
            mkdir -p "$root/var/db/kiss/installed"
            case_args='preferred nothing' ;;
        remove-force)
            install_state "$root" demo 1
            install_state "$root" consumer 1 demo
            case_env='KISS_FORCE=1'
            case_args='remove demo' ;;
        remove-multiple-order)
            install_state "$root" lib 1
            install_state "$root" app 1 lib
            case_args='remove lib app' ;;
        remove-dir-symlink)
            tree=$fixture/tree
            db="$tree/var/db/kiss/installed/demo"
            mkdir -p "$tree/usr/lib/real" "$db"
            printf 'x\n' > "$tree/usr/lib/real/file"
            ln -s real "$tree/usr/lib/alias"
            ln -s lib "$tree/usr/lib64"
            make_recipe "$db" 1
            : > "$db/manifest"
            write_manifest "$tree" "$db/manifest"
            sed 's|^/usr/lib/alias$|/usr/lib/alias/|' "$db/manifest" > "$db/m" && mv "$db/m" "$db/manifest"
            (cd "$tree" && tar -cf - .) | (cd "$root" && tar -xf -)
            case_args='remove demo' ;;
        remove-etc-one-char)
            tree=$fixture/tree
            db="$tree/var/db/kiss/installed/demo"
            mkdir -p "$tree/etc" "$db"
            printf 'a\n' > "$tree/etc/a"
            printf 'bb\n' > "$tree/etc/bb"
            make_recipe "$db" 1
            : > "$db/manifest"
            : > "$db/etcsums"
            write_manifest "$tree" "$db/manifest"
            b3sum -l 33 "$tree/etc/bb" | awk '{print $1}' > "$db/etcsums"
            (cd "$tree" && tar -cf - .) | (cd "$root" && tar -xf -)
            printf 'modified\n' > "$root/etc/a"
            case_args='remove demo' ;;
        remove-pre-remove-pkg-hook-skip)
            install_state "$root" demo 1
            printf '#!/bin/sh\nexit 1\n' > "$root/var/db/kiss/installed/demo/pre-remove"
            chmod 644 "$root/var/db/kiss/installed/demo/pre-remove"
            case_args='remove demo' ;;
        build-deps)
            build_recipe "$repo_a/app" 1 'lib'
            build_recipe "$repo_a/lib" 1 'tool make'
            build_recipe "$repo_b/tool" 3
            case_args='build app' ;;
        build-deps-installed)
            build_recipe "$repo_a/app" 1 'lib'
            build_recipe "$repo_a/lib" 2
            install_state "$root" lib 1
            case_args='build app' ;;
        build-cached-dep)
            build_recipe "$repo_a/app" 1 'lib'
            build_recipe "$repo_a/lib" 1
            mkdir -p "$cache/kiss/bin"
            simple_archive "$fixture" lib 1 cached '' .gz
            mv "$fixture/lib@1-1.tar.gz" "$cache/kiss/bin/"
            case_args='build app' ;;
        build-circular)
            build_recipe "$repo_a/a" 1 'b'
            build_recipe "$repo_a/b" 1 'a'
            case_args='build a' ;;
        build-force-nodeps)
            build_recipe "$repo_a/app" 1 'lib'
            build_recipe "$repo_a/lib" 1
            case_env='KISS_FORCE=1'
            case_args='build app' ;;
        build-sources-local)
            build_recipe "$repo_a/demo" 1
            mkdir -p "$repo_a/demo/files/sub" "$fixture/abs"
            printf 'one\n' > "$repo_a/demo/files/one"
            printf 'two\n' > "$repo_a/demo/files/sub/two"
            printf 'abs\n' > "$fixture/abs/abs.txt"
            printf 'files/one\nfiles/sub dest/\n%s/abs/abs.txt\n' "$fixture" > "$repo_a/demo/sources"
            cat >> "$repo_a/demo/build" <<'EOF'
find . | LC_ALL=C sort
EOF
            b3sum -l 33 "$repo_a/demo/files/one" "$fixture/abs/abs.txt" | awk '{print $1}' > "$repo_a/demo/checksums"
            case_args='build demo' ;;
        build-sources-tar)
            build_recipe "$repo_a/demo" 1
            mkdir -p "$fixture/src/project-1.0/src" "$fixture/src2"
            printf 'main\n' > "$fixture/src/project-1.0/src/main.c"
            printf 'top\n' > "$fixture/src/README"
            printf 'other\n' > "$fixture/src2/other.txt"
            # Fixed timestamps and format so both fixtures' archives match.
            find "$fixture/src" "$fixture/src2" -exec touch -t 202001010000 {} +
            (cd "$fixture/src" && tar --format=ustar -cf - project-1.0 README | gzip -nc > "$fixture/project-1.0.tar.gz")
            (cd "$fixture/src2" && tar --format=ustar -cf "$fixture/flat.tar" .)
            printf '%s/project-1.0.tar.gz\n%s/flat.tar extra\n' "$fixture" "$fixture" > "$repo_a/demo/sources"
            cat >> "$repo_a/demo/build" <<'EOF'
find . | LC_ALL=C sort
EOF
            b3sum -l 33 "$fixture/project-1.0.tar.gz" "$fixture/flat.tar" | awk '{print $1}' > "$repo_a/demo/checksums"
            case_args='build demo' ;;
        build-checksum-skip)
            build_recipe "$repo_a/demo" 1
            printf 'data\n' > "$repo_a/demo/data"
            printf 'data\n' > "$repo_a/demo/sources"
            printf 'SKIP\n' > "$repo_a/demo/checksums"
            case_args='build demo' ;;
        build-checksum-mismatch)
            build_recipe "$repo_a/demo" 1
            printf 'data\n' > "$repo_a/demo/data"
            printf 'data\n' > "$repo_a/demo/sources"
            printf '%066d\n' 0 > "$repo_a/demo/checksums"
            case_args='build demo' ;;
        build-checksum-sha256)
            build_recipe "$repo_a/demo" 1
            printf 'data\n' > "$repo_a/demo/data"
            printf 'data\n' > "$repo_a/demo/sources"
            printf '%064d\n' 0 > "$repo_a/demo/checksums"
            case_args='build demo' ;;
        build-checksum-missing-file)
            build_recipe "$repo_a/demo" 1
            printf 'data\n' > "$repo_a/demo/data"
            printf 'data\n' > "$repo_a/demo/sources"
            case_args='build demo' ;;
        build-depends-sorted)
            build_recipe "$repo_a/demo" 1 'zeta
alpha make'
            build_recipe "$repo_a/zeta" 1
            build_recipe "$repo_a/alpha" 1
            install_state "$root" zeta 1
            install_state "$root" alpha 1
            case_env='KISS_PROMPT=1'
            case_args='build demo' ;;
        build-nostrip)
            build_recipe "$repo_a/demo" 1
            : > "$repo_a/demo/nostrip"
            printf 'nostrip\n' > "$repo_a/demo/sources"
            printf 'SKIP\n' > "$repo_a/demo/checksums"
            case_args='build demo' ;;
        build-default-cwd)
            build_recipe "$repo_a/demo" 1
            case_cwd=$repo_a/demo
            case_args='build' ;;
        build-prompt-install)
            build_recipe "$repo_a/demo" 1
            case_env='KISS_PROMPT=1'
            case_args='build demo' ;;
        build-etc)
            mkdir -p "$repo_a/demo"
            printf '1 1\n' > "$repo_a/demo/version"
            cat > "$repo_a/demo/build" <<'EOF'
#!/bin/sh
mkdir -p "$1/etc/demo" "$1/usr/lib"
printf 'conf\n' > "$1/etc/demo/demo.conf"
ln -s demo.conf "$1/etc/demo/link.conf"
printf 'la\n' > "$1/usr/lib/libdemo.la"
printf 'alias\n' > "$1/usr/lib/charset.alias"
EOF
            chmod 755 "$repo_a/demo/build"
            case_env='KISS_PROMPT=1'
            case_args='build demo' ;;
        build-la-exclusion)
            mkdir -p "$repo_a/demo"
            printf '1 1\n' > "$repo_a/demo/version"
            cat > "$repo_a/demo/build" <<'EOF'
#!/bin/sh
mkdir -p "$1/usr/lib/x.la"
printf 'la\n' > "$1/usr/lib/libdemo.la"
printf 'so\n' > "$1/usr/lib/libdemo.so"
EOF
            chmod 755 "$repo_a/demo/build"
            case_env='KISS_PROMPT=1'
            case_args='build demo' ;;
        checksum-generate)
            make_recipe "$repo_a/demo" 1
            mkdir -p "$repo_a/demo/files"
            printf 'one\n' > "$repo_a/demo/files/one"
            printf 'two\n' > "$repo_a/demo/two"
            printf '# comment\n\nfiles/one\ntwo dest\nfiles\n' > "$repo_a/demo/sources"
            printf 'SKIP\n' > "$repo_a/demo/checksums"
            case_args='checksum demo' ;;
        checksum-no-sources)
            make_recipe "$repo_a/demo" 1
            printf 'keep\n' > "$repo_a/demo/checksums"
            case_args='c demo' ;;
        download-local)
            make_recipe "$repo_a/demo" 1
            printf 'one\n' > "$repo_a/demo/one"
            printf 'one\n' > "$repo_a/demo/sources"
            case_args='download demo' ;;
        download-comment-lines)
            make_recipe "$repo_a/demo" 1
            printf 'one\n' > "$repo_a/demo/one"
            printf '#c\n\none\n' > "$repo_a/demo/sources"
            case_args='d demo' ;;
        upgrade-command)
            build_recipe "$repo_a/demo" 2
            build_recipe "$repo_a/same" 1
            install_state "$root" demo 1
            install_state "$root" same 1
            case_args=upgrade ;;
        upgrade-nothing)
            make_recipe "$repo_a/demo" 1
            install_state "$root" demo 1
            case_args=U ;;
        upgrade-orphan)
            install_state "$root" demo 1
            case_args=upgrade ;;
        build-remote-source|download-remote-cached|checksum-remote)
            build_recipe "$repo_a/demo" 1
            mkdir -p "$fixture/remote"
            printf 'remote data\n' > "$fixture/remote/data.txt"
            printf 'file://%s/remote/data.txt dest\n' "$fixture" > "$repo_a/demo/sources"
            b3sum -l 33 "$fixture/remote/data.txt" | awk '{print $1}' > "$repo_a/demo/checksums"
            case $case_name in
                build-remote-source) case_args='build demo' ;;
                checksum-remote) printf 'SKIP\n' > "$repo_a/demo/checksums"
                                 case_args='checksum demo' ;;
                *)
                    mkdir -p "$cache/kiss/sources/demo/dest"
                    printf 'cached\n' > "$cache/kiss/sources/demo/dest/data.txt"
                    case_args='download demo' ;;
            esac ;;
        build-git-source|download-git-ref)
            build_recipe "$repo_a/demo" 1
            git init -q -b main "$fixture/upstream"
            printf 'tracked\n' > "$fixture/upstream/file"
            git -C "$fixture/upstream" add file
            git -C "$fixture/upstream" -c user.name=t -c user.email=t@t \
                -c commit.gpgsign=false commit -q -m one
            if [ "$case_name" = build-git-source ]; then
                printf 'git+file://%s/upstream\n' "$fixture" > "$repo_a/demo/sources"
                cat >> "$repo_a/demo/build" <<'EOS'
find . -name .git -prune -o -print | LC_ALL=C sort
EOS
                case_args='build demo'
            else
                printf 'git+file://%s/upstream#main src\n' "$fixture" > "$repo_a/demo/sources"
                case_args='download demo'
            fi ;;
        update-git-repo)
            git init -q -b main "$fixture/upstream"
            mkdir -p "$fixture/upstream/core/demo"
            printf '1 1\n' > "$fixture/upstream/core/demo/version"
            printf 'Repository news\n' > "$fixture/upstream/MOTD"
            git -C "$fixture/upstream" add .
            git -C "$fixture/upstream" -c user.name=t -c user.email=t@t \
                -c commit.gpgsign=false commit -q -m one
            git clone -q "$fixture/upstream" "$fixture/clone"
            printf '2 1\n' > "$fixture/upstream/core/demo/version"
            git -C "$fixture/upstream" -c user.name=t -c user.email=t@t \
                -c commit.gpgsign=false commit -q -am two
            rmdir "$repo_a"
            ln -s clone/core "$repo_a"
            case_env='GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1'
            case_args=update ;;
        update-plain-repo)
            printf 'Message of the day\n' > "$repo_a/MOTD"
            case_args=update ;;
        extension)
            cat > "$fixture/bin/kiss-hello" <<'EOF'
#!/bin/sh
# Say hello
printf 'hello %s lvl=%s pid=[%s]\n' "$*" "$_KISS_LVL" "$KISS_PID"
EOF
            chmod 755 "$fixture/bin/kiss-hello"
            case_args='hel a b' ;;
        extension-missing) case_args='nosuchaction' ;;
        help-ext)
            printf '#!/bin/sh\n# First\n' > "$fixture/bin/kiss-one"
            chmod 755 "$fixture/bin/kiss-one"
            case_args='help-ext' ;;
        *)
            echo "unknown case: $case_name" >&2
            return 2 ;;
    esac
    printf '%s\n' "$case_args" > "$fixture/args"
    printf '%s\n' "$case_env" > "$fixture/env"
    printf '%s\n' "$case_cwd" > "$fixture/cwd"
    printf '%s\n' "$case_stdin" > "$fixture/stdin.path"
}

snapshot_tree() {
    tree=$1
    # With a second argument, file contents are compared after replacing
    # that fixture prefix, since recipes may name absolute fixture paths.
    prefix=${2-}
    [ -d "$tree" ] || return 0
    (
        cd "$tree" || exit 1
        find . -print | LC_ALL=C sort | while IFS= read -r path; do
            if [ -L "$path" ]; then
                printf 'link %s %s %s\n' "$path" "$(ls -ld "$path" | awk '{print $1}')" "$(readlink "$path")"
            elif [ -d "$path" ]; then
                printf 'dir %s %s\n' "$path" "$(ls -ld "$path" | awk '{print $1}')"
            elif [ -f "$path" ]; then
                if [ -n "$prefix" ]; then
                    set -- $(sed "s|$prefix|<fixture>|g" < "$path" | cksum)
                else
                    set -- $(cksum < "$path")
                fi
                printf 'file %s %s %s %s\n' "$path" "$(ls -ld "$path" | awk '{print $1}')" "$1" "$2"
            else
                printf 'other %s\n' "$path"
            fi
        done
    )
}

snapshot_cache() {
    cache=$1/cache/kiss
    for d in sources logs; do
        [ -d "$cache/$d" ] && (cd "$cache/$d" && find . -type f | LC_ALL=C sort | sed "s|^|$d |")
    done
    [ -d "$cache/bin" ] || return 0
    (cd "$cache/bin" && for a in *; do
        [ -f "$a" ] || continue
        printf 'archive %s\n' "$a"
        case $a in
            *.gz) gzip -dc "$a" ;;
            *.xz) xz -dc "$a" ;;
            *.zst) zstd -dc "$a" ;;
            *.bz2) bzip2 -dc "$a" ;;
            *) cat "$a" ;;
        esac | tar -tf - | LC_ALL=C sort | sed 's/^/  /'
    done)
}

run_implementation() {
    implementation=$1
    fixture=$2
    physical_fixture=$(cd "$fixture" && pwd -P)
    args=$(cat "$fixture/args")
    extra_env=$(cat "$fixture/env")
    cwd=$(cat "$fixture/cwd")
    stdin_path=$(cat "$fixture/stdin.path")
    set -f
    # shellcheck disable=2086
    set -- $args
    (
        cd "$cwd" || exit 1
        # shellcheck disable=2086
        env KISS_ROOT="$fixture/root" \
            KISS_PATH="$fixture/repo-a:$fixture/repo-b" \
            XDG_CACHE_HOME="$fixture/cache" \
            HOME="$fixture/home" \
            KISS_PROMPT=0 \
            KISS_CHOICE= \
            KISS_HOOK="$fixture/hook" \
            KISS_CONFORMANCE_HOOK_TRACE="$fixture/hook.trace" \
            PATH="$fixture/bin:$PATH" \
            $extra_env \
            "$implementation" "$@" < "$stdin_path" >"$fixture/stdout" 2>"$fixture/stderr"
    )
    printf '%s\n' "$?" > "$fixture/status"
    set +f
    for f in stdout hook.trace; do
        sed -E -e "s|$physical_fixture|<fixture>|g" \
            -e "s|$fixture|<fixture>|g" \
            -e 's|<fixture>/cache/kiss/proc/[0-9]+|<fixture>/cache/kiss/proc/<pid>|g' \
            -e 's|__kiss-tmp-([^ ]*)-[0-9]+|__kiss-tmp-\1-<pid>|g' \
            -e 's|^(\+\+\+\|---) (.*)	.*$|\1 \2|' \
            -e 's|pid=\[[0-9]+\]|pid=[<pid>]|g' \
            -e 's|lvl=[0-9]+|lvl=<n>|g' \
            -e 's|[0-9a-f]{7,40}\.\.[0-9a-f]{7,40}|<rev>..<rev>|g' \
            "$fixture/$f" > "$fixture/$f.normalized"
    done
    {
        echo '# root'
        snapshot_tree "$fixture/root"
        echo '# repositories'
        snapshot_tree "$fixture/repo-a" "$fixture"
        snapshot_tree "$fixture/repo-b" "$fixture"
        echo '# cache'
        snapshot_cache "$fixture"
    } > "$fixture/snapshot"
}

tmp_parent=${TMPDIR:-/tmp}
tmp_parent=${tmp_parent%/}
temporary_base=$(mktemp -d "$tmp_parent/kiss-extra.XXXXXX") || exit 1
[ -n "${KEEP_FIXTURES-}" ] || trap 'rm -rf "$temporary_base"' EXIT HUP INT TERM
failed=0
passed=0
failed_cases=

for case_name do
    ref_fixture=$temporary_base/reference-$case_name
    cand_fixture=$temporary_base/candidate-$case_name
    setup_case "$ref_fixture" "$case_name" || exit $?
    setup_case "$cand_fixture" "$case_name" || exit $?
    run_implementation "$reference" "$ref_fixture"
    run_implementation "$candidate" "$cand_fixture"
    if cmp -s "$ref_fixture/status" "$cand_fixture/status" &&
       cmp -s "$ref_fixture/stdout.normalized" "$cand_fixture/stdout.normalized" &&
       cmp -s "$ref_fixture/hook.trace.normalized" "$cand_fixture/hook.trace.normalized" &&
       cmp -s "$ref_fixture/snapshot" "$cand_fixture/snapshot"; then
        printf 'ok %s\n' "$case_name"
        passed=$((passed + 1))
    else
        printf 'not ok %s\n' "$case_name"
        for f in status stdout.normalized hook.trace.normalized snapshot; do
            diff -u "$ref_fixture/$f" "$cand_fixture/$f" | sed "s|$temporary_base|<base>|g"
        done
        printf '  reference stderr: %s\n  candidate stderr: %s\n' \
            "$ref_fixture/stderr" "$cand_fixture/stderr"
        failed=$((failed + 1))
        failed_cases="${failed_cases}${failed_cases:+ }${case_name}"
    fi
done

printf '\nconformance (extended): %d passed, %d failed\n' "$passed" "$failed"
if [ "$failed" -eq 0 ]; then
    printf 'conformance (extended): PASS\n'
else
    printf 'conformance (extended): FAIL (failed cases: %s)\n' "$failed_cases"
fi
exit "$failed"
