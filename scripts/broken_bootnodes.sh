#!/bin/bash
jq '.[] | select(.valid == false)' /tmp/bootnode_tests/results.json
