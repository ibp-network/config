# Bootnode coverage matrix

`7` active members × `18` chains = `126` cells expected.

Legend: `✓✓` /tcp + /wss · `ws` /wss only · `tcp` /tcp only · `–` nothing

| chain | amforc | dwellir | gatotech | radiumblock | rotko | stakeplus | turboflakes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| asset-hub-kusama | ✓✓ | ✓✓ | ✓✓ | ✓✓ | ✓✓ | ws | ✓✓ |
| asset-hub-paseo | tcp | ✓✓ | ✓✓ | ✓✓ | ✓✓ | tcp | ✓✓ |
| asset-hub-polkadot | ✓✓ | ✓✓ | ✓✓ | ✓✓ | ✓✓ | ws | ✓✓ |
| bridge-hub-kusama | ✓✓ | ✓✓ | ✓✓ | ✓✓ | ✓✓ | ws | ✓✓ |
| bridge-hub-paseo | ✓✓ | – | ✓✓ | – | ✓✓ | – | ✓✓ |
| bridge-hub-polkadot | ✓✓ | ✓✓ | ✓✓ | ✓✓ | ✓✓ | ws | ✓✓ |
| collectives-polkadot | ✓✓ | ✓✓ | ✓✓ | ✓✓ | ✓✓ | ws | ✓✓ |
| coretime-kusama | ✓✓ | ✓✓ | ✓✓ | ✓✓ | ✓✓ | ws | ✓✓ |
| coretime-paseo | ✓✓ | – | ✓✓ | ✓✓ | ✓✓ | – | ✓✓ |
| coretime-polkadot | – | – | ✓✓ | – | ✓✓ | ws | – |
| encointer-kusama | tcp | tcp | ✓✓ | ✓✓ | ✓✓ | tcp | ✓✓ |
| hydration | – | tcp | – | tcp | – | ws | – |
| kusama | ✓✓ | ✓✓ | ✓✓ | ✓✓ | ✓✓ | ws | ✓✓ |
| paseo | ✓✓ | ✓✓ | ✓✓ | – | ✓✓ | tcp | ✓✓ |
| people-kusama | ✓✓ | ✓✓ | ✓✓ | ✓✓ | ✓✓ | ws | ✓✓ |
| people-paseo | – | ✓✓ | ✓✓ | – | ✓✓ | ws | ✓✓ |
| people-polkadot | – | tcp | ✓✓ | – | ✓✓ | – | – |
| polkadot | ✓✓ | ✓✓ | ✓✓ | tcp | ✓✓ | ws | ✓✓ |

## Summary

- ✓✓ both transports: **84**
- ws only: **12**
- tcp only: **10** (not smoldot-reachable)
- missing: **20**

## Per-member gaps

### Amforc (`amforc`)

**Missing entirely (4):** coretime-polkadot, hydration, people-paseo, people-polkadot

**/tcp only, no smoldot path (2):** asset-hub-paseo, encointer-kusama

### Dwellir (`dwellir`)

**Missing entirely (3):** bridge-hub-paseo, coretime-paseo, coretime-polkadot

**/tcp only, no smoldot path (3):** encointer-kusama, hydration, people-polkadot

### Gatotech (`gatotech`)

**Missing entirely (1):** hydration

### RadiumBlock (`radiumblock`)

**Missing entirely (5):** bridge-hub-paseo, coretime-polkadot, paseo, people-paseo, people-polkadot

**/tcp only, no smoldot path (2):** hydration, polkadot

### Rotko Networks (`rotko`)

**Missing entirely (1):** hydration

### Stake Plus (`stakeplus`)

**Missing entirely (3):** bridge-hub-paseo, coretime-paseo, people-polkadot

**/tcp only, no smoldot path (3):** asset-hub-paseo, encointer-kusama, paseo

**/wss only, no CLI fallback (12):** asset-hub-kusama, asset-hub-polkadot, bridge-hub-kusama, bridge-hub-polkadot, collectives-polkadot, coretime-kusama, coretime-polkadot, hydration, kusama, people-kusama, people-paseo, polkadot

### Turboflakes (`turboflakes`)

**Missing entirely (3):** coretime-polkadot, hydration, people-polkadot

## Per-chain gaps

### asset-hub-kusama

- /wss only (no CLI fallback): stakeplus

### asset-hub-paseo

- /tcp only (no smoldot): amforc, stakeplus

### asset-hub-polkadot

- /wss only (no CLI fallback): stakeplus

### bridge-hub-kusama

- /wss only (no CLI fallback): stakeplus

### bridge-hub-paseo

- missing: dwellir, radiumblock, stakeplus

### bridge-hub-polkadot

- /wss only (no CLI fallback): stakeplus

### collectives-polkadot

- /wss only (no CLI fallback): stakeplus

### coretime-kusama

- /wss only (no CLI fallback): stakeplus

### coretime-paseo

- missing: dwellir, stakeplus

### coretime-polkadot

- missing: amforc, dwellir, radiumblock, turboflakes
- /wss only (no CLI fallback): stakeplus

### encointer-kusama

- /tcp only (no smoldot): amforc, dwellir, stakeplus

### hydration

- missing: amforc, gatotech, rotko, turboflakes
- /tcp only (no smoldot): dwellir, radiumblock
- /wss only (no CLI fallback): stakeplus

### kusama

- /wss only (no CLI fallback): stakeplus

### paseo

- missing: radiumblock
- /tcp only (no smoldot): stakeplus

### people-kusama

- /wss only (no CLI fallback): stakeplus

### people-paseo

- missing: amforc, radiumblock
- /wss only (no CLI fallback): stakeplus

### people-polkadot

- missing: amforc, radiumblock, stakeplus, turboflakes
- /tcp only (no smoldot): dwellir

### polkadot

- /tcp only (no smoldot): radiumblock
- /wss only (no CLI fallback): stakeplus

