## KISS System

This section is still somewhat contested, as there has yet to
be any discussion in the wider KISS community as to what
*exactly* should be available on a system for it to be
considered a KISS System.

Generally speaking, the following is expected:

* POSIX core utilites
* git
* curl
* An implementation of SSL
* gzip, bzip2, & xz

It is conceivable to run kiss, the package manager, on any system
that meets these requirements.

It is important to note that this list is not yet comprehensive, and
there is also an expectation that whatever system you are running
the package manager on will also have access to a C compiler and
additional POSIX amenities.

In the future there will ideally be some effort put into making
a package, which when installed, can verify that the system is
compliant.
