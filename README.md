Yixe
====

*Or, what if I made Nix worse?*

Yixe is pronounced exactly like *yikes*, as it is the first sound you're likely tempted to utter, when realizing what this is.

* * *

What's Yixe?
------------

Yixe is an experimental interface to declarative build environments.

See the `documentation` folder in the repository for more notes.


Quickest start
--------------

```
 $ "$(nix-build --no-out-link 'https://github.com/yixehub/yixe/archive/development.zip' --attr yixe)/bin/yixe" --help
Usage: yixe <command>

Commands:
   transpile  <document>
     Transpile a document to Nix.
   lock <document>
     Update a document's locks.
   project shell <document>
     Launches a project's `shell` attribute.
   build <document> [attribute]
     Builds an output. The `attribute` argument is mandatory for documents with mutiple outputs.
```

> ***NOTE***: It is important you understand what the previous command does, before you run it.


FAQ(?)
------

### What does Yixe stands for?

~~*YAML is eXpletively strange*~~.

But don't dwell too much on this acronym.

It's a contrived backronym of trying to fit “*ix*” with the Y of *YAML*.
Yix didn't feel good, and Yixe has a great ring to it.


### Great, so I don't need to learn Nix?

~~Exactly!!~~

> ***Real talk time***
>
> As with any of the other tools wrapping or using Nix, Nixpkgs and NixOS,
> you will need to learn Nix, Nixpkgs and NixOS, in some form.
>
> This stands for all the fancy development environments built around Nix,
> but also stands for Flakes, where understanding the underlying semantics is a strong requirement.
>
> After all, the moment you stray off the happy path, only knowledge of Nix can help you.
> And without appropriate escape hatches into the Nix world, as is available in Yixe,
> it may be hard to solve less-than-trivial issues.
