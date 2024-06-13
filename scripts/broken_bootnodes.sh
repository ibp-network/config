#!/bin/bash
RESULTS_JSON="/tmp/bootnode_tests/results.json"
jq 'map_values(
      map_values(
        select(.valid == false and (.network | contains("encointer") | not) and .peers == "0")
      )
    )' $RESULTS_JSON
