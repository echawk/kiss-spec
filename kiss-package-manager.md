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
