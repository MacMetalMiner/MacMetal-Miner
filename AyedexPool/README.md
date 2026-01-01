# Ayedex Pool (Nerd Edition) v1.1

Solo Bitcoin Mining Pool Server for use with MacMetal CLI Miner.

## Requirements

- macOS with Swift compiler
- Bitcoin Core (fully synced)
- bitcoin.conf with RPC enabled:

```
rpcuser=ayedex
rpcpassword=AyedexPool2025!
rpcallowip=127.0.0.1
rpcbind=127.0.0.1
server=1
```

## Build

```bash
./build.sh
```

## Usage

```bash
./AyedexPool <bitcoin_address> [options]

Options:
  --port <port>         Stratum port (default: 3333)
  --rpc-host <host>     Bitcoin RPC host (default: 127.0.0.1)
  --rpc-port <port>     Bitcoin RPC port (default: 8332)
  --rpc-user <user>     Bitcoin RPC username
  --rpc-pass <pass>     Bitcoin RPC password
  --start-diff <diff>   Starting difficulty (default: 1.0)
  --min-diff <diff>     Minimum difficulty (default: 0.0001)
```

## Example

**Terminal 1 - Start Pool:**
```bash
./AyedexPool bc1q2xh89ghtpxya8hj34vulfvx3ckl6rf00umayjt \
    --rpc-user ayedex \
    --rpc-pass 'AyedexPool2025!' \
    --start-diff 0.001
```

**Terminal 2 - Start Miner:**
```bash
cd ..
./MacMetalCLI bc1q2xh89ghtpxya8hj34vulfvx3ckl6rf00umayjt --pool 127.0.0.1:3333
```

## Architecture

```
MacMetal CLI (350+ MH/s)
        │
        ▼ Stratum (port 3333)
   Ayedex Pool
        │
        ▼ JSON-RPC (port 8332)
   Bitcoin Core
```

## Features

- Full Stratum v1 protocol support
- Variable difficulty (vardiff)
- Real-time stats display
- Multiple worker support
- Zero pool fees (solo mining)

## License

Source Available License - (c) 2025 David Otero / Distributed Ledger Technologies

See [LICENSE](../LICENSE) for full terms.
