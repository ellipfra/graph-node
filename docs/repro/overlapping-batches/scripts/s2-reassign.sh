#!/bin/bash
# usage: s2-reassign.sh DELAY RUN
# Natural race, no signals: deploy to node-a, wait DELAY seconds, reassign to
# node-b, wait until node-b reaches the chain head, then report whether the
# history of Protocol "1" is duplicated.
source "$(dirname "$0")/env.sh"

d=$1
k=$2
tag=s2-$d-$k
H=$("$(dirname "$0")/build-sg.sh" "$tag")
rpc_admin "$A_ADMIN" subgraph_create "{\"name\":\"repro/$tag\"}" > /dev/null
rpc_admin "$A_ADMIN" subgraph_deploy \
  "{\"name\":\"repro/$tag\",\"ipfs_hash\":\"$H\",\"node_id\":\"node-a\"}" > /dev/null
sleep "$d"
rpc_admin "$A_ADMIN" subgraph_reassign "{\"ipfs_hash\":\"$H\",\"node_id\":\"node-b\"}" > /dev/null

sch=$(psqlg -c "select name from deployment_schemas where subgraph = '$H'")
for _ in $(seq 1 90); do
  [ "$(head_of "$H")" = "$CHAIN_HEAD" ] && break
  sleep 1
done
sleep 2

live=$(psqlg -c "select count(*) from $sch.protocol where id = '1' and upper_inf(block_range)")
lower1=$(psqlg -c "select count(*) from $sch.protocol where id = '1' and lower(block_range) = 1")
# Total number of blocks covered by all versions; equals CHAIN_HEAD without duplicates
cover=$(psqlg -c "select sum(coalesce(upper(block_range), $CHAIN_HEAD + 1) - lower(block_range))
                  from $sch.protocol where id = '1'")
health=$(psqlg -c "select d.failed || '/' || d.health from subgraphs.deployment d
                   join deployment_schemas s on s.id = d.id where s.subgraph = '$H'")
echo "delay=$d run=$k hash=$H head=$(head_of "$H") live_versions=$live" \
  "rows_at_lower_1=$lower1 blocks_covered=$cover (expected $CHAIN_HEAD)" \
  "failed/health=$health"
