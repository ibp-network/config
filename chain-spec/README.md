# Chain Spec Overview
This repository contains copies of the chain spec files with bootnodes removed
to enable testing and verifying of each bootnode functionality.
Key checks include:

- Bootnode availability and connectivity
- Ability for a testnode to start syncing from the bootnode
- Bootnode's capability to pass additional peers to the testnode, with `n peers` where `n > 1`

## Relay Chains
Listed below are the relay chains and their respective chain spec files:

| Network      | Chain Spec File URL |
|--------------|---------------------|
| Polkadot     | [polkadot.json](https://raw.githubusercontent.com/paritytech/polkadot-sdk/master/polkadot/node/service/chain-specs/polkadot.json) |
| Kusama       | [kusama.json](https://raw.githubusercontent.com/paritytech/polkadot-sdk/master/polkadot/node/service/chain-specs/kusama.json) |
| Westend      | [westend.json](https://raw.githubusercontent.com/paritytech/polkadot-sdk/master/polkadot/node/service/chain-specs/westend.json) |
| Paseo        | [paseo.json](https://raw.githubusercontent.com/paritytech/polkadot-sdk/master/polkadot/node/service/chain-specs/paseo.json) |

## Parachains
Listed below are the parachains grouped by their corresponding main relay chain:

### Asset Hub
| Network      | Chain Spec File URL |
|--------------|---------------------|
| Polkadot     | [asset-hub-polkadot.json](https://raw.githubusercontent.com/paritytech/polkadot-sdk/master/cumulus/parachains/chain-specs/asset-hub-polkadot.json) |
| Kusama       | [asset-hub-kusama.json](https://raw.githubusercontent.com/paritytech/polkadot-sdk/master/cumulus/parachains/chain-specs/asset-hub-kusama.json) |
| Westend      | [asset-hub-westend.json](https://raw.githubusercontent.com/paritytech/polkadot-sdk/master/cumulus/parachains/chain-specs/asset-hub-westend.json) |
| Paseo        | [asset-hub-paseo.json](https://raw.githubusercontent.com/paseo-network/runtimes/main/chain-specs/asset-hub-paseo.raw.json) |

### Bridge Hub
| Network      | Chain Spec File URL | Status |
|--------------|---------------------|--------|
| Polkadot     | [bridge-hub-polkadot.json](https://raw.githubusercontent.com/paritytech/polkadot-sdk/master/cumulus/parachains/chain-specs/bridge-hub-polkadot.json) | Active |
| Kusama       | [bridge-hub-kusama.json](https://raw.githubusercontent.com/paritytech/polkadot-sdk/master/cumulus/parachains/chain-specs/bridge-hub-kusama.json) | Active |
| Westend      | [bridge-hub-westend.json](https://raw.githubusercontent.com/paritytech/polkadot-sdk/master/cumulus/parachains/chain-specs/bridge-hub-westend.json) | Active |
| Paseo        | N/A | Pending |

### Collectives
| Network      | Chain Spec File URL | Status |
|--------------|---------------------|--------|
| Polkadot     | [collectives-polkadot.json](https://raw.githubusercontent.com/paritytech/polkadot-sdk/master/cumulus/parachains/chain-specs/collectives-polkadot.json) | Active |
| Westend      | [collectives-westend.json](https://raw.githubusercontent.com/paritytech/polkadot-sdk/master/cumulus/parachains/chain-specs/collectives-westend.json) | Active |
| Paseo        | N/A | Pending |

### People
| Network      | Chain Spec File URL | Status |
|--------------|---------------------|--------|
| Polkadot     | N/A | Pending |
| Kusama       | [people-kusama.json](https://raw.githubusercontent.com/paritytech/polkadot-sdk/master/cumulus/parachains/chain-specs/people-kusama.json) | Pending |
| Westend      | [people-westend.json](https://raw.githubusercontent.com/paritytech/polkadot-sdk/master/cumulus/parachains/chain-specs/people-westend.json) | Active |
| Paseo        | N/A | Pending |

### Coretime
| Network      | Chain Spec File URL | Status |
|--------------|---------------------|--------|
| Polkadot     | N/A | Pending |
| Kusama       | [coretime-kusama.json](https://raw.githubusercontent.com/paritytech/polkadot-sdk/master/cumulus/parachains/chain-specs/coretime-kusama.json) | Active |
| Westend      | [coretime-westend.json](https://raw.githubusercontent.com/paritytech/polkadot-sdk/master/cumulus/parachains/chain-specs/coretime-westend.json) | Active |
| Paseo        | N/A | Pending |

### Encointer
Repository link: [Encointer Parachain](https://github.com/encointer/encointer-parachain/tree/master/node/res)

| Network      | Chain Spec File URL | Status |
|--------------|---------------------|--------|
| Kusama       | [encointer-kusama.json](https://raw.githubusercontent.com/encointer/encointer-parachain/master/node/res/encointer-kusama.json) | Active |
