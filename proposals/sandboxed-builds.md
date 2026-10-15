# Proposal: sandboxed builds

## Status and specification integration

**Status:** Non-normative proposal; current builds rely on the recipe's social
DESTDIR isolation rule and are not sandboxed.

**Integration points:**

- Insert sandbox construction into package-manager section 10.3 before source
  extraction and build-script execution, and define the changed build
  environment in section 10.4.
- Add any configuration switch to the public environment contract in section
  3.1.
- Adopt the `kiss-system` inventory proposal into the KISS system profile and
  package-manager state layout first.

Sandboxing must preserve the port-format build arguments and external hook
ordering unless this proposal explicitly amends those canonical interfaces.

## Proposal

Provide the user the option to perform the building of packages in a temporary chroot.
This will prevent builds from picking up random dependencies, and make for a more
reproducible build environment.

Relevant Codeberg Issue: [108](https://codeberg.org/kiss-community/repo/issues/108)

### Setup Chroot

NOTE: The below algorithm depends on the existence and usage of the `kiss-system` package
which is also a proposal in its own right.

```sh
setup_hermetic_root() {
    sandbox_root="$(mktemp -d)"
    log "Constructing hermetic environment..."

    # 1. Gather all dependencies
    #    'kiss-depends' is a hypothetical helper, or the logic from the package manager
    deps=$(kiss-depends "$pkg_name")
    
    # 2. Collect all manifests into one stream
    #    We use 'cat' to combine them.
    #    We filter for existing files to prevent cpio errors on stale manifest entries.
    for dep in $deps kiss-system; do
        cat "$KISS_ROOT/var/db/kiss/installed/$dep/manifest"
    done | 
    
    # 3. The Optimization
    #    - cpio reads the stream of files.
    #    - It handles the mkdir logic internally (fast C implementation).
    #    - It hardlinks files to the destination.
    #    - 2>/dev/null suppresses warnings about "newer or same age" files if deps overlap.
    cpio -pdl "$sandbox_root" 2>/dev/null
}
```

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

Is planning on using [Landlock](https://landlock.io/) to achieve build isolation.
