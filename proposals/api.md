## API

This proposal would suggest that a API for the KISS System be made.
Ideally this would be language agnostic, since all of the data for the
kiss package manager  resides only on the file system, therefore language
specific conventions should be followed when implementing the API.

The outlining of this API would make it somewhat trivial for KISS implementers
to know the entirety of what they would have to implement, as well as
serve as a meaningful way of comparing implementations, since a test
suite could be easily devised.

### Examples

What follows is a potential header file for such an API. Note that this
is merely for illustrative purposes, and is not a suggestion for the
final API.

```c
#ifndef KISS_IMPLEMENTATION
#define KISS_IMPLEMENTATION

#include <stdbool.h>

bool kiss_is_pkg_installed_p(char* pkg);
bool kiss_is_pkg_installable_p(char* pkg);

char** kiss_get_pkg_dependencies(char *pkg);
bool kiss_build_pkg(char *pkg);

#endif
```

Additionally, the above sample does not take into account any potential
structs/classes that may be created.

