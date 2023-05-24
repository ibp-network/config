# Copies of the chain spec files for the various networks.

This repo contains copies of the chain spec files with bootnodes empty.
We use this in teh ibp-monitor to check our bootnodes:
- does the bootnode exist, up and accepting connections
- can the testnode start syncing from the bootnode
- does the bootnode pass additional peers to the testnode `(n peers)` where `n > 1`

## System Chains
- https://github.com/paritytech/polkadot/tree/master/node/service/chain-specs
- polkadot               : https://raw.githubusercontent.com/paritytech/polkadot/master/node/service/chain-specs/polkadot.json
- kusama                 : https://raw.githubusercontent.com/paritytech/polkadot/master/node/service/chain-specs/kusama.json
- westend                : https://raw.githubusercontent.com/paritytech/polkadot/master/node/service/chain-specs/westend.json

## Parachains

https://github.com/paritytech/cumulus/tree/master/parachains/chain-specs
- bridge-hub-kusama      : https://raw.githubusercontent.com/paritytech/cumulus/master/parachains/chain-specs/bridge-hub-kusama.json
- ~~bridge-hub-polkadot~~: https://raw.githubusercontent.com/paritytech/cumulus/master/parachains/chain-specs/bridge-hub-polkadot.json
- ~~bridge-hub-westend~~ : https://raw.githubusercontent.com/paritytech/cumulus/master/parachains/chain-specs/bridge-hub-westend.json
- ~~collectives-kusama~~ : 
- collectives-polkadot   : https://raw.githubusercontent.com/paritytech/cumulus/master/parachains/chain-specs/collectives-polkadot.json
- collectives-westend    : https://raw.githubusercontent.com/paritytech/cumulus/master/parachains/chain-specs/collectives-westend.json
- statemine              : https://raw.githubusercontent.com/paritytech/cumulus/master/parachains/chain-specs/statemine.json
- statemint              : https://raw.githubusercontent.com/paritytech/cumulus/master/parachains/chain-specs/statemint.json
- westmint               : https://raw.githubusercontent.com/paritytech/cumulus/master/parachains/chain-specs/westmint.json


## Monitor

- https://github.com/ibp-network/ibp-monitor

