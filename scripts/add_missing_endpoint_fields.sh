#!/bin/bash

# Define the location of the members.json file and backup
MEMBERS_JSON="members.json"
BACKUP_JSON="${MEMBERS_JSON}.bak"

# Backup the original JSON file
cp "$MEMBERS_JSON" "$BACKUP_JSON"

# Function to update or append missing endpoints for a given member key
update_endpoints() {
    local member_key="$1"
    local endpoint="$2"
    local default_url="wss://placeholder/$endpoint"

    # Update endpoints using jq, assuming endpoints object exists
    jq --arg member_key "$member_key" --arg endpoint "$endpoint" --arg url "$default_url" '
    .members[$member_key].endpoints[$endpoint] = (.members[$member_key].endpoints[$endpoint] // $url)
    ' "$MEMBERS_JSON" > "temp_${MEMBERS_JSON}" && mv "temp_${MEMBERS_JSON}" "$MEMBERS_JSON"
}

# Identify the member with the maximum number of endpoints
template_member_key=$(jq -r '[.members | to_entries[] | select(.value.membership == "professional" and .value.endpoints) | {key: .key, count: (.value.endpoints | length)}] | max_by(.count) | .key' "$MEMBERS_JSON")

if [ -z "$template_member_key" ]; then
    echo "No valid template member found. Check if professional members with endpoints exist."
    exit 1
fi

# Extract all endpoints from the template member
template_endpoints=$(jq -r --arg member_key "$template_member_key" '.members[$member_key].endpoints | keys[]' "$MEMBERS_JSON")

# Ensure all professional members have all endpoints from the template
jq -r '.members | to_entries[] | select(.value.membership == "professional").key' "$MEMBERS_JSON" | while read member_key; do
    echo "Reviewing member key: $member_key"
    for endpoint in $template_endpoints; do
        echo "Ensuring endpoint: $endpoint for member key: $member_key"
        update_endpoints "$member_key" "$endpoint"
    done
done

echo "All missing endpoints have been added successfully."
rm "$BACKUP_JSON"
