#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Fetches the drawn corpus's decoders that Ubuntu's sigrok is too old to have, from the
# snapshot demo/corpus_draw.py pins, into the user's decoder directory (sigrok also searches
# it). They are GPL, so we don't copy them here. Checked against demo/pinned_decoders.sha256.
# Usage: demo/pinned_decoders.sh
set -e
commit=71f451443029322d57376214c330b518efd84f88
here=$(cd "$(dirname "$0")" && pwd)
dir=${XDG_DATA_HOME:-$HOME/.local/share}/libsigrokdecode/decoders
for decoder in lfast caliper xy2-100; do
    mkdir -p "$dir/$decoder"
    for file in __init__.py pd.py; do
        curl -sfL --retry 3 -o "$dir/$decoder/$file" \
            "https://raw.githubusercontent.com/sigrokproject/libsigrokdecode/$commit/decoders/$decoder/$file"
    done
done
cd "$dir" && sha256sum --check --quiet "$here/pinned_decoders.sha256"
