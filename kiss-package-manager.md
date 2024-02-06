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


#### build

The `build` command is responsible for building ports.

The command expects 1 or more arguments, and will follow the standard
rules for search resolution. The actual build order for the packages is
not what is specified to the build command, but instead the dependency
order, where dependencies are built before their dependents.

Additionally, before packages are built, any missing dependencies are
attempted to be installed, and if no binary for the package exists, then
they are to be added to the build queue as well.

#### checksum

The `checksum` command is responsible for creating the checksum file for
a kiss package.

If ran with 0 arguments, the current directory is considered a kiss package
and kiss attempts to generate a checksum file.

If ran with 1 argument, the first package in KISS\_PATH which matches the provided
argument will have it's checksum file generated.

#### download

The `download` command is responsible for downloading the sources of ports.
If ran with 1+ arguments, the package manager attempts to download the remote
sources for each of the packages that were supplied.

#### install

#### list

#### preferred

#### remove

The `remove` command is responsible for removing installed packages.

If ran with 1 argument, the package manager will simply check if the package is removeable
and remove it accordingly.

If ran with 2+ arguments, the package manager will attempt to remove the packages in the order
that they were provided to the package manager.

The `remove` command can be forced to remove a package, with disregard whether
the package manager thinks it can be removed, by setting `KISS_FORCE` equal to **1**.

#### search

#### update

The `update` command is responsible for updating the repositories within KISS\_PATH.
For each repository, a check is done to determine whether or not it is a directory
which belongs to a git repository, and if it does, then the new changes are pulled in.

Directories which do not belong to a git repository have no special code, they are simply
skipped over.

#### upgrade

The `upgrade` command is responsible for building the new version of packages and installing them.

#### version

The `version` command simply prints out the version of the package manager to standard output.
