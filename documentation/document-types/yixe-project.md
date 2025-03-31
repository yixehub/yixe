Yixe Project
============

The *Yixe Project* document describes a *project*.

Think of it as a description of the packages and other miscellaneous environmental consideration for your software project.


Tags
----

### `!project`

The `!project` tag namespace is made available in a Yixe Project document.

#### `!project.shell`

The given mapping will be built as a Yixe Shell derivation.

```yaml
!project.shell

packages:
  # Unqualified packages makes implicit use of `!pkgs`.
  - hello
  # Otherwise tags such as `!call` may be useful
  - !call
    - !inputs.nixpkgs.callPackage
    - ./some/nix/expression.nix
    - {}
environment:
  FOO: BAR
# DO NOT USE:
# Currently passed directly to `mkShell`, but not supported and will be removed.
mkShell:
  # ...
```
