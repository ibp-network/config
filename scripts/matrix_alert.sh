#!/bin/bash

# Dependencies check
command -v jq >/dev/null 2>&1 || { echo >&2 "jq is not installed. Aborting."; exit 1; }
command -v matrix-commander-rs >/dev/null 2>&1 || { echo >&2 "matrix-commander-rs is not installed. Aborting."; exit 1; }

# Determine the script's directory and set the path to the JSON file one folder up
script_dir=$(dirname "$0")
json_file="$script_dir/../alerts.json"

# Display usage if script is not run with correct parameters
[ $# -eq 0 ] && { echo "Usage: $0 -m <message> [-g <group_name> | -a]"; exit 1; }

# Initialize group filter variable and alert everyone flag
group_filter=""
alert_all=false

# Parse command-line options
while getopts ":m:g:a" opt; do
  case $opt in
    m ) alert_message=$OPTARG ;;
    g ) group_filter=$OPTARG ;;
    a ) alert_all=true ;;
    * ) echo "Usage: $0 -m <message> [-g <group_name> | -a]"; exit 1 ;;
  esac
done

# Exit if required message input is missing
[ -z "$alert_message" ] && { echo "Missing required message input."; exit 1; }

# Check if the JSON file exists
[ ! -f "$json_file" ] && { echo "JSON file does not exist."; exit 1; }

# Load Matrix credentials from environment variable
if [ -z "$MATRIX_CREDENTIALS" ]; then
    echo "MATRIX_CREDENTIALS environment variable is not set."
    exit 1
fi

# Create a temporary file for credentials
credentials_file=$(mktemp)
echo "$MATRIX_CREDENTIALS" > "$credentials_file"

# Ensure the temporary file is deleted on exit
trap 'rm -f "$credentials_file"' EXIT

# Parse room ID
room_id=$(jq -r '.matrix.internal_room' "$json_file")
[ -z "$room_id" ] && { echo "Room ID could not be extracted."; exit 1; }

# Determine how to format the message based on user input
if [ "$alert_all" = true ]; then
    message_target="@room"
elif [ -n "$group_filter" ]; then
    mapfile -t members < <(jq -r --arg group "$group_filter" '.matrix.members[$group][]' "$json_file")
    message_target=$(IFS=', '; echo "${members[*]}")
else
    message_target=""
fi

# Function to send a message to a Matrix room
send_message() {
#  echo "debug: @ $1" message: "$2 $3 $credentials_file: $(cat $credentials_file)"  # For dry-run
  matrix-commander-rs -c "$credentials_file" -r "$1" -m "$2 $3"
}

# Send the message with the formatted target
send_message "$room_id" "$alert_message" "$message_target"
