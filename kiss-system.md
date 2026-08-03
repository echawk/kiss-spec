# KISS system profile

## 1. Scope and status

This document describes the broader host environment conventionally called a
KISS System. It does not redefine package-manager behavior or maintain a
second list of commands needed by `kiss`.

The exact package-manager execution model, helper selection, compression
methods, and external-command failure rules are normative in the
[KISS package manager specification](kiss-package-manager.md), particularly
sections 1.1, 3, 6.3, 9, 10, and 14.4. A host capable of running that contract
satisfies the package-manager portion of this profile.

The wider system profile remains informative because the KISS community has
not established a complete, independently testable definition of a KISS
System. Package-manager conformance and system-profile conformance are separate
claims.

## 2. Baseline profile

In addition to satisfying the package-manager host requirements, a KISS System
is expected to provide:

- a POSIX-oriented userspace suitable for executing package build scripts;
- a native build toolchain, including a C compiler; and
- any additional tools required by the repositories selected in `KISS_PATH`.

This profile deliberately does not require one named downloader, checksum
program, privilege-escalation tool, ELF inspector, or compression suite. The
package manager permits several implementations of those facilities and
defines their selection rules in its environment-variable contract.

Repository requirements are open-ended. Being able to execute the package
manager does not imply that the host can build every available port.

## 3. Verification

There is currently no standalone system-profile verifier. Package-manager
implementations should use the conformance matrix in section 18 of the package
manager specification. A future system verifier should test this profile plus
the requirements of a declared repository set, rather than copying a static
utility list into this document.
