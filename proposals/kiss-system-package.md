# Proposal: kiss-system (Dynamic Toolchain Resolution)

We propose the introduction of a special package, kiss-system.
Unlike standard packages which install software, kiss-system acts as a dynamic state capturer. Its build script inspects the host environment to identify the specific installed packages that provide the core build toolchain (compiler, shell, binutils, etc.).

This package is required to unlock the Sandboxing proposal in a portable way.


## Motivation

To implement Sandboxed Builds, the build system must mount a "Base System" into the sandbox. However, in a source-based distribution like KISS, the base system is mutable:

* User A might use gcc and coreutils.
* User B might use clang and busybox.
* User C might use tcc and sbase.

We cannot simply make `kiss-system` depend on `gcc`. We need a mechanism to discover what satisfies cc on the current host and tell the sandbox to mount that specific package.

## Specification

The kiss-system package contains no source code.
Its logic is entirely contained within its build script.

The build script performs three phases:

1. Requirement Verification: It asserts that strictly required POSIX/KISS build tools (cc, make, sed, tar, etc.) are present in the $PATH.
2. Path Resolution: It resolves these commands (and critical libraries like libc, libssl) to their absolute paths on the host filesystem.
3. Reverse Lookup: It scans the KISS package database (/var/db/kiss/installed/*/manifest) to map these absolute paths back to the package names that own them.

The package installs a single file: /var/db/kiss/system (or similar). This file contains a newline-separated list of the packages that constitute the base system.

Example system file:
```
binutils
bzip2
curl
gcc
git
kiss
linux-headers
make
musl
openssl
zlib
```
