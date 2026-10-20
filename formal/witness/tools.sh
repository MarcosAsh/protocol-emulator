#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Puts what check.sh runs in tools/, as the repo's CI pins it: OSS CAD Suite's 2026-09-16
# build for this machine (yosys, aigsplit, aigtocnf, aigsim), and cadical (rel-3.0.1),
# cake_lpr and Certifaiger on the aiger library, from source at the commits below.
# Needs curl, make, cc and a C++23 c++. About 2 min, mostly the 0.5 GB download.
set -e
cadical=@CADICAL@
cake_lpr=@CAKE_LPR@
certifaiger=@CERTIFAIGER@
aiger=@AIGER@
case $(uname -s)-$(uname -m) in
Linux-x86_64) suite=linux-x64 ;;
Linux-aarch64 | Linux-arm64) suite=linux-arm64 ;;
Darwin-x86_64) suite=darwin-x64 ;;
Darwin-arm64) suite=darwin-arm64 ;;
*) echo "no OSS CAD Suite build for $(uname -sm)" >&2; exit 1 ;;
esac
case $(uname -m) in arm64 | aarch64) cake_lpr_target=cake_lpr_arm8 ;; *) cake_lpr_target=cake_lpr ;; esac
cd "$(dirname "$0")"
rm -rf tools && mkdir -p tools/bin && cd tools
curl -fsSL "https://github.com/YosysHQ/oss-cad-suite-build/releases/download/2026-09-16/oss-cad-suite-$suite-20260916.tgz" | tar xz
curl -fsSL "https://github.com/arminbiere/cadical/archive/$cadical.tar.gz" | tar xz
(cd "cadical-$cadical" && ./configure > /dev/null && make -j4 > /dev/null)
cp "cadical-$cadical/build/cadical" bin/
curl -fsSL "https://github.com/tanyongkiam/cake_lpr/archive/$cake_lpr.tar.gz" | tar xz
(cd "cake_lpr-$cake_lpr" && rm -f cake_lpr && make "$cake_lpr_target" > /dev/null)
cp "cake_lpr-$cake_lpr/cake_lpr" bin/
curl -fsSL "https://github.com/arminbiere/aiger/archive/$aiger.tar.gz" | tar xz
curl -fsSL "https://github.com/Froleyks/certifaiger/archive/$certifaiger.tar.gz" | tar xz
cc -O3 -c "aiger-$aiger/aiger.c" -o aiger.o
c++ -std=c++23 -O3 -DNDEBUG -DVERSION='"10.3.1"' -DGITID="\"$certifaiger\"" -iquote "aiger-$aiger" \
    "certifaiger-$certifaiger/src/certifaiger.cpp" aiger.o -o bin/certifaiger
echo "tools: $(cd bin && ls | xargs), yosys from oss-cad-suite/bin"
