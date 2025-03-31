#!/usr/bin/env bash

set -e
set -u
PS4="\n $ "
(
set -x
rubocop --autocorrect
yamllint .
)

cat <<EOF

:: Completed assumedly successfully!

EOF

