#!/bin/bash
set -uo pipefail

# Trap SIGPIPE and handle it
trap 'echo "SIGPIPE received, continuing..."; exit 0' SIGPIPE

# Define paths for scripts and tools
script_dir="$(dirname "$(realpath "$0")")"
root_dir="$(dirname "$script_dir")"
gavel="/usr/local/bin/gavel"
jq="/usr/bin/jq"
services_json="$root_dir/services.json"
members_json="$root_dir/members.json"
output_dir="/tmp/endpoint_tests"
output_file="$output_dir/syndicate_results.json"

# Initialize output
echo "Using gavel built @ $gavel"
mkdir -p "$output_dir"
echo '[]' > "$output_file"

# Function to generate a random number within a range
rand() {
  local min=$1
  local max=$2
  echo $((RANDOM % (max - min + 1) + min))
}

# Function to check SSL certificate expiration
check_ssl_certificate() {
  local domain="$1"
  local ip="$2"
  local port="${3:-443}"
  local timeout=5
  local current=$(date +%s)

  domain=$(echo "$domain" | sed -e 's|^wss://||')
  # Fetch the certificate details using curl
  local output
  output=$(timeout $timeout curl -v --insecure --resolve "$domain:$port:$ip" "https://$domain:$port" 2>&1)
  echo "$output"  # Debug output

  # Extract the expiration date from the curl output
  local expiration
  expiration=$(echo "$output" | grep -oP '(?<=expire date: )\w{3} \d{2} \d{2}:\d{2}:\d{2} \d{4}' | head -1)
  if [[ -z "$expiration" ]]; then
    echo "Error: Could not find expiration date in the output for $domain at IP $ip on port $port" >&2
    return 1
  fi

  # Convert the expiration date to epoch time
  local exp_epoch
  exp_epoch=$(date -d "$expiration" +%s)
  if [[ $? -ne 0 ]]; then
    echo "Error: Could not convert expiration date to epoch for $domain. Received date: $expiration" >&2
    return 1
  fi

  # Format the expiration date
  local exp_str
  exp_str=$(date -d "@$exp_epoch" "+%Y-%m-%d %H:%M:%S")

  # Determine the certificate status
  local week=$((7 * 24 * 3600))
  local triennium=$((21 * 24 * 3600))

  if ((exp_epoch - current <= week)); then
    echo "🔴 $ip ($domain) certificate expires very soon: $exp_str"
  elif ((exp_epoch - current <= triennium)); then
    echo "⚠️ $ip ($domain) certificate expires soon: $exp_str"
  else
    echo "✅ $ip ($domain) certificate is valid until: $exp_str"
  fi
  echo "$exp_epoch"
}

# Function to fetch data using gavel
fetch_gavel_data() {
  local command="$1"
  local endpoint="$2"
  local provider_ip="$3"
  local block_height="${4:-}"

  local full_command
  if [[ -n "$block_height" ]]; then
    full_command="$gavel $command $endpoint $block_height -r $provider_ip"
  else
    full_command="$gavel $command $endpoint -r $provider_ip"
  fi

  local timeout_period=5  # Timeout period in seconds
  local result
  if ! result=$(timeout $timeout_period sh -c "$full_command" 2>&1); then
    echo '{"error":"Timeout when fetching data"}'
  else
    echo "$result" | jq '.' 2>/dev/null || echo '{"error":"Invalid JSON"}'
  fi
}

validate_and_process_data() {
  local block_data="$1"
  local mmr_data="$2"
  local cert_expiration="$3"
  local service_name="$4"
  local member="$5"
  local network="$6"
  local endpoint="$7"
  local chain="$8"
  local client="$9"
  local version="${10}"
  local health="${11}"

  # Handle empty inputs
  if [[ -z "$block_data" ]]; then
    echo "block_data is empty"
    block_data="{}"
  fi

  if [[ -z "$mmr_data" ]]; then
    echo "mmr_data is empty"
    mmr_data="{}"
  fi

  # Determine offchain indexing status
  local offchain_indexing=false
  if [[ $(jq -r '.proof // empty' <<<"$mmr_data") != "" ]]; then
    offchain_indexing=true
  fi

  # Extract first extrinsic bytes
  local first_extrinsic_bytes="null"
  if [[ $(jq -r '.block.extrinsics | length' <<<"$block_data") -gt 0 ]]; then
    first_extrinsic_bytes=$(jq -r '.block.extrinsics[0]' <<<"$block_data" | xxd -r -p | head -c 8 | xxd -p)
    first_extrinsic_bytes=$(jq -Rn --arg bytes "$first_extrinsic_bytes" '$bytes')
  fi

  # Validate JSON
  if ! jq -e '.' <<<"$block_data" >/dev/null 2>&1; then
    echo "block_data is invalid JSON"
    block_data='{ "error": "Invalid JSON" }'
  fi

  # Construct result JSON
  local result_json
  if jq -e '.error' <<<"$block_data" >/dev/null 2>&1; then
    result_json=$(jq -n --arg member "$member" --arg service_name "$service_name" --arg network "$network" --arg endpoint "$endpoint" --arg error "$(jq -r '.error' <<<"$block_data")" --arg chain "$chain" --arg client "$client" --arg version "$version" --argjson health "$health" '{
      id: $member,
      service: $service_name,
      network: $network,
      endpoint: $endpoint,
      error: $error,
      valid: false
    }')
  else
    result_json=$(jq -n --arg member "$member" --arg service_name "$service_name" --arg network "$network" --arg endpoint "$endpoint" --argjson first_extrinsic_bytes "$first_extrinsic_bytes" --argjson block_data "$block_data" --argjson offchain_indexing "$offchain_indexing" --arg cert_expiration "$cert_expiration" --arg chain "$chain" --arg client "$client" --arg version "$version" --argjson health "$health" '{
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
      chain: $chain,
      client: $client,
      version: $version,
      health: $health,
      valid: true
    }')
  fi

  echo "result_json: $result_json"
  update_results "$result_json"
}

fetch_and_process_block_data() {
  local service_name="$1"
  local member="$2"
  local network="$3"
  local endpoint="$4"
  local block_height="$5"

  local provider_ip=$(jq --arg member "$member" -r '.members[$member].services_address // "127.0.0.1"' "$members_json")

  local cert_expiration
  if ! cert_expiration=$(check_ssl_certificate "$endpoint" "$provider_ip" | tail -n1); then
    cert_expiration="null"
  fi
  echo "Fetching data from $member/$network: $endpoint($provider_ip)"

  local block_data=$(fetch_gavel_data "fetch" "$endpoint" "$provider_ip" "$block_height")
  local mmr_data=$(fetch_gavel_data "mmr" "$endpoint" "$provider_ip")

  if [[ -z "$block_data" || "$block_data" == "null" || "$block_data" == '{"error":"timeout"}' ]]; then
    block_data='{ "error": "No data fetched" }'
  fi
  if [[ -z "$mmr_data" || "$mmr_data" == "null" || "$mmr_data" == '{"error":"timeout"}' ]]; then
    mmr_data='{ "error": "No data fetched" }'
  fi

  local chain=$(echo "$block_data" | jq -r '.metadata.chain // ""')
  local client=$(echo "$block_data" | jq -r '.metadata.client // ""')
  local version=$(echo "$block_data" | jq -r '.metadata.version // ""')
  local health=$(echo "$block_data" | jq -r '.metadata.health // "{}"')

  validate_and_process_data "$block_data" "$mmr_data" "$cert_expiration" "$service_name" "$member" "$network" "$endpoint" "$chain" "$client" "$version" "$health"
}

process_endpoints() {
  echo "Processing endpoints from $services_json"
  jq -rc '. | to_entries[]' "$services_json" | while IFS= read -r service; do
    local service_name=$(echo "$service" | jq -r '.key')
    local endpoints=$(echo "$service" | jq -r '.value.endpoints | to_entries[]')
    local members=$(echo "$service" | jq -rc '.value.members[]')

    local block_height=$(rand 1 1000)
    echo "$endpoints" | jq -c '.' | while IFS= read -r endpoint; do
      local network=$(echo "$endpoint" | jq -r '.key')
      local fqdn=$(echo "$endpoint" | jq -r '.value')
      echo "Processing $network at $fqdn"

      echo "$members" | while IFS= read -r member; do
        echo "Fetching data for member $member at network $network with FQDN $fqdn"
        fetch_and_process_block_data "$service_name" "$member" "$network" "$fqdn" "$block_height"
      done
    done
  done
}

update_results() {
  local result_json="$1"
  echo "$result_json" | jq -e . > /dev/null 2>&1 || result_json='{"error":"Invalid JSON"}'
  jq --argjson newEntry "$result_json" '. += [$newEntry]' "$output_file" > "${output_file}.tmp" && mv "${output_file}.tmp" "$output_file"
}

main() {
  process_endpoints
  echo "All data has been fetched and saved."
}

main
