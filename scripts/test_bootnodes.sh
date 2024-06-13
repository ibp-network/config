#!/usr/bin/env bash
set -euo pipefail

readonly POLKADOT_BINARY="/usr/local/bin/polkadot"
readonly POLKADOT_PARACHAIN_BINARY="/usr/local/bin/polkadot-parachain"
readonly JQ_BINARY="/usr/bin/jq"
readonly OUTPUT_DIR="/tmp/bootnode_tests"
readonly DATA_DIR="/tmp/bootnode_data"
readonly OUTPUT_FILE="$OUTPUT_DIR/results.json"
readonly BOOTNODES_JSON="bootnodes.json"

initialize_output() {
    mkdir -p "$OUTPUT_DIR"
    mkdir -p "$DATA_DIR"
    echo '{}' > "$OUTPUT_FILE"
    echo "Initialized output directory and JSON file."
}

update_results() {
    local operator="$1"
    local network="$2"
    local data_file="$3"
    local tmp_file="${OUTPUT_FILE}.tmp"

    "$JQ_BINARY" --arg operator "$operator" --arg network "$network" --slurpfile data "$data_file" '
        .[$operator] |= (if . then . else {} end) | 
        .[$operator][$network] |= (if . then . + $data[0] else $data[0] end)
    ' "$OUTPUT_FILE" > "$tmp_file" && mv "$tmp_file" "$OUTPUT_FILE"
}

test_bootnode() {
    local operator="$1"
    local network="$2"
    local bootnode="$3"
    local command_id="$4"
    local relaychain

    # detect relaychain for parachain nodes
    if [[ "$command_id" == "parachain" ]]; then
        relaychain="${network##*-}"
        echo "relaychain: $relaychain"
    else
      relaychain=""
    fi

    local binary_path="$POLKADOT_BINARY"
    [[ "$command_id" == "parachain" ]] && binary_path="$POLKADOT_PARACHAIN_BINARY"

    # check if chain spec file exists
    local chain_spec_file="./chain-spec/${network}.json"
    if [ ! -f "$chain_spec_file" ]; then
        echo "Chain spec file for $network does not exist."
        return
    fi

    local log_file="$OUTPUT_DIR/${operator}.${network}.log"
    local command="$binary_path --no-hardware-benchmarks --no-mdns -d $DATA_DIR --chain $chain_spec_file"
    [[ -n "$relaychain" ]] && command+=" --relay-chain-rpc-urls wss://rpc.ibp.network/$relaychain"
    command+=" --bootnodes $bootnode"

    echo "$command"
    timeout 24s $command &> "$log_file" &
    sleep 25

 
    # last line in logs with Idle or Syncing
    local peers_line=$(grep -E 'Idle|Syncing' "$log_file" | tail -1)
    echo "$peers_line"
    # number of peers in that line
    local peer_count=$(echo "$peers_line" | grep -oP '(?<=\()\d+(?= peers\))')
    echo "$operator $network peer_count: $peer_count"
    local valid=false
    # if over 1 peer, consider it valid
    [[ "$peer_count" -gt 1 ]] && valid=true

    local result_file="$OUTPUT_DIR/${operator}.${network}.json"
    echo "{\"id\":\"$operator\", \"network\":\"$network\", \"bootnode\":\"$bootnode\", \"valid\":$valid, \"peers\":\"$peer_count\"}" > "$result_file"

    update_results "$operator" "$network" "$result_file" 
    rm "$result_file"
}

main() {
    initialize_output

    if [ ! -f "$BOOTNODES_JSON" ]; then
        echo "Bootnodes configuration file does not exist."
        exit 1
    fi

    # read bootnodes.json and test each bootnode
    cat "$BOOTNODES_JSON" | "$JQ_BINARY" -r 'to_entries[] | .key as $network | .value.commandId as $cid | .value.members | to_entries[] | .key as $operator | .value[] | "\($network) \($cid) \($operator) \(.)"' |
    # looping through each bootnode address
    while IFS=' ' read -r network command_id operator bootnode; do
        test_bootnode "$operator" "$network" "$bootnode" "$command_id"
        rm -rf "$DATA_DIR"
    done
    echo "All data has been fetched and saved."
}

main
