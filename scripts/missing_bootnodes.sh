#!/bin/bash
jq '[. as $root | keys[] as $instance | $root[$instance].members | to_entries | map(select(.value | length == 0) | .key as $provider | {provider: $provider, hub: $instance})] | add | group_by(.provider) | map({(.[0].provider): map(.hub)}) | add' bootnodes.json

