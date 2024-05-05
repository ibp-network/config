#!/usr/bin/env bash
set -euo pipefail

trap 'cleanup' SIGHUP SIGINT SIGTERM EXIT

# Constants
readonly POLKADOT_BINARY="/usr/local/bin/polkadot"
readonly POLKADOT_PARACHAIN_BINARY="/usr/local/bin/polkadot-parachain"
readonly ENCOINTER_BINARY="/usr/local/bin/encointer"
readonly OUTPUT_DIR="/tmp/bootnode_tests"
readonly MAX_TESTING_PERIOD=40
readonly DISCOVERED_REQUIRED=1 # more than 1 peer discovered

# Cleanup function to handle process termination and resource cleanup
cleanup() {
    echo "Cleaning up..."
    if [[ -n "${cmd_pid:-}" ]]; then
        kill "$cmd_pid" 2>/dev/null || true
    fi
    echo "Cleanup complete. Exiting."
    exit
}

# Usage function
usage() {
    echo "Test bootnode connectivity and peer discovery."
    echo "Usage: $0 <network> <command_id> <operator> <bootnode> <prometheus_port>"
    exit 1
}

# Parse and check arguments
if [ "$#" -ne 5 ]; then
    usage
fi

network="$1"
command_id="$2"
operator="$3"
bootnode="$4"
prometheus_port="${5:-9615}"

# Determine binary path and relaychain based on command_id
binary_path="$POLKADOT_BINARY"
relaychain=""
case "$command_id" in
    "parachain")
        binary_path="$POLKADOT_PARACHAIN_BINARY"
        relaychain="${network##*-}"
        ;;
    "encointer")
        binary_path="$ENCOINTER_BINARY"
        relaychain="kusama"
        ;;
esac

# Setup directories and log files
DATA_DIR="/tmp/bootnode_data/${operator}_${network}_$RANDOM"
mkdir -p "$OUTPUT_DIR" "$DATA_DIR"
log_file="$OUTPUT_DIR/${operator}_${network}.log"

# Construct the command
command="$binary_path --no-hardware-benchmarks --no-mdns -d $DATA_DIR --chain ./chain-spec/${network}.json --prometheus-port $prometheus_port"
[[ -n "$relaychain" ]] && command+=" --relay-chain-rpc-urls wss://rpc.ibp.network/$relaychain"
command+=" --bootnodes $bootnode"

# Run the command with background timeout
echo "$command" > "$log_file"
echo "$command" # debug
$command &> "$log_file" &
cmd_pid=$!

# Wait for node initialization
until curl -s "http://127.0.0.1:$prometheus_port/metrics" | grep -q "substrate_sub_libp2p_peerset_num_discovered"; do
    sleep 1
done

start_time=$(date +%s)
best_block=0
peerset_num_discovered=0

# Monitor node and fetch metrics periodically
while true; do
    current_time=$(date +%s)
    elapsed_time=$((current_time - start_time))

    # Fetch metrics with curl, handling curl failure gracefully
    metrics_output=$(curl -s "http://127.0.0.1:$prometheus_port/metrics" || echo "curl_error")


    if [[ "$metrics_output" == "curl_error" ]]; then
        echo "Failed to fetch metrics, trying again..."
        sleep 1
        continue
    fi

    peer_count=$(echo "$metrics_output" | grep -v '^#' | grep -E "substrate_sub_libp2p_peers_count\{[^}]*chain=\"$network\"\}" | awk -F ' ' '{print $NF}' || echo 0)
    peerset_num_discovered=$(echo "$metrics_output" | grep -v '^#' | grep -E "substrate_sub_libp2p_peerset_num_discovered\{[^}]*chain=\"$network\"\}" | awk -F ' ' '{print $NF}' || echo 0)

    echo "Metrics at $(date): peers=$peer_count, discovered=$peerset_num_discovered"

    if [[ "$peerset_num_discovered" -gt "$DISCOVERED_REQUIRED" ]]; then
        echo "Sufficient discoveries found: $peerset_num_discovered"
        break
    fi

    if [[ "$elapsed_time" -ge "$MAX_TESTING_PERIOD" ]]; then
        echo "Timeout reached: $elapsed_time seconds."
        break
    fi

    sleep 3
done

# Output results in JSON format
valid=false
[[ "$peerset_num_discovered" -gt "$DISCOVERED_REQUIRED" ]] && valid=true
result_file="$OUTPUT_DIR/${operator}_${network}_result.json"
echo "{\"member\":\"$operator\", \"network\":\"$network\", \"bootnode\":\"$bootnode\", \"valid\":$valid, \"peers\":$peer_count, \"elapsed\":$elapsed_time, \"peers_discovered\":$peerset_num_discovered}" > "$result_file"

cat "$result_file"

cleanup
