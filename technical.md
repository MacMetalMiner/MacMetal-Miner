# Technical Documentation

MacMetal CLI Miner v2.1 - GPU Edition

## Table of Contents

1. [SHA256d Algorithm](#sha256d-algorithm)
2. [Metal GPU Implementation](#metal-gpu-implementation)
3. [Bitcoin Block Header Structure](#bitcoin-block-header-structure)
4. [Stratum Protocol](#stratum-protocol)
5. [Difficulty and Target](#difficulty-and-target)
6. [Verification Test Details](#verification-test-details)

---

## SHA256d Algorithm

Bitcoin uses SHA256d (double SHA256) for block header hashing:

```
hash = SHA256(SHA256(block_header))
```

### Why Double SHA256?

1. **Length extension attack prevention** - Single SHA256 is vulnerable
2. **Defense in depth** - If SHA256 is partially broken, double hashing provides additional security
3. **Satoshi's design choice** - Established in the original Bitcoin implementation

### Implementation

The Metal shader implements SHA256 following FIPS 180-4:

```metal
// SHA256 round constants
constant uint K[64] = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, ...
};

// Initial hash values (first 32 bits of fractional parts of square roots of first 8 primes)
constant uint H_INIT[8] = {
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
    0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
};
```

---

## Metal GPU Implementation

### Compute Pipeline

```
┌─────────────────────────────────────────────────────────────────┐
│                     GPU Compute Pipeline                        │
├─────────────────────────────────────────────────────────────────┤
│  1. CPU prepares block header (76 bytes without nonce)          │
│  2. CPU sets nonce start value and target zeros                 │
│  3. GPU dispatches 16M threads (each tests one nonce)           │
│  4. Each thread:                                                │
│     a. Copies header + appends its nonce                        │
│     b. Computes SHA256d                                         │
│     c. Counts leading zero bits                                 │
│     d. If meets target, stores result                           │
│  5. CPU reads results array                                     │
└─────────────────────────────────────────────────────────────────┘
```

### Buffer Layout

| Buffer | Size | Contents |
|--------|------|----------|
| headerBase | 76 bytes | Block header without nonce |
| nonceStart | 4 bytes | Starting nonce for batch |
| hashCount | 8 bytes | Atomic counter for hashes |
| resultCount | 4 bytes | Atomic counter for results |
| results | 4000 bytes | Array of MiningResult structs |
| targetZeros | 4 bytes | Minimum zero bits required |

### MiningResult Structure

```metal
struct MiningResult {
    uint nonce;      // 4 bytes - winning nonce
    uint zeros;      // 4 bytes - number of leading zero bits
    uint hash[8];    // 32 bytes - the resulting hash
};  // Total: 40 bytes per result
```

### Thread Configuration

```swift
let batchSize = 16 * 1024 * 1024  // 16 million hashes per dispatch
let threadgroupSize = pipeline.maxTotalThreadsPerThreadgroup  // Usually 1024
let threadgroups = batchSize / threadgroupSize  // ~16,384 threadgroups
```

---

## Bitcoin Block Header Structure

The block header is exactly 80 bytes:

| Field | Size | Description |
|-------|------|-------------|
| version | 4 bytes | Block version (little-endian) |
| prev_block | 32 bytes | Hash of previous block |
| merkle_root | 32 bytes | Merkle root of transactions |
| timestamp | 4 bytes | Unix timestamp (little-endian) |
| bits | 4 bytes | Difficulty target (compact format) |
| nonce | 4 bytes | Value miners iterate (little-endian) |

### Byte Order

Bitcoin uses mixed endianness:

- **Little-endian**: version, timestamp, bits, nonce
- **Big-endian**: SHA256 operations internally
- **Display format**: Hashes shown reversed (big-endian)

### Example: Block 125552

```
Version:     01000000
Prev Block:  81cd02ab7e569e8bcd9317e2fe99f2de44d49ab2b8851ba4a308000000000000
Merkle Root: e320b6c2fffc8d750423db8b1eb942ae710e951ed797f7affc8892b0f1fc122b
Timestamp:   c7f5d74d (2011-05-21 17:26:31 UTC)
Bits:        f2b9441a
Nonce:       42a14695 (1118806677)

Hash:        00000000000000001e8d6829a8a21adc5d38d0a473b144b6765798e61f98bd1d
```

---

## Stratum Protocol

### Connection Flow

```
Miner                                Pool
  │                                    │
  │──── mining.subscribe ─────────────>│
  │<─── result: [extranonce1, en2size] │
  │                                    │
  │──── mining.authorize ─────────────>│
  │<─── result: true ─────────────────│
  │                                    │
  │──── mining.suggest_difficulty ────>│
  │                                    │
  │<─── mining.set_difficulty ────────│
  │<─── mining.notify (job) ──────────│
  │                                    │
  │──── mining.submit (share) ────────>│
  │<─── result: true/false ───────────│
```

### Message Format

All messages are JSON-RPC over TCP with newline delimiter:

```json
{"id": 1, "method": "mining.subscribe", "params": ["MacMetalCLI/2.1-GPU"]}
{"id": 2, "method": "mining.authorize", "params": ["address.worker", "x"]}
{"id": 3, "method": "mining.submit", "params": ["address.worker", "jobId", "extranonce2", "ntime", "nonce"]}
```

### mining.notify Parameters

```json
{
  "params": [
    "jobId",           // Unique job identifier
    "prevHash",        // Previous block hash (swapped 32-bit words)
    "coinbase1",       // Coinbase transaction part 1
    "coinbase2",       // Coinbase transaction part 2
    ["merkle1", ...],  // Merkle branches
    "version",         // Block version
    "nbits",           // Difficulty bits
    "ntime",           // Block timestamp
    true               // Clean jobs (abandon previous work)
  ]
}
```

### Building Block Header from Job

```
1. Coinbase = coinbase1 + extranonce1 + extranonce2 + coinbase2
2. Coinbase Hash = SHA256d(coinbase)
3. Merkle Root = fold merkle branches with SHA256d
4. Header = version || prev_hash || merkle_root || ntime || nbits || nonce
```

---

## Difficulty and Target

### Difficulty 1 Target

```
0x00000000FFFF0000000000000000000000000000000000000000000000000000
```

This represents ~32 leading zero bits.

### Pool Difficulty

Pool difficulty is a multiplier:

```
share_target = difficulty_1_target / pool_difficulty
```

Example:
- Pool diff 0.001 requires ~23 zero bits
- Pool diff 1.0 requires ~32 zero bits
- Pool diff 1000 requires ~42 zero bits

### Zero Bits Calculation

```swift
func difficultyToZeroBits(_ difficulty: Double) -> Int {
    return Int(ceil(32.0 + log2(difficulty)))
}
```

| Difficulty | Zero Bits |
|------------|-----------|
| 0.0001 | 19 |
| 0.001 | 23 |
| 0.01 | 26 |
| 0.1 | 29 |
| 1.0 | 32 |
| 10 | 36 |
| 100 | 39 |
| 1000 | 42 |

### Network Difficulty

Current Bitcoin network difficulty: ~148 trillion
Required zero bits: ~67-68

---

## Verification Test Details

### Test Block: Bitcoin Block #125552

This block was mined on May 21, 2011 and is commonly used for testing Bitcoin implementations.

**Block Details:**
- Height: 125552
- Hash: `00000000000000001e8d6829a8a21adc5d38d0a473b144b6765798e61f98bd1d`
- Timestamp: 2011-05-21 17:26:31 UTC
- Nonce: 1118806677 (0x42a14695 in header, 0x9546a142 big-endian)
- Difficulty: 244,112.49
- Transactions: 227

**Why This Block?**
1. Well-documented and widely used in tests
2. Has many leading zeros (67 bits) - impressive for 2011
3. Nonce is non-trivial (not near 0 or MAX)
4. Verifiable on any block explorer

### Test 1: CPU Verification

```swift
let header = Data(hexString: "0100000081cd02ab...")
let hash = sha256(sha256(header))
let displayHash = hash.reversed().hexString
assert(displayHash == "00000000000000001e8d6829a8a21adc...")
```

### Test 2: GPU Nonce Search

The GPU searches nonces around the known winning value:

```swift
let winningNonce: UInt32 = 0x9546a142  // Big-endian representation
let searchStart = winningNonce - 1000
let (_, results) = gpu.mine(header: header76, nonceStart: searchStart, targetZeros: 32)
// Results should contain the winning nonce
```

### Test 3: Hashrate Benchmark

Three batches of 16M hashes with random headers:

```swift
for batch in 1...3 {
    let (hashes, _) = gpu.mine(header: randomHeader, nonceStart: random, targetZeros: 99)
    // targetZeros: 99 means nothing will match, pure hashrate test
}
avgHashrate = totalHashes / totalTime
```

---

## Security Considerations

### Share Validation

For solo mining pools, strict share validation is optional. Real validation happens when Bitcoin Core accepts a block via `submitblock` RPC.

### Memory Safety

- All GPU buffers use `.storageModeShared` for CPU/GPU access
- Atomic operations prevent race conditions in result counting
- Buffer bounds are checked before access

### Network Security

- Plain TCP connection (no TLS) is standard for Stratum v1
- Password field is typically ignored ("x")
- Address in worker name determines payout

---

## References

1. [Bitcoin Protocol Documentation](https://en.bitcoin.it/wiki/Protocol_documentation)
2. [Stratum Mining Protocol](https://en.bitcoin.it/wiki/Stratum_mining_protocol)
3. [SHA-256 (FIPS 180-4)](https://csrc.nist.gov/publications/detail/fips/180/4/final)
4. [Metal Shading Language Specification](https://developer.apple.com/metal/Metal-Shading-Language-Specification.pdf)
5. [Block 125552 on Blockstream](https://blockstream.info/block/00000000000000001e8d6829a8a21adc5d38d0a473b144b6765798e61f98bd1d)

---

(c) 2025 David Otero / Distributed Ledger Technologies
