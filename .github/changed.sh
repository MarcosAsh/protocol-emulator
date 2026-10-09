#!/bin/sh
# Prints GROUP=true or GROUP=false for each group named: whether a branch changed what
# that group's CI jobs read since it left main. A later push that leaves them alone still
# runs them. Pushes to main, the nightly and a dispatch get true for every group.
# Usage: .github/changed.sh GROUP... >> "$GITHUB_OUTPUT", from a checkout with fetch-depth: 0
set -eu

all=false
if [ "${GITHUB_EVENT_NAME:-push}" != push ] || [ "${GITHUB_REF:-}" = refs/heads/main ]; then
  all=true
elif ! base=$(git merge-base origin/main HEAD); then
  all=true
fi

changed() { [ "$all" = true ] || ! git diff --quiet "$base" HEAD -- "$@"; }

# dune build @runtest, which reads almost everything but the prose
tests() { changed . ':!*.md' ':!docs' ':!LICENSE' ':!.github'; }

# the generators, the certificate writers and the library they link, and formal/
proofs() {
  changed src bin ppx formal test/certify test/models test/dune ':(glob)test/*.ml' \
    ':(glob)test/*.mli' ':(glob)test/*.asm' ':(glob)test/*.hex' ':(glob)test/*.settings' \
    dune-project 'protocol_emulator.opam*'
}

# the cocotb tests on the committed Verilog and what they import, not the OCaml or the
# scripts CI runs elsewhere
rtl() {
  changed src test python demo info.yaml ':!*.ml' ':!*.mli' ':!**/dune' ':!*.md' ':!*.sh' \
    ':!test/assemble' ':!test/certify' ':!test/split' ':!test/python' ':!test/results.py' \
    ':!test/check_docs.py' ':!test/mutate.py' ':!test/mutation_allow.txt' \
    ':!test/heldout.sha256'
}

# the same on the FPGA netlists, which are built from the OCaml and icepi/ too
fpga() { rtl || changed src bin ppx icepi dune-project 'protocol_emulator.opam*'; }

for group in "$@"; do
  case $group in
    tests | proofs | rtl | fpga) ;;
    *) echo "no group $group" >&2; exit 1 ;;
  esac
  if "$group"; then echo "$group=true"; else echo "$group=false"; fi
done
