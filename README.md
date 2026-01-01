# MacMetal Miner

Native Metal GPU Bitcoin Solo Miner for Apple Silicon Macs - 350+ MH/s

![Version](https://img.shields.io/badge/version-2.1-green)
![Platform](https://img.shields.io/badge/platform-macOS-blue)
![Architecture](https://img.shields.io/badge/arch-Apple%20Silicon-orange)

## Overview

MacMetal Miner is a high-performance Bitcoin mining application that leverages Apple's Metal GPU framework to achieve maximum hashrate on Apple Silicon Macs. The CLI miner includes a built-in test suite that mathematically proves correct SHA256d computation using real Bitcoin block data.

## Features

- **Metal GPU Acceleration** - Full Apple Silicon GPU utilization
- **350+ MH/s** on M3 Pro (varies by chip)
- **Verified Correct** - Built-in test mode proves SHA256d accuracy
- **Solo Mining** - Mine directly to your wallet
- **Stratum Protocol** - Compatible with any Stratum v1 pool
- **Ayedex Pool** - Included solo mining pool server

## Verified Working

The miner includes a `--test` flag that proves correctness using Bitcoin Block #125552:

```
[TEST 2] GPU Mining - Find Known Nonce
   → Nonce: 0x9546a142 (2504433986) - 67 bits
   [PASS] ✓ GPU found correct nonce!
   Verified hash: 00000000000000001e8d6829a8a21adc5d38d0a473b144b6765798e61f98bd1d

   ╔═══════════════════════════════════════════════════════════════════╗
   ║  ✅ ALL TESTS PASSED - GPU MINER VERIFIED WORKING                 ║
   ╚═══════════════════════════════════════════════════════════════════╝
```

## Quick Start

### Build

```bash
./build.sh
```

Or manually:

```bash
swiftc -O -o MacMetalCLI main.swift -framework Metal -framework CoreGraphics
```

### Verify Installation

```bash
./MacMetalCLI --test
```

### Run (Connect to Pool)

```bash
./MacMetalCLI <bitcoin_address> --pool <host:port>
```

## Usage Examples

```bash
# Run verification tests
./MacMetalCLI --test

# Connect to public pool
./MacMetalCLI bc1qYourAddress --pool public-pool.io:21496

# Connect to local Ayedex Pool
./MacMetalCLI bc1qYourAddress --pool 127.0.0.1:3333

# With custom worker name
./MacMetalCLI bc1qYourAddress --pool solo.ckpool.org:3333 --worker myrig
```

## Solo Mining with Ayedex Pool

For true solo mining with zero fees, use the included Ayedex Pool server.

### 1. Configure Bitcoin Core

Add to `~/Library/Application Support/Bitcoin/bitcoin.conf`:

```ini
# RPC Settings
rpcuser=ayedex
rpcpassword=YourSecurePassword
rpcallowip=127.0.0.1
rpcbind=127.0.0.1
server=1

# Optional: Reduce memory usage
dbcache=450
maxmempool=300
```

Restart Bitcoin Core after changes.

### 2. Build and Run the Pool

```bash
cd AyedexPool
./build.sh
./AyedexPool bc1qYourAddress \
    --rpc-user ayedex \
    --rpc-pass 'YourSecurePassword' \
    --start-diff 0.001
```

### 3. Connect the Miner

```bash
./MacMetalCLI bc1qYourAddress --pool 127.0.0.1:3333
```

## Architecture

```
┌──────────────────────────────────────────────────────────────────────────┐
│                     MacMetal CLI Miner v2.1                              │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │  Metal Compute Shader                                              │  │
│  │  ├── SHA256d (double SHA256) implementation                        │  │
│  │  ├── 16 million hashes per GPU batch                               │  │
│  │  └── Parallel nonce testing across GPU cores                       │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │  Stratum v1 Client                                                 │  │
│  │  ├── mining.subscribe / mining.authorize                           │  │
│  │  ├── mining.notify (job reception)                                 │  │
│  │  └── mining.submit (share submission)                              │  │
│  └────────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼ Stratum Protocol (TCP)
┌──────────────────────────────────────────────────────────────────────────┐
│                  Ayedex Pool (Nerd Edition) v1.1                         │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │  Stratum Server (:3333)                                            │  │
│  │  ├── Variable difficulty (vardiff)                                 │  │
│  │  ├── Multiple worker support                                       │  │
│  │  └── Real-time statistics                                          │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │  Bitcoin Core RPC Client                                           │  │
│  │  ├── getblocktemplate (fetch new work)                             │  │
│  │  └── submitblock (broadcast found blocks)                          │  │
│  └────────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼ JSON-RPC
┌──────────────────────────────────────────────────────────────────────────┐
│                         Bitcoin Core                                     │
│                    └── Mainnet (fully synced)                            │
└──────────────────────────────────────────────────────────────────────────┘
```

## Performance

| Chip | Expected Hashrate |
|------|-------------------|
| M1 | ~200-250 MH/s |
| M1 Pro | ~280-300 MH/s |
| M1 Max | ~350-400 MH/s |
| M2 | ~220-280 MH/s |
| M2 Pro | ~300-330 MH/s |
| M2 Max | ~380-420 MH/s |
| M3 | ~250-300 MH/s |
| M3 Pro | ~320-360 MH/s |
| M3 Max | ~400-450 MH/s |

*Actual performance varies based on thermal conditions and system load.*

## Requirements

- macOS 12.0+ (Monterey or later)
- Apple Silicon Mac (M1/M2/M3 series)
- Xcode Command Line Tools (`xcode-select --install`)
- Bitcoin Core (for solo mining with Ayedex Pool)

## Test Mode Details

The `--test` flag runs three verification tests:

### Test 1: CPU SHA256d Verification
Computes the hash of Bitcoin Block #125552 using CPU and verifies against the known hash.

### Test 2: GPU Mining Verification
Uses the GPU to search for the winning nonce of Block #125552. Finding the exact nonce proves the GPU SHA256d implementation is mathematically correct.

### Test 3: Hashrate Benchmark
Runs three batches of 16 million hashes each to measure GPU performance.

## File Structure

```
MacMetal-Miner/
├── main.swift              # CLI Miner source code
├── build.sh                # Build script
├── README.md               # This file
├── technical.md            # Technical documentation
├── LICENSE                 # Source Available License
└── AyedexPool/
    ├── AyedexPool.swift    # Pool server source code
    ├── build.sh            # Pool build script
    └── README.md           # Pool documentation
```

## Troubleshooting

### "No Metal device found"
Your Mac doesn't have a compatible GPU. Apple Silicon is required.

### "Connect failed"
- Ensure the pool is running and accessible
- Check firewall settings
- Verify the host:port is correct

### Low hashrate
- Close other GPU-intensive applications
- Ensure Mac is plugged in (not on battery)
- Check Activity Monitor for thermal throttling

### Shares rejected
- Verify your Bitcoin address is correct
- Check pool difficulty settings
- Ensure system clock is synchronized

## License

Source Available License - (c) 2025 David Otero / Distributed Ledger Technologies

This software is provided for inspection and personal use only. See [LICENSE](LICENSE) for full terms.

**Commercial use:** [Purchase GUI version](https://winnertakeall.gumroad.com/l/bitcoin)

**Contact:** david@knexmail.com

## Disclaimer

Solo Bitcoin mining with consumer hardware is extremely unlikely to find a block due to the enormous network difficulty. At current difficulty (~148T), a single Mac mining at 350 MH/s has approximately a 1 in 13 trillion chance of finding a block per day. This software is provided for educational, entertainment, and lottery-like purposes. Mine responsibly.

## Links

- Website: [www.distributedledgertechnologies.com](https://www.distributedledgertechnologies.com)
- GUI Version: [Purchase on Gumroad](https://winnertakeall.gumroad.com/l/bitcoin)
- Support: david@knexmail.com
