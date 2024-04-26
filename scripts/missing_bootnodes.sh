jq '. as $root | keys[] as $instance | "\($instance): Missing bootnodes for \($root[$instance].members | to_entries | map(select(.value | length == 0) | .key))"' bootnodes.json
