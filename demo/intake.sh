#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Spec intake: a headless Claude Code agent turns a protocol's spec (a datasheet PDF, a
# WaveJSON file or a limit table as text) into a protocol file, firmware and test with
# generate new-protocol, and the kernel certifies it. Makes a worktree intake-NAME on a branch
# intake/NAME off the current commit and a run directory holding the prompt (demo/intake_prompt.txt),
# the spec as text with page markers (pdftotext -layout) and an index of its limits, the full
# transcript (transcript.jsonl, stream-json), stages.log, speed.tsv and verdict.txt: certified,
# refused with the named limit, or failed. speed.tsv is the worktree's demo/speed.tsv rows for
# NAME, which generate new-protocol and the formal targets write through demo/speed.py.
# Usage: demo/intake.sh [--dry-run] [--budget USD] [--model M] [--out DIR] SPEC NAME
#   --dry-run  makes the worktree and run directory and prints the claude command, then removes the worktree
set -e
dry=
budget=${INTAKE_BUDGET:-25}
model=
out=${INTAKE_OUT:-$HOME/.local/share/protocol-emulator/intake}
while [ $# -gt 0 ]; do
    case $1 in
    --dry-run) dry=yes ;;
    --budget) budget=$2; shift ;;
    --model) model=$2; shift ;;
    --out) out=$2; shift ;;
    -*) echo "unknown option $1" >&2; exit 2 ;;
    *) break ;;
    esac
    shift
done
[ $# = 2 ] || { sed -n 's/^# Usage: //p' "$0" >&2; exit 2; }
spec=$(realpath "$1")
name=$2
[ -f "$spec" ] || { echo "no spec at $1" >&2; exit 2; }
case $name in
*[!a-z0-9_]* | [!a-z]*) echo "NAME is lowercase letters, digits and _" >&2; exit 2 ;;
esac
here=$(cd "$(dirname "$0")/.." && pwd)
root=$(git -C "$here" rev-parse --show-toplevel)
run=$out/$name-$(date +%Y%m%d-%H%M%S)
main=$(dirname "$(git -C "$root" rev-parse --path-format=absolute --git-common-dir)")
tree=$root/.claude/worktrees/intake-$name
mkdir -p "$run"
log() { printf '%s\t%s\n' "$(date -Is)" "$*" >> "$run/stages.log"; }
verdict() {
    echo "$*" > "$run/verdict.txt"
    log "verdict $*"
    echo "$*"
    echo "run directory: $run"
}
log "start $name from $spec"

# the spec as text, with "=== page N ===" markers
case $spec in
*.pdf | *.PDF)
    kind=pdf
    command -v pdftotext >/dev/null || { verdict "failed: pdftotext is missing"; exit 1; }
    pages=$(pdfinfo "$spec" 2>/dev/null | sed -n 's/^Pages: *//p')
    [ -n "$pages" ] || { verdict "failed: not a readable PDF"; exit 1; }
    : > "$run/spec.txt"
    p=1
    while [ "$p" -le "$pages" ]; do
        echo "=== page $p ===" >> "$run/spec.txt"
        { pdftotext -layout -f "$p" -l "$p" "$spec" - 2>/dev/null || true; } | tr -d "\f" >> "$run/spec.txt"
        p=$((p + 1))
    done
    chars=$(grep -v '^=== page' "$run/spec.txt" | tr -d ' \t\n\f' | wc -c)
    if [ "$chars" -lt $((pages * 10)) ]; then
        verdict "failed: the PDF has no text layer ($chars characters in $pages pages), scanned or image only"
        exit 1
    fi
    cp "$spec" "$run/spec.pdf"
    note="the text is $run/spec.txt (pdftotext -layout, $pages pages), the limits' lines with their pages are indexed in $run/spec.index, the original is $run/spec.pdf"
    ;;
*.json)
    kind=wavejson
    python3 -I -c 'import json,sys; json.load(open(sys.argv[1]))' "$spec" 2>/dev/null ||
        { verdict "failed: the WaveJSON file is not valid JSON"; exit 1; }
    { echo "=== page 1 ==="; cat "$spec"; } > "$run/spec.txt"
    note="the WaveJSON is $run/spec.txt (one page); src/wavedrom.mli says what the compiler takes and test/diagrams/ has examples"
    ;;
*)
    kind="limit table"
    { echo "=== page 1 ==="; cat "$spec"; } > "$run/spec.txt"
    note="the limit table is $run/spec.txt (one page); it has no page numbers to cite, so cite its line numbers"
    ;;
esac
awk '/^=== page /{p=$3; next}
    tolower($0) ~ /(table|figure|fig\.)|[0-9] ?(ns|µs|us|ms|khz|mhz|kbit|baud|bps)([^a-z]|$)/ {print p ": " $0}' \
    "$run/spec.txt" | head -400 > "$run/spec.index"

# the worktree and the prompt
git -C "$root" worktree add -q -b "intake/$name" "$tree" HEAD ||
    { verdict "failed: could not make the worktree $tree"; exit 1; }
log "worktree $tree"
sed -e "s#@NAME@#$name#g" -e "s#@SPEC@#$spec#g" -e "s#@KIND@#$kind#g" -e "s#@DIR@#$run#g" \
    -e "s#@SPEC_NOTE@#$note#" \
    "$here/demo/intake_prompt.txt" > "$run/prompt.txt"
tools="Read,Write,Edit,Glob,Grep,Bash(dune:*),Bash(make:*),Bash(test/only.sh:*),Bash(python3:*),Bash(ocamlformat:*),Bash(sigrok-cli:*),Bash(git add:*),Bash(git commit:*),Bash(git status:*),Bash(git diff:*),Bash(git log:*),Bash(timeout:*),Bash(ls:*),Bash(cat:*),Bash(sleep:*)"
set -- claude -p --output-format stream-json --verbose --permission-mode acceptEdits \
    --max-budget-usd "$budget" --add-dir "$run" --allowedTools "$tools"
[ -z "$model" ] || set -- "$@" --model "$model"
if [ -n "$dry" ]; then
    echo "worktree: $tree"
    echo "run directory: $run (prompt.txt, spec.txt, spec.index)"
    echo "would run in the worktree: $* < $run/prompt.txt > $run/transcript.jsonl"
    git -C "$root" worktree remove --force "$tree"
    git -C "$root" branch -D "intake/$name" >/dev/null
    log "dry run, worktree removed"
    exit 0
fi

# the agent, then the kernel's own check of what it left
cd "$tree"
# the untracked files of the root the agent and the flow need
for f in env.sh CLAUDE.md CONVENTIONS.md PLAN.md; do
    [ -f "$f" ] || [ ! -f "$main/$f" ] || cp "$main/$f" "$f"
done
[ ! -f env.sh ] || . ./env.sh
command -v opam >/dev/null && eval "$(opam env --switch 5.2.0+ox --set-switch)"
log "agent start"
status=0
timeout "${INTAKE_TIMEOUT:-14400}" "$@" < "$run/prompt.txt" > "$run/transcript.jsonl" 2> "$run/claude.err" || status=$?
log "agent end exit $status"
{ head -n 1 demo/speed.tsv; grep "^$name	" demo/speed.tsv; } > "$run/speed.tsv" 2>/dev/null || true
agent=$(python3 -I - "$run/transcript.jsonl" <<'PY'
import json, sys
last = ""
for line in open(sys.argv[1], errors="replace"):
    try:
        m = json.loads(line)
    except ValueError:
        continue
    if m.get("type") == "result":
        last = str(m.get("result", "")) or m.get("subtype", "")
        sub = m.get("subtype", "")
        if sub and sub != "success":
            print("VERDICT: failed " + sub)
            sys.exit()
lines = [l.strip() for l in last.splitlines() if l.strip().startswith("VERDICT:")]
print(lines[-1] if lines else "VERDICT: failed the agent gave no verdict line")
PY
)
check=0
test/only.sh "test_$name.ml" > "$run/check.log" 2>&1 || check=$?
log "check test/only.sh test_$name.ml exit $check"
case $agent in
"VERDICT: certified")
    if [ $check = 0 ] && grep -q "certificate" "$run/speed.tsv"; then
        verdict certified
    else
        verdict "failed: the agent said certified, but the check exited $check or no certificate stage was marked"
    fi
    ;;
"VERDICT: refused"*) verdict "refused:${agent#VERDICT: refused}" ;;
*) verdict "failed:${agent#VERDICT: failed}" ;;
esac
echo "transcript: $run/transcript.jsonl"
