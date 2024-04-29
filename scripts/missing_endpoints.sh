#!/bin/bash

# Path to the JSON file containing member data
RESULTS_JSON="/tmp/endpoint_tests/results.json"
OUTPUT_FILE="/tmp/endpoint_tests/missing.json"

# Use jq to filter out members with valid=false endpoints and construct a new JSON object
missing=$(jq -r 'to_entries | reduce .[] as $member ({}; 
  if ($member.value | map(select(.valid == false)) | length > 0) then
    . + {
      ($member.key): {
        member: $member.key,
        endpoints: ($member.value | map(select(.valid == false)) | map({(.network): .endpoint}) | add)
      }
    }
  else
    .
  end
)' "$RESULTS_JSON")

# Save the output to a new JSON file and display it
echo "$missing" > "$OUTPUT_FILE"
cat "$OUTPUT_FILE"
