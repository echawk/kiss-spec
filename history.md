## History

KISS, both the package manager and system trace their origin back
to 2019, and were created by Dylan Araps.

Since their creation in 2019, there has been rather little change
in both the format and the structure of the system. The biggest
change that impacts this document was the migration from using
sha256 checksums to using b3sums in September of 2022.

There was also a brief period, from July of 2021 to March of 2022
where the sources file supported a DSL that allowed the maintainer
to have the version of the package be automatically resolved just
by updating the version file. This feature was added by Dylan,
and removed by the community after his second hiatus. The reason for
its removal was that VERSION markers made certain tasks with
the system somewhat trickier, as well as complicating the package format.
For historical reasons, this format will be documented in this document,
however this behavior has long since been deprecated.

While this section is not strictly necessary for the definition of
either the package manager or the system, I think this section ought
to exist, so that way future readers and implementers can
gleam some insight into the why and how KISS became what it is today.
