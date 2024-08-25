## Supporting other "VC" sources

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
