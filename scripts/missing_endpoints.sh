#!/bin/bash

# Path to the JSON file containing member data
RESULTS_JSON="/tmp/endpoint_tests/results.json"

jq -r 'to_entries | reduce .[] as $member ({}; 
  if ($member.value | map(select(.valid == false)) | length > 0) then
    . + {
      ($member.key): {
        member: $member.key,
        endpoints: ($member.value | map(select(.valid == false)) | map({(.network): .endpoint}) | add)
      }
    }
  else
    .
  end
)' $RESULTS_JSON
