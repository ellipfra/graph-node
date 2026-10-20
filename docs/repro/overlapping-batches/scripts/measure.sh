#!/bin/bash
# usage: measure.sh HASH [QUERY_PORT]
# Print the head, the rows of Protocol "1", the number of live versions and
# what a GraphQL list query returns.
source "$(dirname "$0")/env.sh"

h=$1
qp=${2:-$A_HTTP}
sch=$(psqlg -c "select name from deployment_schemas where subgraph = '$h'")
echo "hash=$h schema=$sch head=$(head_of "$h")"
psqlg -c "select 'assigned', node_id from subgraphs.subgraph_deployment_assignment a
          join deployment_schemas d on d.id = a.id where d.subgraph = '$h'"
psqlg -c "select 'rows_total', count(*) from $sch.protocol"
psqlg -c "select 'live_versions', count(*) from $sch.protocol
          where id = '1' and upper_inf(block_range)"
psqlg -c "select 'live', vid, block_range, n, tag from $sch.protocol
          where id = '1' and upper_inf(block_range) order by vid"
psqlg -c "select 'rows_at_lower_1', vid, block_range from $sch.protocol
          where id = '1' and lower(block_range) = 1 order by vid"
echo -n "graphql: "
curl -s -X POST -H 'content-type: application/json' \
  --data '{"query":"{ protocols(first: 5, orderBy: id) { id n } }"}' \
  "http://127.0.0.1:$qp/subgraphs/id/$h"
echo
