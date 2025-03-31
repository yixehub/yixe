Conventions for Yixe
====================


Default paths
-------------

There is no *default path* implied like with Nix.
No equivalents to `default.nix`, no `shell.nix`, no `flake.nix` either.

While it may be inconvenient, users always have to declare their use of a specific document.

This prevents too much magic from being involved all at once.

As such, to get into a shell:

```
 $ yixe project shell project.yixe
```

This way, the provenance of the expressions at play is always known.

Similarly, importing or using a folder is not allowed, the path to a document is needed.

> When dealing with “Nix compatibility”, the default semantics of Nix are followed.
> Naturally it wouldn't make sense to not have a Nix `import` follow the Nix semantics.
