#!/bin/bash

# Define paths for input and output JSON files
PROVIDER_RESULTS_JSON="/tmp/endpoint_tests/provider_results.json"
SYNDICATE_RESULTS_JSON="/tmp/endpoint_tests/syndicate_results.json"
PROVIDER_OUTPUT_FILE="/tmp/endpoint_tests/invalid_provider_endpoints.json"
SYNDICATE_OUTPUT_FILE="/tmp/endpoint_tests/invalid_syndicate_endpoints.json"

# Use jq to filter out members with valid=false endpoints and construct a new JSON object
invalid_provider=$(jq '
  # Filter entries where valid is false and group by id
  map(select(.valid == false)) 
  | group_by(.id)
  | map({
      id: .[0].id,
      invalid_endpoints: map({network, endpoint})
    })
' "$PROVIDER_RESULTS_JSON")

invalid_syndicate=$(jq '
  # Filter entries where valid is false and group by id
  map(select(.valid == false)) 
  | group_by(.id)
  | map({
      id: .[0].id,
      invalid_endpoints: map({network, endpoint})
    })
' "$SYNDICATE_RESULTS_JSON")

# Save the output to a new JSON file and display it
echo "$invalid_provider" > "$PROVIDER_OUTPUT_FILE"
echo "$invalid_syndicate" > "$SYNDICATE_OUTPUT_FILE"
cat "$PROVIDER_OUTPUT_FILE"
echo ""
cat "$SYNDICATE_OUTPUT_FILE"
