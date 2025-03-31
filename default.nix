# This stubs allows using Yixe directly from a tarball.
# "$(nix-build --no-out-link 'https://github.com/yixehub/yixe/archive/development.zip' --attr yixe)/bin/yixe" --help
import ./project.yixe.nix
