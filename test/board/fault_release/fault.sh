# The runtime fault on the frozen 8x4 bitstream, under ~/pe-bench/lock: a fresh load, then
# fault_board.py on Pico A while analyser A captures OUT0 and OUT2.
# Usage: A_PORT=3-3 bash ~/frozen-8x4/fault/fault.sh
set -eu
hour=$(date +%H%M)
if [ "$hour" -ge 2250 ] || [ "$hour" -lt 0750 ]; then echo "tt-ci window, not starting"; exit 4; fi
N23=github:NixOS/nixpkgs/205fd4226592cc83fd4c0885a3e4c9c400efabb5
exec flock -w 3600 $HOME/pe-bench/lock nix shell nixpkgs#git nixpkgs#mpremote nixpkgs#python3 nixpkgs#python3Packages.numpy $N23#sigrok-cli $N23#sigrok-firmware-fx2lafw --command bash -c '
set -eu
F=$HOME/frozen-8x4 A_PORT=$1
cd $F/repo
np=$(dirname $(dirname $(readlink -f $(command -v f2py))))
export PYTHONPATH=$(ls -d $np/lib/python3*/site-packages | head -1)
export SIGROK_FIRMWARE_DIR=$(ls -d /nix/store/*sigrok-firmware-fx2lafw*/share/sigrok-firmware | head -1)
export PATH=$PATH:$HOME/tools/oss-cad-suite/bin
P=id:e66548545717552e
BIT=$F/bit/frozen-67386afb.bit
echo "$(date -Is) commit $(git rev-parse HEAD) $(sha256sum $BIT)"
openFPGALoader -b icepi-zero $BIT 2>&1 | tail -1
mpremote connect $P cp python/protocol_emulator.py python/pico_board.py $F/fault/fault_board.py :
mpremote connect $P exec "import os
try:
    os.remove(\"fault.log\")
except OSError:
    pass"
ANALYSER=A ANALYSER_A_PORT=$A_PORT demo/capture.sh $F/fault/fault.sr 4000 mpremote connect $P run --no-follow $F/fault/fault_board.py
sleep 2
mpremote connect $P cat :fault.log | tee $F/fault/fault.log
python3 $F/fault/edges.py $F/fault/fault.sr | tee $F/fault/edges.txt
(cd $F/fault && sha256sum fault_board.py fault.sr fault.log edges.txt edges.py fault.sh $BIT > SHA256SUMS)
openFPGALoader -b icepi-zero -r > /dev/null 2>&1 || true
' fault "${A_PORT:-3-3}"
