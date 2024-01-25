## Provides System

This is a working document to detail a provides system.

The fundamental idea behind the provides system is to prevent the existence
of dummy packages. For example, if one were to use LLVM/Clang as their
C compiler/binutils then it would not make sense for them to also have a
separate package for clang. In this case, their llvm package would **provide**
both llvm and clang.

Relevant Codeberg Issue: [88](https://codeberg.org/kiss-community/repo/issues/88)

## Implementors

### kiss-rs
[kiss-rs](https://github.com/XDream8/kiss-rs) has implemented a provides system
with the following behavior/features.

There is now a new command `kiss-provides`.

To have package A provide package B, you would run `kiss-provides A B`

The provides system data is stored in `/var/db/kiss/provides`, with the
following format:

```
<provider> <provides>
```

If one were to provide *rust* with *rustup*, they would enter the following:

```
rustup rust
```


### kiss.el

[kiss.el](https://github.com/ehawkvu/kiss.el) has implemented an ad-hoc
provides system in the README for the project.

The system works by hooking into the internal functions of the implementation
itself, using GNU Emacs' advice system.

The configuration is done through setting the `kiss-provides-alist` variable.
The syntax is as follows:

```
("provider" . ("provides" "these" "packages"))
```
