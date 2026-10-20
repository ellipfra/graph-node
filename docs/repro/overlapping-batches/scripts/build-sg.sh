#!/bin/bash
# usage: build-sg.sh TAG
# Build the subgraph with a distinct TAG (so every run gets a new deployment
# hash), upload it to IPFS and print the hash.
source "$(dirname "$0")/env.sh"

cd "$SUBGRAPH_DIR" || exit 1
sed "s/__TAG__/$1/" src/mapping.ts.tpl > src/mapping.ts
npx graph codegen > /dev/null || exit 1
npx graph build --ipfs "http://$IPFS_API" 2>&1 \
  | grep -o 'Qm[1-9A-HJ-NP-Za-km-z]\{44\}' | tail -1
