# Changelog

All notable changes to MacMetal Miner.

## [10.1.0] - 2026-04-22

### Changed
- **Pool reward model switched to PPLNS.** Your slice of every block now scales with your
  fraction of pool hashrate, weighted over the last 500 shares. Solo is still available
  on the backend (port 7777) but is not exposed in MMM — the mass-adoption UX is PPLNS.
- **Pool picker narrowed to 4 NEX regional endpoints** (Virginia, California, Mumbai,
  São Paulo). All on port 3333. Removed: `nexLocal`, `nexTestnet`, `publicPool`, `ckpool`,
  `custom`.
- **Labels throughout**: "Solo" / "100% of rewards" → "PPLNS" / "shared rewards".
- **Host / Port fields**: now read-only display auto-populated from the selected region.
  Previously editable text fields tied to the removed `.custom` pool case.

### Removed
- Custom pool UI (host / port / password text fields)
- `customFee`, `customPassword` state + UserDefaults persistence
- `.custom` enum branch in the mining-setup path
- Back-compat kept for `customHost` / `customPort` / `customPoolName` UserDefaults keys
  (now storing the resolved preset values, not user input)

### Distribution
- Available via Gumroad as a pre-built signed app ($3, free trial):
  https://winnertakeall.gumroad.com/l/knexcoin
- Free route remains: clone + `BUILD.command` from source (requires Xcode CLI tools).

## [10.0.0] - 2026-04-05

### Changed
- **Solo mining** — all pool options now pay 100% of block rewards directly to the miner's address
- **NEX Mainnet pool** IP updated to 98.80.98.17 (NEX PQ mainnet launch, genesis 2026-04-01)
- **Pool label** "NEX Mainnet Pool (1% fee)" → "NEX Mainnet Solo (0% fee)"
- **Stats URL** pool.ayedex.com → untraceablex.com

### Removed
- ESP (Equal Sharing Pool) staking UI — was experimental, not launching with NEX PQ
- ESP tier selector, stake/unstake buttons, current-tier badge
- All ESP-branded labels in mining info sheets

## [2.1] - 2025-01-01

### Added
- **Test Mode** (`--test` flag) - Verifies SHA256d correctness using Bitcoin Block #125552
- **Ayedex Pool** - Solo mining pool server with full Stratum v1 support
- **GPU Hashrate Benchmark** - Three-batch benchmark in test mode
- **Technical Documentation** - Comprehensive technical.md

### Fixed
- GPU result buffer stride calculation (was reading wrong memory offsets)
- Best zeros overflow display bug

### Changed
- Improved error handling for network connections
- Better statistics display formatting

## [2.0] - 2024-12-29

### Added
- **Metal GPU Acceleration** - Full Apple Silicon GPU support
- **Stratum v1 Protocol** - Connect to any mining pool
- **Non-blocking I/O** - Responsive network handling
- **Real-time Statistics** - Hashrate, shares, difficulty display

### Changed
- Complete rewrite from CPU to GPU mining
- Inline Metal shader (no external .metal file required)

## [1.0] - 2024-12-27

### Added
- Initial CLI miner release
- CPU-based SHA256d mining
- Basic Stratum protocol support
- Pool connection wizard

---

## Ayedex Pool

### [1.1] - 2025-01-01

### Added
- Variable difficulty (vardiff) support
- Multiple worker connections
- Real-time statistics display
- Automatic block template refresh

### Fixed
- Share validation simplified for solo mining
- Memory leak in client connection handling

### [1.0] - 2024-12-31

### Added
- Initial pool server release
- Bitcoin Core JSON-RPC integration
- Stratum v1 server implementation
- Coinbase transaction building
