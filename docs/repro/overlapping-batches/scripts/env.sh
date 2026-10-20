# Common settings for the two-node reproduction. Source this file; every
# value can be overridden from the environment.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SUBGRAPH_DIR="${SUBGRAPH_DIR:-$HERE/../subgraph}"
export WORK_DIR="${WORK_DIR:-$HERE/../work}"
mkdir -p "$WORK_DIR"

export GRAPH_NODE_BIN="${GRAPH_NODE_BIN:-graph-node}"
export PG_URL="${PG_URL:-postgresql://graph:graph@127.0.0.1:5432/graph-node}"
export PSQL="${PSQL:-psql}"
export IPFS_API="${IPFS_API:-127.0.0.1:5001}"
export ETH_RPC="${ETH_RPC:-http://127.0.0.1:8545}"
# Number of pre-mined blocks on the local chain (the chain does not advance)
export CHAIN_HEAD="${CHAIN_HEAD:-21000}"

# node-a uses the default ports; node-b the same ports shifted by 100
export A_HTTP="${A_HTTP:-8000}" A_ADMIN="${A_ADMIN:-8020}"
export A_INDEX="${A_INDEX:-8030}" A_METRICS="${A_METRICS:-8040}"
export B_HTTP="${B_HTTP:-8100}" B_ADMIN="${B_ADMIN:-8120}"
export B_INDEX="${B_INDEX:-8130}" B_METRICS="${B_METRICS:-8140}"

psqlg() { "$PSQL" "$PG_URL" -At "$@"; }

# rpc_admin PORT METHOD PARAMS_JSON
rpc_admin() {
  curl -s -X POST -H 'content-type: application/json' \
    --data "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"$2\",\"params\":$3}" \
    "http://127.0.0.1:$1"
  echo
}

# head_of HASH: current subgraph head block, or NULL
head_of() {
  psqlg -c "select coalesce(h.block_number::text, 'NULL') from subgraphs.head h
            join deployment_schemas d on d.id = h.id where d.subgraph = '$1'"
}

ts() { date +%H:%M:%S; }
