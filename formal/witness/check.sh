#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Rechecks this bundle's Certifaiger witnesses with no OCaml or repo build. Per lemma, Yosys
# remakes model.aig from the Verilog through model.ys byte for byte, and each of Certifaiger's
# nine checks is UNSAT by an LRAT proof cake_lpr verifies. Each tooth, a weakened model, has
# to replay its counterexample in aigsim and make Certifaiger reject the witness. Tools as
# tools.sh pins them, from tools/ or PATH. One line per lemma, exit 1 if any fails.
# Usage: [HEAP=<cake_lpr's heap in MB, 4096>] ./check.sh [lemma ...]
set -u
here=$(cd "$(dirname "$0")" && pwd)
PATH=$here/tools/bin:$here/tools/oss-cad-suite/bin:$PATH
checks="Reset Safety Base Transition Liveness Decrease Closure Consistent Inductive"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

sha256() {
    if command -v sha256sum > /dev/null; then sha256sum "$@"; else shasum -a 256 "$@"; fi
}

# $2's model in $3, from the Verilog in $1 and $2's read.ys, the same as $2/model.aig
model() {
    mkdir -p "$3" && find "$1" -maxdepth 1 -type f -name '*.*v' -exec cp {} "$3" \; \
        && cp "$2/read.ys" "$3" && (cd "$3" && yosys -q -l model.log "$here/model.ys" > /dev/null 2>&1) \
        && cmp -s "$3/model.aig" "$2/model.aig"
}

# $2 UNSAT in $1 only if cake_lpr verifies the LRAT proof cadical pipes to it
unsat() {
    (cd "$1" && aigtocnf "$2.aig" "$2.cnf" \
        && { cadical -q --unsat --lrat=true -w "$2.cadical" "$2.cnf" -; echo $? >> "$2.cadical"; } \
        | cake_lpr --CML_HEAP_SIZE="${HEAP:-4096}" "$2.cnf" /dev/stdin > "$2.cake" 2>&1)
    [ "$(tail -n 1 "$1/$2.cadical")" = 20 ] && [ "$(cat "$1/$2.cake")" = "s VERIFIED UNSAT" ] \
        && rm "$1/$2.cnf"
}

# Certifaiger's checks of $1's model and witness $2, split into $1, exactly the nine
split() {
    (cd "$1" && certifaiger model.aig "$2" check.aig > certifaiger.log && aigsplit -n check.aig) \
        && [ "$(ls "$1" | grep '\.aig$' | grep -vx -e model.aig -e check.aig | sort | xargs)" \
            = "$(printf '%s.aig\n' $checks | sort | xargs)" ]
}

# one of the checks in $1 satisfiable, cheapest first; a tool erroring out is no rejection
rejects() {
    for check in $checks; do
        (cd "$1" && aigtocnf "$check.aig" "$check.cnf" && cadical -q "$check.cnf" > "$check.cadical")
        case $? in 10) return 0 ;; 20) ;; *) return 1 ;; esac
    done
    return 1
}

lemma() {
    dir=$here/$1
    [ -f "$dir/witness.aig" ] || { echo "no lemma $1 in this bundle"; return 1; }
    model "$dir" "$dir" "$work/$1" || { echo "model.aig is not the Verilog's"; return 1; }
    split "$work/$1" "$dir/witness.aig" || { echo "Certifaiger did not make the nine checks"; return 1; }
    for check in $checks; do
        unsat "$work/$1" "$check" || { echo "$check not verified"; return 1; }
    done
    teeth=0
    for tooth in "$dir"/teeth/*; do
        [ -d "$tooth" ] || continue
        name=$(basename "$tooth")
        model "$dir" "$tooth" "$work/$1_$name" || { echo "tooth $name: model.aig is not the Verilog's"; return 1; }
        aigsim -c "$work/$1_$name/model.aig" "$tooth/cex.aiw" > /dev/null \
            || { echo "tooth $name: counterexample does not replay"; return 1; }
        { split "$work/$1_$name" "$dir/witness.aig" && rejects "$work/$1_$name"; } \
            || { echo "tooth $name: witness not rejected"; return 1; }
        teeth=$((teeth + 1))
    done
    echo "9 checks verified, $teeth teeth fail"
}

cd "$here" || exit 1
sha256 -c --status SHA256SUMS || { echo "a file differs from SHA256SUMS"; exit 1; }
echo "SHA256SUMS $(sha256 SHA256SUMS | cut -c1-64)"
echo "yosys: $(yosys -V), cadical $(cadical --version), certifaiger $(certifaiger --version)"
[ $# -gt 0 ] || set -- $(ls */witness.aig | xargs -n 1 dirname)
failed=0
for name in "$@"; do
    start=$(date +%s)
    line=$(lemma "$name") || { line="FAIL, $line"; failed=1; }
    echo "$name: $line ($(($(date +%s) - start)) s)"
done
exit $failed
