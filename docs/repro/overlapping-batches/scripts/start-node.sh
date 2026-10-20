#!/bin/bash
# usage: start-node.sh a|b
# Start node-a (block ingestor) or node-b (--disable-block-ingestor) on the
# same database and IPFS. Logs and pid files go to $WORK_DIR.
source "$(dirname "$0")/env.sh"

case "$1" in
  a) http=$A_HTTP admin=$A_ADMIN index=$A_INDEX metrics=$A_METRICS extra="" ;;
  b) http=$B_HTTP admin=$B_ADMIN index=$B_INDEX metrics=$B_METRICS extra="--disable-block-ingestor" ;;
  *) echo "usage: $0 a|b" >&2; exit 1 ;;
esac

# Debug logs are needed: the scenarios watch for "Start processing block"
export GRAPH_LOG="${GRAPH_LOG:-debug}"
export GRAPH_STORE_WRITE_BATCH_DURATION="${GRAPH_STORE_WRITE_BATCH_DURATION:-60}"

nohup "$GRAPH_NODE_BIN" --node-id "node-$1" --postgres-url "$PG_URL" \
  --ethereum-rpc "anvil:archive:$ETH_RPC" --ipfs "$IPFS_API" \
  --http-port "$http" --admin-port "$admin" \
  --index-node-port "$index" --metrics-port "$metrics" \
  $extra > "$WORK_DIR/node-$1.log" 2>&1 &
echo $! > "$WORK_DIR/node-$1.pid"
echo "node-$1 pid $(cat "$WORK_DIR/node-$1.pid"), log $WORK_DIR/node-$1.log"
