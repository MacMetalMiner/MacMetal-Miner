# Changelog

All notable changes to MacMetal Miner.

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
