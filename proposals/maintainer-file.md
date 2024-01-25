## Maintainer File

Currently the maintainer of a package is assumed to be the email address
of the last person to have modified the package's version file according to
git.

This has downsides, since if repositories were to be hosted through a means
other than git, then this method would fail to properly report the maintainer
information.

Relevant Codeberg Issue: [96](https://codeberg.org/kiss-community/repo/issues/96)

## Implementors

### Carbs Linux

[Carbs Linux](https://carbslinux.org/) makes use of the `meta` file to store miscellaneous information
about the package including the maintainer information.

The format of the meta file is as follows:
```
description: The description of the package
license: MIT
maintainer: Your Name <you@example.org>
```
