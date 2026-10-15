#!/bin/sh
# Runs the inline tests a partition at a time, as dune runtest does, with Hardcaml's
# cyclesim coverage on, and keeps each partition's report as coverage/PARTITION.txt.
# Fails if a test does: coverage counts only on a passing suite.
# Usage: test/coverage.sh RUNNER, from the test directory in _build
set -eu
runner=$1
rm -rf coverage
mkdir coverage
status=0
for partition in $("$runner" inline-test-runner protocol_emulator_test -list-partitions); do
  HARDCAML_CYCLESIM_COVERAGE_VERBOSE=1 "$runner" inline-test-runner protocol_emulator_test \
    -source-tree-root . -diff-cmd - -partition "$partition" ||
    { echo "coverage.sh: $partition failed" >&2; status=1; }
  mv coverage.txt "coverage/$partition.txt"
done
exit $status
