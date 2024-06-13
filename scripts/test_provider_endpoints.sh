#!/bin/bash
set -euo pipefail

# define paths for scripts and tools
script_dir="$(dirname "$(realpath "$0")")"
root_dir="$(dirname "$script_dir")"
gavel="/usr/local/bin/gavel"
jq="/usr/bin/jq"
members_json="$root_dir/members.json"
output_dir="/tmp/endpoint_tests"
output_file="$output_dir/provider_results.json"

# init
echo "Using gavel built @ $gavel"
mkdir -p "$output_dir"
echo '[]' > "$output_file"

# Function to generate a random number within a range
rand() {
    local min=$1
    local max=$2
    echo $((RANDOM % (max - min + 1) + min))
}

# fetch block data from network endpoint
fetch_block_data() {
    local operator="$1"
    local network="$2"
    local endpoint="$3"
    local block_height="$4"
    local current=$(date +%s) # Current time in seconds since the epoch
    local triennium=$((21 * 24 * 3600)) # 21 days in seconds
    local week=$((7 * 24 * 3600)) # 7 days in seconds

    echo "Fetching data from $operator at $endpoint for $network"

    # attempt to fetch block and MMR data
    block_data=$("$gavel" fetch "$endpoint" "$block_height" 2>&1 || echo '{"error":"Failed to fetch block data"}')

    mmr_data=$("$gavel" mmr "$endpoint" 2>&1 || echo '{"proof":null}')

    # echo "Debug: block_data received: $block_data" >&2
    # echo "Debug: mmr_data received: $mmr_data" >&2

    offchain_indexing=false

    if echo "$mmr_data" | jq -e . > /dev/null 2>&1; then
        offchain_indexing=$(echo "$mmr_data" | jq -r 'if .proof != null and .proof != "" then true else false end')
    fi

    # echo out if block_data fetch succesful and if offchain_indexing 
    if echo "$block_data" | jq -e . > /dev/null 2>&1; then
        echo "offchain-indexing: $offchain_indexing"
    else
        # ensure the block_data is in JSON format
        echo "$block_data"
        block_data="{\"error\":\"$block_data\"}"
    fi

    if echo "$block_data" | jq -e '.error' >/dev/null; then
        local error_message=$(echo "$block_data" | jq -r '.error')
        result_json=$(jq -n --arg operator "$operator" --arg network "$network" --arg endpoint "$endpoint" --arg error "$error_message" '{
            id: $operator,
            network: $network,
            endpoint: $endpoint,
            valid: false,
            error: $error,
        }')
    else
        # Extract specific details from valid block data
        first_extrinsic_byte=$(echo "$block_data" | jq -r '.block.extrinsics[0] // empty | .[0:8]')
        result_json=$(jq -n --arg operator "$operator" --arg network "$network" --arg endpoint "$endpoint" --arg first_extrinsic_byte "$first_extrinsic_byte" --argjson offchain_indexing "$offchain_indexing" --argjson block_data "$block_data" '{
            id: $operator,
            network: $network,
            endpoint: $endpoint,
            block_number: ($block_data.block.header.number // null),
            parent_hash: ($block_data.block.header.parentHash // null),
            state_root: ($block_data.block.header.stateRoot // null),
            first_extrinsic_byte: $first_extrinsic_byte,
            offchain_indexing: $offchain_indexing,
            valid: true
        }')
    fi

    # echo "Debug: result_json received: $result_json" >&2
    update_results "$result_json"
}


# process all endpoints for each operator from a given JSON
process_endpoints() {
    jq -rc '.members | to_entries[]' "$members_json" | while IFS= read -r member; do
        local operator=$(echo "$member" | jq -r '.key')
        local endpoints=$(echo "$member" | jq -r '.value.endpoints | to_entries[]')
        local block_height=$(rand 1 1000)
        echo "$endpoints" | jq -c '.' | while IFS= read -r endpoint; do
            local network=$(echo "$endpoint" | jq -r '.key')
            local fqdn=$(echo "$endpoint" | jq -r '.value')
            fetch_block_data "$operator" "$network" "$fqdn" "$block_height"
        done
    done
}

# grow json
update_results() {
    local result_json="$1"
    jq --argjson newEntry "$result_json" '. += [$newEntry]' "$output_file" > "${output_file}.tmp" && mv "${output_file}.tmp" "$output_file"
}

# main function to run the script
main() {
    process_endpoints
    echo "All data has been fetched and saved."
}

main
