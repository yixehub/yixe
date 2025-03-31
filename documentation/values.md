Values
======

Values in a Yixe document *kinda* follows the semantics of a YAML document, but also specializes for Nix conventions.

As such, scalar values may differ from the expectation.

Scalar Values
-------------

Scalar values in YAML *“represents strings, integers, dates and other atomic data types”*[^1].

Where it differs from YAML (1.2) is that the different scalar types are not tagged.
Additionally, *Scalar Formats*[^2] differ from YAML (1.1) expectations.
They also differ from YAML (1.2) *Tag Resolution*[^4]

> ***NOTE***: This is subject to change, and may be updated to better follow these conventions.
> It is likely to be configured via a document-level tag, or other feature enablement.


Strings
-------

Any quoted strings, or block scalars, will result in string values.

There is currently no *antiquotation* or *expansion* scheme available.
Strings values are guaranteed forward compatible for *antiquotation* and *expansion*,
as any such scheme will require using a tag on a given string.

Unquoted strings currently will be expanded to different types when they match some rules.

When no rules are matched, they keep being strings.

There is currently no distinction between quoted strings and unquoted strings in a Yixe expression,
but some constructs may require an unquoted string in the future.

> ***NOTE***:
>
>  - Unquoted strings usage as strings may be deprecated in all or some context at some point.
>  - Quoted strings in contexts describing non-string values may become an error in the future.


Boolean
-------

Scalars matching `true` and `false` will be handled as boolean values.


Numbers
-------

Integer values can be represented through different formats:

 - `4`, `-99` for decimal.
 - `0b0100`, for binary.
 - `0777`, `-0123`, for octal.
 - `0xff`, `-0x0A` for hexadecimal.

The main consideration here is that leading zeroes are forbidden for decimal representations.
Except for the value `0`.
`090` is invalid, and `010` is `8`.

For octal values, leading zero digits past the base zero are forbidden.
`00` is invalid, and `0010` is also invalid.

The range of representable values is ***not a concern for Yixe***.
The underlying runtime (currently Nix) is what limits the range of numbers.

There is no floating point representation at the moment.


Empty Nodes
-----------

Null values are represented through empty nodes, and the `null` value.

The `NULL`, `Null` and `~` values are not supported.

```yaml
nothing:
also-nothing: null
```


Paths
-----

Since paths have special semantics in Nix, path-like scalars are treated as path when transpiled to Nix.

> ***NOTE***: The same semantics as followed in Nix are attempted to be followed, but may not work well for files included from another file.
>
> The paths are not currently reworked to stay relative to the location of the original Yixe expression when they are transpiled into Nix.
>
> Relative paths handled within Yixe follow the expected semantics.
> They are relative to the file in which the path is written.

```yaml
relative_path: ./.
absolute_path: /.
not_a_path: /
not_a_path_either: ./
home_relative: ~/.
but_not: ~/
```


* * *

[^1]: https://yaml.org/spec/1.2.2/#311-dump
[^2]: https://yaml.org/spec/1.1/#id864510
[^3]: https://yaml.org/spec/1.2.2/#72-empty-nodes
[^4]: https://yaml.org/spec/1.2.2/#1032-tag-resolution
