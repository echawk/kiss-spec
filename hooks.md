## Hooks

| hook          | arg1   | arg2     | arg3               | arg4           |
|---------------|--------|----------|--------------------|----------------|
| build-fail    | Type   | Package  | Build directory    |                |
| post-build    | Type   | Package  | DESTDIR            |                |
| post-install  | Type   | Package  | Installed database |                |
| post-package  | Type   | Package  | Tarball            |                |
| post-source   | Type   | Package  | Verbatim source    | Resolved source|
| post-update   | Type   | [7]      |                    |                |
| pre-build     | Type   | Package  | Build directory    |                |
| pre-extract   | Type   | Package  | DESTDIR            |                |
| pre-install   | Type   | Package  | Extracted package  |                |
| pre-remove    | Type   | Package  | Installed database |                |
| pre-source    | Type   | Package  | Verbatim source    | Resolved source|
| pre-update    | Type   | [7] [8]  |                    |                |
| queue-status  | Type   | Package  | Number in queue    | Total in queue |

The -update hooks start in the current repository. In other words, you can
operate on the repository directly or grab the value from '\$PWD'.

The second argument of pre-update is '0' if the current user owns the
repository and '1' if they do not. In the latter case, privilege
escalation is required to preserve ownership.
