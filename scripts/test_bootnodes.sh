#!/bin/bash
set -euo pipefail

if ! command -v polkadot &> /dev/null; then
    echo "polkadot is not installed. Exiting..."
    exit 1
fi
echo "using polkadot at /usr/bin/polkadot"
jq="/usr/bin/jq"

# define the output directory and file
output_dir="/tmp/bootnode_tests"
output_file="$output_dir/results.json"

# function to initialize output directory and file
initialize_output() {
    mkdir -p "$output_dir"
    echo '{}' > "$output_file"
}

fetch_block_data() {
    local operator="$1"
    local network="$2"
    local bootnode="$3"
    local result_file=$(mktemp)

    # check if the bootnode is a placeholder, skip fetching
    if [[ "$bootnode" == *"placeholder"* ]]; then
        echo "{\"id\":\"$operator\", \"network\":\"$network\", \"bootnode\":\"$bootnode\", \"valid\":false}" > "$result_file"
        echo "Skipped fetching data for $operator on $network due to placeholder bootnode."
        update_results "$operator" "$result_file"
        rm "$result_file"
        return
    fi


    # check if an error occurred during fetch
    if [[ "$block_data" == *"Error"* ]]; then
        echo "{\"id\":\"$operator\", \"network\":\"$network\", \"bootnode\":\"$bootnode\", \"valid\":false}" > "$result_file"
        echo "Failed to fetch data for $operator on $network due to error: $block_data"
        update_results "$operator" "$result_file"
        rm "$result_file"
        return
    fi

    # process and store fetched block data
    echo "$block_data" | $jq -c --arg operator "$operator" --arg network "$network" --arg bootnode "$bootnode" '{
        id: $operator,
        network: $network,
        bootnode: $bootnode,
        block_number: .block.header.number,
        extrinsics_root: .block.header.extrinsicsRoot,
        parent_hash: .block.header.parentHash,
        state_root: .block.header.stateRoot,
        valid: true
    }' > "$result_file"

    # print the processed data
    cat "$result_file"
    echo "Data fetched successfully for $operator on $network"

    # update the main results file and clean up
    update_results "$operator" "$result_file"
    rm "$result_file"
}

# function to process all bootnodes for each operator
process_bootnodes() {
    local bootnodes_json="bootnodes.json"
    local operators=$($jq -rc '.members | keys[]' "$members_json")
    for operator in $operators; do
        $jq -rc --arg operator "$operator" '.members[$operator].bootnodes | to_entries[] | [.key, .value]' "$members_json" |
        while IFS= read -r line; do
            local network=$(echo "$line" | $jq -r '.[0]')
            local bootnode=$(echo "$line" | $jq -r '.[1]')
            fetch_block_data "$operator" "$network" "$bootnode"
        done
    done
}

# update results
update_results() {
    local operator="$1"
    local data_file="$2"
    # append new data to the existing array for the operator
    jq --arg operator "$operator" --slurpfile data "$data_file" '
        if .[$operator] then
            .[$operator] += $data
        else
            .[$operator] = $data
        end
    ' "$output_file" > "${output_file}.tmp" && mv "${output_file}.tmp" "$output_file"
}

# main function to run the script
main() {
    initialize_output
    process_bootnodes
    echo "all data has been fetched and saved."
}

main
