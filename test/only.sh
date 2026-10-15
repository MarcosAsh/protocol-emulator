#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# The inline tests of some files of test/ alone, four at a time, in minutes where dune's
# runtest takes them all, then a diff of each whose output changed. -library adds every
# test that reads Library, which a new protocol's lines show up in. -promote puts the new
# output in place, as dune promote would: rerun after a fix before promoting, or the old
# run's output goes over it.
# Usage: test/only.sh [-promote] [-library] test_uart.ml...   from the repository's root
set -e
promote=
library=
while [ $# -gt 0 ]; do
    case $1 in
    -promote) promote=yes ;;
    -library) library=yes ;;
    *) break ;;
    esac
    shift
done
files=$*
[ -z "$library" ] || files="$files $(grep -l 'Library\.' test/test_*.ml | xargs -n1 basename)"
files=$(for f in $files; do basename "$f"; done | sort -u)
[ -n "$files" ] || { echo "usage: $0 [-promote] [-library] test_FILE.ml..." >&2; exit 1; }
runner=.protocol_emulator_test.inline-tests/inline-test-runner.exe
# the runner, and the files its tests read, as test/dune lists them
deps=$(ls test/*.asm test/*.hex test/assemble/*.asm formal/Makefile src/protocol_emulator.v \
    python/demo_board.py icepi/Makefile | sed 's|^|_build/default/|')
# shellcheck disable=SC2086
dune build --root . "_build/default/test/$runner" $deps
for file in $files; do
    rm -f "_build/default/test/$file.corrected"
done
status=0
# shellcheck disable=SC2086
(cd _build/default/test && printf '%s\n' $files | xargs -P 4 -I % \
    "./$runner" inline-test-runner protocol_emulator_test -source-tree-root . \
    -only-test % -diff-cmd -) || status=$?
changed=0
for file in $files; do
    corrected="_build/default/test/$file.corrected"
    if [ -f "$corrected" ] && ! cmp -s "test/$file" "$corrected"; then
        changed=1
        diff -u "test/$file" "$corrected" || true
        [ -z "$promote" ] || cp "$corrected" "test/$file"
    fi
done
if [ $status != 0 ]; then
    echo "the test runner exited $status" >&2
    exit 1
fi
if [ $changed = 1 ] && [ -z "$promote" ]; then
    exit 1
fi
