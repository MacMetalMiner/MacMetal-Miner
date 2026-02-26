//
//  SHA256.metal
//  MacMetal Miner
//
//  Bitcoin SHA256d compute shader for Apple Metal GPU
//  Processes millions of nonces in parallel
//
//  MIT License - See LICENSE for details
//

#include <metal_stdlib>
using namespace metal;

// ============================================================================
// SHA256 Constants
// ============================================================================

constant uint K[64] = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
};

// SHA256 Initial Hash Values
constant uint H_INIT[8] = {
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
    0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
};

// ============================================================================
// SHA256 Helper Functions
// ============================================================================

inline uint rotr(uint x, uint n) { return (x >> n) | (x << (32 - n)); }
inline uint ch(uint x, uint y, uint z) { return (x & y) ^ (~x & z); }
inline uint maj(uint x, uint y, uint z) { return (x & y) ^ (x & z) ^ (y & z); }
inline uint ep0(uint x) { return rotr(x, 2) ^ rotr(x, 13) ^ rotr(x, 22); }
inline uint ep1(uint x) { return rotr(x, 6) ^ rotr(x, 11) ^ rotr(x, 25); }
inline uint sig0(uint x) { return rotr(x, 7) ^ rotr(x, 18) ^ (x >> 3); }
inline uint sig1(uint x) { return rotr(x, 17) ^ rotr(x, 19) ^ (x >> 10); }

// Swap endianness (Bitcoin uses little-endian, SHA256 uses big-endian)
inline uint swap32(uint val) {
    return ((val & 0xff000000) >> 24) |
           ((val & 0x00ff0000) >> 8) |
           ((val & 0x0000ff00) << 8) |
           ((val & 0x000000ff) << 24);
}

// ============================================================================
// SHA256 Transform
// ============================================================================

// SHA256 compression function for a single 64-byte block
void sha256_transform(thread uint* state, thread uint* w) {
    uint a = state[0], b = state[1], c = state[2], d = state[3];
    uint e = state[4], f = state[5], g = state[6], h = state[7];
    
    // Extend the sixteen 32-bit words into sixty-four 32-bit words
    for (int i = 16; i < 64; i++) {
        w[i] = sig1(w[i-2]) + w[i-7] + sig0(w[i-15]) + w[i-16];
    }
    
    // Main compression loop (64 rounds)
    for (int i = 0; i < 64; i++) {
        uint t1 = h + ep1(e) + ch(e, f, g) + K[i] + w[i];
        uint t2 = ep0(a) + maj(a, b, c);
        h = g; g = f; f = e; e = d + t1;
        d = c; c = b; b = a; a = t1 + t2;
    }
    
    // Add compressed chunk to current hash value
    state[0] += a; state[1] += b; state[2] += c; state[3] += d;
    state[4] += e; state[5] += f; state[6] += g; state[7] += h;
}

// ============================================================================
// SHA256 Functions for Different Input Sizes
// ============================================================================

// SHA256 of 80-byte block header (Bitcoin block header)
void sha256_80(thread uchar* data, thread uint* hash) {
    uint state[8];
    uint w[64];
    
    // Initialize state with SHA256 initial values
    for (int i = 0; i < 8; i++) state[i] = H_INIT[i];
    
    // First block (bytes 0-63)
    for (int i = 0; i < 16; i++) {
        w[i] = (uint(data[i*4]) << 24) | (uint(data[i*4+1]) << 16) | 
               (uint(data[i*4+2]) << 8) | uint(data[i*4+3]);
    }
    sha256_transform(state, w);
    
    // Second block (bytes 64-79 + padding)
    w[0] = (uint(data[64]) << 24) | (uint(data[65]) << 16) | (uint(data[66]) << 8) | uint(data[67]);
    w[1] = (uint(data[68]) << 24) | (uint(data[69]) << 16) | (uint(data[70]) << 8) | uint(data[71]);
    w[2] = (uint(data[72]) << 24) | (uint(data[73]) << 16) | (uint(data[74]) << 8) | uint(data[75]);
    w[3] = (uint(data[76]) << 24) | (uint(data[77]) << 16) | (uint(data[78]) << 8) | uint(data[79]);
    w[4] = 0x80000000;  // Padding bit
    for (int i = 5; i < 15; i++) w[i] = 0;
    w[15] = 640;  // Length in bits (80 * 8)
    sha256_transform(state, w);
    
    // Copy result
    for (int i = 0; i < 8; i++) hash[i] = state[i];
}

// SHA256 of 32-byte hash (for double SHA256)
void sha256_32(thread uint* data, thread uint* hash) {
    uint state[8];
    uint w[64];
    
    // Initialize state
    for (int i = 0; i < 8; i++) state[i] = H_INIT[i];
    
    // Single block (32 bytes of data + padding)
    for (int i = 0; i < 8; i++) w[i] = data[i];
    w[8] = 0x80000000;  // Padding bit
    for (int i = 9; i < 15; i++) w[i] = 0;
    w[15] = 256;  // Length in bits (32 * 8)
    
    sha256_transform(state, w);
    
    // Copy result
    for (int i = 0; i < 8; i++) hash[i] = state[i];
}

// ============================================================================
// Mining Result Structure
// ============================================================================

struct MiningResult {
    uint nonce;
    uint hash[8];
    uint zeros;
};

// ============================================================================
// Main Mining Kernel
// ============================================================================

/// Bitcoin mining kernel - processes one nonce per thread
/// 
/// @param headerBase    76-byte block header (without nonce)
/// @param nonceStart    Starting nonce value
/// @param hashCount     Atomic counter for total hashes computed
/// @param resultCount   Atomic counter for results found
/// @param results       Array to store found shares
/// @param target        Full 256-bit target (8 x uint32, big-endian)
/// @param gid           Thread ID (used to calculate nonce)
///
kernel void sha256_mine(
    device uchar* headerBase [[buffer(0)]],
    device uint* nonceStart [[buffer(1)]],
    device atomic_uint* hashCount [[buffer(2)]],
    device atomic_uint* resultCount [[buffer(3)]],
    device MiningResult* results [[buffer(4)]],
    device uint* target [[buffer(5)]],
    uint gid [[thread_position_in_grid]]
) {
    // Build full 80-byte header with nonce
    uchar header[80];
    for (int i = 0; i < 76; i++) {
        header[i] = headerBase[i];
    }
    
    // Calculate nonce for this thread
    uint nonce = nonceStart[0] + gid;
    
    // Insert nonce at bytes 76-79 (little-endian)
    header[76] = nonce & 0xff;
    header[77] = (nonce >> 8) & 0xff;
    header[78] = (nonce >> 16) & 0xff;
    header[79] = (nonce >> 24) & 0xff;
    
    // First SHA256
    uint hash1[8];
    sha256_80(header, hash1);
    
    // Second SHA256 (double SHA256 = SHA256d)
    uint hash2[8];
    sha256_32(hash1, hash2);
    
    // Increment hash counter
    atomic_fetch_add_explicit(hashCount, 1, memory_order_relaxed);
    
    // Count leading zero bits (for logging/display purposes)
    // hash2[0] is the most significant word (standard SHA256 output order)
    uint zeros = 0;
    uint val = hash2[0];
    if (val == 0) {
        zeros = 32;
        val = hash2[1];
        if (val == 0) {
            zeros = 64;
            val = hash2[2];
            if (val == 0) {
                zeros = 96;
            } else {
                zeros += clz(val);
            }
        } else {
            zeros += clz(val);
        }
    } else {
        zeros = clz(val);
    }

    // Proper 256-bit comparison: hash < target
    // hash2[0] = most significant word, hash2[7] = least significant
    // target[0] = most significant word, target[7] = least significant
    // Compare from most significant to least significant
    bool belowTarget = false;
    bool decided = false;

    for (int i = 0; i < 8 && !decided; i++) {
        uint hashWord = hash2[i];
        uint targetWord = target[i];

        if (hashWord < targetWord) {
            belowTarget = true;
            decided = true;
        } else if (hashWord > targetWord) {
            belowTarget = false;
            decided = true;
        }
        // If equal, continue to next word
    }

    // If all words equal, hash == target, which is NOT below target
    
    // If hash < target, save the result
    if (belowTarget) {
        uint idx = atomic_fetch_add_explicit(resultCount, 1, memory_order_relaxed);
        if (idx < 100) {  // Max 100 results per batch
            results[idx].nonce = nonce;
            results[idx].zeros = zeros;
            for (int i = 0; i < 8; i++) {
                results[idx].hash[i] = hash2[i];
            }
        }
    }
}
