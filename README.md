# Mac Metal Miner

**GPU-accelerated SHA-256d miner for Apple Silicon with built-in wallet, ESP pool support, and ASIC proxy.**

Mac Metal Miner (MMM) mines NEX using Apple's Metal compute shaders, delivering multi-gigahash performance from a single Mac. It connects to NEX's EqualShare Pool (ESP) via Stratum V1 and includes an integrated wallet, CLI terminal, and LAN proxy for external ASIC hardware like Bitaxe.

---

## Features

- **Metal GPU Mining** -- SHA-256d compute kernel optimized for Apple Silicon
- **Built-in Wallet** -- Send, receive, and check balances via JSON-RPC to nexd
- **ESP Pool Integration** -- Tiered stake-to-mine with automatic tier detection
- **ASIC LAN Proxy** -- Bridge external miners (Bitaxe, etc.) through MMM to the pool
- **CLI Terminal** -- Run any nex-cli command directly from the app
- **Stratum V1** -- Full protocol support including mining.configure (version-rolling)
- **Real-time Monitoring** -- Hashrate, GPU power, temperature, and efficiency gauges
- **Mining Efficiency Slider** -- Throttle GPU usage from 1-100%
- **Auto-reconnect** -- Recovers from pool disconnects automatically
- **Sleep Prevention** -- Keeps Mac awake while mining
- **Session Logging** -- Logs to ~/Library/Logs/MacMetalMiner/

---

## Requirements

- macOS 14.0+ (Sonoma or later)
- Apple Silicon (M1 / M2 / M3 / M4)
- NEX pool connection (default: ESP pool on port 3333)

---

## Build

```bash
chmod +x BUILD.command
./BUILD.command
```

Produces `Mac Metal Miner.app` -- a standalone macOS application.

---

## ESP Pool Tiers

MMM integrates with NEX's EqualShare Pool. Stake NEX to unlock higher reward tiers:

| Tier | Stake | Reward Share |
|------|-------|-------------|
| Starter | 0 NEX | 5% |
| Nano | 10 NEX | 10% |
| Micro | 50 NEX | 15% |
| Standard | 100 NEX | 20% |
| Pro | 500 NEX | 25% |
| Ultra | 1,000 NEX | 25% |

Your current tier is shown in the Wallet tab. Stake and unstake directly from the app.

---

## ASIC Proxy

MMM can act as a LAN Stratum proxy for external mining hardware:

1. Enable LAN mode in the app
2. Note the displayed IP and port (e.g. `192.168.1.x:3334`)
3. Point your Bitaxe or other ASIC to that address
4. ASIC shares are submitted through your MMM session to the pool

The proxy handles mining.configure (version-rolling), job distribution, and difficulty forwarding.

---

## Performance (Approximate)

| Chip | Hashrate |
|------|----------|
| M1 | ~1.2 GH/s |
| M1 Pro/Max | ~2.5 - 4.0 GH/s |
| M2 | ~1.5 GH/s |
| M2 Pro/Max | ~3.0 - 5.0 GH/s |
| M3 | ~2.0 GH/s |
| M3 Pro/Max | ~4.0 - 6.0 GH/s |
| M4 | ~2.5 GH/s |
| M4 Pro/Max | ~5.0 - 7.0 GH/s |

---

## Block Reward

95 NEX per block. Reward is distributed through the ESP pool based on your tier and share contribution.

---

## Architecture

| File | Description |
|------|-------------|
| `MacMetalMinerProMax.swift` | Main application -- SwiftUI UI, Stratum client, wallet, ASIC proxy |
| `SHA256.metal` | Metal GPU compute kernel -- SHA-256d mining with parallel nonce search |
| `BUILD.command` | Build script -- compiles Swift + Metal into .app bundle |

---

## License

MIT
