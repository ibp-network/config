# Bootnode health report

Probed **212** multiaddrs; **95** skipped (/tcp-only, not browser-reachable);
**105** reachable; **12** unreachable.

Dead entries have been removed from `bootnodes.json` by this run.

## Unreachable from WSS-101 probe

Grouped by chain and member. `reason` is the underlying error returned
by the WebSocket upgrade. Replace with current upstream addrs by running
`scripts/sync_bootnodes.py` after `paritytech/chainspecs` has refreshed,
or open a PR upstream with corrected addrs from the operator.

### asset-hub-paseo

- `amforc` — timeout after 6.0s
  - `/dns/asset-hub-paseo.bootnode.amforc.com/tcp/30333/wss/p2p/12D3KooWERfFUg8UFPCakzTFkktdRYeG2cD3A9ga1DfynbPdYqGL`
- `stakeplus` — timeout after 6.0s
  - `/dns/boot.stake.plus/tcp/44333/wss/p2p/12D3KooWSaDfEuvzA8xFyPvDaptCJn2WYUz1f1QFtTiwk4MpnHVo`

### asset-hub-polkadot

- `stakeplus` — HTTP 503
  - `/dns/asset-hub-polkadot.boot.stake.plus/tcp/30332/wss/p2p/12D3KooWJzTrFcc11AZKTMUmmLr5XLJ9qKVupZXkwHUMx4ULbwm2`

### bridge-hub-polkadot

- `stakeplus` — HTTP 503
  - `/dns/bridge-hub-polkadot.boot.stake.plus/tcp/30332/wss/p2p/12D3KooWGqVn69EWriuszxcuBVMgTtpKUHYcULEiuLiqkC3kf35F`

### encointer-kusama

- `amforc` — timeout after 6.0s
  - `/dns/encointer-kusama.bootnode.amforc.com/tcp/30333/wss/p2p/12D3KooWDBr4sfp9R7t7tA1LAkNzADcGVXW9rX1BryES47mhUMEz`
- `stakeplus` — timeout after 6.0s
  - `/dns/boot.stake.plus/tcp/36334/wss/p2p/12D3KooWNFFdJFV21haDiSdPJ1EnGmv6pa2TgB81Cvu7Y96hjTAu`

### hydration

- `dwellir` — TLS: [SSL: CERTIFICATE_VERIFY_FAILED] certificate verify failed: Hostname mismatch, certificate is not valid for 'hydration-boot-ng.dwellir.com'. (_ssl.c:1081)
  - `/dns/hydration-boot-ng.dwellir.com/tcp/443/wss/p2p/12D3KooWMNf1YGh3rxaiWPjzQ1UKQxKq2WSjAKdrSgdcYaFH4ie5`
- `radiumblock` — TLS: [SSL: CERTIFICATE_VERIFY_FAILED] certificate verify failed: certificate has expired (_ssl.c:1081)
  - `/dns/hydration-bootnode.radiumblock.com/tcp/30336/wss/p2p/12D3KooWCtrMH4H2p5XkGHkU7K4CcbSmErouNuN3j7Bysj4a8hJX`

### kusama

- `stakeplus` — HTTP 503
  - `/dns/kusama.boot.stake.plus/tcp/31334/wss/p2p/12D3KooWANYqS81DkERRrBW1swoMgqUHK69pJN8XjQCnS6dnUAps`

### paseo

- `stakeplus` — timeout after 6.0s
  - `/dns/boot.stake.plus/tcp/43334/wss/p2p/12D3KooWNhgAC3hjZHxaT52EpPFZohkCL1AHFAijqcN8xB9Rwud2`

### people-polkadot

- `dwellir` — timeout after 6.0s
  - `/dns/people-polkadot-boot-ng.dwellir.com/tcp/30333/wss/p2p/12D3KooWLVCw68epXsdXhMH1sDhrwkxi5DGZ5J77dCoCBd2HFafq`

### polkadot

- `radiumblock` — timeout after 6.0s
  - `/dns/polkadot-bootnode.radiumblock.com/tcp/30335/wss/p2p/12D3KooWNwWNRrPrTk4qMah1YszudMjxNw2qag7Kunhw3Ghs9ea5`

