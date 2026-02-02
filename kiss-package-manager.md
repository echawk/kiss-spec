## KISS Package Manager

For this section, unless otherwise specified, KISS refers to the
package manager.

KISS the package manager is a source-based package manager
not too dissimilar from portage from Gentoo, or the ports
system from the BSDs. Unlike those systems however,
KISS has no system wide configuration, instead relying
on the existence of environment variables to change it's behavior.

### Environment Variables

KISS is entirely configured through the existence of these environment
variables. What follows is a table of each environment variable along
with a brief description of what the said variable does.

| Variable       | Description |
|----------------|-------------|
| KISS\_CHK      | Utility to use when checksumming sources |
| KISS\_CHOICE   | Enables or Disables the alternatives system |
| KISS\_COLOR    | Enable or Disable colors |
| KISS\_COMPRESS | Compression method to use for built tarballs |
| KISS\_DEBUG    | Keep temporary directories around (debugging purposes) |
| KISS\_ELF      | Which readelf command to use |
| KISS\_FORCE    | Force the installation/removal of packages |
| KISS\_GET      | Utility to use when downloading sources |
| KISS\_HOOK     | Colon separated list of absolute paths to executable files |
| KISS\_KEEPLOG  | Keep build logs around for successful builds and not just |
| KISS\_PATH     | List of repositories. Works exactly like |
| KISS\_PROMPT   | Enables or Disables prompts from the package manager |
| KISS\_ROOT     | Where installed packages will go |
| KISS\_STRIP    | Enable or Disable package stripping globally |
| KISS\_SU       | The sudo-like utility to use for privilege escalation |
| KISS\_TMPDIR   | Temporary directory for builds |

The following table denotes the valid values for each of the
variables, where applicable.

| Variable       | Default Value | Valid Values |
|----------------|---------------|--------------|
| KISS\_CHK      | openssl       | openssl, sha256sum, sha256, shasum, digest |
| KISS\_CHOICE   | 1             | 0, 1                                       |
| KISS\_COLOR    | 1             | 0, 1                                       |
| KISS\_COMPRESS | gz            | gz, bz2, lzma, lz, xz, zst                 |
| KISS\_DEBUG    | 0             | 0, 1                                       |
| KISS\_ELF      | readelf       | readelf, readelf-*, ldd                    |
| KISS\_FORCE    | 0             | 0, 1                                       |
| KISS\_GET      | curl          | aria2c, axel, curl, wget, wget2            |
| KISS\_HOOK     | ""            | (anything)                                 |
| KISS\_KEEPLOG  | 0             | 0, 1                                       |
| KISS\_PATH     | ""            | (anything)                                 |
| KISS\_PROMPT   | 1             | 0, 1                                       |
| KISS\_ROOT     | "/"           | (anything)                                 |
| KISS\_STRIP    | 1             | 0, 1                                       |
| KISS\_SU       | ""            | ssu, sudo, doas, su                        |
| KISS\_TMPDIR   | ""            | (anything)                                 |

### Search Resolution

The environment variable **KISS_PATH** is responsible for determining
where a particular package will be sourced from. Directories earlier
in **KISS_PATH** will be searched first for the package, in a similar
way to how the system PATH is searched for an executable.

#### algorithm

**Path Resolution (`pkg_find`)**:
All commands utilizing package names must resolve them by searching directories in `$KISS_PATH`.
1. Iterate through paths in `$KISS_PATH`.
2. Return the *first* directory match containing a `version` file.
3. Ignore subsequent matches (shadowing).
4. Implicitly include the System Database (`$KISS_ROOT/var/db/kiss/`) as a search path for installed checks.

**Dependency Resolution**:
1. distinct_list = []
2. For each package in query:
a. Recurse through `depends` file.
b. Detect Circular Dependency (abort if found).
c. If package not in distinct\_list:
i. Prepend to distinct\_list (Deepest dependency first).
3. Return distinct\_list.


### Alternatives System

The KISS package manager supports an on-the-fly alternatives system, which
allows users to swap files from one package with another. This can be used
to switch from busybox to the GNU coreutils, or to suckless' sbase/ubase.

This behavior can also be explicitly disabled by the user, by setting the
environment variable `KISS_CHOICE` equal to 0.

Alternatives are stored in the `/var/db/kiss/choices/` directory, where
packages which could be "swapped" to have their files stored.

For example, if the user has *busybox* installed, then installs *util-linux*,
and also has the alternatives system enabled, then the exectuable
`/usr/bin/kill` in the *util-linux* will become
`/var/db/kiss/choices/util-linux>usr>bin>kill` on the filesystem.

The naming scheme for files in the choices directory is simply the
name of the package, followed by the path to the file, with the "/"
replaced with ">".

### Commands

The following table gives a very high level overview of each of the commands
that kiss is expected to have.

| Command      | # of Arguments  |  Description |
|--------------|------------------|--------------|
| alternatives | 0, 2            | List or swap alternatives |
| build        | 1+              | Build the specified packages |
| checksum     | 0, 1+           | Create the checksum file for a package port. |
| download     | 1+              | Download the source files for the packages. |
| install      | 1+              | Install the specified packages |
| list         | 0, 1            | List all installed packages or return the specified package version |
| preferred    | 0, 1            | List the preferred packages for utilities |
| remove       | 1+              | Removes the specified packages |
| search       | 1+              | Search for the specified packages |
| update       | 0               | Update the list of system repositories. |
| upgrade      | 0               | Build and install newer versions of out of date packages. |
| version      | 0               | Prints version info |


#### alternatives

The `alternatives` command is responsible for managing and modifying the
alternatives system.

When ran with 0 arguments, the command simply lists out all of the files
in `/var/db/kiss/choices/`.

When ran with 2 arguments, the first is taken to be a package name, and the
second is a file path. The command then checks to see if there is an
alternative in the choices directory that meets the criteria, and if there
is, will make the package's version of file path the default on the system.

This will also modify the manifest of both of the involved packages, the current
provider of the file and the new provider.

##### algorithm
```
function cmd_alternatives(pkg_name):
    # 1. List Mode (No args)
    if pkg_name is empty:
        # Scan for broken symlinks or overwritten files in DB
        conflicts = find_conflicting_files_in_db()
        print(conflicts)
        return

    # 2. Swap Mode
    target_pkg = pkg_name

    # Verify the package actually owns the conflicting files
    if not is_installed(target_pkg):
        abort("Package not installed")

    # Re-link logic
    manifest = read_manifest(target_pkg)
    for file in manifest:
        # Force creation of symlink, overwriting existing
        if file_is_symlink(file) or file_is_binary(file):
            link_file_to_root(file)

    update_choices_db(target_pkg)
    print("Swapped to " + target_pkg)
```

#### build

The `build` command is responsible for building ports.

The command expects 1 or more arguments, and will follow the standard
rules for search resolution. The actual build order for the packages is
not what is specified to the build command, but instead the dependency
order, where dependencies are built before their dependents.

Additionally, before packages are built, any missing dependencies are
attempted to be installed, and if no binary for the package exists, then
they are to be added to the build queue as well.

##### algorithm

```
function cmd_build(packages):
dependencies = resolve_dependencies(packages)

    for pkg in dependencies:
        if pkg is installed and versions_match:
            continue

        # 1. Source Acquisition
        sources = parse_sources_file(pkg)
        for src in sources:
            if not exists_in_cache(src):
                download_source(src)
                verify_checksum(src) # Abort on mismatch

        # 2. Preparation
        extract_sources_to_build_dir()
        run_hook("pre-build", pkg)

        # 3. Compilation
        # Execute 'build' script with args: $dest_dir, $version, $release
        execute_build_script(pkg, dest_dir)

        # 4. Packaging
        if dest_dir is empty:
            abort("Build script did not install any files")

        strip_binaries(dest_dir) # Optional: strip debug symbols
        generate_manifest(dest_dir) # List of all files owned by pkg
        create_tarball(pkg, dest_dir)

        run_hook("post-build", pkg)
```

#### checksum

The `checksum` command is responsible for creating the checksum file for
a kiss package.

If ran with 0 arguments, the current directory is considered a kiss package
and kiss attempts to generate a checksum file.

If ran with 1 argument, the first package in KISS\_PATH which matches the provided
argument will have it's checksum file generated.

##### algorithm

```
function cmd_checksum(packages):
    for pkg in packages:
        sources = parse_sources_file(pkg)
        hashes = []

        for src in sources:
            file_path = download_source(src)
            hash = calculate_b3sum(file_path)
            hashes.append(hash)

        write_checksums_file(pkg, hashes)
        print("Generated checksums for " + pkg)
```

#### download

The `download` command is responsible for downloading the sources of ports.
If ran with 1+ arguments, the package manager attempts to download the remote
sources for each of the packages that were supplied. It must handle the logic
of skipping existing sources to avoid redundant downloads.

##### algorithm

```
function cmd_download(packages):
    for pkg in packages:
        repo_dir = pkg_find(pkg)
        sources = parse_sources_file(repo_dir)

        for src in sources:
            if is_remote(src):
                dest = derive_cache_path(src)

                if not file_exists(dest):
                    log("Downloading " + src)
                    perform_fetch(src, dest)
                else:
                    log("Cached " + src)

            # Validation (Optional but recommended for strict implementations)
            verify_checksum_single(pkg, src, dest)
```

#### install

##### algorithm

```
function cmd_install(packages):
    for pkg in packages:
        tarball = locate_tarball(pkg)
        manifest_new = read_manifest_from_tarball(tarball)

        # 1. Conflict Resolution
        for file in manifest_new:
            if file_exists_on_disk(file):
                owner = find_owner_in_db(file)
                if owner != pkg and owner != null:
                    abort("File conflict detected with " + owner)

        # 2. Installation
        run_hook("pre-install", pkg)

        extract_tarball_to_root(tarball, "$KISS_ROOT/")
        register_package_in_db(pkg) # Move metadata to /var/db/kiss/

        run_hook("post-install", pkg)
```

#### list

When ran with 0 arguments, will return all currently installed packages.
Otherwise, each argument is checked to see if it is installed, if so the version number is printed.

##### algorithm

```
function cmd_list(packages):
    # Database Root: /var/db/kiss/

    if packages is empty:
        # List ALL installed packages
        packages = list_directories_in(DB_ROOT)

    for pkg in packages:
        if not directory_exists(DB_ROOT + pkg):
            print("Package '" + pkg + "' not installed")
            continue

        read_version_file(DB_ROOT + pkg + "/version")
        # Format: name version-release
        print(pkg + " " + version + "-" + release)
```

#### preferred


#### remove

The `remove` command is responsible for removing installed packages.

If ran with 1 argument, the package manager will simply check if the package is removeable
and remove it accordingly.

If ran with 2+ arguments, the package manager will attempt to remove the packages in the order
that they were provided to the package manager.

The `remove` command can be forced to remove a package, with disregard whether
the package manager thinks it can be removed, by setting `KISS_FORCE` equal to **1**.

##### algorithm

```
function cmd_remove(packages):
    for pkg in packages:
        # 1. Reverse Dependency Check
        requirers = find_packages_depending_on(pkg)
        if requirers is not empty and KISS_FORCE != 1:
            abort("Package is required by: " + requirers)

        # 2. Deletion
        run_hook("pre-remove", pkg)

        manifest = read_installed_manifest(pkg)
        for file in manifest:
            delete_file(file)
            # Prune empty parent directories recursively
            rmdir_recursive(parent_of(file))

        remove_db_entry(pkg)
```

#### search

##### algorithm

```
function cmd_search(query):
    # Standard glob match
    matches = glob("$KISS_PATH/*" + query + "*")
    print(matches)
```

#### update

The `update` command is responsible for updating the repositories within KISS\_PATH.
For each repository, a check is done to determine whether or not it is a directory
which belongs to a git repository, and if it does, then the new changes are pulled in.

Directories which do not belong to a git repository have no special code, they are simply
skipped over.

##### algorithm

```
function cmd_update():
    run_hook("pre-update")

    for repo_dir in $KISS_PATH:
        if is_git_repo(repo_dir):
            git_pull(repo_dir)
            print("Updated " + repo_dir)

    run_hook("post-update")
```

#### upgrade

The `upgrade` command is responsible for building the new version of packages and installing them.

##### algorithm

```
function cmd_upgrade():
    update_list = []

    # Compare installed versions vs repo versions
    for pkg in installed_packages:
        repo_ver = get_version_from_repo(pkg)
        installed_ver = get_version_from_db(pkg)

        if repo_ver > installed_ver:
            update_list.append(pkg)

    if update_list is not empty:
        cmd_build(update_list)
        cmd_install(update_list)
```

#### version

The `version` command simply prints out the version of the package manager to standard output.

##### algorithm

```
function cmd_version():
    # Must output the strict version string of the Package Manager itself
    print(KISS_VERSION)
    exit(0)
```
