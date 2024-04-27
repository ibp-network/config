#!/bin/bash

# Path to the JSON file containing member data
MEMBERS_JSON="members.json"

# Function to identify and list endpoints with placeholders
find_missing_endpoints() {
    # Use jq to parse the JSON file and find endpoints with a placeholder URL
    jq '[
          .members | to_entries[] | 
          select(.value.membership == "professional" and .value.endpoints) | 
          {member: .key, endpoints: .value.endpoints | to_entries | map(select(.value | test("placeholder"))) | from_entries} | 
          select(.endpoints | length > 0)
        ]' "$MEMBERS_JSON"
}

# Call the function and display the output
find_missing_endpoints
