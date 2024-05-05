#!/usr/bin/env bash
set -euo pipefail

readonly POLKADOT_BINARY="/usr/local/bin/polkadot"
readonly POLKADOT_PARACHAIN_BINARY="/usr/local/bin/polkadot-parachain"
readonly ENCOINTER_BINARY="eusr/local/bin/encointer"
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

    local data_content=$(cat "$data_file")
    echo "debug: Data to append from $data_file: $data_content"

    "$JQ_BINARY" --arg operator "$operator" --arg network "$network" --argjson data "$data_content" '
        .[$operator] = (if .[$operator] then .[$operator] else {} end) |
        .[$operator][$network] = (if .[$operator][$network] | type == "array" then .[$operator][$network] else [] end) |
        .[$operator][$network] += [$data]  # Ensure data is appended as an array element
    ' "$OUTPUT_FILE" > "$tmp_file" && mv "$tmp_file" "$OUTPUT_FILE"

    echo "debug: Updated results.json for $operator on $network"
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
    elif [[ "$command_id" == "encointer" ]]; then
        relaychain="kusama"
        echo "relaychain: $relaychain"
    else
      relaychain=""
    fi

    local binary_path="$POLKADOT_BINARY"
    [[ "$command_id" == "parachain" ]] && binary_path="$POLKADOT_PARACHAIN_BINARY"
    [[ "$command_id" == "encointer" ]] && binary_path="$ENCOINTER_BINARY"

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
    # if command is parachain or encointer wait 45s
    [[ "$command_id" == "parachain" || "$command_id" == "encointer" ]] && echo 44s && timeout 44s $command &> "$log_file" &
    [[ "$command_id" == "parachain" || "$command_id" == "encointer" ]] && sleep 45
    [[ "$command_id" == "polkadot" ]] && echo 34s && timeout 34s $command &> "$log_file" &
    [[ "$command_id" == "polkadot" ]] && sleep 35
 
    # last line in logs with Idle or Syncing
    local peers_line=$(grep -E 'Idle|Syncing' "$log_file" | tail -1)
    echo "$peers_line"
    # number of peers in that line
    local peer_count=$(echo "$peers_line" | grep -oP '(?<=\()\d+(?= peers\))')
    echo "$operator $network peer_count: $peer_count"
    local valid=false
    # if over 0 peer(for now), consider it valid
    [[ "$peer_count" -gt 0 ]] && valid=true

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
    done
    rm -rf "$DATA_DIR"
    echo "All data has been fetched and saved."
}

main
