#!/usr/bin/env bash

set -e
set -u
PS4="\n $ "
set -x

exec ./yixe transpile ./project.yixe > project.yixe.nix
