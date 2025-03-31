#!/usr/bin/env bash

set -e
set -u
PS4="\n $ "
set -x

ruby ./test/run.rb
