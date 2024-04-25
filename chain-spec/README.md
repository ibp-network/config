# Copies of the chain spec files for the various networks.

This repo contains copies of the chain spec files with bootnodes empty.
We use this in the ibp-monitor to check our bootnodes:
- does the bootnode exist, up and accepting connections
- can the testnode start syncing from the bootnode
- does the bootnode pass additional peers to the testnode `(n peers)` where `n > 1`

## Relay Chains

https://github.com/paritytech/polkadot-sdk/tree/master/polkadot/node/service/chain-specs

- polkadot               : https://raw.githubusercontent.com/paritytech/polkadot-sdk/master/polkadot/node/service/chain-specs/polkadot.json
- kusama                 : https://raw.githubusercontent.com/paritytech/polkadot-sdk/master/polkadot/node/service/chain-specs/kusama.json
- westend                : https://raw.githubusercontent.com/paritytech/polkadot-sdk/master/polkadot/node/service/chain-specs/westend.json
- paseo                  : https://raw.githubusercontent.com/paritytech/polkadot-sdk/master/polkadot/node/service/chain-specs/paseo.json

## Parachains

https://github.com/paritytech/polkadot-sdk/tree/master/cumulus/parachains/chain-specs

- asset-hub-polkadot    : https://raw.githubusercontent.com/paritytech/polkadot-sdk/master/cumulus/parachains/chain-specs/asset-hub-polkadot.json
- asset-hub-kusama      : https://raw.githubusercontent.com/paritytech/polkadot-sdk/master/cumulus/parachains/chain-specs/asset-hub-kusama.json
- asset-hub-westend     : https://raw.githubusercontent.com/paritytech/polkadot-sdk/master/cumulus/parachains/chain-specs/asset-hub-westend.json
- asset-hub-paseo       : https://raw.githubusercontent.com/paseo-network/runtimes/main/chain-specs/asset-hub-paseo.raw.json

- bridge-hub-polkadot   : https://raw.githubusercontent.com/paritytech/polkadot-sdk/master/cumulus/parachains/chain-specs/bridge-hub-polkadot.json
- bridge-hub-kusama     : https://raw.githubusercontent.com/paritytech/polkadot-sdk/master/cumulus/parachains/chain-specs/bridge-hub-kusama.json
- bridge-hub-westend    : https://raw.githubusercontent.com/paritytech/polkadot-sdk/master/cumulus/parachains/chain-specs/bridge-hub-westend.json
- bridge-hub-paseo      : pending

- collectives-polkadot  : https://raw.githubusercontent.com/paritytech/polkadot-sdk/master/cumulus/parachains/chain-specs/collectives-polkadot.json
- collectives-kusama    : pending
- collectives-westend   : https://raw.githubusercontent.com/paritytech/polkadot-sdk/master/cumulus/parachains/chain-specs/collectives-westend.json
- collectives-paseo     : pending

- people-polkadot       : pending
- people-kusama         : pending
- people-westend        : https://raw.githubusercontent.com/paritytech/polkadot-sdk/master/cumulus/parachains/chain-specs/people-westend.json
- people-paseo          : pending

- coretime-polkadot     : pending
- coretime-kusama       : https://raw.githubusercontent.com/paritytech/polkadot-sdk/master/cumulus/parachains/chain-specs/coretime-kusama.json
- coretime-westend      : https://raw.githubusercontent.com/paritytech/polkadot-sdk/master/cumulus/parachains/chain-specs/coretime-westend.json
- coretime-paseo        : pending

https://github.com/encointer/encointer-parachain/tree/master/node/res

- encointer-polkadot    : pending
- encointer-kusama      : https://raw.githubusercontent.com/encointer/encointer-parachain/master/node/res/encointer-kusama.json
- encointer-westend     : pending
- encointer-paseo       : pending

## Monitor

- https://github.com/ibp-network/ibp-monitor

