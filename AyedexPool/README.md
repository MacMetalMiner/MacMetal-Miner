# Ayedex Pool (Nerd Edition) v1.1

Solo Bitcoin Mining Pool Server for Apple Silicon Macs

## Overview

Ayedex Pool is a lightweight Stratum v1 mining pool server that connects to Bitcoin Core via JSON-RPC. It enables true solo mining with zero fees - if you find a block, you keep the entire reward.

## Features

- **Full Stratum v1 Protocol** - Compatible with any Stratum miner
- **Variable Difficulty (Vardiff)** - Automatically adjusts to miner hashrate
- **Multiple Workers** - Support for multiple connected miners
- **Real-time Statistics** - Live hashrate, shares, and network info
- **Zero Fees** - You keep 100% of any block reward
- **Block Template Caching** - Efficient Bitcoin Core interaction

## Requirements

- macOS with Swift compiler
- Bitcoin Core (fully synced, ~600GB disk space)
- Xcode Command Line Tools (`xcode-select --install`)

## Bitcoin Core Configuration

Add to `~/Library/Application Support/Bitcoin/bitcoin.conf`:

```ini
# Server mode (required)
server=1

# RPC credentials
rpcuser=ayedex
rpcpassword=YourSecurePasswordHere

# RPC binding
rpcallowip=127.0.0.1
rpcbind=127.0.0.1

# Optional performance settings
dbcache=450
maxmempool=300
```

**Important:** Restart Bitcoin Core after changing configuration.

## Build

```bash
./build.sh
```

Or manually:

```bash
swiftc -O -o AyedexPool AyedexPool.swift
```

## Usage

```bash
./AyedexPool <bitcoin_address> [options]
```

### Options

| Option | Default | Description |
|--------|---------|-------------|
| `--port <port>` | 3333 | Stratum server port |
| `--rpc-host <host>` | 127.0.0.1 | Bitcoin Core RPC host |
| `--rpc-port <port>` | 8332 | Bitcoin Core RPC port |
| `--rpc-user <user>` | (required) | Bitcoin Core RPC username |
| `--rpc-pass <pass>` | (required) | Bitcoin Core RPC password |
| `--start-diff <diff>` | 1.0 | Starting difficulty for new miners |
| `--min-diff <diff>` | 0.0001 | Minimum allowed difficulty |

### Example

```bash
./AyedexPool bc1q2xh89ghtpxya8hj34vulfvx3ckl6rf00umayjt \
    --rpc-user ayedex \
    --rpc-pass 'YourSecurePasswordHere' \
    --start-diff 0.001 \
    --min-diff 0.0001
```

## Connecting Miners

### MacMetal CLI Miner

```bash
./MacMetalCLI bc1qYourAddress --pool 127.0.0.1:3333
```

### MacMetal Pro Max (GUI)

1. Open Settings
2. Select "Custom Pool (Advanced)"
3. Enter Server: `127.0.0.1`
4. Enter Port: `3333`
5. Click "Start Mining"

### Other Stratum Miners

Any Stratum v1 compatible miner can connect:

```bash
# Generic example
miner -o stratum+tcp://127.0.0.1:3333 -u bc1qYourAddress.worker -p x
```

## Display

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║     █████╗ ██╗   ██╗███████╗██████╗ ███████╗██╗  ██╗                        ║
║    ██╔══██╗╚██╗ ██╔╝██╔════╝██╔══██╗██╔════╝╚██╗██╔╝                        ║
║    ███████║ ╚████╔╝ █████╗  ██║  ██║█████╗   ╚███╔╝                         ║
║    ██╔══██║  ╚██╔╝  ██╔══╝  ██║  ██║██╔══╝   ██╔██╗                         ║
║    ██║  ██║   ██║   ███████╗██████╔╝███████╗██╔╝ ██╗                        ║
║    ╚═╝  ╚═╝   ╚═╝   ╚══════╝╚═════╝ ╚══════╝╚═╝  ╚═╝                        ║
║                                                                              ║
║                    P O O L  (Nerd Edition) v1.1                              ║
║                      Solo Bitcoin Mining Pool                                ║
╚══════════════════════════════════════════════════════════════════════════════╝

                          AYEDEX POOL - NERD STATS                          

┌─ POOL STATUS ─────────────────────────────────────────────────────────────┐
│    Uptime:             00:05:32                                           │
│    Workers Connected:  1                                                  │
│    Pool Hashrate:      354.28 MH/s                                        │
│    Shares/sec:         42.3                                               │
└───────────────────────────────────────────────────────────────────────────┘

┌─ SHARE STATISTICS ────────────────────────────────────────────────────────┐
│    Submitted:          12847                                              │
│    Accepted:           12847                                              │
│    Rejected:           0                                                  │
│    Accept Rate:        100.0%                                             │
└───────────────────────────────────────────────────────────────────────────┘

┌─ NETWORK ─────────────────────────────────────────────────────────────────┐
│    Block Height:       930410                                             │
│    Network Diff:       148.26T                                            │
│    Blocks Found:       0                                                  │
│    Jobs Sent:          847                                                │
└───────────────────────────────────────────────────────────────────────────┘
```

## Architecture

```
┌─────────────────────┐
│  Miner 1 (350 MH/s) │──┐
└─────────────────────┘  │
┌─────────────────────┐  │     ┌─────────────────┐     ┌──────────────┐
│  Miner 2 (350 MH/s) │──┼────>│  Ayedex Pool    │────>│ Bitcoin Core │
└─────────────────────┘  │     │  (port 3333)    │     │  (port 8332) │
┌─────────────────────┐  │     └─────────────────┘     └──────────────┘
│  Miner 3 (350 MH/s) │──┘           │                       │
└─────────────────────┘              │                       │
                                     ▼                       ▼
                              Stratum Protocol        JSON-RPC
                              (mining.notify)         (getblocktemplate)
                              (mining.submit)         (submitblock)
```

## How It Works

1. **Pool starts** and connects to Bitcoin Core
2. **Fetches block template** via `getblocktemplate` RPC
3. **Miner connects** and subscribes via Stratum
4. **Pool sends job** with block header data
5. **Miner hashes** and submits shares
6. **Pool accepts shares** that meet difficulty target
7. **If share is a block** (meets network difficulty):
   - Pool calls `submitblock` to Bitcoin Core
   - Block propagates to network
   - **You win the entire block reward!**

## Difficulty Settings

For a 350 MH/s miner:

| Start Diff | Shares/sec | Recommended For |
|------------|------------|-----------------|
| 0.0001 | ~40/sec | Testing |
| 0.001 | ~4/sec | Normal operation |
| 0.01 | ~0.4/sec | Low bandwidth |
| 0.1 | ~0.04/sec | Multiple miners |

The pool automatically adjusts difficulty (vardiff) based on share submission rate.

## Troubleshooting

### "Failed to connect to Bitcoin Core"

1. Ensure Bitcoin Core is running
2. Check RPC credentials match bitcoin.conf
3. Verify Bitcoin Core is fully synced
4. Check firewall allows localhost connections

### "getblocktemplate failed"

Bitcoin Core must be fully synced. Check sync progress:

```bash
bitcoin-cli getblockchaininfo | grep verificationprogress
```

Should show `1.0` when fully synced.

### No miners connecting

1. Check pool is listening: `lsof -i :3333`
2. Verify miner is pointing to correct host:port
3. Check for firewall blocking connections

### High rejection rate

- Lower the starting difficulty
- Check miner clock is synchronized
- Verify Bitcoin address is valid

## Block Reward

If you find a block, you receive:

- **Block subsidy**: 3.125 BTC (as of 2024 halving)
- **Transaction fees**: Variable (typically 0.1-1 BTC)

**Current block reward: ~3.25-4 BTC (~$300,000+)**

## Probability

At 350 MH/s vs network difficulty 148T:

- Chance per hash: 1 in 148,000,000,000,000
- Hashes per day: ~30 trillion
- Blocks per day (expected): 0.0002
- Expected time to find block: ~13,700 years

*Solo mining is a lottery. Play responsibly.*

## License

Source Available License - (c) 2025 David Otero / Distributed Ledger Technologies

See [LICENSE](../LICENSE) for full terms.
