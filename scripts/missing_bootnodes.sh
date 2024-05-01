#!/bin/bash
RESULTS_JSON="/tmp/bootnode_tests/results.json"
OUTPUT_FILE="/tmp/endpoint_tests/missing.json"

missing=$(jq '
  . as $root | 
  to_entries | 
  map({
    id: .key,
    missing_endpoints: [
      .value | to_entries |
      map(select(.value.valid == false) | {
        network: .key,
        endpoint: .value.bootnode
      })
    ]
  }) | map(select(.missing_endpoints | length > 0))
' "$RESULTS_JSON")

echo "$missing" | jq . > "$OUTPUT_FILE"
cat "$OUTPUT_FILE"


