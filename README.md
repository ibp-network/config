# IBP Network Configuration Repository

## Overview
This repository serves as the central storage for configuration files crucial to
the operations of the IBP network's monitoring and alert systems. Each file is
essential for specific functionalities within our infrastructure, enabling
efficient management and monitoring of our network nodes.

## Repository Structure

```
IBP.network/
├── chain-spec/
│   ├── [chain-spec files]
│   └── README.md
├── logos/
│   └── [logo files]
├── bootnodes.json
├── members.json
├── services.json
└── external.json
```

## Key Components

### Chain Specifications (`chain-spec/`)
Contains the chain spec files for various blockchain networks, used by the
`ibp-monitor` to initialize nodes with no preconfigured bootnodes. This ensures
that our monitoring systems can independently verify node connectivity and
performance without predefined biases. It is crucial for participants to
regularly update these files to reflect the current state of their network nodes.
Details on how each file is used can be found in the [chain-spec README](chain-spec/README.md).

### Members and Services Configuration
- `members.json`: Contains detailed profiles for each network participant,
  including their service endpoints and monitoring URLs. This file is integral
  to the operation of our `ibp-monitor` and the `ibp-matrix-alerts-bot`.
- `services.json`: Defines the services provided by network members, including
  RPC endpoints required for network operations. Although not all sections are
  currently in use, they represent potential expansion points for monitoring
  capabilities.

### Bootnodes
- `bootnodes.json`: Acts as the source of truth for the bootnodes used within
  our network. 

### Utility Scripts
- `scripts/`: Includes utilities for maintaining the integrity and accuracy of
  our bootnode lists, critical for the automated recovery and setup processes
  in our monitoring systems.

## Contribution Guidelines
Members are expected to keep their information within `members.json`,
`bootnodes.json` and `services.json`  up-to-date. Monitoring and scoring systems
will be following these files. These files should always reflect the
`polkadot-sdk`.

### Updates and Maintenance
- **Chain Specs**: Update your chain spec files promptly, when changes occur in
  your network's configuration. [Chain-spec README](chain-spec/README.md) chain-
  specs for production nodes and `/chain-spec/*` for monitoring and testing purposes.
- **Member Information**: Regularly verify and update your service endpoints and
  node statuses to reflect your current operational status.
- **Services**: Ensure that your service endpoints are accurate and up-to-date.
  This is crucial for maintaining the integrity of our monitoring systems.
- **Bootnodes**: Submit changes to your bootnodes here always when submitting
  PR to the service repositories(`polkadot-sdk`).

