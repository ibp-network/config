#!/bin/bash
set -euo pipefail

# define paths for scripts and tools
script_dir="$(dirname "$(realpath "$0")")"
root_dir="$(dirname "$script_dir")"
gavel="$script_dir/binaries/gavel"
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

  cmd_output=$(echo | openssl s_client -connect "$provider_ip:$port" -servername "$domain" -showcerts 2>/dev/null | openssl x509 -noout -enddate)
  if [[ $? -ne 0 ]]; then
    echo "Error fetching certificate for $domain at IP $provider_ip on port $port" >&2
    return 1
  fi

  expiration_str=$(echo "$cmd_output" | cut -d= -f2)
  if [[ -z "$expiration_str" ]]; then
    echo "Error parsing expiration date for $domain. Command output: $cmd_output" >&2
    return 1
  fi

  expiration=$(date -d "$expiration_str" +%s 2>/dev/null)
  if [[ $? -ne 0 ]]; then
    echo "Error converting expiration date to epoch for $domain. Received date: $expiration_str" >&2
    return 1
  fi

  echo "$expiration"
}

# fetch block data from network endpoint
fetch_block_data() {
  local service_name="$1"
  local member="$2"
  local network="$3"
  local endpoint="$4"
  local block_height="$5"
  local current=$(date +%s) # Current time in seconds since the epoch
  local triennium=$((21 * 24 * 3600)) # 21 days in seconds
  local week=$((7 * 24 * 3600)) # 7 days in seconds

  # Default to localhost IP if no service address is provided
  local provider_ip=$(jq --arg member "$member" -r '.members[$member].services_address // "127.0.0.1"' "$members_json")

  local cert_expiration=$(check_ssl_certificate "$endpoint" "$provider_ip")
  echo "Fetching data from $member/$network: $endpoint($provider_ip)"
  local cert_expiration_str=$(date -d "@$cert_expiration" "+%Y-%m-%d %H:%M:%S")

  # Determine alert status based on expiration proximity
  if [[ $((cert_expiration - current)) -le $week ]]; then
      echo "🔴 Red Alert: $provider_ip ($service_name) certificate expires very soon: $cert_expiration_str"
  elif [[ $((cert_expiration - current)) -le $triennium ]]; then
      echo "⚠️ Alert: $provider_ip ($service_name) certificate expires soon: $cert_expiration_str"
  else
      echo "✅ $provider_ip ($service_name) certificate is valid until: $cert_expiration_str"
  fi

  local block_data
  local block_result=$("$gavel" fetch "$endpoint" "$block_height" -r "$provider_ip" 2>&1)
  local block_status=$?
  if [[ $block_status -ne 0 ]]; then
      echo "Error fetching block data: $block_result"
      block_data="{\"error\":\"$block_result\"}"
  else
      block_data="$block_result"
  fi

  local mmr_data
  local mmr_result=$("$gavel" mmr "$endpoint" -r "$provider_ip" 2>&1)
  local mmr_status=$?
  echo "mmr_data: $mmr_result"
  if [[ $mmr_status -ne 0 ]]; then
      echo "Error fetching MMR data: $mmr_result"
      mmr_data="{\"error\":\"$mmr_result\", \"proof\":null}"
  else
      mmr_data="$mmr_result"
  fi

  local offchain_indexing=false
  if echo "$mmr_data" | jq -e . > /dev/null 2>&1; then
    offchain_indexing=$(echo "$mmr_data" | jq -r 'if .proof != null and .proof != "" then true else false end')
  fi

  echo "✅ success, offchain-indexing: $offchain_indexing"

  local first_extrinsic_bytes
  if echo "$block_data" | jq -e . > /dev/null 2>&1; then
    first_extrinsic_bytes=$(echo "$block_data" | jq -r '.block.extrinsics[0]' | xxd -r -p | head -c 8 | xxd -p)
  fi

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
  echo "Processing endpoints from $services_json"
  jq -rc '. | to_entries[]' "$services_json" | while IFS= read -r service; do
    local service_name=$(echo "$service" | jq -r '.key')
    local endpoints=$(echo "$service" | jq -r '.value.endpoints | to_entries[]')
    local members=$(echo "$service" | jq -rc '.value.members[]')

    echo "Service: $service_name, Members: $members"

    local block_height=$(rand 1 1000)
    echo "$endpoints" | jq -c '.' | while IFS= read -r endpoint; do
      local network=$(echo "$endpoint" | jq -r '.key')
      local fqdn=$(echo "$endpoint" | jq -r '.value')
      echo "Processing $network at $fqdn"

      echo "$members" | while IFS= read -r member; do
        echo "Fetching data for member $member at network $network with FQDN $fqdn"
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
