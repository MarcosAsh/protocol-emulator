#!/bin/sh
# Runs the inline tests one partition at a time, like dune runtest, with Hardcaml cyclesim
# coverage on. Each report lands in coverage/PARTITION.txt. Fails if any test fails, since
# coverage only counts on a passing suite. COVERAGE_SHARD=K/N keeps every Nth partition
# from the Kth, for CI to spread the run over N runners.
# Usage: test/coverage.sh RUNNER, from the test directory in _build
set -eu
runner=$1
rm -rf coverage
mkdir coverage
shard=${COVERAGE_SHARD:-0/1}
status=0
index=0
for partition in $("$runner" inline-test-runner protocol_emulator_test -list-partitions); do
  index=$((index + 1))
  [ $((index % ${shard#*/})) -eq "${shard%/*}" ] || continue
  HARDCAML_CYCLESIM_COVERAGE_VERBOSE=1 "$runner" inline-test-runner protocol_emulator_test \
    -source-tree-root . -diff-cmd - -partition "$partition" ||
    { echo "coverage.sh: $partition failed" >&2; status=1; }
  mv coverage.txt "coverage/$partition.txt"
done
exit $status
