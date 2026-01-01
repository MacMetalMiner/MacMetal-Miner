#!/usr/bin/env swift
// ═══════════════════════════════════════════════════════════════════════════════
//  MacMetal CLI Miner v2.1 - GPU Edition
//  Metal GPU Accelerated Bitcoin Mining for Ayedex Pool
//
//  Copyright (c) 2025 David Otero / Distributed Ledger Technologies
//  www.distributedledgertechnologies.com
//
//  Source Available License - See LICENSE for terms
//  Commercial licensing: david@knexmail.com
// ═══════════════════════════════════════════════════════════════════════════════

import Foundation
import Metal

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

kernel void sha256_mine(
    device uchar* headerBase [[buffer(0)]],
    device uint* nonceStart [[buffer(1)]],
    device atomic_uint* hashCount [[buffer(2)]],
    device atomic_uint* resultCount [[buffer(3)]],
    device MiningResult* results [[buffer(4)]],
    device uint* targetZeros [[buffer(5)]],
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
    uint val = swap32(hash2[7]);
    if (val == 0) {
        zeros = 32; val = swap32(hash2[6]);
        if (val == 0) { zeros = 64; val = swap32(hash2[5]); if (val == 0) { zeros = 96; } else { zeros += clz(val); } }
        else { zeros += clz(val); }
    } else { zeros = clz(val); }
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

// MARK: - Configuration
struct Config {
    static var address = ""
    static var worker = "cli"
    static var password = "x"
    static var poolHost = "127.0.0.1"
    static var poolPort: UInt16 = 3333
    static let userAgent = "MacMetalCLI/2.1-GPU"
}

// MARK: - Stats
class Stats {
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
    var authorized = false
    var gpuName = "Unknown"
}
let stats = Stats()

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

func difficultyToZeroBits(_ d: Double) -> Int { d <= 0 ? 32 : Int(ceil(32.0 + log2(d))) }

// MARK: - GPU Miner
class GPUMiner {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let pipeline: MTLComputePipelineState
    let batchSize = 1024 * 1024 * 16
    var headerBuffer, nonceBuffer, hashCountBuffer, resultCountBuffer, resultsBuffer, targetBuffer: MTLBuffer?
    
    init?() {
        guard let dev = MTLCreateSystemDefaultDevice() else { return nil }
        device = dev; stats.gpuName = dev.name
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
    }
    
    func mine(header: [UInt8], nonceStart: UInt32, targetZeros: UInt32) -> (UInt64, [(UInt32, UInt32)]) {
        guard let hb = headerBuffer, let nb = nonceBuffer, let hcb = hashCountBuffer,
              let rcb = resultCountBuffer, let rb = resultsBuffer, let tb = targetBuffer else { return (0, []) }
        memcpy(hb.contents(), header, min(header.count, 76))
        var ns = nonceStart; memcpy(nb.contents(), &ns, 4)
        var t = targetZeros; memcpy(tb.contents(), &t, 4)
        memset(hcb.contents(), 0, 8); memset(rcb.contents(), 0, 4)
        guard let cb = commandQueue.makeCommandBuffer(), let enc = cb.makeComputeCommandEncoder() else { return (0, []) }
        enc.setComputePipelineState(pipeline)
        enc.setBuffer(hb, offset: 0, index: 0); enc.setBuffer(nb, offset: 0, index: 1)
        enc.setBuffer(hcb, offset: 0, index: 2); enc.setBuffer(rcb, offset: 0, index: 3)
        enc.setBuffer(rb, offset: 0, index: 4); enc.setBuffer(tb, offset: 0, index: 5)
        let tgSize = pipeline.maxTotalThreadsPerThreadgroup
        enc.dispatchThreadgroups(MTLSize(width: (batchSize + tgSize - 1) / tgSize, height: 1, depth: 1),
                                threadsPerThreadgroup: MTLSize(width: tgSize, height: 1, depth: 1))
        enc.endEncoding(); cb.commit(); cb.waitUntilCompleted()
        let hashes = hcb.contents().load(as: UInt64.self)
        let count = min(rcb.contents().load(as: UInt32.self), 100)
        var results: [(UInt32, UInt32)] = []
        let ptr = rb.contents().assumingMemoryBound(to: UInt32.self)
        for i in 0..<Int(count) { results.append((ptr[i * 10], ptr[i * 10 + 1])) }
        return (hashes, results)
    }
}

// MARK: - Stratum
struct Job { var id = "", prevHash = "", cb1 = "", cb2 = "", version = "", nbits = "", ntime = ""; var branches: [String] = [] }
var job = Job()
var gpu: GPUMiner?
var sock: Int32 = -1, msgId = 1

func send(_ s: String) { _ = s.withCString { Darwin.send(sock, $0, strlen($0), 0) } }
func subscribe() { send("{\"id\":\(msgId),\"method\":\"mining.subscribe\",\"params\":[\"\(Config.userAgent)\"]}\n"); msgId += 1 }
func authorize() { send("{\"id\":\(msgId),\"method\":\"mining.authorize\",\"params\":[\"\(Config.address).\(Config.worker)\",\"\(Config.password)\"]}\n"); msgId += 1 }
func suggestDiff(_ d: Double) { send("{\"id\":\(msgId),\"method\":\"mining.suggest_difficulty\",\"params\":[\(d)]}\n"); msgId += 1 }
func submit(_ j: String, _ e2: String, _ t: String, _ n: String) { send("{\"id\":\(msgId),\"method\":\"mining.submit\",\"params\":[\"\(Config.address).\(Config.worker)\",\"\(j)\",\"\(e2)\",\"\(t)\",\"\(n)\"]}\n"); msgId += 1; stats.sharesSubmitted += 1 }

func process(_ msg: String) {
    guard let d = msg.data(using: .utf8), let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return }
    if let m = j["method"] as? String, let p = j["params"] as? [Any] {
        if m == "mining.set_difficulty", let diff = p.first as? Double { stats.poolDifficulty = diff; stats.requiredZeros = difficultyToZeroBits(diff) }
        if m == "mining.notify", p.count >= 8 {
            job.id = p[0] as? String ?? ""; job.prevHash = p[1] as? String ?? ""
            job.cb1 = p[2] as? String ?? ""; job.cb2 = p[3] as? String ?? ""
            job.branches = p[4] as? [String] ?? []; job.version = p[5] as? String ?? ""
            job.nbits = p[6] as? String ?? ""; job.ntime = p[7] as? String ?? ""
            stats.jobsReceived += 1
        }
    }
    if let id = j["id"] as? Int {
        if id == 1, let r = j["result"] as? [Any], r.count >= 2 { stats.extranonce1 = r[1] as? String ?? ""; stats.extranonce2Size = r[2] as? Int ?? 4 }
        if id == 2, let r = j["result"] as? Bool, r { stats.authorized = true; suggestDiff(0.001) }
        if id >= 3 { if let r = j["result"] as? Bool, r { stats.sharesAccepted += 1 } else { stats.sharesRejected += 1 } }
    }
}

// MARK: - Mining
import CommonCrypto
func sha256(_ d: Data) -> Data { var h = [UInt8](repeating: 0, count: 32); d.withUnsafeBytes { CC_SHA256($0.baseAddress, CC_LONG(d.count), &h) }; return Data(h) }
func sha256d(_ d: Data) -> Data { sha256(sha256(d)) }

func buildHeader(_ e2: String) -> [UInt8]? {
    guard let cb = Data(hexString: job.cb1 + stats.extranonce1 + e2 + job.cb2) else { return nil }
    var mh = sha256d(cb)
    for b in job.branches { if let bd = Data(hexString: b) { mh = sha256d(mh + bd) } }
    var h = Data()
    if let v = Data(hexString: job.version) { h.append(v.reversedBytes) }
    var ph = ""; var i = job.prevHash.endIndex
    while i > job.prevHash.startIndex { let s = job.prevHash.index(i, offsetBy: -8, limitedBy: job.prevHash.startIndex) ?? job.prevHash.startIndex; ph += String(job.prevHash[s..<i]); i = s }
    if let p = Data(hexString: ph) { h.append(p) }
    h.append(mh)
    if let t = Data(hexString: job.ntime) { h.append(t.reversedBytes) }
    if let b = Data(hexString: job.nbits) { h.append(b.reversedBytes) }
    return Array(h)
}

var nonce: UInt32 = 0
func mine() {
    guard let g = gpu, !job.id.isEmpty else { return }
    let e2 = String(format: "%0\(stats.extranonce2Size * 2)x", UInt32.random(in: 0...UInt32.max))
    guard let hdr = buildHeader(e2) else { return }
    let t0 = Date()
    let (h, res) = g.mine(header: hdr, nonceStart: nonce, targetZeros: UInt32(stats.requiredZeros))
    stats.totalHashes += h; stats.hashrate = Double(h) / max(Date().timeIntervalSince(t0), 0.001)
    nonce &+= UInt32(g.batchSize)
    for r in res {
        stats.sharesFound += 1
        let zeros = Int(r.1)
        if zeros > 0 && zeros < 256 && zeros > stats.bestZeros { stats.bestZeros = zeros }
        submit(job.id, e2, job.ntime, String(format: "%08x", r.0.bigEndian))
    }
}

// MARK: - Display
func fmt(_ h: Double) -> String { h >= 1e9 ? String(format: "%.2f GH/s", h/1e9) : h >= 1e6 ? String(format: "%.2f MH/s", h/1e6) : String(format: "%.2f KH/s", h/1e3) }
func fmtH(_ h: UInt64) -> String { let d = Double(h); return d >= 1e12 ? String(format: "%.2fT", d/1e12) : d >= 1e9 ? String(format: "%.2fG", d/1e9) : String(format: "%.2fM", d/1e6) }
func fmtT(_ t: TimeInterval) -> String { String(format: "%02d:%02d:%02d", Int(t/3600), Int(t.truncatingRemainder(dividingBy: 3600)/60), Int(t.truncatingRemainder(dividingBy: 60))) }

func display() {
    print("\u{1B}[2J\u{1B}[H")
    print("╔══════════════════════════════════════════════════════════════════════════╗")
    print("║           MacMetal CLI Miner v2.1 - GPU Edition                          ║")
    print("╠══════════════════════════════════════════════════════════════════════════╣")
    print("║  GPU: \(stats.gpuName)".padding(toLength: 75, withPad: " ", startingAt: 0) + "║")
    print("║  Pool: \(Config.poolHost):\(Config.poolPort)".padding(toLength: 75, withPad: " ", startingAt: 0) + "║")
    print("╠══════════════════════════════════════════════════════════════════════════╣")
    print("║  Hashrate:    \(fmt(stats.hashrate))".padding(toLength: 75, withPad: " ", startingAt: 0) + "║")
    print("║  Hashes:      \(fmtH(stats.totalHashes))".padding(toLength: 75, withPad: " ", startingAt: 0) + "║")
    print("║  Uptime:      \(fmtT(Date().timeIntervalSince(stats.startTime)))".padding(toLength: 75, withPad: " ", startingAt: 0) + "║")
    print("║  Jobs:        \(stats.jobsReceived)".padding(toLength: 75, withPad: " ", startingAt: 0) + "║")
    print("╠══════════════════════════════════════════════════════════════════════════╣")
    print("║  Difficulty:  \(String(format: "%.6f", stats.poolDifficulty)) (need \(stats.requiredZeros) bits)".padding(toLength: 75, withPad: " ", startingAt: 0) + "║")
    print("║  Found:       \(stats.sharesFound)".padding(toLength: 75, withPad: " ", startingAt: 0) + "║")
    print("║  Accepted:    \(stats.sharesAccepted)".padding(toLength: 75, withPad: " ", startingAt: 0) + "║")
    print("║  Rejected:    \(stats.sharesRejected)".padding(toLength: 75, withPad: " ", startingAt: 0) + "║")
    print("║  Best:        \(stats.bestZeros) bits".padding(toLength: 75, withPad: " ", startingAt: 0) + "║")
    print("╚══════════════════════════════════════════════════════════════════════════╝")
    print("Press Ctrl+C to stop")
}

// MARK: - Main
func main() {
    let args = CommandLine.arguments
    if args.count < 2 { print("Usage: MacMetalCLI <address> [--pool host:port]"); return }
    Config.address = args[1]
    for i in 2..<args.count where args[i] == "--pool" && i+1 < args.count {
        let p = args[i+1].split(separator: ":"); Config.poolHost = String(p[0])
        if p.count > 1, let port = UInt16(p[1]) { Config.poolPort = port }
    }
    
    print("\n[+] Initializing GPU...")
    gpu = GPUMiner(); guard gpu != nil else { print("[-] No GPU!"); return }
    print("[+] GPU: \(stats.gpuName)")
    
    print("[+] Connecting to \(Config.poolHost):\(Config.poolPort)...")
    sock = socket(AF_INET, SOCK_STREAM, 0); guard sock >= 0 else { return }
    var hints = addrinfo(); hints.ai_family = AF_INET; hints.ai_socktype = SOCK_STREAM
    var res: UnsafeMutablePointer<addrinfo>?
    guard getaddrinfo(Config.poolHost, String(Config.poolPort), &hints, &res) == 0, let ai = res else { return }
    defer { freeaddrinfo(res) }
    guard connect(sock, ai.pointee.ai_addr, ai.pointee.ai_addrlen) == 0 else { print("[-] Connect failed"); return }
    print("[+] Connected!")
    
    subscribe(); Thread.sleep(forTimeInterval: 0.3)
    var buf = [CChar](repeating: 0, count: 4096)
    if recv(sock, &buf, 4095, 0) > 0 { String(cString: buf).split(separator: "\n").forEach { process(String($0)) } }
    authorize(); Thread.sleep(forTimeInterval: 0.3)
    if recv(sock, &buf, 4095, 0) > 0 { String(cString: buf).split(separator: "\n").forEach { process(String($0)) } }
    
    signal(SIGINT) { _ in print("\n[+] Shares: \(stats.sharesAccepted)/\(stats.sharesSubmitted), Best: \(stats.bestZeros) bits"); exit(0) }
    var flags = fcntl(sock, F_GETFL, 0); fcntl(sock, F_SETFL, flags | O_NONBLOCK)
    
    var lastDisplay = Date()
    while true {
        if recv(sock, &buf, 4095, 0) > 0 { String(cString: buf).split(separator: "\n").forEach { process(String($0)) } }
        if stats.authorized && !job.id.isEmpty { mine() }
        if Date().timeIntervalSince(lastDisplay) >= 1 { display(); lastDisplay = Date() }
    }
}
main()
