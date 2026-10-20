#!/bin/bash
# usage: s1-sigstop.sh TAG
# Forced ordering: deploy to node-a, SIGSTOP node-a as soon as it processes
# blocks (before its first commit), reassign to node-b, SIGCONT node-a once
# node-b has processed block 1, wait for node-b's first commit, measure.
source "$(dirname "$0")/env.sh"

tag=$1
H=$("$(dirname "$0")/build-sg.sh" "$tag")
echo "$(ts) tag=$tag hash=$H"
A=$(cat "$WORK_DIR/node-a.pid")
la0=$(wc -l < "$WORK_DIR/node-a.log" | tr -d ' ')
lb0=$(wc -l < "$WORK_DIR/node-b.log" | tr -d ' ')
alog() { tail -n +"$la0" "$WORK_DIR/node-a.log" | grep "$H"; }
blog() { tail -n +"$lb0" "$WORK_DIR/node-b.log" | grep "$H"; }

rpc_admin "$A_ADMIN" subgraph_create "{\"name\":\"repro/$tag\"}" > /dev/null
echo "$(ts) deploy -> node-a"
rpc_admin "$A_ADMIN" subgraph_deploy \
  "{\"name\":\"repro/$tag\",\"ipfs_hash\":\"$H\",\"node_id\":\"node-a\"}"

# 1. Wait until node-a processes block >= 100, then freeze it
until alog | grep -q "Start processing block.*block_number: [0-9]\{3,\}"; do sleep 0.05; done
kill -STOP "$A"
echo "$(ts) SIGSTOP node-a"
sleep 0.5
echo "$(ts) head=$(head_of "$H") a_commits=$(alog | grep -c 'Committed write batch')"

# 2. Reassign to node-b; wait until node-b processes its first block
echo "$(ts) reassign -> node-b"
rpc_admin "$B_ADMIN" subgraph_reassign "{\"ipfs_hash\":\"$H\",\"node_id\":\"node-b\"}"
until blog | grep -q "Start processing block.*block_number: "; do sleep 0.02; done
echo "$(ts) node-b first block: $(blog | grep -o 'Start processing block.*block_number: [0-9]*' \
  | head -1 | grep -o '[0-9]*$') head=$(head_of "$H")"

# 3. Resume node-a: it notices the unassignment and commits its pending batch
kill -CONT "$A"
echo "$(ts) SIGCONT node-a"

# 4. Wait (up to 90 s) for node-b's first commit or an error
for _ in $(seq 1 900); do
  blog | grep -q "Committed write batch\|ERRO\|WARN.*rror" && break
  sleep 0.1
done
sleep 2
echo "--- node-a"
alog | grep "Committed write batch\|unassigned\|WARN\|ERRO" | cut -c1-300 | tail -10
echo "--- node-b"
blog | grep "Committed write batch\|WARN\|ERRO" | cut -c1-300 | head -10
echo "--- measurement $(ts)"
"$(dirname "$0")/measure.sh" "$H" "$A_HTTP"
