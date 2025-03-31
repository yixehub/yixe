Yixe Nixpkgs Package
====================

This document is expected to use `arguments` and `outputs`, and is equivalent to a `callPackage`'d package in Nixpkgs.

The `pkgs` and `lib` arguments may be automatically promoted in the arguments of the document when needed.

The builder in use can be changed with the `builder` value, which defaults to `stdenv.mkDerivation`.

The builder does not need to be added to `arguments`, it automatically will be.

The contents of `output.environment` will be passed as `env`.

The `name` argument will be used as `pname` if `version` is also given.
