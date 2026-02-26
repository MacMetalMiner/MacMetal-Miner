#!/usr/bin/env swift
// ═══════════════════════════════════════════════════════════════════════════════
//  MacMetal CLI Miner v2.9 - Debug Edition
//  Metal GPU Accelerated Bitcoin Mining for macOS
//
//  Copyright (c) 2025 David Otero / Distributed Ledger Technologies
//  www.distributedledgertechnologies.com
// ═══════════════════════════════════════════════════════════════════════════════

import Foundation
import Metal
import CryptoKit

// ============================================================
// MARK: - Config
// ============================================================

enum PrevHashMode: String {
    case asIs          // append prevhash bytes exactly as sent (32 bytes)
    case wordSwap4     // reverse each 4-byte word (common stratum quirk)
    case fullReverse   // reverse all 32 bytes (rare, but useful for testing)
}

enum MerkleBranchMode: String {
    case reverseBranchBytes  // reverse each 32-byte branch from notify before hashing (common)
    case asIs                // use branch bytes as given
}

enum NonceSubmitEndian: String {
    case littleHeaderBytes   // submit nonce as 4 bytes little-endian hex (bytes as in header)
    case bigUInt32Hex        // submit nonce as %08x (big-endian textual value)
}

struct MinerConfig {
    var host: String = "europe.solomining.io"
    var port: UInt16 = 7777
    var worker: String = "bc1qagznhy7yckwjcc2cchh2808ufufhsy94qvz80x.terminal"
    var password: String = "x"

    // These 3 toggles are what you flip when you see "Above target" but local validate passes.
    var prevHashMode: PrevHashMode = .wordSwap4
    var merkleBranchMode: MerkleBranchMode = .reverseBranchBytes
    var nonceSubmitEndian: NonceSubmitEndian = .littleHeaderBytes

    // Extranonce2 counter starts at 0 unless you prefer random.
    var extranonce2Start: UInt64 = 0

    var debug: Bool = true
}

// ============================================================
// MARK: - Job Model
// ============================================================

struct StratumJob {
    let jobId: String
    let prevHashHex: String
    let cb1Hex: String
    let cb2Hex: String
    let merkleBranchesHex: [String]
    let versionHex: String
    let nbitsHex: String
    let ntimeHex: String
    let cleanJobs: Bool
}

// ============================================================
// MARK: - Hex helpers
// ============================================================

func hexToBytes(_ hex: String) -> [UInt8] {
    var bytes: [UInt8] = []
    bytes.reserveCapacity(hex.count / 2)
    var i = hex.startIndex
    while i < hex.endIndex {
        let j = hex.index(i, offsetBy: 2, limitedBy: hex.endIndex) ?? hex.endIndex
        let byteStr = hex[i..<j]
        bytes.append(UInt8(byteStr, radix: 16) ?? 0)
        i = j
    }
    return bytes
}

func bytesToHex(_ bytes: [UInt8]) -> String {
    bytes.map { String(format: "%02x", $0) }.joined()
}

func u32LE(_ hex8: String) -> [UInt8] {
    let v = UInt32(hex8, radix: 16) ?? 0
    let le = v.littleEndian
    return withUnsafeBytes(of: le) { Array($0) }
}

func reverseEvery4Bytes(_ bytes: [UInt8]) -> [UInt8] {
    guard bytes.count % 4 == 0 else { return bytes }
    var out: [UInt8] = []
    out.reserveCapacity(bytes.count)
    for i in stride(from: 0, to: bytes.count, by: 4) {
        out.append(contentsOf: bytes[i..<i+4].reversed())
    }
    return out
}

// ============================================================
// MARK: - SHA256d
// ============================================================

func sha256(_ data: [UInt8]) -> [UInt8] {
    let digest = SHA256.hash(data: Data(data))
    return Array(digest)
}

func sha256d(_ data: [UInt8]) -> [UInt8] {
    sha256(sha256(data))
}

// ============================================================
// MARK: - Difficulty target (diff1 target / difficulty)
// ============================================================

let diff1TargetBE: [UInt8] = [
    0x00,0x00,0x00,0x00, 0xFF,0xFF,0x00,0x00,
    0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00,
    0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00,
    0x00,0x00,0x00,0x00, 0x00,0x00,0x00,0x00
]

func div256ByUInt32BE(_ valueBE: [UInt8], divisor: UInt32) -> [UInt8] {
    guard valueBE.count == 32 else { return valueBE }
    var quotient = [UInt8](repeating: 0, count: 32)
    var rem: UInt64 = 0
    for i in 0..<32 {
        rem = (rem << 8) | UInt64(valueBE[i])
        let q = rem / UInt64(divisor)
        rem = rem % UInt64(divisor)
        quotient[i] = UInt8(q & 0xFF)
    }
    return quotient
}

func compareBE(_ a: [UInt8], _ b: [UInt8]) -> Int {
    guard a.count == b.count else { return 0 }
    for i in 0..<a.count {
        if a[i] < b[i] { return -1 }
        if a[i] > b[i] { return 1 }
    }
    return 0
}

// ============================================================
// MARK: - Telemetry (sends stats to macmetalminer.com)
// ============================================================

class Telemetry {
    static let shared = Telemetry()
    private let apiURL = "https://api.macmetalminer.com/api.php"
    private var lastHeartbeat: Date = .distantPast

    private var address: String = ""
    private var machine: String = ""
    private var gpu: String = ""
    private var pool: String = ""
    private var hashrate: Double = 0
    private var totalHashes: UInt64 = 0
    private var uptime: Int = 0
    private var sessionShares: Int = 0
    private var bestDiff: UInt32 = 0

    private init() {
        // Get machine info
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        let modelId = String(cString: model)
        machine = Self.friendlyMacName(modelId)

        if let device = MTLCreateSystemDefaultDevice() {
            gpu = device.name
        }
    }

    private static func friendlyMacName(_ id: String) -> String {
        let map: [String: String] = [
            // M1 Series
            "MacBookAir10,1": "MacBook Air M1",
            "MacBookPro17,1": "MacBook Pro 13\" M1",
            "MacBookPro18,1": "MacBook Pro 16\" M1 Pro",
            "MacBookPro18,2": "MacBook Pro 16\" M1 Max",
            "MacBookPro18,3": "MacBook Pro 14\" M1 Pro",
            "MacBookPro18,4": "MacBook Pro 14\" M1 Max",
            "Macmini9,1": "Mac mini M1",
            "iMac21,1": "iMac 24\" M1",
            "iMac21,2": "iMac 24\" M1",
            "Mac13,1": "Mac Studio M1 Max",
            "Mac13,2": "Mac Studio M1 Ultra",

            // M2 Series
            "Mac14,2": "MacBook Air M2",
            "Mac14,7": "MacBook Pro 13\" M2",
            "Mac14,15": "MacBook Air 15\" M2",
            "Mac14,5": "MacBook Pro 14\" M2 Pro",
            "Mac14,9": "MacBook Pro 14\" M2 Pro",
            "Mac14,6": "MacBook Pro 16\" M2 Pro",
            "Mac14,10": "MacBook Pro 16\" M2 Max",
            "Mac14,14": "Mac Studio M2 Max",
            "Mac14,13": "Mac Studio M2 Ultra",
            "Mac14,8": "Mac Pro M2 Ultra",
            "Mac14,3": "Mac mini M2",
            "Mac14,12": "Mac mini M2 Pro",

            // M3 Series
            "Mac15,3": "MacBook Pro 14\" M3",
            "Mac15,4": "iMac 24\" M3",
            "Mac15,5": "iMac 24\" M3",
            "Mac15,6": "MacBook Pro 14\" M3 Pro",
            "Mac15,7": "MacBook Pro 16\" M3 Pro",
            "Mac15,8": "MacBook Pro 14\" M3 Max",
            "Mac15,9": "MacBook Pro 16\" M3 Max",
            "Mac15,10": "MacBook Pro 14\" M3 Max",
            "Mac15,11": "MacBook Pro 16\" M3 Max",
            "Mac15,12": "MacBook Air 13\" M3",
            "Mac15,13": "MacBook Air 15\" M3",

            // M4 Series
            "Mac16,1": "MacBook Pro 14\" M4",
            "Mac16,2": "iMac 24\" M4",
            "Mac16,3": "iMac 24\" M4",
            "Mac16,5": "MacBook Pro 16\" M4 Pro",
            "Mac16,6": "MacBook Pro 14\" M4 Pro",
            "Mac16,7": "MacBook Pro 16\" M4 Max",
            "Mac16,8": "MacBook Pro 14\" M4 Max",
            "Mac16,9": "Mac Studio M4 Max",
            "Mac16,10": "Mac mini M4",
            "Mac16,11": "Mac mini M4 Pro",
            "Mac16,12": "MacBook Air 13\" M4",
            "Mac16,13": "MacBook Air 15\" M4",
        ]
        return map[id] ?? id
    }

    func start(address: String, pool: String) {
        self.address = address
        self.pool = pool

        // Send start event
        send(action: "start", extra: ["machine": machine, "gpu": gpu, "via": "CLI"])

        // Send immediate heartbeat
        sendHeartbeat()
    }

    func stop() {
        send(action: "stop", extra: [:])
    }

    func update(hashrate: Double, totalHashes: UInt64, uptime: Int, shares: Int, bestDiff: UInt32) {
        self.hashrate = hashrate
        self.totalHashes = totalHashes
        self.uptime = uptime
        self.sessionShares = shares
        self.bestDiff = bestDiff

        // Send heartbeat every 30 seconds
        if Date().timeIntervalSince(lastHeartbeat) >= 30 {
            sendHeartbeat()
            lastHeartbeat = Date()
        }
    }

    func shareSent(difficulty: UInt32) {
        send(action: "share", extra: [
            "difficulty": difficulty,
            "machine": machine,
            "session_shares": sessionShares,
            "via": "CLI"
        ])
    }

    private func sendHeartbeat() {
        send(action: "heartbeat", extra: [
            "hashrate": Int(hashrate),
            "total_hashes": totalHashes,
            "uptime": uptime,
            "pool": pool,
            "session_shares": sessionShares,
            "best_diff": bestDiff,
            "machine": machine,
            "gpu": gpu,
            "version": "2.9-CLI",
            "via": "CLI"
        ])
    }

    private func send(action: String, extra: [String: Any]) {
        var payload: [String: Any] = [
            "action": action,
            "address": address,
            "via": "CLI"
        ]

        for (key, value) in extra {
            payload[key] = value
        }

        guard let url = URL(string: apiURL),
              let jsonData = try? JSONSerialization.data(withJSONObject: payload) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request).resume()
    }
}

// ============================================================
// MARK: - Metal Shader (Inline)
// ============================================================

let metalShaderSource = """
#include <metal_stdlib>
using namespace metal;

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

constant uint H_INIT[8] = {
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
    0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
};

inline uint rotr(uint x, uint n) { return (x >> n) | (x << (32 - n)); }
inline uint ch(uint x, uint y, uint z) { return (x & y) ^ (~x & z); }
inline uint maj(uint x, uint y, uint z) { return (x & y) ^ (x & z) ^ (y & z); }
inline uint ep0(uint x) { return rotr(x, 2) ^ rotr(x, 13) ^ rotr(x, 22); }
inline uint ep1(uint x) { return rotr(x, 6) ^ rotr(x, 11) ^ rotr(x, 25); }
inline uint sig0(uint x) { return rotr(x, 7) ^ rotr(x, 18) ^ (x >> 3); }
inline uint sig1(uint x) { return rotr(x, 17) ^ rotr(x, 19) ^ (x >> 10); }

inline uint swap32(uint val) {
    return ((val & 0xff000000) >> 24) | ((val & 0x00ff0000) >> 8) |
           ((val & 0x0000ff00) << 8) | ((val & 0x000000ff) << 24);
}

void sha256_transform(thread uint* state, thread uint* w) {
    uint a = state[0], b = state[1], c = state[2], d = state[3];
    uint e = state[4], f = state[5], g = state[6], h = state[7];
    for (int i = 16; i < 64; i++) {
        w[i] = sig1(w[i-2]) + w[i-7] + sig0(w[i-15]) + w[i-16];
    }
    for (int i = 0; i < 64; i++) {
        uint t1 = h + ep1(e) + ch(e, f, g) + K[i] + w[i];
        uint t2 = ep0(a) + maj(a, b, c);
        h = g; g = f; f = e; e = d + t1;
        d = c; c = b; b = a; a = t1 + t2;
    }
    state[0] += a; state[1] += b; state[2] += c; state[3] += d;
    state[4] += e; state[5] += f; state[6] += g; state[7] += h;
}

void sha256_80(thread uchar* data, thread uint* hash) {
    uint state[8];
    uint w[64];
    for (int i = 0; i < 8; i++) state[i] = H_INIT[i];
    for (int i = 0; i < 16; i++) {
        w[i] = (uint(data[i*4]) << 24) | (uint(data[i*4+1]) << 16) |
               (uint(data[i*4+2]) << 8) | uint(data[i*4+3]);
    }
    sha256_transform(state, w);
    w[0] = (uint(data[64]) << 24) | (uint(data[65]) << 16) | (uint(data[66]) << 8) | uint(data[67]);
    w[1] = (uint(data[68]) << 24) | (uint(data[69]) << 16) | (uint(data[70]) << 8) | uint(data[71]);
    w[2] = (uint(data[72]) << 24) | (uint(data[73]) << 16) | (uint(data[74]) << 8) | uint(data[75]);
    w[3] = (uint(data[76]) << 24) | (uint(data[77]) << 16) | (uint(data[78]) << 8) | uint(data[79]);
    w[4] = 0x80000000;
    for (int i = 5; i < 15; i++) w[i] = 0;
    w[15] = 640;
    sha256_transform(state, w);
    for (int i = 0; i < 8; i++) hash[i] = state[i];
}

void sha256_32(thread uint* data, thread uint* hash) {
    uint state[8];
    uint w[64];
    for (int i = 0; i < 8; i++) state[i] = H_INIT[i];
    for (int i = 0; i < 8; i++) w[i] = data[i];
    w[8] = 0x80000000;
    for (int i = 9; i < 15; i++) w[i] = 0;
    w[15] = 256;
    sha256_transform(state, w);
    for (int i = 0; i < 8; i++) hash[i] = state[i];
}

struct MiningResult {
    uint nonce;
    uint zeros;
    uint hash0; uint hash1; uint hash2; uint hash3;
    uint hash4; uint hash5; uint hash6; uint hash7;
};

struct BestShare {
    atomic_uint zeros;
    atomic_uint nonce;
};

kernel void sha256_mine(
    device uchar* headerBase [[buffer(0)]],
    device uint* nonceStart [[buffer(1)]],
    device atomic_uint* hashCount [[buffer(2)]],
    device atomic_uint* resultCount [[buffer(3)]],
    device MiningResult* results [[buffer(4)]],
    device uint* targetZeros [[buffer(5)]],
    device BestShare* bestShare [[buffer(6)]],
    uint gid [[thread_position_in_grid]]
) {
    uchar header[80];
    for (int i = 0; i < 76; i++) header[i] = headerBase[i];
    uint nonce = nonceStart[0] + gid;
    header[76] = nonce & 0xff;
    header[77] = (nonce >> 8) & 0xff;
    header[78] = (nonce >> 16) & 0xff;
    header[79] = (nonce >> 24) & 0xff;
    uint hash1[8]; sha256_80(header, hash1);
    uint hash2[8]; sha256_32(hash1, hash2);
    atomic_fetch_add_explicit(hashCount, 1, memory_order_relaxed);
    uint zeros = 0;
    uint val = hash2[0];
    if (val == 0) {
        zeros = 32; val = hash2[1];
        if (val == 0) { zeros = 64; val = hash2[2]; if (val == 0) { zeros = 96; } else { zeros += clz(val); } }
        else { zeros += clz(val); }
    } else { zeros = clz(val); }

    uint currentBest = atomic_load_explicit(&bestShare->zeros, memory_order_relaxed);
    while (zeros > currentBest) {
        if (atomic_compare_exchange_weak_explicit(&bestShare->zeros, &currentBest, zeros,
                                                   memory_order_relaxed, memory_order_relaxed)) {
            atomic_store_explicit(&bestShare->nonce, nonce, memory_order_relaxed);
            break;
        }
    }

    if (zeros >= targetZeros[0]) {
        uint idx = atomic_fetch_add_explicit(resultCount, 1, memory_order_relaxed);
        if (idx < 100) {
            results[idx].nonce = nonce; results[idx].zeros = zeros;
            results[idx].hash0 = hash2[0]; results[idx].hash1 = hash2[1];
            results[idx].hash2 = hash2[2]; results[idx].hash3 = hash2[3];
            results[idx].hash4 = hash2[4]; results[idx].hash5 = hash2[5];
            results[idx].hash6 = hash2[6]; results[idx].hash7 = hash2[7];
        }
    }
}
"""

// ============================================================
// MARK: - Header Builder
// ============================================================

struct HeaderBuilder {
    let config: MinerConfig

    func buildHeader76(job: StratumJob, extranonce1: String, extranonce2: String) -> [UInt8] {
        // 1) Build coinbase (literal bytes)
        let coinbase = hexToBytes(job.cb1Hex + extranonce1 + extranonce2 + job.cb2Hex)

        // 2) Merkle root
        var merkle = sha256d(coinbase)

        for branchHex in job.merkleBranchesHex {
            let branch = hexToBytes(branchHex)
            merkle = sha256d(merkle + branch)
        }
        // Merkle root from SHA256d is already in correct byte order for the block header
        let merkleForHeader = merkle

        // 3) Prevhash handling
        let prevBytes = hexToBytes(job.prevHashHex)
        let prevForHeader: [UInt8] = {
            switch config.prevHashMode {
            case .asIs:
                return prevBytes
            case .wordSwap4:
                return reverseEvery4Bytes(prevBytes)
            case .fullReverse:
                return Array(prevBytes.reversed())
            }
        }()

        // 4) Assemble 76-byte header
        var header: [UInt8] = []
        header.reserveCapacity(76)

        header.append(contentsOf: u32LE(job.versionHex))
        header.append(contentsOf: prevForHeader)
        header.append(contentsOf: merkleForHeader)
        header.append(contentsOf: u32LE(job.ntimeHex))
        header.append(contentsOf: u32LE(job.nbitsHex))

        return header
    }

    func buildHeader80(header76: [UInt8], nonce: UInt32) -> [UInt8] {
        var h = header76
        let nLE = withUnsafeBytes(of: nonce.littleEndian) { Array($0) }
        h.append(contentsOf: nLE)
        return h
    }

    func nonceStringForSubmit(nonce: UInt32) -> String {
        switch config.nonceSubmitEndian {
        case .littleHeaderBytes:
            let le = withUnsafeBytes(of: nonce.littleEndian) { Array($0) }
            return bytesToHex(le)
        case .bigUInt32Hex:
            return String(format: "%08x", nonce)
        }
    }
}

// ============================================================
// MARK: - GPU Miner
// ============================================================

struct MineResult {
    let hashes: UInt64
    let shares: [(nonce: UInt32, zeros: UInt32)]
    let bestZeros: UInt32
    let bestNonce: UInt32
}

class GPUMiner {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let pipeline: MTLComputePipelineState
    let batchSize = 1024 * 1024 * 16
    var headerBuffer, nonceBuffer, hashCountBuffer, resultCountBuffer, resultsBuffer, targetBuffer, bestShareBuffer: MTLBuffer?
    var gpuName: String

    init?() {
        guard let dev = MTLCreateSystemDefaultDevice() else { return nil }
        device = dev
        gpuName = dev.name
        guard let q = dev.makeCommandQueue() else { return nil }
        commandQueue = q
        guard let lib = try? dev.makeLibrary(source: metalShaderSource, options: nil),
              let fn = lib.makeFunction(name: "sha256_mine"),
              let ps = try? dev.makeComputePipelineState(function: fn) else { return nil }
        pipeline = ps
        headerBuffer = dev.makeBuffer(length: 80, options: .storageModeShared)
        nonceBuffer = dev.makeBuffer(length: 4, options: .storageModeShared)
        hashCountBuffer = dev.makeBuffer(length: 8, options: .storageModeShared)
        resultCountBuffer = dev.makeBuffer(length: 4, options: .storageModeShared)
        resultsBuffer = dev.makeBuffer(length: 100 * 40, options: .storageModeShared)
        targetBuffer = dev.makeBuffer(length: 4, options: .storageModeShared)
        bestShareBuffer = dev.makeBuffer(length: 8, options: .storageModeShared)
    }

    func mine(header: [UInt8], nonceStart: UInt32, targetZeros: UInt32) -> MineResult {
        guard let hb = headerBuffer, let nb = nonceBuffer, let hcb = hashCountBuffer,
              let rcb = resultCountBuffer, let rb = resultsBuffer, let tb = targetBuffer,
              let bsb = bestShareBuffer else { return MineResult(hashes: 0, shares: [], bestZeros: 0, bestNonce: 0) }

        memcpy(hb.contents(), header, min(header.count, 76))
        var ns = nonceStart; memcpy(nb.contents(), &ns, 4)
        var t = targetZeros; memcpy(tb.contents(), &t, 4)
        memset(hcb.contents(), 0, 8); memset(rcb.contents(), 0, 4)
        memset(bsb.contents(), 0, 8)

        guard let cb = commandQueue.makeCommandBuffer(), let enc = cb.makeComputeCommandEncoder() else {
            return MineResult(hashes: 0, shares: [], bestZeros: 0, bestNonce: 0)
        }
        enc.setComputePipelineState(pipeline)
        enc.setBuffer(hb, offset: 0, index: 0); enc.setBuffer(nb, offset: 0, index: 1)
        enc.setBuffer(hcb, offset: 0, index: 2); enc.setBuffer(rcb, offset: 0, index: 3)
        enc.setBuffer(rb, offset: 0, index: 4); enc.setBuffer(tb, offset: 0, index: 5)
        enc.setBuffer(bsb, offset: 0, index: 6)

        let tgSize = pipeline.maxTotalThreadsPerThreadgroup
        enc.dispatchThreadgroups(MTLSize(width: (batchSize + tgSize - 1) / tgSize, height: 1, depth: 1),
                                threadsPerThreadgroup: MTLSize(width: tgSize, height: 1, depth: 1))
        enc.endEncoding(); cb.commit(); cb.waitUntilCompleted()

        let hashes = hcb.contents().load(as: UInt64.self)
        let count = min(rcb.contents().load(as: UInt32.self), 100)
        var shares: [(UInt32, UInt32)] = []
        let ptr = rb.contents().assumingMemoryBound(to: UInt32.self)
        for i in 0..<Int(count) { shares.append((ptr[i * 10], ptr[i * 10 + 1])) }

        let bestPtr = bsb.contents().assumingMemoryBound(to: UInt32.self)
        let bestZeros = bestPtr[0]
        let bestNonce = bestPtr[1]

        return MineResult(hashes: hashes, shares: shares, bestZeros: bestZeros, bestNonce: bestNonce)
    }
}

// ============================================================
// MARK: - Stratum Client
// ============================================================

class StratumClient {
    var config: MinerConfig
    var socket: Int32 = -1
    var msgId = 1

    var extranonce1: String = ""
    var extranonce2SizeBytes: Int = 8
    var extranonce2Counter: UInt64 = 0
    var difficulty: UInt32 = 1
    var currentJob: StratumJob?
    var authorized = false

    let builder: HeaderBuilder

    init(config: MinerConfig) {
        self.config = config
        self.builder = HeaderBuilder(config: config)
        self.extranonce2Counter = config.extranonce2Start
    }

    func connect() -> Bool {
        socket = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard socket >= 0 else { return false }

        var hints = addrinfo()
        hints.ai_family = AF_INET
        hints.ai_socktype = SOCK_STREAM
        var res: UnsafeMutablePointer<addrinfo>?

        guard getaddrinfo(config.host, String(config.port), &hints, &res) == 0, let ai = res else { return false }
        defer { freeaddrinfo(res) }

        guard Darwin.connect(socket, ai.pointee.ai_addr, ai.pointee.ai_addrlen) == 0 else { return false }

        var flags = fcntl(socket, F_GETFL, 0)
        fcntl(socket, F_SETFL, flags | O_NONBLOCK)

        return true
    }

    func send(_ s: String) {
        _ = s.withCString { Darwin.send(socket, $0, strlen($0), 0) }
        print("[SEND] \(s.trimmingCharacters(in: .newlines))")
    }

    func subscribe() {
        send("{\"id\":\(msgId),\"method\":\"mining.subscribe\",\"params\":[\"macmetal/2.9\"]}\n")
        msgId += 1
    }

    func authorize() {
        send("{\"id\":\(msgId),\"method\":\"mining.authorize\",\"params\":[\"\(config.worker)\",\"\(config.password)\"]}\n")
        msgId += 1
    }

    func submitShare(jobId: String, extranonce2: String, ntime: String, nonceStr: String) {
        send("{\"id\":\(msgId),\"method\":\"mining.submit\",\"params\":[\"\(config.worker)\",\"\(jobId)\",\"\(extranonce2)\",\"\(ntime)\",\"\(nonceStr)\"]}\n")
        msgId += 1
    }

    func receive() {
        var buf = [CChar](repeating: 0, count: 8192)
        let n = recv(socket, &buf, 8191, 0)
        if n > 0 {
            let str = String(cString: buf)
            for line in str.split(separator: "\n") {
                processMessage(String(line))
            }
        }
    }

    func processMessage(_ msg: String) {
        print("[RECV] \(msg)")
        guard let data = msg.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        if let method = json["method"] as? String, let params = json["params"] as? [Any] {
            switch method {
            case "mining.set_difficulty":
                if let d = params.first as? Double {
                    difficulty = UInt32(max(1, Int(d.rounded())))
                    print("[STATE] difficulty=\(difficulty)")
                }
            case "mining.notify":
                parseNotify(params)
            default:
                break
            }
        }

        if let id = json["id"] as? Int {
            if let result = json["result"] as? [Any], result.count >= 3 {
                if let en1 = result[1] as? String, let en2sz = result[2] as? Int {
                    extranonce1 = en1
                    extranonce2SizeBytes = en2sz
                    print("[STATE] extranonce1=\(extranonce1) extranonce2SizeBytes=\(extranonce2SizeBytes)")
                }
            }
            if let result = json["result"] as? Bool {
                if result {
                    if id >= 3 {
                        print("[SHARE] ACCEPTED!")
                    } else {
                        authorized = true
                        print("[STATE] Authorized!")
                    }
                } else {
                    let reason = (json["reject-reason"] as? String) ?? "unknown"
                    print("[SHARE] REJECT: \(reason)")
                    print("        Try flipping: prevHashMode, merkleBranchMode, or nonceSubmitEndian")
                }
            }
        }
    }

    func parseNotify(_ params: [Any]) {
        guard params.count >= 9 else { return }

        currentJob = StratumJob(
            jobId: params[0] as? String ?? "",
            prevHashHex: params[1] as? String ?? "",
            cb1Hex: params[2] as? String ?? "",
            cb2Hex: params[3] as? String ?? "",
            merkleBranchesHex: params[4] as? [String] ?? [],
            versionHex: params[5] as? String ?? "",
            nbitsHex: params[6] as? String ?? "",
            ntimeHex: params[7] as? String ?? "",
            cleanJobs: params[8] as? Bool ?? false
        )

        if currentJob!.cleanJobs {
            extranonce2Counter = 0
        }

        print("[JOB] id=\(currentJob!.jobId) branches=\(currentJob!.merkleBranchesHex.count)")
    }

    func nextExtranonce2() -> String {
        let width = extranonce2SizeBytes * 2
        let s = String(format: "%0\(width)llx", extranonce2Counter)
        extranonce2Counter &+= 1
        return s
    }

    func validateAndSubmit(nonce: UInt32, header76: [UInt8], en2: String) {
        guard let job = currentJob else { return }

        let header80 = builder.buildHeader80(header76: header76, nonce: nonce)
        let hash = sha256d(header80)
        let shareTarget = div256ByUInt32BE(diff1TargetBE, divisor: max(1, difficulty))

        let cmp = compareBE(hash, shareTarget)
        let isValid = (cmp <= 0)

        let displayHash = bytesToHex(hash.reversed())
        print("[CHECK] nonce=0x\(String(format:"%08x", nonce)) en2=\(en2)")
        print("        hash=\(displayHash)")
        print("        valid? \(isValid)")

        if isValid {
            let nonceStr = builder.nonceStringForSubmit(nonce: nonce)
            submitShare(jobId: job.jobId, extranonce2: en2, ntime: job.ntimeHex, nonceStr: nonceStr)
        } else {
            print("[DROP] Local check says Above target; not submitting.")
        }
    }
}

// ============================================================
// MARK: - Main
// ============================================================

func formatHashrate(_ h: Double) -> String {
    if h >= 1e9 { return String(format: "%.2f GH/s", h/1e9) }
    if h >= 1e6 { return String(format: "%.2f MH/s", h/1e6) }
    return String(format: "%.2f KH/s", h/1e3)
}

func formatUptime(_ t: TimeInterval) -> String {
    let h = Int(t / 3600)
    let m = Int(t.truncatingRemainder(dividingBy: 3600) / 60)
    let s = Int(t.truncatingRemainder(dividingBy: 60))
    return String(format: "%02d:%02d:%02d", h, m, s)
}

func main() {
    print("═══════════════════════════════════════════════════════════════════════")
    print("  MacMetal CLI Miner v2.9 - Debug Edition")
    print("  Bitcoin Address: bc1qagznhy7yckwjcc2cchh2808ufufhsy94qvz80x")
    print("  Worker: terminal")
    print("═══════════════════════════════════════════════════════════════════════")

    var cfg = MinerConfig()
    cfg.worker = "bc1qagznhy7yckwjcc2cchh2808ufufhsy94qvz80x.terminal"
    cfg.host = "europe.solomining.io"
    cfg.port = 7777

    // Start with common settings - flip ONE at a time if "Above target"
    cfg.prevHashMode = .wordSwap4
    cfg.merkleBranchMode = .reverseBranchBytes
    cfg.nonceSubmitEndian = .littleHeaderBytes

    print("[CONFIG] prevHashMode=\(cfg.prevHashMode)")
    print("[CONFIG] merkleBranchMode=\(cfg.merkleBranchMode)")
    print("[CONFIG] nonceSubmitEndian=\(cfg.nonceSubmitEndian)")
    print("")

    // Initialize GPU
    print("[+] Initializing Metal GPU...")
    guard let gpu = GPUMiner() else {
        print("[-] Failed to initialize GPU!")
        return
    }
    print("[+] GPU: \(gpu.gpuName)")

    // Connect to pool
    print("[+] Connecting to \(cfg.host):\(cfg.port)...")
    let stratum = StratumClient(config: cfg)

    guard stratum.connect() else {
        print("[-] Failed to connect to pool!")
        return
    }
    print("[+] Connected!")

    // Subscribe and authorize
    stratum.subscribe()
    Thread.sleep(forTimeInterval: 0.5)
    stratum.receive()

    stratum.authorize()
    Thread.sleep(forTimeInterval: 0.5)
    stratum.receive()

    // Wait for job
    print("[+] Waiting for job...")
    for _ in 0..<20 {
        stratum.receive()
        if stratum.currentJob != nil { break }
        Thread.sleep(forTimeInterval: 0.25)
    }

    guard stratum.currentJob != nil else {
        print("[-] No job received!")
        return
    }

    // Setup signal handler
    signal(SIGINT) { _ in
        print("\n[+] Stopping miner...")
        exit(0)
    }

    var nonce: UInt32 = 0
    var totalHashes: UInt64 = 0
    var sharesFound: UInt64 = 0
    var bestZeros: Int = 0
    let startTime = Date()
    var lastDisplay = Date()
    var hashesThisSecond: UInt64 = 0
    var lastHashUpdate = Date()
    var hashrate: Double = 0

    // Calculate required zeros from difficulty
    let requiredZeros = stratum.difficulty <= 1 ? 32 : Int(ceil(32.0 + log2(Double(stratum.difficulty))))
    print("[+] Mining at difficulty \(stratum.difficulty) (need \(requiredZeros) zero bits)")
    print("")

    // Start telemetry (sends stats to macmetalminer.com)
    let address = cfg.worker.components(separatedBy: ".").first ?? cfg.worker
    Telemetry.shared.start(address: address, pool: "\(cfg.host):\(cfg.port)")

    // Main mining loop
    while true {
        stratum.receive()

        guard let job = stratum.currentJob, !stratum.extranonce1.isEmpty else {
            Thread.sleep(forTimeInterval: 0.1)
            continue
        }

        let en2 = stratum.nextExtranonce2()
        let header76 = stratum.builder.buildHeader76(job: job, extranonce1: stratum.extranonce1, extranonce2: en2)

        let result = gpu.mine(header: header76, nonceStart: nonce, targetZeros: UInt32(requiredZeros))

        hashesThisSecond += result.hashes
        totalHashes += result.hashes

        if result.bestZeros > 0 && Int(result.bestZeros) > bestZeros {
            bestZeros = Int(result.bestZeros)
        }

        let now = Date()
        if now.timeIntervalSince(lastHashUpdate) >= 1.0 {
            let elapsed = now.timeIntervalSince(lastHashUpdate)
            hashrate = Double(hashesThisSecond) / elapsed
            hashesThisSecond = 0
            lastHashUpdate = now

            // Update telemetry stats
            Telemetry.shared.update(
                hashrate: hashrate,
                totalHashes: totalHashes,
                uptime: Int(now.timeIntervalSince(startTime)),
                shares: Int(sharesFound),
                bestDiff: UInt32(bestZeros)
            )
        }

        for r in result.shares {
            sharesFound += 1
            stratum.validateAndSubmit(nonce: r.nonce, header76: header76, en2: en2)
            Telemetry.shared.shareSent(difficulty: r.zeros)
        }

        nonce &+= UInt32(gpu.batchSize)

        if now.timeIntervalSince(lastDisplay) >= 1.0 {
            print("\u{1B}[2J\u{1B}[H", terminator: "")
            print("═══════════════════════════════════════════════════════════════════════")
            print("  MacMetal CLI Miner v2.9 - Debug Edition")
            print("  Worker: bc1qagznhy7yckwjcc2cchh2808ufufhsy94qvz80x.terminal")
            print("═══════════════════════════════════════════════════════════════════════")
            print("  GPU:        \(gpu.gpuName)")
            print("  Pool:       \(cfg.host):\(cfg.port)")
            print("  Hashrate:   \(formatHashrate(hashrate))")
            print("  Uptime:     \(formatUptime(now.timeIntervalSince(startTime)))")
            print("───────────────────────────────────────────────────────────────────────")
            print("  Difficulty: \(stratum.difficulty) (need \(requiredZeros) zero bits)")
            print("  Shares:     \(sharesFound)")
            print("  Best:       \(bestZeros) bits")
            print("───────────────────────────────────────────────────────────────────────")
            print("  Config:")
            print("    prevHashMode:      \(cfg.prevHashMode)")
            print("    merkleBranchMode:  \(cfg.merkleBranchMode)")
            print("    nonceSubmitEndian: \(cfg.nonceSubmitEndian)")
            print("═══════════════════════════════════════════════════════════════════════")
            print("  Press Ctrl+C to stop")
            lastDisplay = now
        }
    }
}

main()
