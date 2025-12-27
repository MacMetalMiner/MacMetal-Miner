# MacMetal Miner v1.0

**The First Native Metal GPU Bitcoin Miner for Apple Silicon**

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║   ███╗   ███╗ █████╗  ██████╗███╗   ███╗███████╗████████╗ █████╗ ██╗          ║
║   ████╗ ████║██╔══██╗██╔════╝████╗ ████║██╔════╝╚══██╔══╝██╔══██╗██║          ║
║   ██╔████╔██║███████║██║     ██╔████╔██║█████╗     ██║   ███████║██║          ║
║   ██║╚██╔╝██║██╔══██║██║     ██║╚██╔╝██║██╔══╝     ██║   ██╔══██║██║          ║
║   ██║ ╚═╝ ██║██║  ██║╚██████╗██║ ╚═╝ ██║███████╗   ██║   ██║  ██║███████╗     ║
║   ╚═╝     ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝     ╚═╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝     ║
║                                                                               ║
║                      ₿ Bitcoin Solo Mining for macOS                          ║
║                        Native Metal GPU Acceleration                          ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS-blue?style=flat-square&logo=apple" alt="Platform">
  <img src="https://img.shields.io/badge/GPU-Metal-orange?style=flat-square" alt="Metal">
  <img src="https://img.shields.io/badge/Chip-Apple%20Silicon-green?style=flat-square" alt="Apple Silicon">
  <img src="https://img.shields.io/badge/License-Source%20Available-red?style=flat-square" alt="License">
</p>

---

## Copyright Notice

**Copyright (c) 2025 David Otero / Distributed Ledger Technologies**  
Website: [www.distributedledgertechnologies.com](https://www.distributedledgertechnologies.com)

### Source-Available License

This source code is provided for **inspection and verification purposes only**.

**You MAY:**
- View and read the source code
- Verify the software is safe and doesn't steal your mining rewards
- Run the unmodified software for personal Bitcoin mining

**You MAY NOT:**
- Copy, reproduce, or duplicate this code
- Modify or create derivative works
- Distribute or share with others
- Use any portion in other projects
- Sell or commercially exploit

See [LICENSE](LICENSE) for complete terms.

---

## What Is This?

MacMetal Miner is a **native Swift + Metal GPU Bitcoin solo miner** designed specifically for Apple Silicon Macs (M1/M2/M3/M4). It leverages Apple's Metal compute shaders to perform SHA256d hashing directly on the GPU, achieving hashrates previously thought impossible on macOS.

**Warning:** This is a *lottery miner*. Solo mining Bitcoin with consumer hardware has astronomically low odds, but if you win, you get the entire block reward (~3.125 BTC).

## Features

- 🎮 **Native Metal GPU Acceleration** - True GPU compute shaders, not CPU mining
- 🍎 **Built for Apple Silicon** - Optimized for M1/M2/M3/M4 chips
- ⚡ **High Performance** - 350+ MH/s on M3 Pro (352x faster than Python!)
- 🔗 **Stratum Protocol** - Connects to solo.ckpool.org
- 🎨 **Beautiful Terminal UI** - Real-time stats with color-coded display
- 💾 **Persistent Stats** - Tracks cumulative shares across sessions

## Performance

| Mac Model | GPU Cores | Hashrate |
|-----------|-----------|----------|
| M4 Max    | 40        | ~800 MH/s |
| M3 Pro    | 14        | ~350 MH/s |
| M3 Max    | 30        | ~600 MH/s |
| M2 Pro    | 16        | ~280 MH/s |
| M1 Pro    | 14        | ~200 MH/s |
| M1        | 8         | ~120 MH/s |

### Comparison

| Method | Hashrate | Improvement |
|--------|----------|-------------|
| Python (threading) | 1 MH/s | Baseline |
| **MacMetal Miner** | **352 MH/s** | **352x faster** |

## Mining Odds

Let's be real about the math:

| Timeframe | Chance of Finding Block |
|-----------|------------------------|
| Per hour | 1 in 5.7 billion |
| Per day | 1 in 237 million |
| Per year | 1 in 650,000 |
| Per lifetime | 1 in 8,125 |

**But remember:** Someone with just 1 MH/s won a block worth $272,000 in December 2024. Every hash is a lottery ticket! 🎰

## Quick Start

### Prerequisites

- macOS 14.0 (Sonoma) or later
- Apple Silicon Mac (M1/M2/M3/M4) or Intel Mac with Metal GPU
- Xcode Command Line Tools

### Installation

```bash
# Clone the repository
git clone https://github.com/SystemThreat/MacMetal-Miner.git
cd MacMetal-Miner

# Build the miner
chmod +x build.sh
./build.sh

# Create miner directory and copy shader
mkdir -p ~/BTCMiner
cp SHA256.metal ~/BTCMiner/

# Run with your Bitcoin address
./BTCMiner YOUR_BITCOIN_ADDRESS
```

### Manual Build

```bash
# Install Xcode Command Line Tools (if not installed)
xcode-select --install

# Compile
swiftc -O -o BTCMiner main.swift -framework Metal -framework Foundation

# Run
./BTCMiner bc1qYourBitcoinAddressHere
```

## Usage

```bash
./BTCMiner <BITCOIN_ADDRESS>

# Example
./BTCMiner bc1q2xh89ghtpxya8hj34vulfvx3ckl6rf00umayjt
```

### Controls

- `Ctrl+C` - Stop mining and show session summary

## Why Source-Available?

This code represents **novel intellectual property** - the first working implementation of Metal GPU Bitcoin mining on macOS. We make the source visible so you can:

1. **Verify Safety** - Confirm we're not stealing your hashrate or rewards
2. **Audit the Code** - See exactly what the software does
3. **Build Trust** - Transparency without giving away our work

## GUI Version - MacMetal Miner Pro Max

Want more features?

- ✅ Auto-start on login
- ✅ Sleep prevention
- ✅ Connection monitoring with auto-retry
- ✅ Beautiful native macOS GUI
- ✅ Persistent settings
- ✅ Multiple pool selection
- ✅ Custom pool support

**Purchase:** [winnertakeall.gumroad.com/l/bitcoin](https://winnertakeall.gumroad.com/l/bitcoin)

---

## Technical Details

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      MacMetal Miner                         │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │   Stratum   │  │    Swift    │  │    Metal Shader     │ │
│  │   Client    │◄─┤    Host     │◄─┤   (SHA256d GPU)     │ │
│  │  (Network)  │  │  (Control)  │  │  (16M hashes/batch) │ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
│         │                │                    │             │
│         ▼                ▼                    ▼             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              solo.ckpool.org:3333                    │   │
│  │                 (Mining Pool)                        │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### The Mining Process

1. **Connect** to solo mining pool via Stratum protocol
2. **Receive** block template (previous hash, merkle branches, etc.)
3. **Build** 76-byte block header
4. **Dispatch** 16 million nonces to GPU in parallel
5. **Compute** double SHA256 on each header variation
6. **Check** if hash meets difficulty target
7. **Submit** valid shares to pool
8. **Repeat** with new nonces

### Metal Compute Shader

The GPU kernel (`SHA256.metal`) implements:

- Full SHA256 compression function
- Double SHA256 (SHA256d) for Bitcoin
- Parallel processing of millions of nonces
- Atomic counters for hash counting
- Share detection (32+ zero bits)

## Project Structure

```
MacMetal-Miner/
├── README.md           # This file
├── LICENSE             # Source-Available License
├── build.sh            # Build script
├── main.swift          # Swift host application
├── SHA256.metal        # Metal compute shader
└── technical.md        # Technical deep-dive
```

## Disclaimer

- **Not Financial Advice** - Solo mining is a lottery, not an investment
- **Electricity Costs** - Mining uses power; calculate your costs
- **Hardware Wear** - Extended GPU usage may increase wear
- **No Guarantees** - You may never find a block

---

**Copyright 2025 David Otero / Distributed Ledger Technologies**  
All Rights Reserved | [www.distributedledgertechnologies.com](https://www.distributedledgertechnologies.com)

*"The Times 03/Jan/2009 Chancellor on brink of second bailout for banks"*

₿ HODL! 💎🙌
