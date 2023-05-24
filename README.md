# IBP.network

This repo holds config files for various processes.

# Where used:

## chain-spec/*
- ibp-monitor - the files are used as empty bootnode specifications for `f-check-boot-node`.

## members.json
- ibp-monitor - the file is loaded periodically, and the datastore updated for each monitor instance.

## bootnodes.json
- ibp-monitor - we use this as the source of truth for our bootnodes

## services.json
- ibp-monitor - ??? not used (yet?)
