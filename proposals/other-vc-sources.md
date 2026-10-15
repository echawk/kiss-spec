# Proposal: additional version-control sources

## Status and specification integration

**Status:** Non-normative proposal; current source acquisition supports only
the `git+` version-control form.

**Integration points:**

- Add `hg+` and `fossil+` records to the source-form precedence list in section
  5 of the KISS port format.
- Add cache naming, fetch, checkout, and extraction behavior to
  package-manager sections 9.1 and 9.4.
- If repository updates, rather than only package sources, gain these forms,
  extend repository detection and update behavior in section 14.4 separately.

Until all relevant points are adopted, these prefixes are not valid current
port sources.

## Proposal

In addition to supporting the *git* version control system for both package
sources and repositories, we should also support other version control systems.

The big two to support initially are mercurial and fossil.

For mercurial, the source string should resemble the following:

```
hg+https://linktorepo.com/repo/path#somecommitsha
```

For fossil, the source string should resemble the following:

```
fossil+https://linktorepo.com/repo/path#somecommitsha
```

## Implementors

### kiss.el

kiss.el supports both mercurial and fossil repositories for both packages and
repositories.


### cpt

Carbs Linux's package manager [cpt](https://fossil.carbslinux.org/cpt/doc/trunk/www/index.md) supports mercurial and fossil repositories
using the same scheme as outlined above.
