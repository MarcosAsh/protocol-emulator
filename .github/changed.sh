#!/bin/sh
# Prints GROUP=true or GROUP=false for each group named: whether a branch changed what
# that group's CI jobs read since it left main. A later push that leaves them alone still
# runs them. Pushes to main, the nightly and a dispatch get true for every group. A nightly
# on a commit whose push run of ocaml.yaml is green gets repeat, proofs for the generate
# job, and nothing else (needs GH_TOKEN).
# Usage: .github/changed.sh GROUP... >> "$GITHUB_OUTPUT", from a checkout with fetch-depth: 0
set -eu

all=false
if [ "${GITHUB_EVENT_NAME:-push}" != push ] || [ "${GITHUB_REF:-}" = refs/heads/main ]; then
  all=true
elif ! base=$(git merge-base origin/main HEAD); then
  all=true
fi

repeat=false
if [ "${GITHUB_EVENT_NAME:-}" = schedule ] && [ -n "${GH_TOKEN:-}" ]; then
  green=$(gh api "repos/$GITHUB_REPOSITORY/actions/workflows/ocaml.yaml/runs?head_sha=$GITHUB_SHA&event=push&status=success" \
    --jq .total_count) || green=0
  if [ "$green" -gt 0 ]; then repeat=true; fi
fi
repeat() { [ "$repeat" = true ]; }

changed() { [ "$all" = true ] || ! git diff --quiet "$base" HEAD -- "$@"; }

# dune build @runtest, which reads almost everything but the prose, and the board variants
tests() {
  ! repeat || return 1
  changed . ':!*.md' ':!docs' ':!LICENSE' ':!.github' ':!test/evidence.py' ':!test/evidence.sha256' \
    ':!test/board' ||
    changed test/board/kernel_vs_board/SHA256SUMS.inputs test/board/kernel_vs_board/verdicts.tsv
}

# the generators, the certificate writers, the translation check and the library they
# link, formal/, and the workflow whose Prove step names the proofs
proofs() {
  changed src bin ppx formal test/certify test/models test/translation test/dune ':(glob)test/*.ml' \
    .github/workflows/ocaml.yaml \
    ':(glob)test/*.mli' ':(glob)test/*.asm' ':(glob)test/*.hex' ':(glob)test/*.settings' \
    dune-project 'protocol_emulator.opam*'
}

# the cocotb tests on the committed Verilog and what they import, not the OCaml or the
# scripts CI runs elsewhere
rtl() {
  changed src test python demo info.yaml icepi/carrier_check.v ':!*.ml' ':!*.mli' ':!**/dune' ':!*.md' ':!*.sh' \
    ':!test/assemble' ':!test/certify' ':!test/split' ':!test/python' ':!test/results.py' \
    ':!test/check_docs.py' ':!test/mutate.py' ':!test/mutation_allow.txt' ':!test/plant.py' \
    ':!test/check_coverage.py' ':!test/coverage_triage.txt' \
    ':!test/heldout.sha256' ':!test/evidence.py' ':!test/evidence.sha256' ':!test/board' \
    ':!demo/witness.py' ':!test/test_witness.py'
}

# the same on the FPGA netlists, which are built from the OCaml and icepi/ too
fpga() { ! repeat || return 1; rtl || changed src bin ppx icepi dune-project 'protocol_emulator.opam*'; }

for group in "$@"; do
  case $group in
    tests | proofs | rtl | fpga | repeat) ;;
    *) echo "no group $group" >&2; exit 1 ;;
  esac
  if "$group"; then echo "$group=true"; else echo "$group=false"; fi
done
