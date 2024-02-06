## Sandboxed Builds

Provide the user the option to perform the building of packages in a temporary chroot.
This will prevent builds from picking up random dependencies, and make for a more
reproducible build environment.

Relevant Codeberg Issue: [108](https://codeberg.org/kiss-community/repo/issues/108)

## Implementors

### kiss.el

Has an implementation of this proposal. The build sandboxing can either
be accomplished through bubblewrap or proot, whichever is specified by the
user. Additionally, the end user is able to configure certain qualities
of the generated chroot. The user can either specify to always use packages
that the user has made the primary provider of an executable/shared library
through the alternatives system. Or, the chroot could be constructed in such
a way that none of the user's chosen alternatives are respected, and instead
the "default" system values are chosen instead.

NOTE: The latter behavior described here is somewhat ad-hoc, and would be
better served by the 'kiss-system' package (also in this repo) becoming
widely adopted.

### kiss-ng

Is planning on using [landlock](landlock.io) to achieve build isolation.
