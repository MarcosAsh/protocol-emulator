#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Each NAME.job.json's result files as generate.exe lab writes them, against NAME/, which
# test/test_lab_worker.py's stand-in for the checker hands the worker. -update rewrites
# NAME/ instead, after a change to Remote_lab.
# Usage: test/lab/check.sh [-update] GENERATE.EXE DIR
set -e
update=
[ "$1" != -update ] || { update=yes; shift; }
generate=$1
dir=$2
out=$(mktemp -d)
trap 'rm -rf "$out"' EXIT
status=0
for job in "$dir"/*.job.json; do
    name=$(basename "$job" .job.json)
    "$generate" lab "$job" -out "$out/$name" > /dev/null 2>&1 || [ $? -le 2 ]
    if [ -n "$update" ]; then
        rm -rf "${dir:?}/$name" && cp -r "$out/$name" "$dir/$name"
    else
        diff -r "$dir/$name" "$out/$name" || status=1
    fi
done
exit $status
