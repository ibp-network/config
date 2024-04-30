#!/usr/bin/env bash
set -euo pipefail

# Define constants
readonly POLKADOT_BINARY="/usr/bin/polkadot"
readonly POLKADOT_PARACHAIN_BINARY="/usr/bin/polkadot-parachain"
readonly JQ_BINARY="/usr/bin/jq"
readonly OUTPUT_DIR="/tmp/bootnode_tests"
readonly OUTPUT_FILE="$OUTPUT_DIR/results.json"
readonly BOOTNODES_JSON="bootnodes.json"
readonly LOG_FILE="$OUTPUT_DIR/log.txt"

# Initialize output directory and file
initialize_output() {
    mkdir -p "$OUTPUT_DIR"
    echo '{}' > "$OUTPUT_FILE"
}

# Update results in JSON file
update_results() {
    local operator="$1"
    local data_file="$2"
    local tmp_file="${OUTPUT_FILE}.tmp"
    "$JQ_BINARY" --arg operator "$operator" --slurpfile data "$data_file" '
        if .[$operator] then
            .[$operator] += $data[0]
        else
            .[$operator] = $data[0]
        end
    ' "$OUTPUT_FILE" > "$tmp_file" && mv "$tmp_file" "$OUTPUT_FILE"
}

test_bootnode() {
    local operator="$1"
    local command_id="$2"
    local bootnode="$3"
    local network
    local relaychain

    if [[ "$command_id" == "parachain" ]]; then
        # Assuming 'parachain' commands follow the format: <network>-<relaychain>
        network="${command_id%-*}"  # Everything before the last hyphen
        relaychain="${command_id##*-}"  # Everything after the last hyphen
    else
        network="$command_id"
        relaychain=""
    fi

    local binary_path="$POLKADOT_BINARY"
    [[ "$command_id" == "parachain" ]] && binary_path="$POLKADOT_PARACHAIN_BINARY"

    local chain_spec_file="./chain-spec/${network}.json"
    if [ ! -f "$chain_spec_file" ]; then
        echo "Chain spec file for $network does not exist."
        return
    fi

    local command="$binary_path --no-hardware-benchmarks --no-mdns --chain $chain_spec_file"
    [[ -n "$relaychain" ]] && command+=" --relay-chain-rpc-urls wss://rpc.ibp.network/$relaychain"
    command+=" --bootnodes $bootnode"

    echo "Executing: $command"
    timeout 20s $command &> "$LOG_FILE"

    # Analyze logs for number of peers
    local peers_line=$(grep 'Syncing,' "$LOG_FILE" | tail -1)  # Fetch the last occurrence
    local peer_count=$(echo "$peers_line" | grep -oP '(?<=\()\d+')
    local valid=false
    [[ "$peer_count" -gt 1 ]] && valid=true

    # Prepare JSON result
    echo "{\"id\":\"$operator\", \"network\":\"$network\", \"bootnode\":\"$bootnode\", \"valid\":$valid, \"peers\":\"$peer_count\"}" > "$result_file"
    cat "$result_file"
    echo "Data fetched successfully for $operator on $network"

    # Update the main results file and clean up
    update_results "$operator" "$result_file"
    rm "$result_file"
}

# Main function to run the script
main() {
    initialize_output

    if [ ! -f "$BOOTNODES_JSON" ]; then
        echo "Bootnodes configuration file does not exist."
        exit 1
    fi

    # Extract the network names (keys) and their details
    cat "$BOOTNODES_JSON" | "$JQ_BINARY" -r 'to_entries[] | .key as $network | .value.commandId as $cid | .value.members | to_entries[] | .key as $operator | .value[] | "\($network) \($cid) \($operator) \(.)"' |
    while IFS=' ' read -r network command_id operator bootnode; do
        test_bootnode "$operator" "$network" "$bootnode" "$command_id"
    done

    echo "All data has been fetched and saved."
}

main
