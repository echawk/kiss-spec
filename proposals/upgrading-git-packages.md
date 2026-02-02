## Upgrading "git" packages.

Currently, git packages will not receive updates through the normal
`kiss update` and `kiss upgrade` commands. Instead, responsibility falls
to the user to make sure that they update these packages appropriately.

A remedy to fix this would be to log the current git hash of the package
into a file on the system - this could be easily compared against whatever
the latest from git is.

The downside to this approach is that every git package will have to have
its' sources downloaded before the check can occur, making this a potentially
expensive check.

Instead of this being included with the default update & upgrade commands,
this behavior could be added to separate commands.

These commands could be called something along the lines of `kiss vc-update`
and `kiss vc-upgrade` which will perform the aforementioned updating and
upgrading of said packages. Additionally, this naming scheme keeps the
actual process version control agnostic, so if mercurial or fossil sources
were supported in the future, they could also be added to this scheme.

The relevant commands to get the commit sha for each of the respective
vc sources are as follows:

### git

```sh
git rev-parse HEAD
```


### hg

```sh
hg id -i
```

### fossil
```sh
fossil info . | awk '/^checkout/ {print $2}'
```

## Implementors


