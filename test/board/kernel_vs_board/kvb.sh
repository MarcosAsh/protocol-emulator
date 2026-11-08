# Kernel vs board with the chip's own check on the frozen 8x4 bitstream, one firmware at a
# time under ~/pe-bench/lock, never starting inside the tt-ci window. Results accumulate
# in EVID/kvb, so a firmware can be rerun alone.
# Usage: bash ~/frozen-8x4/kvb.sh COMMIT FIRMWARE...
set -eu
commit=$1; shift
B=$HOME/frozen-8x4
BIT=$B/bit/frozen-67386afb.bit EVID=$B/evidence/kvb
mkdir -p $EVID
for fw in "$@"; do
  hour=$(date +%H%M)
  if [ "$hour" -ge 2250 ] || [ "$hour" -lt 0750 ]; then echo "tt-ci window, stopping before $fw"; exit 4; fi
  flock -w 3600 $HOME/pe-bench/lock nix shell nixpkgs#git nixpkgs#mpremote nixpkgs#python3 --command bash -c '
set -eu
B=$1 commit=$2 BIT=$3 EVID=$4 fw=$5
cd $B/repo
git checkout -q --force --detach $commit
export PATH=$PATH:$HOME/tools/oss-cad-suite/bin PICO=id:e66548545717552e
echo "$(date +%T) $fw commit $(git rev-parse HEAD) $(sha256sum $BIT)"
python3 demo/kernel_vs_board.py $B/bit/variants.jsonl --bitstream $BIT --out $EVID --chip --only $fw
openFPGALoader -b icepi-zero -r > /dev/null 2>&1 || true
' kvb "$B" "$commit" "$BIT" "$EVID" "$fw"
done
echo KVB-END $(date +%T)
