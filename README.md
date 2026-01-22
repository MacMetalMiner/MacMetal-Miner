# MacMetal CLI Miner v2.2

Native Metal GPU Bitcoin miner for Apple Silicon Macs - Command Line Edition.

## Features

- 🖥️ **Native Metal GPU** - Custom compute shaders for Apple Silicon
- 🌐 **Universal Pool Support** - Works with Ayedex Pool AND standard pools
- 📊 **Live Leaderboard** - Your miner appears on [macmetalminer.com](https://macmetalminer.com)
- 🔔 **Discord Notifications** - Block wins are announced automatically
- ⚡ **500 MH/s to 3+ GH/s** - Scales with your Mac's GPU cores

## Quick Start

```bash
# Build
chmod +x BUILD.command
./BUILD.command

# Run with interactive pool selection
./MacMetalCLI bc1qYourBitcoinAddress

# Or specify pool directly
./MacMetalCLI bc1qYourBitcoinAddress --ayedex           # Local Ayedex Pool
./MacMetalCLI bc1qYourBitcoinAddress --pool europe.solomining.io:7777  # Public Pool
```

## Pool Compatibility

| Pool | Command | Fee | Notes |
|------|---------|-----|-------|
| **Ayedex Pool** | `--ayedex` | 0% | Your local pool instance |
| **Public Pool** | `--pool public-pool.io:21496` | 0% | Open source community pool |
| **Solo CKPool** | `--pool solo.ckpool.org:3333` | 2% | Most popular, by cgminer creator |

## Command Line Options

```
USAGE:
    MacMetalCLI <bitcoin_address> [options]

OPTIONS:
    --pool <host:port>   Connect directly to specified pool
    --ayedex             Use Ayedex Pool (local, 127.0.0.1:3333)
    --worker <name>      Set worker name (default: cli)
    --debug              Enable debug logging
    --test               Run GPU verification tests
    --help               Show help message
```

## Leaderboard Integration

Your miner automatically registers with macmetalminer.com:
- Appears on the live leaderboard
- Tracks your hashrate and uptime
- Discord notifications for significant events

Visit: https://macmetalminer.com/leaderboard.html

## Technical Details

### Byte Order Handling

The miner handles two different stratum implementations:

**Standard Pools (CKPool, Public Pool, etc.):**
- Merkle branches sent in big-endian (display order)
- Branches used directly in merkle calculation

**Ayedex Pool:**
- Merkle branches pre-reversed to little-endian
- Miner reverses them back before calculation

This is handled automatically based on pool selection.

### Performance

| Mac Model | Expected Hashrate |
|-----------|-------------------|
| MacBook Air M1 | ~400-500 MH/s |
| MacBook Air M2 | ~500-600 MH/s |
| MacBook Pro M3 Max | ~2.2 GH/s |
| Mac Studio M2 Ultra | ~3-3.5 GH/s |

## Verification

Run the test suite to verify your GPU is working correctly:

```bash
./MacMetalCLI --test
```

This tests:
1. CPU SHA256d correctness
2. GPU nonce finding (Bitcoin Block #125552)
3. GPU hashrate benchmark

## License

Source Available License - See LICENSE for terms.
Commercial licensing: david@knexmail.com

## Support

- GitHub Issues: https://github.com/MacMetalMiner/MacMetal-Miner/issues
- Discord: https://discord.gg/86dnKhpV7P
- Website: https://macmetalminer.com

---

Created by **David Otero** at [Distributed Ledger Technologies](https://www.distributedledgertechnologies.com)
