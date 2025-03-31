Yixe Documents
==============

Yixe documents are YAML documents which encode opinionated concepts mapping to Nix expressions.

The produced Nix expressions generally target a specific usage of Nix, for example NixOS, or Nixpkgs.

Documents are built from YAML *mappings*, and the first pair in the document denotes the document type, and its version.

The following describes a Yixe Project document:

```yaml
yixe-project: v0

# [...]
```

The semantics within a document are broadly defined by the document type.

The entries at the root of the document are reserved for the document type's implementation.


Shared semantics
----------------

These semantics should be followed by any Yixe document type, though they may not be used.

### Inputs

```yaml
# ...

inputs:
  sources:
    $name: { $type: $configuration }
```

The `inputs` *mapping* at the root of a document describe the document's inputs.

The provenance of an input is described in `sources`.

Any input in `sources` will be made available, and (when used) automatically `imported`.

> ***TODO***: allowing other transformations than `!call [ !nix.import, $input, {} ]`

Inputs may be locked, depending on the scheme used to fetch the source.

See the *Yixe Lock* document type.


### Outputs

```yaml
# ...

outputs:
  hello: "Hello, world!"
```

When a document has multiple outputs, they are defined with the `outputs` *mapping*.

The semantics are defined by the document type.

Note that the singular `output` name is used by `yixe-expression`, which is a document type mapping to a Nix expression.


### Arguments

```yaml
# ...

arguments:
  - hello
  - ...
```

Some documents may describe a *Nix function* with a *set-pattern* argument.

The `arguments` pair at the root-level is a *sequence* of arguments.

 - A string describes an argument name. Must be a valid Nix identifier.

> ***TODO***: Support default values with a one-entry mapping argument ` - arg: defaultValue`


Magic and Tags
--------------

YAML as-is wouldn't be sufficient to properly convey the richness of a programming language such as Nix.

To help provide this richness, Yixe uses *tags* from YAML to implement advanced features.

Since a lot of this would be inconvenient when this is supposed to help end-users think less, the concept of *magic* exists in Yixe.

By default, all Yixe documents are ran in with *magic* turned on.

> ***TODO***: allow turning magic off at the document level, and opting-in into magic.

The *magic* in Yixe is expressed through the tags system being turned on.

A Yixe document type defines the tags that are available.


### Common Tags

Quick demonstration:

```yaml
# ...

# This example describes a commong Nix pattern, but there are other ways to
# describe a package with Yixe.
outputs:
  my-package: !call
   - !inputs.nixpkgs.callPackage
   - ./my-package.nix
   - {}
```

> ***TODO***: A less misleading, and maybe more useful, example.


#### `!call`

This tag implements the “*Nix ABI*”, if you will.
It allows calling into Nix native code from within a Yixe document, for when Yixe cannot express a given concept.

The `!call` tag expects to receive a sequence, which is producing a series of Nix function calls.

```yaml
!call
 - a
 - b
 - c
```

Produces:

```nix
(("a") ("b") ("c"))
```

***This is not valid Nix***, but this shows that the Yixe types are the ones in use in the produced Nix document.


#### `!nix.*`

This tag allows referring to identifiers from the global Nix scope.

```yaml
!nix.builtins.nixVersion
```

Produces:

```nix
(builtins.nixVersion)
```


#### `!nix`

This tag will transclude the node it is attached to directly into the Nix document.

In other words, this can be used to include a raw fragment of Nix.

Note that the scope is subject to change, and not a stable API.


#### `!inputs`

This tag allows referring to an inputs.

```yaml
!inputs.nixpkgs.callPackage
```

Produces (morally equivalent to):

```nix
(/* “inputs from Yixe” */).nixpkgs.callPackage
```


#### `!pkgs.*`

> ***TODO***: Implement.

This tag automatically refers to *a package set*, which default to the `pkgs` argument, the `nixpkgs` input, or the `pkgs` input.

```yaml
 - !pkgs.hello
```

Produces (morally equivalent to):

```nix
((/* “inputs from Yixe” */).nixpkgs).hello
```

An alternative package set can be configured with `inputs`, for document types with `inputs`.

```yaml
inputs:
  pkgs: !inputs.not-nixpkgs.package-sets.all-packages
```

For document types using only `arguments`, only the `pkgs` argument will be promoted to the arguments set automatically.


#### `!lib.*`

> ***TODO***: Implement.

This tag automatically refers to a `lib` input or argument.
Generally it will come from either the `arguments`, or from `!pkgs.lib`.
It is important to note that it will prefer using `arguments` to get `lib`, as it is conventional that the `lib` from `pkgs` may not be as featured as the one from arguments (e.g. in NixOS modules or `callPackage`).

```yaml
something: !lib.mkForce someValue
```

Produces (morally equivalent to):

```nix
{
  something = (/* “Some input or argument” */).lib.mkForce "someValue";
}
```

When a value is given to `!lib.*`, it will be assumed that the `lib` reference is to a function call.
When multiple arguments need to be passed, passing a sequence will be necessary.

```yaml
something-else: !lib.mkIf
  - false
  - "Will not happen"
```

Produces (morally equivalent to):

```nix
{
  something-else =
    (/* “Some input or argument” */).lib.mkIf
    (false)
    ("someValue")
  ;
}
```

When no value is given, it is used as a value.

```yaml
version: !lib.version
```

Produces (morally equivalent to):

```nix
{
  version = (/* “Some input or argument” */).lib.version;
}
```
