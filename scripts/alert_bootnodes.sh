#!/bin/bash

# Define paths
script_dir="$(dirname "$(realpath "$0")")"
matrix_alert="${script_dir}/matrix_alert.sh"
bootnodes_json="${script_dir}/../bootnodes.json"
results_json="/tmp/bootnode_tests/results.json"


# Function to check for required dependencies and files
check_dependencies() {
    if ! command -v jq &>/dev/null; then
        echo "Error: jq is not installed."
        return 1
    fi

    if [ ! -x "$matrix_alert" ]; then
        echo "Error: Alert script is not executable or not found at $matrix_alert"
        return 1
    fi

    if [ ! -f "$bootnodes_json" ] || [ ! -f "$results_json" ]; then
        echo "Error: Necessary JSON files are missing."
        return 1
    fi

    return 0
}

# Ensure all dependencies and files are in place
if ! check_dependencies; then
    exit 1
fi

missing_data=$(jq '[. as $root | keys[] as $instance | $root[$instance].members | to_entries | 
  map(select(.value | length == 0) | .key as $provider | {provider: $provider, hub: $instance})] | 
  add | group_by(.provider) | map({(.[0].provider): map(.hub)}) | add' "$bootnodes_json")
echo "$missing_data"

# Gather broken bootnodes data, excluding "encointer" network for now
broken_data=$(jq -r '[.[] | to_entries[] |
    {provider: .key, broken: [.value[] | select(.valid == false) | .id]} |
    select(.broken | length > 0)]' "$results_json")
echo "$broken_data"

data_json=$(jq -n --argjson missing "$missing_data" --argjson broken "$broken_data" '
    {
        providers: ($missing + $broken | map(.provider) | unique),
        data: ($missing + $broken)
      }')
echo $data_json

# Send alerts based on the prepared data
send_alerts() {
    local data_json=$1
    local providers=$(echo "$data_json" | jq -r '.providers[]')

    for provider in $providers; do
        local missing=$(echo "$data_json" | jq -r --arg provider "$provider" '.data[] | select(.provider == $provider) | .hubs | join(", ")')
        local broken=$(echo "$data_json" | jq -r --arg provider "$provider" '.data[] | select(.provider == $provider) | .broken | join(", ")')

        # Construct the message only if there is relevant data
        if [[ -n "$missing" || -n "$broken" ]]; then
            local alert_message="Alert for $provider: 🔨 Broken bootnodes [${broken}], ❓ Missing bootnodes [${missing}]"
            echo "$alert_message"
            # "$matrix_alert" -m "$alert_message" # Uncomment to enable alerting
        fi
    done
}

send_alerts "$data_json"

