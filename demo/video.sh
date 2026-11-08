#!/bin/bash
# SPDX-License-Identifier: Apache-2.0
# Runs the video's shots (demo/video.py) on the bench machine under its lock, outside the
# tt-ci window, and copies the run back to
# ~/.local/share/protocol-emulator/board-evidence/<date>/video/<time>/.
# Usage: demo/video.sh late|fixed|heldout|keyboard|all
#   PC=marcos@192.168.0.219 A_PORT=3-3 B_PORT=3-2 (the analysers' USB ports)
set -euo pipefail
shot=${1:?usage: demo/video.sh late|fixed|heldout|keyboard|all}
PC=${PC:-marcos@192.168.0.219}
stamp=$(date +%Y%m%d-%H%M%S)
dest=$HOME/.local/share/protocol-emulator/board-evidence/$(date +%F)/video/$stamp
mkdir -p "$dest"
cd "$(git rev-parse --show-toplevel)"
git ls-files -z --cached --others --exclude-standard | rsync -a --mkpath --from0 --files-from=- ./ "$PC:video/repo/"
# assembled here, so the bench machine needs only the words
opam exec --switch 5.2.0+ox -- dune build --root . bin/generate.exe
python3 demo/video.py assemble _build/default/bin/generate.exe --programs "$dest/programs.json"
rsync -a --mkpath "$dest/programs.json" "$PC:video/runs/$stamp/programs.json"
trap 'rsync -a "$PC:video/runs/$stamp/" "$dest/" 2>/dev/null || true' EXIT
ssh -T "$PC" bash -s -- "$shot" "$stamp" "${A_PORT:-3-3}" "${B_PORT:-3-2}" <<'REMOTE' | tee "$dest/output.txt"
set -eu
shot=$1 stamp=$2 a_port=$3 b_port=$4
hour=$(date +%H%M)
if [ "$hour" -ge 2250 ] || [ "$hour" -lt 0750 ]; then echo "tt-ci window, not starting"; exit 4; fi
N23=github:NixOS/nixpkgs/205fd4226592cc83fd4c0885a3e4c9c400efabb5
mkdir -p "$HOME/video/runs/$stamp"
exec flock -w 3600 "$HOME/pe-bench/lock" nix shell nixpkgs#git nixpkgs#mpremote nixpkgs#picotool \
    nixpkgs#python3 nixpkgs#python3Packages.numpy $N23#sigrok-cli $N23#sigrok-firmware-fx2lafw \
    --command bash -c '
set -eu
shot=$1 stamp=$2 a_port=$3 b_port=$4
B=$HOME/frozen-8x4
cd "$HOME/video/repo"
np=$(dirname $(dirname $(readlink -f $(command -v f2py))))
export PYTHONPATH=$(ls -d $np/lib/python3*/site-packages | head -1)
export SIGROK_FIRMWARE_DIR=$(ls -d /nix/store/*sigrok-firmware-fx2lafw*/share/sigrok-firmware | head -1)
export SIGROKDECODE_DIR=$HOME/board-corpus/pinned
export PATH=$PATH:$HOME/tools/oss-cad-suite/bin
export PICO=id:e66548545717552e PICO_B_SERIAL=e66548545740ad29
export ANALYSER_A_PORT=$a_port ANALYSER_B_PORT=$b_port PYTHONUNBUFFERED=1
status=0
python3 demo/video.py "$shot" --run "$HOME/video/runs/$stamp" \
    --bitstream "$B/bit/frozen-67386afb.bit" --programs "$HOME/video/runs/$stamp/programs.json" || status=$?
openFPGALoader -b icepi-zero -r > /dev/null 2>&1 || true
exit $status
' video "$shot" "$stamp" "$a_port" "$b_port"
REMOTE
