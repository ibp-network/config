#!/bin/bash

# Define directories and files
readonly SCRIPT_DIR="$(dirname "$(realpath "$0")")"
readonly ROOT_DIR="$(dirname "$SCRIPT_DIR")"
readonly OUTPUT_DIR="/tmp/bootnode_tests"
readonly FINAL_OUTPUT_FILE="$OUTPUT_DIR/final_results.json"
readonly BOOTNODES_JSON="$ROOT_DIR/bootnodes.json"
readonly TEST_BOOTNODE_SCRIPT="$SCRIPT_DIR/test_bootnode.sh"
readonly TEMP_PORTS_FILE="$OUTPUT_DIR/bootnodes_with_ports.txt" # Temporary file for port assignments
readonly AMOUNT_OF_THREADS=2

# Ensure necessary directories exist
mkdir -p "$OUTPUT_DIR" || { echo "Failed to create output directory"; exit 1; }

# Function to check if a port is available
is_port_available() {
    local port=$1
    ! ss -tulwn | grep -q ":$port "
}

# Generate tasks and pre-allocate ports
tasks=$(jq -r 'to_entries[] | .key as $network | .value.commandId as $cid | .value.members | to_entries[] | .key as $operator | .value[] | "\($network) \($cid) \($operator) \(.)"' "$BOOTNODES_JSON")
port=49152

# Loop through tasks and assign a unique port to each one
echo "$tasks" | while read -r task; do
    while ! is_port_available "$port"; do
        ((port++))
        if [[ $port -gt 65535 ]]; then
            echo "No more ports available in the allowed range."
            exit 1
        fi
    done
    echo "$task $port" >> "$TEMP_PORTS_FILE"
    ((port++))  # Ensure the next task checks the next available port
done

# Verify that tasks are formatted correctly
if [ ! -s "$TEMP_PORTS_FILE" ]; then
    echo "No tasks generated, check jq filter syntax or input file."
    exit 1
fi

# Parallel execution using pre-allocated ports
parallel -j $AMOUNT_OF_THREADS --halt now,fail=1 --line-buffer --colsep ' ' \
    "$TEST_BOOTNODE_SCRIPT {1} {2} {3} {4} {5}" :::: "$TEMP_PORTS_FILE"

# Check if parallel execution was successful
if [ $? -ne 0 ]; then
    echo "An error occurred during parallel execution"
    exit 1
fi

echo "Parallel execution complete."

# Combine results
if ! jq -s 'add' $OUTPUT_DIR/*_result.json > "$OUTPUT_DIR/new_results.json"; then
    echo "Failed to combine results"; exit 1;
fi

# Handle the final results file
if [ -f "$FINAL_OUTPUT_FILE" ]; then
    if ! jq -s '.[0] + .[1]' "$FINAL_OUTPUT_FILE" "$OUTPUT_DIR/new_results.json" > "$OUTPUT_DIR/temp_result.json" || ! mv "$OUTPUT_DIR/temp_result.json" "$FINAL_OUTPUT_FILE"; then
        echo "Failed to update final results file"; exit 1;
    fi
else
    if ! mv "$OUTPUT_DIR/new_results.json" "$FINAL_OUTPUT_FILE"; then
        echo "Failed to create final results file"; exit 1;
    fi
fi

echo "Results combined into $FINAL_OUTPUT_FILE."
