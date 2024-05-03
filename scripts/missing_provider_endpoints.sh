#!/bin/bash

# Define paths for input and output JSON files
RESULTS_JSON="/tmp/endpoint_tests/results.json"
OUTPUT_FILE="/tmp/endpoint_tests/missing.json"

# Use jq to filter out members with valid=false endpoints and construct a new JSON object
missing=$(jq '
  # Filter entries where valid is false and group by id
  map(select(.valid == false)) 
  | group_by(.id)
  | map({
      id: .[0].id,
      missing_endpoints: map({network, endpoint})
    })
' "$RESULTS_JSON")

# Save the output to a new JSON file and display it
echo "$missing" > "$OUTPUT_FILE"
cat "$OUTPUT_FILE"
