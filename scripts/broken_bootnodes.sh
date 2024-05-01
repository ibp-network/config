#!/bin/bash
RESULTS_JSON="/tmp/bootnode_tests/results.json"
jq '.[] | .[] | select(.valid == false)' "$RESULTS_JSON"

