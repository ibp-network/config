#!/bin/bash
set -euo pipefail

# define paths for scripts and tools
script_dir="$(dirname "$(realpath "$0")")"
root_dir="$(dirname "$script_dir")"
gavel="$script_dir/gavel/target/release/gavel"
jq="/usr/bin/jq"
services_json="$root_dir/services.json"
members_json="$root_dir/members.json"
output_dir="/tmp/endpoint_tests"
output_file="$output_dir/syndicate_results.json"

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

check_ssl_certificate() {
  local domain="$1"
  local provider_ip="$2"
  local port="${3:-443}"  # Default to port 443 if not specified
  local cmd_output
  local expiration_str
  local expiration
  local current

    # Perform the SSL fetch safely, capturing both output and errors
    cmd_output=$(echo | openssl s_client -servername "$domain" -connect "$provider_ip:$port" -showcerts 2>&1 | openssl x509 -noout -enddate)

    # Check for successful fetch, parse the end date only if successful
    if [[ $? -eq 0 ]]; then
      expiration_str=$(echo "$cmd_output" | sed -n 's/notAfter=\(.*\)$/\1/p')
      if [[ -z "$expiration_str" ]]; then
        echo "$domain: Error parsing certificate data."
        return 1
      fi
    else
      echo "$domain: Failed to fetch certificate."
      return 1
    fi

    # Calculate expiration date in seconds since the epoch
    expiration=$(date -d "$expiration_str" +%s)
    echo "$expiration"
  }

# fetch block data from network endpoint
fetch_block_data() {
  local service_name="$1"
  local member="$2"
  local network="$3"
  local endpoint="$4"
  local block_height="$5"
  local cert_expiration
  local current=$(date +%s) # Current time in seconds since the epoch
  local triennium=$((21 * 24 * 3600)) # 21 days in seconds
  local week=$((7 * 24 * 3600)) # 7 days in seconds


    # Default to localhost IP if no service address is provided
    local provider_ip=$(jq --arg member "$member" -r '.members[$member].services_address // "127.0.0.1"' "$members_json")

    cert_expiration=$(check_ssl_certificate "$fqdn" "$provider_ip")

    echo "Fetching data from $member/$network: $endpoint($provider_ip)"

    cert_expiration_str=$(date -d "@$cert_expiration" "+%Y-%m-%d %H:%M:%S")

    # Determine alert status based on expiration proximity
    if [[ $((cert_expiration - current)) -le $week ]]; then
        echo "🔴 Red Alert: $provider_ip ($service_name) certificate expires very soon: $cert_expiration_str"
    elif [[ $((cert_expiration - current)) -le $triennium ]]; then
        echo "⚠️ Alert: $provider_ip ($service_name) certificate expires soon: $cert_expiration_str"
    else
        echo "✅ $provider_ip ($service_name) certificate is valid until: $cert_expiration_str"
    fi

    # Attempt to fetch block and MMR data
    local block_data=$("$gavel" fetch "$endpoint" -b "$block_height" -r "$provider_ip" 2>&1 || echo '{"error":"Failed to fetch block data"}')
    local mmr_data=$("$gavel" mmr "$endpoint" "$block_height" -r "$provider_ip" 2>&1 || echo '{"proof":null}')

    local offchain_indexing=false
    if echo "$mmr_data" | jq -e . > /dev/null 2>&1; then
      offchain_indexing=$(echo "$mmr_data" | jq -r 'if .proof != null and .proof != "" then true else false end')
      fi

      if echo "$block_data" | jq -e . > /dev/null 2>&1; then
        echo "✅ success, offchain-indexing: $offchain_indexing"
      else
        echo "❌ error: $block_data"
        block_data="{\"error\":\"$block_data\"}"
      fi

      local first_extrinsic_bytes=$(echo "$block_data" | jq -r '.block.extrinsics[0]' | xxd -r -p | head -c 8 | xxd -p)
      local result_json
      if echo "$block_data" | jq -e '.error' >/dev/null; then
        local error_message=$(echo "$block_data" | jq -r '.error')
        result_json=$(jq -n \
          --arg member "$member" \
          --arg service_name "$service_name" \
          --arg network "$network" \
          --arg endpoint "$endpoint" \
          --arg error "$error_message" '{
                  id: $member,
                  service: $service_name,
                  network: $network,
                  endpoint: $endpoint,
                  error: $error,
                  valid: false
      }')
    else
      if [[ -z "$first_extrinsic_bytes" ]]; then first_extrinsic_bytes="null"; fi
      result_json=$(jq -n \
        --arg member "$member" \
        --arg service_name "$service_name" \
        --arg network "$network" \
        --arg endpoint "$endpoint" \
        --argjson block_data "$block_data" \
        --argjson offchain_indexing "$offchain_indexing" \
        --arg first_extrinsic_bytes "$first_extrinsic_bytes" \
        --argjson cert_expiration "$cert_expiration" \
        '{
              id: $member,
              service: $service_name,
              network: $network,
              endpoint: $endpoint,
              block_number: ($block_data.block.header.number // null),
              parent_hash: ($block_data.block.header.parentHash // null),
              state_root: ($block_data.block.header.stateRoot // null),
              first_extrinsic_bits: $first_extrinsic_bytes,
              offchain_indexing: $offchain_indexing,
              cert_expiration: $cert_expiration,
              valid: true
            }')
      fi
      echo "result_json: $result_json"
      update_results "$result_json"
    }

# process all endpoints for each service from a given JSON
process_endpoints() {
  jq -rc '. | to_entries[]' "$services_json" | while IFS= read -r service; do
  local service_name=$(echo "$service" | jq -r '.key')
  local endpoints=$(echo "$service" | jq -r '.value.endpoints | to_entries[]')
  local members=$(echo "$service" | jq -rc '.value.members[]')
  local block_height=$(rand 1 1000)
  echo "$endpoints" | jq -c '.' | while IFS= read -r endpoint; do
  local network=$(echo "$endpoint" | jq -r '.key')
  local fqdn=$(echo "$endpoint" | jq -r '.value')
  echo "$members" | while IFS= read -r member; do
  fetch_block_data "$service_name" "$member" "$network" "$fqdn" "$block_height"
done
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
