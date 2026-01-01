# MacMetal Miner

Native Metal GPU Bitcoin Solo Miner for Apple Silicon Macs - 350+ MH/s

## Features

- **Metal GPU Acceleration** - Full Apple Silicon GPU utilization
- **350+ MH/s** on M3 Pro (varies by chip)
- **Solo Mining** - Mine directly to your wallet
- **Stratum Protocol** - Compatible with any Stratum v1 pool
- **Ayedex Pool** - Included solo mining pool server

## Quick Start

### Build

```bash
./build.sh
```

### Run (Connect to Pool)

```bash
./MacMetalCLI <bitcoin_address> --pool <host:port>
```

### Examples

```bash
# Connect to public pool
./MacMetalCLI bc1q... --pool public-pool.io:21496

# Connect to local Ayedex Pool
./MacMetalCLI bc1q... --pool 127.0.0.1:3333
```

## Solo Mining with Ayedex Pool

For true solo mining with zero fees, use the included Ayedex Pool:

1. **Configure Bitcoin Core** (`~/Library/Application Support/Bitcoin/bitcoin.conf`):
```
rpcuser=ayedex
rpcpassword=AyedexPool2025!
rpcallowip=127.0.0.1
rpcbind=127.0.0.1
server=1
```

2. **Build and run the pool:**
```bash
cd AyedexPool
./build.sh
./AyedexPool bc1q... --rpc-user ayedex --rpc-pass 'AyedexPool2025!' --start-diff 0.001
```

3. **Connect the miner:**
```bash
./MacMetalCLI bc1q... --pool 127.0.0.1:3333
```

## Architecture

```
┌──────────────────────────────────────┐
│  MacMetal CLI Miner v2.1             │
│  ├── Metal SHA256d GPU Shader        │
│  ├── 16M hashes per batch            │
│  └── Stratum v1 client               │
└──────────────────────────────────────┘
                │
                ▼
┌──────────────────────────────────────┐
│  Ayedex Pool (Nerd Edition) v1.1     │
│  ├── Stratum server (:3333)          │
│  ├── Variable difficulty             │
│  └── Bitcoin Core RPC client         │
└──────────────────────────────────────┘
                │
                ▼
┌──────────────────────────────────────┐
│  Bitcoin Core                        │
│  └── Mainnet (fully synced)          │
└──────────────────────────────────────┘
```

## Requirements

- macOS 12+ (Monterey or later)
- Apple Silicon Mac (M1/M2/M3)
- Xcode Command Line Tools (`xcode-select --install`)
- Bitcoin Core (for solo mining with Ayedex Pool)

## Performance

| Chip | Hashrate |
|------|----------|
| M1 | ~250 MH/s |
| M1 Pro | ~300 MH/s |
| M2 | ~280 MH/s |
| M2 Pro | ~320 MH/s |
| M3 | ~300 MH/s |
| M3 Pro | ~350 MH/s |
| M3 Max | ~400+ MH/s |

## License

Source Available License - (c) 2025 David Otero / Distributed Ledger Technologies

This software is provided for inspection and personal use only. See [LICENSE](LICENSE) for full terms.

**Commercial use:** [Purchase GUI version](https://winnertakeall.gumroad.com/l/bitcoin)

**Contact:** david@knexmail.com

## Disclaimer

Solo Bitcoin mining with consumer hardware is extremely unlikely to find a block. This software is provided for educational and entertainment purposes. Mine responsibly.
