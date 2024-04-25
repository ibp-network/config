#!/bin/bash

# Original JSON file
JSON_FILE="bootnodes.json"

# Function to add an empty array for a missing member in a network
add_missing_member() {
    local member=$1
    local network=$2

    # Use jq to add an empty array for the member in the specified network
    jq --arg member "$member" --arg network "$network" '
    if .[$network].members | has($member) then .
    else .[$network].members[$member] = []
    end' "$JSON_FILE" > tmp.json && mv tmp.json "$JSON_FILE"
}

# Iterate over each member and network, adding missing members
jq -r '[.[] | .members | keys[]] | unique[]' "$JSON_FILE" | while read member; do
    echo "Networks missing member $member:"
    jq --arg member "$member" -r 'to_entries[] | select(.value.members | has($member) | not) | .key' "$JSON_FILE" | while read network; do
        echo "Adding $member to $network"
        add_missing_member "$member" "$network"
    done
done

# Verify the updated JSON structure
cat "$JSON_FILE"
