# Overlapping write batches from two runners

## Mechanism

1. Runner A (node-a) starts a new deployment and accumulates its first write batch.
2. The deployment is reassigned to node-b before A commits; B reads the head (still the start pointer) and starts from the start block.
3. A is stopped because it was unassigned, and its pending batch `[start..X_A]` is committed on the way out.
4. B commits `[start..X_B]` with `X_B > X_A`; `deployment::transact_block` only compares the *last* block of the batch with the head, so it accepts it.
5. Every entity written in `[start..X_A]` now has two versions per block; for `specVersion < 1.3.0` (`vid bigserial`, and no exclusion constraint in release builds) nothing rejects them, and queries return such entities twice.

## Store-level test

`store/test-store/tests/postgres/overlapping_batches.rs` simulates two processes with two
independent `Store` instances on one database. Run it like the other store tests (see
`CONTRIBUTING.md` for the test database):

```sh
THEGRAPH_STORE_POSTGRES_DIESEL_URL=postgresql://graph:graph@127.0.0.1:5432/graph-test \
  cargo test -p test-store --test postgres -- overlapping_batches --test-threads=1
```

Expected on master: the two controls pass and the reproduction fails with

```
overlapping batch from writer B was accepted: flush = Ok(()), live versions of Protocol "1" = 2,
list query at head returns "1" 2 times
```

## Two graph-node processes

Requirements: a release `graph-node` binary, Postgres, IPFS (kubo), anvil (foundry), Node.js.
All scripts read their settings from `scripts/env.sh`; override any of them from the
environment (`GRAPH_NODE_BIN`, `PG_URL`, `PSQL`, `IPFS_API`, `ETH_RPC`, `CHAIN_HEAD`, `A_*` and
`B_*` ports, `WORK_DIR`).

1. Postgres: create an empty database for `PG_URL` with the extensions `pg_trgm`, `btree_gist`,
   `postgres_fdw` and `pg_stat_statements` (as for a normal graph-node setup).
2. IPFS: `ipfs init && ipfs daemon --offline` (API on `IPFS_API`, default `127.0.0.1:5001`).
3. Chain: `anvil --port 8545`, then pre-mine 21,000 blocks and mine nothing afterwards:
   `cast rpc anvil_mine 0x5208 --rpc-url http://127.0.0.1:8545`.
4. Subgraph dependencies: `(cd subgraph && npm install)`. The subgraph (`specVersion 0.0.4`)
   has one unfiltered block handler that writes `Protocol { id: "1", n: block }` at every block.
5. Start both nodes: `scripts/start-node.sh a` (block ingestor, ports 8000/8020/8030/8040) and
   `scripts/start-node.sh b` (`--disable-block-ingestor`, ports 8100/8120/8130/8140). Both use
   `GRAPH_LOG=debug` and `GRAPH_STORE_WRITE_BATCH_DURATION=60`.
6. Natural race: `for k in 1 2 3; do scripts/s2-reassign.sh 1 $k; done` (deploy to node-a,
   reassign to node-b after 1 second). Repeat with a delay of 5, 15 and 30 seconds.
7. Forced ordering: `scripts/s1-sigstop.sh s1` (SIGSTOP node-a while its first batch is pending,
   reassign, SIGCONT).

`scripts/measure.sh HASH` prints the head, the live versions and the GraphQL answer for any
deployment.

## Expected results

On a local chain the first batch closes on size after about 3 seconds (roughly 12,000 blocks).

- **Reassignment after 1 s: duplicated history in 3 runs out of 3.** node-a commits its batch while
  stopping (about 5,200 blocks), then node-b commits `[1..~12,100]`, which is accepted. The
  covered block count is about 33,100 instead of 21,000, two rows start at block 1, no error is
  logged and the deployment stays healthy. `protocols(block: {number: 2000})` returns `"1"` twice.
- **Reassignment after 5, 15 or 30 s:** no duplicates (node-a had already committed). In one 5 s
  run, node-b failed instead with a non-deterministic error, which is the same race with the
  commit order reversed:

  ```
  writing Protocol entities at block 12121 failed: range lower bound must be less than or equal
  to range upper bound Query: clamp ids [1]
  ```

- **SIGSTOP variant:** node-a logs `Terminating the subgraph runner because subgraph was
  unassigned` and commits `block_count: 2919`; node-b then commits `block_count: 12179`, accepted.
  Right after node-b's first commit there are two live versions and the head query returns
  `{"data":{"protocols":[{"id":"1","n":"2919"},{"id":"1","n":"12179"}]}}`. The live duplicate
  disappears with node-b's next overwrite of the entity, but the history stays doubled for blocks
  1 to 12,179. An entity that is not written again would keep two live versions.

Measured on master 190f0aa4f8 (graph-node 0.45.0, release build), Postgres 17, anvil 1.8.5,
graph-cli 0.97.1.
