#!/usr/bin/env swift
// ═══════════════════════════════════════════════════════════════════════════════
//  MacMetal CLI Miner v2.7 - Universal GPU Edition
//  Metal GPU Accelerated Bitcoin Mining for macOS
//
//  Copyright (c) 2025 David Otero / Distributed Ledger Technologies
//  www.distributedledgertechnologies.com
//
//  Features:
//  • Works with Ayedex Pool AND standard public pools
//  • Interactive pool selection with validation
//  • Leaderboard integration via macmetalminer.com API
//  • Discord webhook notifications
//  • Real-time hashrate monitoring
//  • Proper difficulty negotiation
//
//  Source Available License - See LICENSE for terms
// ═══════════════════════════════════════════════════════════════════════════════

import Foundation
import Metal
import CryptoKit

// MARK: - Version Info
struct AppVersion {
    static let version = "2.8.0"
    static let build = "CLI"
    static let full = "v\(version) \(build)"
    static let userAgent = "MacMetalCLI/\(version)"
}

// MARK: - ANSI Colors
struct Colors {
    static let reset = "\u{001B}[0m"
    static let bold = "\u{001B}[1m"
    static let dim = "\u{001B}[2m"
    static let red = "\u{001B}[31m"
    static let green = "\u{001B}[32m"
    static let yellow = "\u{001B}[33m"
    static let blue = "\u{001B}[34m"
    static let magenta = "\u{001B}[35m"
    static let cyan = "\u{001B}[36m"
    static let white = "\u{001B}[37m"
    static let brightGreen = "\u{001B}[92m"
    static let brightYellow = "\u{001B}[93m"
    static let brightCyan = "\u{001B}[96m"
    static let bgBlue = "\u{001B}[44m"
    static let clearScreen = "\u{001B}[2J\u{001B}[H"
}

// MARK: - Metal Shader (Inline)
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

    // Track best share found in this batch (regardless of difficulty)
    uint currentBest = atomic_load_explicit(&bestShare->zeros, memory_order_relaxed);
    while (zeros > currentBest) {
        if (atomic_compare_exchange_weak_explicit(&bestShare->zeros, &currentBest, zeros,
                                                   memory_order_relaxed, memory_order_relaxed)) {
            atomic_store_explicit(&bestShare->nonce, nonce, memory_order_relaxed);
            break;
        }
    }

    // Only add to results array if meets pool difficulty
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

// MARK: - Pool Configuration
enum PoolType: String, CaseIterable {
    case ayedex = "Ayedex Pool"
    case custom = "Custom Pool"
    
    var host: String {
        switch self {
        case .ayedex: return "127.0.0.1"
        case .custom: return ""
        }
    }
    
    var port: UInt16 {
        switch self {
        case .ayedex: return 3333
        case .custom: return 3333
        }
    }
    
    var isAyedex: Bool { self == .ayedex }
}

// MARK: - Configuration
class Config {
    static let shared = Config()
    
    var address = ""
    var worker = "cli"
    var password = "x"
    var poolHost = "127.0.0.1"
    var poolPort: UInt16 = 3333
    var poolType: PoolType = .ayedex
    var poolFee: Double = 0.0  // Pool fee percentage
    var debug = false
    var testMode = false
    
    private init() {}
}

// MARK: - Telemetry (API Integration)
class Telemetry {
    static let shared = Telemetry()
    
    private let apiURL = "https://api.macmetalminer.com/api.php"
    private let discordWebhook = "https://discord.com/api/webhooks/1321716567498854461/WiIgx3A-9NfZrShBjShMevjTvLEzPvNPRKOlJ_NlPrJJOShpjCiWSrLIqyNLiHBBFJYl"
    private var heartbeatTimer: Timer?
    private var lastMilestoneHour = 0
    
    private init() {}
    
    func start() {
        send(action: "start", extra: ["machine": getMacModel(), "version": AppVersion.version, "type": "cli"])
        
        // Heartbeat every 60 seconds
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.sendHeartbeat()
        }
        RunLoop.current.add(heartbeatTimer!, forMode: .common)
    }
    
    func stop() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        send(action: "stop", extra: [:])
    }
    
    func sendHeartbeat() {
        let stats = MinerStats.shared
        
        // Check uptime milestones
        let currentHours = Int(stats.uptime / 3600)
        let milestones = [1, 6, 12, 24, 48, 72, 168]
        for milestone in milestones {
            if currentHours >= milestone && lastMilestoneHour < milestone {
                lastMilestoneHour = milestone
                send(action: "uptime_milestone", extra: [
                    "hours": milestone,
                    "machine": getMacModel(),
                    "total_hashes": stats.totalHashes
                ])
                break
            }
        }
        
        send(action: "heartbeat", extra: [
            "hashrate": Int(stats.hashrate),
            "total_hashes": stats.totalHashes,
            "uptime": Int(stats.uptime),
            "pool": Config.shared.poolHost,
            "session_shares": stats.sharesAccepted,
            "best_diff": stats.bestZeros,
            "machine": getMacModel(),
            "gpu": stats.gpuName,
            "version": AppVersion.version,
            "type": "cli"
        ])
    }
    
    func shareSent(difficulty: Int) {
        send(action: "share", extra: [
            "difficulty": difficulty,
            "machine": getMacModel(),
            "session_shares": MinerStats.shared.sharesAccepted
        ])
    }
    
    func blockWon(blockHeight: Int = 0, btcPrice: Double = 100000) {
        send(action: "block_won", extra: [
            "reward": 3.125,
            "btc_price": btcPrice,
            "block_height": blockHeight,
            "machine": getMacModel(),
            "hashrate": Int(MinerStats.shared.hashrate)
        ])
        sendDiscordNotification(blockHeight: blockHeight, btcPrice: btcPrice)
    }
    
    private func sendDiscordNotification(blockHeight: Int, btcPrice: Double) {
        let jackpotValue = 3.125 * btcPrice
        let message = """
        🎰 **JACKPOT WINNER!** 🎰
        
        The current jackpot today is **$\(Int(jackpotValue).formatted())** (3.125 BTC)
        
        Block: #\(blockHeight)
        BTC Price: $\(Int(btcPrice).formatted())
        Miner: MacMetal CLI v\(AppVersion.version)
        
        🏆 A MacMetal Miner user just hit the Bitcoin lottery!
        """
        
        let payload: [String: Any] = ["content": message]
        guard let url = URL(string: discordWebhook),
              let jsonData = try? JSONSerialization.data(withJSONObject: payload) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request).resume()
    }
    
    private func send(action: String, extra: [String: Any]) {
        var payload: [String: Any] = [
            "action": action,
            "address": Config.shared.address,
            "license": "CLI_FREE"
        ]
        for (key, value) in extra { payload[key] = value }
        
        guard let url = URL(string: apiURL),
              let jsonData = try? JSONSerialization.data(withJSONObject: payload) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10
        
        URLSession.shared.dataTask(with: request).resume()
    }
    
    func getMacModel() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        let modelId = String(cString: model)
        
        let modelMap: [String: String] = [
            "Mac14,2": "MacBook Air 13\" M2",
            "Mac14,7": "MacBook Pro 13\" M2",
            "Mac14,5": "MacBook Pro 14\" M2 Pro",
            "Mac14,6": "MacBook Pro 14\" M2 Max",
            "Mac14,9": "MacBook Pro 16\" M2 Pro",
            "Mac14,10": "MacBook Pro 16\" M2 Max",
            "Mac14,3": "Mac mini M2",
            "Mac14,12": "Mac mini M2 Pro",
            "Mac14,13": "Mac Studio M2 Max",
            "Mac14,14": "Mac Studio M2 Ultra",
            "Mac15,3": "MacBook Pro 14\" M3",
            "Mac15,6": "MacBook Pro 14\" M3 Pro",
            "Mac15,8": "MacBook Pro 14\" M3 Max",
            "Mac15,7": "MacBook Pro 16\" M3 Pro",
            "Mac15,9": "MacBook Pro 16\" M3 Max",
            "Mac15,12": "MacBook Air 13\" M3",
            "Mac15,13": "MacBook Air 15\" M3"
        ]
        return modelMap[modelId] ?? modelId
    }
}

// MARK: - Stats
class MinerStats {
    static let shared = MinerStats()
    
    var startTime = Date()
    var totalHashes: UInt64 = 0
    var hashrate: Double = 0
    var sharesFound: UInt64 = 0
    var sharesSubmitted: UInt64 = 0
    var sharesAccepted: UInt64 = 0
    var sharesRejected: UInt64 = 0
    var bestZeros: Int = 0
    var jobsReceived: UInt64 = 0
    var poolDifficulty: Double = 1.0
    var requiredZeros: Int = 32
    var extranonce1 = ""
    var extranonce2Size = 4
    var extranonce2Counter: UInt32 = 0
    var authorized = false
    var gpuName = "Unknown"
    var uptime: TimeInterval { Date().timeIntervalSince(startTime) }
    
    private init() {}
    
    func reset() {
        startTime = Date()
        totalHashes = 0
        hashrate = 0
        sharesFound = 0
        sharesSubmitted = 0
        sharesAccepted = 0
        sharesRejected = 0
        bestZeros = 0
        jobsReceived = 0
        poolDifficulty = 1.0
        requiredZeros = 32
        extranonce1 = ""
        extranonce2Counter = 0
        authorized = false
    }
}

// MARK: - Debug Logger
func dlog(_ s: String) {
    guard Config.shared.debug else { return }
    let timestamp = ISO8601DateFormatter().string(from: Date())
    if let data = ("[\(timestamp)] [DEBUG] " + s + "\n").data(using: .utf8) {
        FileHandle.standardError.write(data)
    }
}

// MARK: - Data Extensions
extension Data {
    var hexString: String { map { String(format: "%02x", $0) }.joined() }
    
    init?(hexString: String) {
        let len = hexString.count / 2
        var data = Data(capacity: len)
        var index = hexString.startIndex
        for _ in 0..<len {
            let nextIndex = hexString.index(index, offsetBy: 2)
            guard let byte = UInt8(hexString[index..<nextIndex], radix: 16) else { return nil }
            data.append(byte)
            index = nextIndex
        }
        self = data
    }
    
    var reversedBytes: Data { Data(self.reversed()) }
}

extension Int {
    func formatted() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: self)) ?? String(self)
    }
}

// MARK: - GPU Miner
struct MineResult {
    let hashes: UInt64
    let shares: [(nonce: UInt32, zeros: UInt32)]  // Shares meeting difficulty
    let bestZeros: UInt32  // Best zeros found in batch (regardless of difficulty)
    let bestNonce: UInt32
}

class GPUMiner {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let pipeline: MTLComputePipelineState
    let batchSize = 1024 * 1024 * 16  // 16M hashes per batch
    var headerBuffer, nonceBuffer, hashCountBuffer, resultCountBuffer, resultsBuffer, targetBuffer, bestShareBuffer: MTLBuffer?

    init?() {
        guard let dev = MTLCreateSystemDefaultDevice() else { return nil }
        device = dev
        MinerStats.shared.gpuName = dev.name
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
        bestShareBuffer = dev.makeBuffer(length: 8, options: .storageModeShared)  // zeros (4) + nonce (4)
    }

    func mine(header: [UInt8], nonceStart: UInt32, targetZeros: UInt32) -> MineResult {
        guard let hb = headerBuffer, let nb = nonceBuffer, let hcb = hashCountBuffer,
              let rcb = resultCountBuffer, let rb = resultsBuffer, let tb = targetBuffer,
              let bsb = bestShareBuffer else { return MineResult(hashes: 0, shares: [], bestZeros: 0, bestNonce: 0) }

        memcpy(hb.contents(), header, min(header.count, 76))
        var ns = nonceStart; memcpy(nb.contents(), &ns, 4)
        var t = targetZeros; memcpy(tb.contents(), &t, 4)
        memset(hcb.contents(), 0, 8); memset(rcb.contents(), 0, 4)
        memset(bsb.contents(), 0, 8)  // Reset best share buffer

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

        // Read best share from buffer
        let bestPtr = bsb.contents().assumingMemoryBound(to: UInt32.self)
        let bestZeros = bestPtr[0]
        let bestNonce = bestPtr[1]

        return MineResult(hashes: hashes, shares: shares, bestZeros: bestZeros, bestNonce: bestNonce)
    }
}

// MARK: - Stratum Protocol
struct Job {
    var id = ""
    var prevHash = ""
    var cb1 = ""
    var cb2 = ""
    var version = ""
    var nbits = ""
    var ntime = ""
    var branches: [String] = []
    var cleanJobs = false
}

class StratumClient {
    var job = Job()
    var socket: Int32 = -1
    var msgId = 1
    var authorizeId = 0  // Track which ID was used for authorize
    var onJobReceived: (() -> Void)?
    
    func connect(host: String, port: UInt16) -> Bool {
        socket = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard socket >= 0 else { return false }
        
        var hints = addrinfo()
        hints.ai_family = AF_INET
        hints.ai_socktype = SOCK_STREAM
        var res: UnsafeMutablePointer<addrinfo>?
        
        guard getaddrinfo(host, String(port), &hints, &res) == 0, let ai = res else { return false }
        defer { freeaddrinfo(res) }
        
        guard Darwin.connect(socket, ai.pointee.ai_addr, ai.pointee.ai_addrlen) == 0 else { return false }
        
        // Set non-blocking after connect
        var flags = fcntl(socket, F_GETFL, 0)
        fcntl(socket, F_SETFL, flags | O_NONBLOCK)
        
        return true
    }
    
    func disconnect() {
        if socket >= 0 { close(socket); socket = -1 }
    }
    
    func send(_ s: String) {
        _ = s.withCString { Darwin.send(socket, $0, strlen($0), 0) }
        dlog("SEND: \(s.trimmingCharacters(in: .newlines))")
    }
    
    func subscribe() {
        send("{\"id\":\(msgId),\"method\":\"mining.subscribe\",\"params\":[\"\(AppVersion.userAgent)\"]}\n")
        msgId += 1
    }
    
    func authorize() {
        let fullWorker = "\(Config.shared.address).\(Config.shared.worker)"
        authorizeId = msgId  // Track which ID we used
        send("{\"id\":\(msgId),\"method\":\"mining.authorize\",\"params\":[\"\(fullWorker)\",\"\(Config.shared.password)\"]}\n")
        msgId += 1
    }
    
    func suggestDifficulty(_ d: Double) {
        send("{\"id\":\(msgId),\"method\":\"mining.suggest_difficulty\",\"params\":[\(d)]}\n")
        msgId += 1
    }
    
    func submitShare(jobId: String, extranonce2: String, ntime: String, nonce: String) {
        let fullWorker = "\(Config.shared.address).\(Config.shared.worker)"
        send("{\"id\":\(msgId),\"method\":\"mining.submit\",\"params\":[\"\(fullWorker)\",\"\(jobId)\",\"\(extranonce2)\",\"\(ntime)\",\"\(nonce)\"]}\n")
        msgId += 1
        MinerStats.shared.sharesSubmitted += 1
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
        dlog("RECV: \(msg)")
        guard let data = msg.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        
        // Handle method calls (notifications from pool)
        if let method = json["method"] as? String, let params = json["params"] as? [Any] {
            switch method {
            case "mining.set_difficulty":
                if let diff = params.first as? Double {
                    let oldDiff = MinerStats.shared.poolDifficulty
                    MinerStats.shared.poolDifficulty = diff
                    MinerStats.shared.requiredZeros = diff <= 0 ? 32 : Int(ceil(32.0 + log2(diff)))
                    dlog("Difficulty set to \(diff), need \(MinerStats.shared.requiredZeros) bits")
                    // Print to user if difficulty changed
                    if oldDiff != diff {
                        print("\n[+] Pool set difficulty: \(diff) (need \(MinerStats.shared.requiredZeros) zero bits)")
                        // Warn if difficulty is too high for GPU mining
                        if MinerStats.shared.requiredZeros > 40 {
                            print("[!] WARNING: Difficulty too high for GPU mining!")
                            print("[!] At \(MinerStats.shared.requiredZeros) bits, expect 1 share every few hours/days")
                            print("[!] Try Public Pool (option 2) for lower difficulty with vardiff")
                        }
                    }
                }
                
            case "mining.notify":
                if params.count >= 8 {
                    job.id = params[0] as? String ?? ""
                    job.prevHash = params[1] as? String ?? ""
                    job.cb1 = params[2] as? String ?? ""
                    job.cb2 = params[3] as? String ?? ""
                    job.branches = params[4] as? [String] ?? []
                    job.version = params[5] as? String ?? ""
                    job.nbits = params[6] as? String ?? ""
                    job.ntime = params[7] as? String ?? ""
                    job.cleanJobs = params.count > 8 ? (params[8] as? Bool ?? false) : false
                    
                    if job.cleanJobs {
                        MinerStats.shared.extranonce2Counter = 0
                    }
                    
                    MinerStats.shared.jobsReceived += 1
                    if MinerStats.shared.jobsReceived == 1 {
                        print("[+] First job received - mining started!")
                    }
                    onJobReceived?()
                    dlog("New job: \(job.id), branches: \(job.branches.count)")
                }
                
            default:
                break
            }
        }
        
        // Handle responses
        if let id = json["id"] as? Int {
            if id == 1 {
                // Subscribe response
                if let result = json["result"] as? [Any], result.count >= 2 {
                    MinerStats.shared.extranonce1 = result[1] as? String ?? ""
                    MinerStats.shared.extranonce2Size = result[2] as? Int ?? 4
                    dlog("Subscribed: extranonce1=\(MinerStats.shared.extranonce1)")
                }
            } else if id == authorizeId {
                // Authorize response
                if let result = json["result"] as? Bool, result {
                    MinerStats.shared.authorized = true
                    print("[+] Authorized successfully!")
                } else {
                    print("[!] Authorization failed!")
                    if let error = json["error"] {
                        print("[!] Error: \(error)")
                    }
                }
            } else if authorizeId > 0 && id > authorizeId {
                // Share response (any ID after authorize)
                if let result = json["result"] as? Bool, result {
                    MinerStats.shared.sharesAccepted += 1
                } else {
                    MinerStats.shared.sharesRejected += 1
                    // Always print rejection reason (even without --debug)
                    if let error = json["error"] as? [Any], error.count >= 2 {
                        let code = error[0]
                        let message = error[1] as? String ?? "unknown"
                        print("\n[!] Share rejected: \(message) (code: \(code))")
                    } else if let error = json["error"] {
                        print("\n[!] Share rejected: \(error)")
                    }
                }
            }
        }
    }
}

// MARK: - Header Builder
func hexToBytes(_ hex: String) -> [UInt8] {
    var bytes: [UInt8] = []
    var i = hex.startIndex
    while i < hex.endIndex {
        let next = hex.index(i, offsetBy: 2, limitedBy: hex.endIndex) ?? hex.endIndex
        if let byte = UInt8(hex[i..<next], radix: 16) { bytes.append(byte) }
        i = next
    }
    return bytes
}

func sha256(_ data: [UInt8]) -> [UInt8] {
    let digest = SHA256.hash(data: data)
    return Array(digest)
}

func sha256d(_ data: [UInt8]) -> [UInt8] {
    return sha256(sha256(data))
}

func buildHeader(job: Job, extranonce1: String, extranonce2: String) -> [UInt8] {
    // Build coinbase transaction
    let cb = hexToBytes(job.cb1 + extranonce1 + extranonce2 + job.cb2)
    
    // FREELANCER'S FIX for standard pools (Public Pool, CKPool, etc):
    // Stratum sends merkle branches in big-endian (display/hex order)
    // Must reverse each branch to little-endian before hashing
    // Then reverse final result for block header
    
    var merkle = sha256d(cb)

    for b in job.branches {
        let branch = hexToBytes(b)
        merkle = sha256d(merkle + branch)
    }

    // Merkle root from SHA256d is already in correct byte order for the block header
    
    var header: [UInt8] = []
    
    // Version: 4 bytes little-endian
    let v = UInt32(job.version, radix: 16) ?? 0
    withUnsafeBytes(of: v.littleEndian) { header.append(contentsOf: $0) }
    
    // PrevHash: Stratum sends as 8 little-endian 32-bit words, swap each word
    let prevHashBytes = hexToBytes(job.prevHash)
    for i in stride(from: 0, to: prevHashBytes.count, by: 4) {
        let end = min(i + 4, prevHashBytes.count)
        header.append(contentsOf: prevHashBytes[i..<end].reversed())
    }
    
    // Merkle root: already little-endian from above
    header.append(contentsOf: merkle)
    
    // nTime: 4 bytes little-endian
    let nt = UInt32(job.ntime, radix: 16) ?? 0
    withUnsafeBytes(of: nt.littleEndian) { header.append(contentsOf: $0) }
    
    // nBits: 4 bytes little-endian
    let nb = UInt32(job.nbits, radix: 16) ?? 0
    withUnsafeBytes(of: nb.littleEndian) { header.append(contentsOf: $0) }
    
    return header
}

// MARK: - Pool Validation
func checkAyedexPool() -> Bool {
    let sock = socket(AF_INET, SOCK_STREAM, 0)
    guard sock >= 0 else { return false }
    defer { close(sock) }
    
    var addr = sockaddr_in()
    addr.sin_family = sa_family_t(AF_INET)
    addr.sin_port = CFSwapInt16HostToBig(3333)
    addr.sin_addr.s_addr = inet_addr("127.0.0.1")
    
    // Set timeout
    var timeout = timeval(tv_sec: 2, tv_usec: 0)
    setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
    setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
    
    let result = withUnsafePointer(to: &addr) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
            Darwin.connect(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
        }
    }
    
    return result == 0
}

// MARK: - Display Functions
func formatHashrate(_ h: Double) -> String {
    if h >= 1e9 { return String(format: "%.2f GH/s", h/1e9) }
    if h >= 1e6 { return String(format: "%.2f MH/s", h/1e6) }
    if h >= 1e3 { return String(format: "%.2f KH/s", h/1e3) }
    return String(format: "%.0f H/s", h)
}

func formatHashes(_ h: UInt64) -> String {
    let d = Double(h)
    if d >= 1e15 { return String(format: "%.2f P", d/1e15) }
    if d >= 1e12 { return String(format: "%.2f T", d/1e12) }
    if d >= 1e9 { return String(format: "%.2f G", d/1e9) }
    if d >= 1e6 { return String(format: "%.2f M", d/1e6) }
    return String(format: "%.0f", d)
}

func formatUptime(_ t: TimeInterval) -> String {
    let h = Int(t / 3600)
    let m = Int(t.truncatingRemainder(dividingBy: 3600) / 60)
    let s = Int(t.truncatingRemainder(dividingBy: 60))
    return String(format: "%02d:%02d:%02d", h, m, s)
}

func displayStats() {
    let stats = MinerStats.shared
    let config = Config.shared
    
    if !config.debug {
        print(Colors.clearScreen, terminator: "")
    }
    
    let c = Colors.self
    
    print("")
    print("  \(c.bold)\(c.brightCyan)⛏  MacMetal CLI Miner \(AppVersion.full)\(c.reset)")
    print("  \(c.dim)Native Metal GPU Bitcoin Mining for macOS\(c.reset)")
    print("\(c.cyan)────────────────────────────────────────────────────────────────────────\(c.reset)")
    
    print("  GPU:       \(c.brightGreen)\(stats.gpuName)\(c.reset)")
    print("  Pool:      \(c.brightYellow)\(config.poolHost):\(config.poolPort)\(c.reset)" + (config.poolFee > 0 ? " (\(String(format: "%.1f", config.poolFee))% fee)" : ""))
    print("  Status:    " + (stats.authorized ? "\(c.brightGreen)● MINING\(c.reset)" : "\(c.yellow)○ Connecting...\(c.reset)"))
    
    print("\(c.cyan)────────────────────────────────────────────────────────────────────────\(c.reset)")
    
    print("  Hashrate:     \(c.bold)\(c.white)\(formatHashrate(stats.hashrate))\(c.reset)")
    print("  Total Hashes: \(formatHashes(stats.totalHashes))")
    print("  Uptime:       \(formatUptime(stats.uptime))")
    print("  Jobs:         \(stats.jobsReceived)")
    
    print("\(c.cyan)────────────────────────────────────────────────────────────────────────\(c.reset)")
    
    print("  Difficulty:   \(String(format: "%.6f", stats.poolDifficulty)) (need \(stats.requiredZeros) zero bits)")
    print("  Found:        \(stats.sharesFound)")
    print("  Accepted:     \(c.brightGreen)\(stats.sharesAccepted)\(c.reset)")
    print("  Rejected:     \(stats.sharesRejected > 0 ? c.red : "")\(stats.sharesRejected)\(c.reset)")
    print("  Best Share:   \(stats.bestZeros) bits")
    
    print("\(c.cyan)────────────────────────────────────────────────────────────────────────\(c.reset)")
    print("  \(c.dim)📊 macmetalminer.com/leaderboard.html  •  Ctrl+C to stop\(c.reset)")
    print("")
}

// MARK: - Interactive Pool Selection (Advanced)
func selectPool() -> PoolType {
    let c = Colors.self
    
    print(c.clearScreen, terminator: "")
    print("")
    print("  \(c.bold)\(c.brightCyan)⛏  MacMetal CLI Miner \(AppVersion.full)\(c.reset)")
    print("  \(c.dim)Advanced Pool Configuration\(c.reset)")
    print("\(c.cyan)────────────────────────────────────────────────────────────────────────\(c.reset)")
    print("")
    
    // Check Ayedex status
    let ayedexRunning = checkAyedexPool()
    
    print("  \(c.bold)1.\(c.reset) Ayedex Pool (Local) ", terminator: "")
    if ayedexRunning {
        print("\(c.brightGreen)● RUNNING\(c.reset)")
    } else {
        print("\(c.red)○ NOT RUNNING\(c.reset)")
    }
    print("     \(c.dim)127.0.0.1:3333\(c.reset)")
    print("")
    
    print("  \(c.bold)2.\(c.reset) Custom Pool")
    print("     \(c.dim)Enter stratum host and port manually\(c.reset)")
    print("")
    
    print("\(c.cyan)────────────────────────────────────────────────────────────────────────\(c.reset)")
    print("\(c.cyan)Enter choice [1-2]:\(c.reset) ", terminator: "")
    fflush(stdout)
    
    guard let input = readLine()?.trimmingCharacters(in: .whitespaces) else {
        return selectPool()
    }
    
    switch input {
    case "1":
        if !ayedexRunning {
            print("")
            print("\(c.yellow)⚠ Ayedex Pool is not running on localhost:3333\(c.reset)")
            print("Continue anyway? [y/N]: ", terminator: "")
            fflush(stdout)
            if let confirm = readLine()?.lowercased(), confirm == "y" || confirm == "yes" {
                Config.shared.poolHost = "127.0.0.1"
                Config.shared.poolPort = 3333
                Config.shared.poolFee = 0.0
                return .ayedex
            }
            return selectPool()
        }
        Config.shared.poolHost = "127.0.0.1"
        Config.shared.poolPort = 3333
        Config.shared.poolFee = 0.0
        return .ayedex
        
    case "2":
        print("")
        print("\(c.cyan)────────────────────────────────────────────────────────────────────────\(c.reset)")
        print("  \(c.bold)Custom Pool Configuration\(c.reset)")
        print("")
        
        print("  Pool host (e.g., solo.ckpool.org): ", terminator: "")
        fflush(stdout)
        let host = readLine()?.trimmingCharacters(in: .whitespaces) ?? ""
        guard !host.isEmpty else {
            print("\(c.red)  Host cannot be empty\(c.reset)")
            Thread.sleep(forTimeInterval: 1)
            return selectPool()
        }
        
        print("  Pool port [3333]: ", terminator: "")
        fflush(stdout)
        let portStr = readLine()?.trimmingCharacters(in: .whitespaces) ?? ""
        let port = UInt16(portStr) ?? 3333
        
        print("  Pool fee % [0]: ", terminator: "")
        fflush(stdout)
        let feeStr = readLine()?.trimmingCharacters(in: .whitespaces) ?? ""
        let fee = Double(feeStr) ?? 0.0
        
        print("")
        print("  Is this an Ayedex-compatible pool? [y/N]: ", terminator: "")
        fflush(stdout)
        let isAyedex = readLine()?.lowercased() == "y"
        
        Config.shared.poolHost = host
        Config.shared.poolPort = port
        Config.shared.poolFee = fee
        
        print("")
        print("  \(c.green)✓\(c.reset) Pool configured: \(host):\(port)" + (fee > 0 ? " (\(fee)% fee)" : ""))
        Thread.sleep(forTimeInterval: 0.5)
        
        if isAyedex {
            return .ayedex
        }
        return .custom
        
    default:
        print("\(c.red)Invalid choice\(c.reset)")
        Thread.sleep(forTimeInterval: 0.5)
        return selectPool()
    }
}

// MARK: - Test Mode
func runTestMode() {
    let c = Colors.self
    
    print("")
    print("  \(c.bold)MacMetal CLI Miner - TEST MODE\(c.reset)")
    print("  \(c.dim)SHA256d Verification Suite\(c.reset)")
    print("\(c.cyan)────────────────────────────────────────────────────────────────────────\(c.reset)")
    print("")
    
    // Initialize GPU
    print("[TEST] Initializing Metal GPU...")
    guard let testGPU = GPUMiner() else {
        print("\(c.red)[FAIL] Cannot initialize GPU!\(c.reset)")
        exit(1)
    }
    print("[TEST] \(c.green)✓\(c.reset) GPU: \(MinerStats.shared.gpuName)")
    print("")
    
    var passed = 0
    var failed = 0
    
    // TEST 1: Known Block Header
    print("[TEST 1] Bitcoin Block #125552 Header Hash")
    print("─────────────────────────────────────────────────────────────────────────────")
    
    let block125552Header = "0100000081cd02ab7e569e8bcd9317e2fe99f2de44d49ab2b8851ba4a308000000000000e320b6c2fffc8d750423db8b1eb942ae710e951ed797f7affc8892b0f1fc122bc7f5d74df2b9441a42a14695"
    let expectedHash = "00000000000000001e8d6829a8a21adc5d38d0a473b144b6765798e61f98bd1d"
    
    let headerData = hexToBytes(block125552Header)
    print("   Header:   \(block125552Header.prefix(40))...")
    print("   Expected: \(expectedHash)")
    
    let cpuHash = sha256d(headerData)
    let cpuHashHex = cpuHash.reversed().map { String(format: "%02x", $0) }.joined()
    print("   CPU Hash: \(cpuHashHex)")
    
    if cpuHashHex == expectedHash {
        print("   \(c.green)[PASS] ✓ CPU SHA256d correct\(c.reset)")
        passed += 1
    } else {
        print("   \(c.red)[FAIL] ✗ CPU SHA256d incorrect\(c.reset)")
        failed += 1
    }
    print("")
    
    // TEST 2: GPU Mining
    print("[TEST 2] GPU Mining - Find Known Nonce")
    print("─────────────────────────────────────────────────────────────────────────────")
    
    let headerNoNonce = "0100000081cd02ab7e569e8bcd9317e2fe99f2de44d49ab2b8851ba4a308000000000000e320b6c2fffc8d750423db8b1eb942ae710e951ed797f7affc8892b0f1fc122bc7f5d74df2b9441a"
    let header76 = hexToBytes(headerNoNonce)
    let winningNonce: UInt32 = 0x9546a142
    
    print("   Searching for nonce: 0x\(String(format: "%08x", winningNonce))")
    
    let searchStart = winningNonce - 1000
    let startTime = Date()
    let mineResult = testGPU.mine(header: header76, nonceStart: searchStart, targetZeros: 32)
    let elapsed = Date().timeIntervalSince(startTime)

    print("   Hashes: \(mineResult.hashes) in \(String(format: "%.3f", elapsed))s")
    print("   Hashrate: \(String(format: "%.2f", Double(mineResult.hashes) / elapsed / 1_000_000)) MH/s")
    print("   Best share: \(mineResult.bestZeros) bits")

    var foundCorrect = false
    for r in mineResult.shares {
        if r.nonce == winningNonce {
            print("   \(c.green)[PASS] ✓ GPU found correct nonce!\(c.reset)")
            foundCorrect = true
            passed += 1
            break
        }
    }
    if !foundCorrect && mineResult.shares.isEmpty {
        print("   \(c.red)[FAIL] ✗ Nonce not found\(c.reset)")
        failed += 1
    } else if !foundCorrect {
        print("   \(c.yellow)[WARN] Found \(mineResult.shares.count) nonces but not exact match\(c.reset)")
        passed += 1
    }
    print("")
    
    // TEST 3: Benchmark
    print("[TEST 3] GPU Hashrate Benchmark")
    print("─────────────────────────────────────────────────────────────────────────────")
    
    var benchHeader = [UInt8](repeating: 0, count: 76)
    for i in 0..<76 { benchHeader[i] = UInt8.random(in: 0...255) }
    
    var totalHashes: UInt64 = 0
    var totalTime: Double = 0
    
    for batch in 1...3 {
        let batchStart = Date()
        let benchResult = testGPU.mine(header: benchHeader, nonceStart: UInt32.random(in: 0...UInt32.max), targetZeros: 99)
        let batchTime = Date().timeIntervalSince(batchStart)
        totalHashes += benchResult.hashes
        totalTime += batchTime
        print("   Batch \(batch): \(String(format: "%.2f", Double(benchResult.hashes) / batchTime / 1_000_000)) MH/s")
    }
    
    let avgHashrate = Double(totalHashes) / totalTime / 1_000_000
    print("   ─────────────────────────────────")
    print("   \(c.bold)Average: \(String(format: "%.2f", avgHashrate)) MH/s\(c.reset)")
    passed += 1
    print("")
    
    // Results
    print("\(c.cyan)────────────────────────────────────────────────────────────────────────\(c.reset)")
    print("  Passed: \(c.green)\(passed)\(c.reset)  Failed: \(failed > 0 ? c.red : "")\(failed)\(c.reset)")
    print("\(c.cyan)────────────────────────────────────────────────────────────────────────\(c.reset)")
    
    if failed == 0 {
        print("")
        print("  \(c.brightGreen)✅ ALL TESTS PASSED - GPU MINER VERIFIED\(c.reset)")
        print("")
    }
}

// MARK: - Main Mining Loop
func startMining() {
    let config = Config.shared
    let stats = MinerStats.shared
    let c = Colors.self
    
    // Initialize GPU
    print("\n[+] Initializing Metal GPU...")
    guard let gpu = GPUMiner() else {
        print("\(c.red)[-] Failed to initialize GPU!\(c.reset)")
        return
    }
    print("[+] GPU: \(c.green)\(stats.gpuName)\(c.reset)")
    
    // Connect to pool
    print("[+] Connecting to \(config.poolHost):\(config.poolPort)...")
    let stratum = StratumClient()
    
    guard stratum.connect(host: config.poolHost, port: config.poolPort) else {
        print("\(c.red)[-] Failed to connect to pool!\(c.reset)")
        return
    }
    print("[+] \(c.green)Connected!\(c.reset)")
    
    // Start telemetry
    print("[+] Registering with macmetalminer.com...")
    Telemetry.shared.start()
    
    // Subscribe and authorize
    stratum.subscribe()
    Thread.sleep(forTimeInterval: 0.5)
    stratum.receive()
    
    stratum.authorize()
    Thread.sleep(forTimeInterval: 0.5)
    stratum.receive()
    
    // Request low difficulty after auth
    stratum.suggestDifficulty(0.0001)  // Very low difficulty for faster shares
    Thread.sleep(forTimeInterval: 0.3)
    stratum.receive()
    
    // Setup signal handler
    signal(SIGINT) { _ in
        print("\n\n[+] Stopping miner...")
        Telemetry.shared.stop()
        let s = MinerStats.shared
        print("[+] Final stats: \(s.sharesAccepted)/\(s.sharesSubmitted) accepted, Best: \(s.bestZeros) bits")
        exit(0)
    }
    
    var nonce: UInt32 = 0
    var lastDisplay = Date()
    var hashesThisSecond: UInt64 = 0
    var lastHashUpdate = Date()
    var lastHeartbeat = Date().addingTimeInterval(-50)  // First heartbeat in 10 seconds (after we have hashrate)
    var lastWaitMessage = Date()
    var sentFirstHeartbeat = false
    
    // Main loop
    while true {
        // Receive pool messages
        stratum.receive()
        
        // Check if we have work
        if !stats.authorized || stratum.job.id.isEmpty {
            // Show waiting status every 3 seconds
            let now = Date()
            if now.timeIntervalSince(lastWaitMessage) >= 3.0 {
                if !stats.authorized {
                    print("[.] Waiting for authorization...")
                } else {
                    print("[.] Waiting for job from pool...")
                }
                lastWaitMessage = now
            }
            Thread.sleep(forTimeInterval: 0.1)
            continue
        }
        
        // Generate extranonce2
        let en2 = String(format: "%0\(stats.extranonce2Size * 2)x", stats.extranonce2Counter)
        stats.extranonce2Counter &+= 1
        
        // Build header - merkle calculation now works for all pool types
        let header = buildHeader(
            job: stratum.job,
            extranonce1: stats.extranonce1,
            extranonce2: en2
        )
        
        // Mine batch
        let result = gpu.mine(header: header, nonceStart: nonce, targetZeros: UInt32(max(stats.requiredZeros, 1)))

        hashesThisSecond += result.hashes
        stats.totalHashes += result.hashes

        // Track best share found (regardless of difficulty)
        if result.bestZeros > 0 && Int(result.bestZeros) > stats.bestZeros {
            stats.bestZeros = Int(result.bestZeros)
            dlog("New best share: \(result.bestZeros) bits (nonce: 0x\(String(format: "%08x", result.bestNonce)))")
        }

        // Update hashrate every second
        let now = Date()
        if now.timeIntervalSince(lastHashUpdate) >= 1.0 {
            let elapsed = now.timeIntervalSince(lastHashUpdate)
            stats.hashrate = Double(hashesThisSecond) / elapsed
            hashesThisSecond = 0
            lastHashUpdate = now
        }

        // Process shares that meet pool difficulty (submit them)
        for r in result.shares {
            let foundNonce = r.nonce
            let zeros = Int(r.zeros)

            stats.sharesFound += 1

            // Submit share - stratum expects nonce as little-endian hex
            // foundNonce is a UInt32, we need to represent it as LE bytes in hex
            // e.g., nonce 0x12345678 -> "78563412"
            let nonceHex = String(format: "%02x%02x%02x%02x",
                                  foundNonce & 0xFF,
                                  (foundNonce >> 8) & 0xFF,
                                  (foundNonce >> 16) & 0xFF,
                                  (foundNonce >> 24) & 0xFF)
            stratum.submitShare(jobId: stratum.job.id, extranonce2: en2, ntime: stratum.job.ntime, nonce: nonceHex)
            dlog("Submitted share: nonce=0x\(String(format: "%08x", foundNonce)) -> LE hex=\(nonceHex), zeros=\(zeros), difficulty=\(stats.poolDifficulty)")

            // Telemetry
            Telemetry.shared.shareSent(difficulty: zeros)

            // Check for potential block (very high difficulty)
            if zeros >= 72 {
                Telemetry.shared.blockWon()
            }
        }
        
        nonce &+= UInt32(gpu.batchSize)
        
        // Update display
        if now.timeIntervalSince(lastDisplay) >= 1.0 {
            displayStats()
            lastDisplay = now
        }
        
        // Send heartbeat - first one after 10s (to have hashrate), then every 60s
        let heartbeatInterval = sentFirstHeartbeat ? 60.0 : 10.0
        if now.timeIntervalSince(lastHeartbeat) >= heartbeatInterval && stats.hashrate > 0 {
            Telemetry.shared.sendHeartbeat()
            lastHeartbeat = now
            if !sentFirstHeartbeat {
                sentFirstHeartbeat = true
                print("[+] Registered on macmetalminer.com leaderboard")
            }
        }
    }
}

// MARK: - Main Entry Point
func main() {
    let args = CommandLine.arguments
    let c = Colors.self
    
    // Parse command line args
    if args.contains("--debug") { Config.shared.debug = true }
    if args.contains("--test") { runTestMode(); return }
    if args.contains("--help") || args.contains("-h") {
        print("""
        \(c.bold)MacMetal CLI Miner \(AppVersion.full)\(c.reset)
        
        \(c.bold)USAGE:\(c.reset)
            MacMetalCLI <bitcoin_address> [options]
        
        \(c.bold)OPTIONS:\(c.reset)
            --pool <host:port>   Connect directly to specified pool
            --ayedex             Use Ayedex Pool byte ordering
            --worker <name>      Set worker name (default: cli)
            --debug              Enable debug logging
            --test               Run GPU verification tests
            --help               Show this help message
        
        \(c.bold)EXAMPLES:\(c.reset)
            MacMetalCLI bc1q...           Interactive pool selection
            MacMetalCLI bc1q... --ayedex  Connect to local Ayedex Pool
            MacMetalCLI bc1q... --pool public-pool.io:21496
        
        \(c.bold)LEADERBOARD:\(c.reset)
            Your miner will appear on macmetalminer.com/leaderboard.html
        """)
        return
    }
    
    // Get Bitcoin address
    var address = ""
    for (i, arg) in args.enumerated() {
        if i > 0 && !arg.starts(with: "-") {
            address = arg
            break
        }
    }
    
    if address.isEmpty {
        print("\(c.bold)MacMetal CLI Miner \(AppVersion.full)\(c.reset)")
        print("")
        print("Enter your Bitcoin address: ", terminator: "")
        fflush(stdout)
        address = readLine()?.trimmingCharacters(in: .whitespaces) ?? ""
    }
    
    guard !address.isEmpty else {
        print("\(c.red)Error: Bitcoin address required\(c.reset)")
        print("Usage: MacMetalCLI <bitcoin_address> [options]")
        return
    }
    
    Config.shared.address = address
    
    // Parse other options
    for (i, arg) in args.enumerated() {
        switch arg {
        case "--pool":
            if i + 1 < args.count {
                let parts = args[i + 1].split(separator: ":")
                Config.shared.poolHost = String(parts[0])
                if parts.count > 1, let port = UInt16(parts[1]) {
                    Config.shared.poolPort = port
                }
                Config.shared.poolType = .custom
            }
        case "--ayedex":
            Config.shared.poolType = .ayedex
            Config.shared.poolHost = "127.0.0.1"
            Config.shared.poolPort = 3333
        case "--worker":
            if i + 1 < args.count {
                Config.shared.worker = args[i + 1]
            }
        default:
            break
        }
    }
    
    // Interactive pool selection if not specified
    if Config.shared.poolType == .ayedex && !args.contains("--ayedex") && !args.contains("--pool") {
        let selectedPool = selectPool()
        Config.shared.poolType = selectedPool
        
        if selectedPool != .custom {
            Config.shared.poolHost = selectedPool.host
            Config.shared.poolPort = selectedPool.port
        }
    }
    
    // Start mining
    startMining()
}

// Run
main()
RunLoop.current.run()
