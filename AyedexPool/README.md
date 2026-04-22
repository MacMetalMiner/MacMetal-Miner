# Ayedex Pool (Nerd Edition) v2.0

Solo Bitcoin Mining Pool Server for Apple Silicon Macs

## Features

- **Difficulty Range 100-10000** - User-selectable difficulty (Bitaxe compatible)
- **Rainbow Bitaxe-Style Logging** - Colorful terminal output
- **Clean Stats Display** - Horizontal dividers only, no side borders
- **Full Stratum v1 Protocol** - Compatible with any Stratum miner
- **Variable Difficulty (Vardiff)** - Automatically adjusts to miner hashrate
- **Zero Fees** - You keep 100% of any block reward

## Requirements

- macOS with Swift compiler
- Bitcoin Core (fully synced, ~600GB disk space)
- Xcode Command Line Tools (`xcode-select --install`)

## Bitcoin Core Configuration

Add to `~/Library/Application Support/Bitcoin/bitcoin.conf`:

```ini
server=1
rpcuser=ayedex
rpcpassword=AyedexPool2026!
rpcallowip=127.0.0.1
rpcbind=127.0.0.1
```

**Important:** Restart Bitcoin Core after changing configuration.

## Build

```bash
chmod +x build.sh
./build.sh
```

Or manually:

```bash
swiftc -O -o AyedexPool AyedexPool.swift
```

## Usage

```bash
./AyedexPool <bitcoin_address> --rpc-user <user> --rpc-pass <pass>
```

Or simply:

```bash
./RUN_POOL.command
```

## Difficulty Selection

When the pool starts, you'll be prompted to select difficulty:

```
  100   = Very Easy   (~40 shares/sec at 350 MH/s)
  500   = Easy        (~8 shares/sec)
  1000  = Normal      (~4 shares/sec)
  2048  = Bitaxe      (~2 shares/sec)  ← Recommended
  5000  = Medium      (~0.8 shares/sec)
  10000 = Hard        (~0.4 shares/sec)
```

## Connecting Miners

### MacMetal CLI Miner

```bash
./macmetal bc1qYourAddress
# Select Option 1 (Ayedex Pool)
```

### Other Stratum Miners

```bash
miner -o stratum+tcp://127.0.0.1:3333 -u bc1qYourAddress.worker -p x
```

## License

Source Available License - (c) 2025 David Otero / Distributed Ledger Technologies
