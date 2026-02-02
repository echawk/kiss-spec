## Upgrading "git" packages.

Currently, git packages will not receive updates through the normal
`kiss update` and `kiss upgrade` commands. Instead, responsibility falls
to the user to make sure that they update these packages appropriately.

A remedy to fix this would be to log the current git hash of the package
into a file on the system - this could be easily compared against whatever
the latest from git is.

The downside to this approach is that every git package will have to have
its' sources downloaded before the check can occur, making this a potentially
expensive check.

Instead of this being included with the default update & upgrade commands,
this behavior could be added to separate commands.

These commands could be called something along the lines of `kiss vc-update`
and `kiss vc-upgrade` which will perform the aforementioned updating and
upgrading of said packages. Additionally, this naming scheme keeps the
actual process version control agnostic, so if mercurial or fossil sources
were supported in the future, they could also be added to this scheme.

The relevant commands to get the commit sha for each of the respective
vc sources are as follows:

### git

```sh
git rev-parse HEAD
```


### hg

```sh
hg id -i
```

### fossil
```sh
fossil info . | awk '/^checkout/ {print $2}'
```


### Implementation strategy

Snapshot Metadata: When a git package is installed, write the commit hash to the database:

```sh
git -C "$src_dir" rev-parse HEAD > "$KISS_ROOT/var/db/kiss/$pkg/commit"
```

The `vc-update` Command: This command should not download the repo. It should query the remote.

```
cmd_vc_update() {
    log "Checking for git updates..."

    # 1. DISCOVERY PHASE (Local only, Fast)
    # Find all packages where the version is literally 'git'
    # This filters out 'stable' packages that just happen to use git sources.

    # We use 'grep' to scan the DB.
    # /var/db/kiss/*/version -> match "^git"

    candidates=$(grep -l "^git" "$KISS_ROOT/var/db/kiss/"*/version)

    for ver_file in $candidates; do
        pkg_dir="${ver_file%/version}"
        pkg_name="${pkg_dir##*/}"

        # 2. SOURCE PARSING PHASE
        # We need to find the git source URL.
        # We also strictly filter out pinned commits here.

        while read -r src _dest; do
            case "$src" in
                # Match git sources WITHOUT a fragment (#)
                git+*#*)
                    # This has a hash/tag (e.g. #v1.0 or #a1b2c3).
                    # It is PINNED. Do not auto-update.
                    continue
                    ;;
                git+*@*)
                    # This has a hash/tag (e.g. @v1.0 or @a1b2c3).
                    # It is PINNED. Do not auto-update.
                    continue
                    ;;
                git+*)
                    # This is a naked git URL. It tracks HEAD.
                    # Strip the 'git+' prefix for the command
                    remote_url="${src#git+}"

                    # 3. NETWORK PHASE (The only slow part)
                    check_git_update "$pkg_name" "$remote_url" "$pkg_dir"
                    ;;
            esac
        done < "$pkg_dir/sources"
    done
}

check_git_update() {
    pkg="$1"
    url="$2"
    db_dir="$3"

    # Get the commit we currently have installed
    # (Assuming we saved this during install as discussed previously)
    if [ -f "$db_dir/commit" ]; then
        current_hash="$(cat "$db_dir/commit")"
    else
        # Fallback: If we didn't save the commit, we can't compare.
        return
    fi

    # Check remote HEAD (Lightweight, headers only)
    # We use awk to grab the first field (the hash)
    remote_hash="$(git ls-remote "$url" HEAD | awk '{print $1}')"

    if [ -n "$remote_hash" ] && [ "$current_hash" != "$remote_hash" ]; then
        log "$pkg" "Update available ($current_hash -> $remote_hash)"
        # Append to a list to offer an upgrade prompt later
    fi
}
```

## Implementors


