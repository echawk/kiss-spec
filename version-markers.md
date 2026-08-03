# Historical VERSION markers

## 1. Status

This document is informative and historical. Current `sources` records are
literal as specified in section 2 of the KISS port format; implementations
MUST NOT apply the substitutions below when conforming to KISS 6.2.0.

VERSION markers were introduced in kiss version `5.5.0` and removed in
version `6.1.1`. This represents a period of 1 year and 8 months. If
you encounter packages made during this period, chances are that they
could use VERSION markers, and you must fix the `sources` file.

## 2. Introduction

VERSION markers were added in July of 2021.

The commit describing them is as follows:

```
commit d296b90b75d02ee81ec9a5902f107144f6dda3b8
Author: Dylan Araps <dylan.araps@gmail.com>
Date:   Wed Jul 14 17:08:58 2021 +0300

    kiss: support variables in sources files.

    This adds support for replacement of simple markers with
    corresponding values. To handle cases where a replacement
    is not 1:1, various transformations are made available.

    - VERSION : The full version string (first field in version file).
    - MAJOR   : First component separated by '.'.
    - MINOR   : Second component separated by '.'.
    - PATCH   : Third component separated by '.'.
    - IDENT   : All remaining components separated by '.+-'.
    - PKG     : The name of the current package.

    NOTE: This may be reverted. Depends on how good the benefits
    are. Will do an evaluation of the repositories.
```

However, this was later amended with some extra variables and some renamed
variables, due to conflicts with upstream package sources.

### 2.1 Final variation

The final variation of the VERSION markers was:

- `VERSION`: full version string.
- `MAJOR`: first component separated by `.`.
- `MINOR`: second component separated by `.`.
- `PATCH`: third component separated by `.`.
- `IDENT`: all remaining components separated by `.`, `+`, or `-`.
- `PACKAGE`: current package name.
- `\VERSION`, `\MAJOR`, `\MINOR`, `\PATCH`, and `\PACKAGE`: the corresponding
  literal marker name without the leading backslash.

## 3. Removal

VERSION markers were removed in March of 2023. This was after a lengthy
discussion as to their usefulness, which occurred primarily in this
[thread](https://codeberg.org/kiss-community/repo/issues/90). The primary
reason for their removal was due to the complications that it brought to the
package format, and making `source` files more difficult to parse.
