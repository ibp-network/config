curl -s https://raw.githubusercontent.com/ibp-network/config/main/services_rpc.json | \
  jq -r 'to_entries[] | [
    .key,
    (.value.Providers.Dotters.RpcUrls[0] | sub("wss";"https"))
  ] | @tsv' | \
  while read net url; do
    genesis_hash=$(curl -s -H "Content-Type: application/json" \
      -d '{"id":1,"jsonrpc":"2.0","method":"chain_getBlockHash","params":[0]}' \
      $url | jq -r .result)
    
    state_root=$(curl -s -H "Content-Type: application/json" \
      -d '{"id":1,"jsonrpc":"2.0","method":"chain_getHeader","params":["'$genesis_hash'"]}' \
      $url | jq -r .result.stateRoot)
    
    echo "$net: $state_root"
  done
