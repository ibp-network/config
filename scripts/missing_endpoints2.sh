jq -r 'reduce .[] as $blocks ({}; . + ($blocks | reduce .[] as $item ({}; select($item.valid == false) | .[$item.id] += ["\($item.network):\($item.endpoint)"])))' /tmp/endpoint_tests/results.json
