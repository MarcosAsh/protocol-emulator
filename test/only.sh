#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# The inline tests of some files of test/ alone, in a minute where dune's runtest takes
# them all, then a diff of each whose output changed. -promote puts the new output in
# place, as dune promote would.
# Usage: test/only.sh [-promote] test_uart.ml test_protocol.ml   from the repository's root
set -e
promote=
if [ "$1" = -promote ]; then
    promote=yes
    shift
fi
[ $# -gt 0 ] || { echo "usage: $0 [-promote] test_FILE.ml..." >&2; exit 1; }
runner=test/.protocol_emulator_test.inline-tests/inline-test-runner.exe
# the runner, and the files its tests read, as test/dune lists them
deps=$(ls test/*.asm test/*.hex test/assemble/*.asm formal/Makefile src/protocol_emulator.v \
    python/demo_board.py icepi/Makefile | sed 's|^|_build/default/|')
# shellcheck disable=SC2086
dune build --root . "_build/default/$runner" $deps
only=
for file in "$@"; do
    only="$only -only-test $(basename "$file")"
    rm -f "_build/default/test/$(basename "$file").corrected"
done
# shellcheck disable=SC2086
(cd _build/default/test && "./$(basename "$(dirname "$runner")")/$(basename "$runner")" \
    inline-test-runner protocol_emulator_test -source-tree-root . $only -diff-cmd -)
changed=0
for file in "$@"; do
    name=$(basename "$file")
    corrected="_build/default/test/$name.corrected"
    if [ -f "$corrected" ] && ! cmp -s "test/$name" "$corrected"; then
        changed=1
        diff -u "test/$name" "$corrected" || true
        [ -z "$promote" ] || cp "$corrected" "test/$name"
    fi
done
if [ $changed = 1 ] && [ -z "$promote" ]; then
    exit 1
fi
