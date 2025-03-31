Input types
===========


`npins`
-------

This input type borrows the semantics from `npins`, with a twist.

 - Instead of using a command-line tool to edit the pins, the pins are always declared within the Yixe document.
 - The pinning data is saved to the `*.yixe.lock` file, instead of `npins/sources.json`.
 - The `npins/default.nix` stub is managed by Yixe.

```yaml
inputs:
  sources:
    # Example usage of `channel` npin input type
    nixpkgs: { npins: { channel: nixos-unstable } }
    # Example usage of a `github` npin input type
    yixe:
      npins:
        github:
          owner: "yixehub"
          repo: "yixe"
```

See the `npins` command's help for the different fields an input can use.
The mapping keys directly map to named parameters (e.g. `branch:` for `--branch`, `owner:` for `<owner>`).


`nixos-channel`
---------------

> ***NOTE***: Cannot currently be locked.

This is equivalent to a `builtins.fetchTarball "channel:https://channels.nixos.org/[...]/nixexprs.tar.xz"` call.

Using this input type should be limited to trivial examples.

Prefer using `npins` with a `channel` input instead.
