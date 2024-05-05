#!/bin/bash
RESULTS_JSON="/tmp/bootnode_tests/results.json"
jq 'map_values(
      with_entries(
        .value |= map(select(.valid == false))
      )
    )' $RESULTS_JSON

