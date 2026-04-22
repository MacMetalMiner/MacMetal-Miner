# Mac Metal Miner

**GPU-accelerated SHA-256d PPLNS miner for Apple Silicon with built-in wallet and ASIC proxy.**

Mac Metal Miner (MMM) mines NEX using Apple's Metal compute shaders, delivering multi-gigahash performance from a single Mac. It connects to the NEX PPLNS mining pools via Stratum V1 and includes an integrated wallet, CLI terminal, and LAN proxy for external ASIC hardware like Bitaxe. Payouts are shared proportionally by recent hashrate contribution — steady daily NEX instead of a years-long solo lottery.

---

## Features

- **Metal GPU Mining** -- SHA-256d compute kernel optimized for Apple Silicon
- **Built-in Wallet** -- Send, receive, and check balances via JSON-RPC to nexd
- **PPLNS Rewards** -- Your slice of every block scales with your hashrate contribution (weighted over last 500 shares)
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
- NEX pool connection (default: PPLNS pool on port 3333)

---

## Build

```bash
chmod +x BUILD.command
./BUILD.command
```

Produces `Mac Metal Miner.app` -- a standalone macOS application.

---

## PPLNS Mining

MMM connects via Stratum v1 to one of 4 regional NEX PPLNS pools (Virginia, California, Mumbai, São Paulo) on port `3333`. Every accepted share you submit goes into a rolling window of the last ~500 shares across all miners; when the pool finds a block, the 100 NEX reward is split proportionally across that window's contributors via a multi-vout coinbase. There are no pool fees — the full block subsidy is distributed to miners.

Why PPLNS rather than solo: at current network difficulty, a single Mac solo-mining against the 100 NEX reward would expect a block every ~90 days. PPLNS smooths that into steady daily NEX based on your hashrate share of the pool — meaningful for most Macs (50 MH/s – 1 GH/s depending on model).

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

100 NEX per block (Era 1, blocks 0-374,999). Halves every 375,000 blocks down to 1.5625 NEX in Era 7+. Mining ends at block 3,000,000. The full reward goes to the address you mine to.

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
