# Technical Documentation

**Copyright (c) 2025 David Otero / Distributed Ledger Technologies**  
Source-Available - See LICENSE for terms

---

## Architecture Overview

MacMetal Miner is built with three main components:

1. **Metal Compute Shader** (`SHA256.metal`) - GPU-accelerated SHA256d implementation
2. **Swift Host Application** (`main.swift`) - Network, UI, and coordination
3. **Stratum Protocol Client** - Pool communication

## SHA256 Implementation

### Why GPU?

Bitcoin mining requires computing double SHA256 (SHA256d) on 80-byte block headers. Each hash attempt requires:
- First SHA256: 80 bytes → 32 bytes
- Second SHA256: 32 bytes → 32 bytes

A single CPU core can compute ~100K-1M hashes per second. A GPU with thousands of cores can compute 100M+ hashes per second in parallel.

### Metal Compute Shader

The shader (`SHA256.metal`) implements:

```metal
kernel void mine(
    device uchar* headerBase,           // 76-byte header without nonce
    device uint* nonceStart,            // Starting nonce for this batch
    device atomic_uint* hashCount,      // Counter for total hashes
    device atomic_uint* resultCount,    // Counter for shares found
    device MiningResult* results,       // Array to store found shares
    device uint* targetZeros,           // Minimum zero bits required
    uint gid [[thread_position_in_grid]]
)
```

Each GPU thread:
1. Copies the 76-byte header base
2. Calculates its unique nonce: `nonceStart + thread_id`
3. Appends nonce to header (bytes 76-79, little-endian)
4. Computes SHA256 of 80-byte header
5. Computes SHA256 of resulting 32-byte hash
6. Counts leading zero bits in final hash
7. If zeros >= target, saves result

### SHA256 Algorithm

The shader implements SHA256 from scratch:

```metal
// Compression function
void sha256_transform(thread uint* state, thread uint* w) {
    // Initialize working variables
    uint a = state[0], b = state[1], ...
    
    // Extend 16 words to 64 words
    for (int i = 16; i < 64; i++) {
        w[i] = sig1(w[i-2]) + w[i-7] + sig0(w[i-15]) + w[i-16];
    }
    
    // 64 rounds of compression
    for (int i = 0; i < 64; i++) {
        uint t1 = h + ep1(e) + ch(e,f,g) + K[i] + w[i];
        uint t2 = ep0(a) + maj(a,b,c);
        // Rotate and update
    }
    
    // Add to state
    state[0] += a; ...
}
```

## Stratum Protocol

### Connection Flow

1. **Connect** to `solo.ckpool.org:3333` via TCP
2. **Subscribe**: `{"method":"mining.subscribe","params":["MacMetalMiner/1.0"]}`
3. **Receive** extranonce1 and extranonce2 size
4. **Authorize**: `{"method":"mining.authorize","params":["ADDRESS.worker","x"]}`
5. **Receive jobs** via `mining.notify`

### Job Structure

```json
{
  "method": "mining.notify",
  "params": [
    "job_id",           // Unique job identifier
    "prev_hash",        // Previous block hash (64 hex chars)
    "coinbase1",        // Coinbase transaction part 1
    "coinbase2",        // Coinbase transaction part 2
    "merkle_branches",  // Array of merkle branch hashes
    "version",          // Block version (8 hex chars)
    "nbits",            // Difficulty target (8 hex chars)
    "ntime",            // Current timestamp (8 hex chars)
    true                // Clean jobs (new block)
  ]
}
```

### Building Block Header

1. **Coinbase Transaction**:
   ```
   coinbase = coinbase1 + extranonce1 + extranonce2 + coinbase2
   ```

2. **Merkle Root**:
   ```
   merkle = SHA256d(coinbase)
   for branch in merkle_branches:
       merkle = SHA256d(merkle + branch)
   ```

3. **Header** (80 bytes):
   | Bytes | Field | Format |
   |-------|-------|--------|
   | 0-3 | Version | Little-endian |
   | 4-35 | Previous Hash | Reversed |
   | 36-67 | Merkle Root | Reversed |
   | 68-71 | Timestamp | Little-endian |
   | 72-75 | Bits (difficulty) | Little-endian |
   | 76-79 | Nonce | Little-endian |

## Performance Optimization

### Batch Size

We use 16 million (2^24) hashes per GPU dispatch:
- Small enough to stay responsive
- Large enough to minimize dispatch overhead
- Approximately 40-50ms per batch on M3 Pro

### Memory Layout

All buffers use `MTLResourceStorageModeShared`:
- Unified memory on Apple Silicon
- Zero-copy access from both CPU and GPU
- Optimal for frequent small updates

### Thread Configuration

```swift
let threadsPerGroup = min(pipeline.maxTotalThreadsPerThreadgroup, 256)
let threadGroups = (batchSize + threadsPerGroup - 1) / threadsPerGroup
```

On M3 Pro (14 GPU cores):
- Max threads per threadgroup: 1024
- We use 256 for better occupancy
- 65,536 threadgroups per dispatch

## Share Difficulty

A "share" is a hash with enough leading zeros to prove work was done:

| Zeros | Probability | Meaning |
|-------|------------|---------|
| 32 bits | 1 in 4.3B | Pool share |
| 64 bits | 1 in 18.4Q | Very rare |
| 76+ bits | 1 in 800E | Bitcoin block! |

Current Bitcoin difficulty requires ~76 leading zero bits. We submit shares at 32 bits to prove we're mining.

## Files

| File | Purpose |
|------|---------|
| `main.swift` | Host application, networking, UI |
| `SHA256.metal` | GPU compute shader |
| `build.sh` | Compilation script |
| `~/.macmetal_shares.json` | Persistent share counter |

## Dependencies

- **Metal.framework** - GPU compute
- **Foundation** - Basic utilities
- **Network.framework** - TCP networking
- **CommonCrypto** - SHA256 for merkle calculation

## Future Improvements

1. **Midstate Optimization**: Pre-compute SHA256 state for bytes 0-63
2. **Multiple Jobs**: Work on multiple jobs in parallel
3. **Block Submission**: Actually submit found blocks to network
4. **Testnet Support**: Test on Bitcoin testnet
5. **Pool Failover**: Automatic fallback to backup pools
