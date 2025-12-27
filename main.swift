// MacMetal Miner v1.0 - Terminal Edition
//
// Copyright (c) 2025 David Otero / Distributed Ledger Technologies
// www.distributedledgertechnologies.com
//
// SOURCE-AVAILABLE - ALL RIGHTS RESERVED
//
// This source code is provided for inspection and verification purposes only.
// You may view this code to verify the software is safe and that mining
// rewards are sent to YOUR wallet address.
//
// PROHIBITED: Copying, modifying, distributing, or using this code in any
// other project without explicit written permission.
//
// Unauthorized use will result in DMCA takedown and legal action.
// See LICENSE file for complete terms.
//
// Purchase GUI version: https://winnertakeall.gumroad.com/l/bitcoin

import Foundation
import Metal
import Darwin

// MARK: - ANSI Colors
struct Colors {
    static let reset = "\u{001B}[0m"
    static let bold = "\u{001B}[1m"
    static let dim = "\u{001B}[2m"
    static let red = "\u{001B}[91m"
    static let green = "\u{001B}[92m"
    static let yellow = "\u{001B}[93m"
    static let blue = "\u{001B}[94m"
    static let magenta = "\u{001B}[95m"
    static let cyan = "\u{001B}[96m"
    static let gold = "\u{001B}[38;5;220m"
    static let pink = "\u{001B}[38;5;198m"
    static let lime = "\u{001B}[38;5;118m"
    static let aqua = "\u{001B}[38;5;45m"
    static let orange = "\u{001B}[38;5;208m"
    static let violet = "\u{001B}[38;5;135m"
    static let clearScreen = "\u{001B}[2J"
    static let home = "\u{001B}[H"
    static let hideCursor = "\u{001B}[?25l"
    static let showCursor = "\u{001B}[?25h"
    static let rainbow = [red, orange, yellow, green, cyan, blue, violet, pink]
}

// MARK: - Mining Result
struct MiningResult {
    var nonce: UInt32
    var hash: (UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32)
    var zeros: UInt32
}

// MARK: - Stratum Job
struct StratumJob {
    var id: String
    var prevHash: String
    var coinbase1: String
    var coinbase2: String
    var merkleBranches: [String]
    var version: String
    var nbits: String
    var ntime: String
    var cleanJobs: Bool
}

// MARK: - Block Info
struct BlockInfo {
    var height: Int
    var pool: String
    var address: String
    var reward: Double
    var timestamp: Int
}

// MARK: - Log Entry
struct LogEntry {
    var time: String
    var icon: String
    var color: String
    var message: String
}

// MARK: - GPU Miner
class GPUMiner {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let pipeline: MTLComputePipelineState
    let batchSize: Int = 1024 * 1024 * 16  // 16M hashes per batch
    
    var headerBuffer: MTLBuffer?
    var nonceBuffer: MTLBuffer?
    var hashCountBuffer: MTLBuffer?
    var resultCountBuffer: MTLBuffer?
    var resultsBuffer: MTLBuffer?
    var targetBuffer: MTLBuffer?
    
    init?() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("❌ Metal not supported")
            return nil
        }
        self.device = device
        
        guard let queue = device.makeCommandQueue() else {
            print("❌ Could not create command queue")
            return nil
        }
        self.commandQueue = queue
        
        // Load shader
        let shaderPath = NSString(string: "~/BTCMiner/SHA256.metal").expandingTildeInPath
        guard let shaderSource = try? String(contentsOfFile: shaderPath) else {
            print("❌ Could not load shader file")
            return nil
        }
        
        do {
            let library = try device.makeLibrary(source: shaderSource, options: nil)
            guard let function = library.makeFunction(name: "mine") else {
                print("❌ Could not find 'mine' function")
                return nil
            }
            self.pipeline = try device.makeComputePipelineState(function: function)
        } catch {
            print("❌ Shader compilation error: \(error)")
            return nil
        }
        
        // Create buffers
        headerBuffer = device.makeBuffer(length: 76, options: .storageModeShared)
        nonceBuffer = device.makeBuffer(length: 4, options: .storageModeShared)
        hashCountBuffer = device.makeBuffer(length: 4, options: .storageModeShared)
        resultCountBuffer = device.makeBuffer(length: 4, options: .storageModeShared)
        resultsBuffer = device.makeBuffer(length: MemoryLayout<MiningResult>.size * 100, options: .storageModeShared)
        targetBuffer = device.makeBuffer(length: 4, options: .storageModeShared)
        
        print("\(Colors.green)✅ GPU Initialized: \(device.name)\(Colors.reset)")
    }
    
    func mine(header: [UInt8], nonceStart: UInt32, targetZeros: UInt32 = 32) -> (hashes: UInt64, results: [(UInt32, UInt32)]) {
        guard header.count == 76 else { return (0, []) }
        
        memcpy(headerBuffer!.contents(), header, 76)
        
        var nonce = nonceStart
        memcpy(nonceBuffer!.contents(), &nonce, 4)
        
        memset(hashCountBuffer!.contents(), 0, 4)
        memset(resultCountBuffer!.contents(), 0, 4)
        
        var target = targetZeros
        memcpy(targetBuffer!.contents(), &target, 4)
        
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return (0, [])
        }
        
        encoder.setComputePipelineState(pipeline)
        encoder.setBuffer(headerBuffer, offset: 0, index: 0)
        encoder.setBuffer(nonceBuffer, offset: 0, index: 1)
        encoder.setBuffer(hashCountBuffer, offset: 0, index: 2)
        encoder.setBuffer(resultCountBuffer, offset: 0, index: 3)
        encoder.setBuffer(resultsBuffer, offset: 0, index: 4)
        encoder.setBuffer(targetBuffer, offset: 0, index: 5)
        
        let threadsPerGroup = min(pipeline.maxTotalThreadsPerThreadgroup, 256)
        let threadGroups = (batchSize + threadsPerGroup - 1) / threadsPerGroup
        
        encoder.dispatchThreadgroups(
            MTLSize(width: threadGroups, height: 1, depth: 1),
            threadsPerThreadgroup: MTLSize(width: threadsPerGroup, height: 1, depth: 1)
        )
        
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        let hashCount = hashCountBuffer!.contents().load(as: UInt32.self)
        let resultCount = resultCountBuffer!.contents().load(as: UInt32.self)
        
        var shares: [(UInt32, UInt32)] = []
        if resultCount > 0 {
            let resultsPtr = resultsBuffer!.contents().bindMemory(to: MiningResult.self, capacity: 100)
            for i in 0..<min(Int(resultCount), 100) {
                let result = resultsPtr[i]
                shares.append((result.nonce, result.zeros))
            }
        }
        
        return (UInt64(hashCount), shares)
    }
}

// MARK: - BSD Socket Stratum Client
class StratumClient {
    var sockfd: Int32 = -1
    var extranonce1: String = ""
    var extranonce2Size: Int = 8
    var currentJob: StratumJob?
    var address: String
    var isConnected = false
    var buffer = Data()
    
    var onJobReceived: ((StratumJob) -> Void)?
    var onConnected: (() -> Void)?
    var onLog: ((String, String, String) -> Void)?
    
    init(address: String) {
        self.address = address
    }
    
    func connect() -> Bool {
        onLog?("🌐", Colors.blue, "Connecting...")
        
        // DNS resolution
        var hints = addrinfo()
        hints.ai_family = AF_INET
        hints.ai_socktype = SOCK_STREAM
        hints.ai_protocol = IPPROTO_TCP
        
        var result: UnsafeMutablePointer<addrinfo>?
        let status = getaddrinfo("solo.ckpool.org", "3333", &hints, &result)
        
        guard status == 0, let addrInfo = result else {
            onLog?("❌", Colors.red, "DNS failed")
            return false
        }
        defer { freeaddrinfo(result) }
        
        // Create socket
        sockfd = socket(addrInfo.pointee.ai_family, addrInfo.pointee.ai_socktype, addrInfo.pointee.ai_protocol)
        guard sockfd >= 0 else {
            onLog?("❌", Colors.red, "Socket failed")
            return false
        }
        
        // Set timeout
        var timeout = timeval(tv_sec: 30, tv_usec: 0)
        setsockopt(sockfd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(sockfd, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
        
        // Connect
        let connectResult = Darwin.connect(sockfd, addrInfo.pointee.ai_addr, addrInfo.pointee.ai_addrlen)
        guard connectResult == 0 else {
            close(sockfd)
            sockfd = -1
            onLog?("❌", Colors.red, "Connect failed")
            return false
        }
        
        isConnected = true
        onLog?("✅", Colors.green, "Connected!")
        return true
    }
    
    func disconnect() {
        if sockfd >= 0 {
            close(sockfd)
            sockfd = -1
        }
        isConnected = false
    }
    
    func send(_ message: String) -> Bool {
        guard sockfd >= 0 else { return false }
        let data = message.data(using: .utf8)!
        return data.withUnsafeBytes { ptr in
            Darwin.send(sockfd, ptr.baseAddress, data.count, 0) == data.count
        }
    }
    
    func receive() -> [String] {
        guard sockfd >= 0 else { return [] }
        
        var buf = [UInt8](repeating: 0, count: 4096)
        let bytesRead = recv(sockfd, &buf, buf.count, 0)
        
        if bytesRead <= 0 {
            return []
        }
        
        buffer.append(contentsOf: buf[0..<bytesRead])
        
        var messages: [String] = []
        while let newlineIndex = buffer.firstIndex(of: 0x0A) {
            let lineData = buffer[buffer.startIndex..<newlineIndex]
            if let line = String(data: lineData, encoding: .utf8), !line.isEmpty {
                messages.append(line)
            }
            buffer.removeSubrange(buffer.startIndex...newlineIndex)
        }
        
        return messages
    }
    
    func subscribe() -> Bool {
        let msg = "{\"id\":1,\"method\":\"mining.subscribe\",\"params\":[\"MacMetalMiner/1.0\"]}\n"
        return send(msg)
    }
    
    func authorize() -> Bool {
        let msg = "{\"id\":2,\"method\":\"mining.authorize\",\"params\":[\"\(address).gpu\",\"x\"]}\n"
        return send(msg)
    }
    
    func handleMessages() {
        let messages = receive()
        for message in messages {
            parseMessage(message)
        }
    }
    
    func parseMessage(_ message: String) {
        guard let data = message.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        
        // Handle subscription response
        if let id = json["id"] as? Int, id == 1,
           let result = json["result"] as? [Any], result.count >= 3 {
            extranonce1 = result[1] as? String ?? ""
            extranonce2Size = result[2] as? Int ?? 8
            _ = authorize()
        }
        
        // Handle authorization
        if let id = json["id"] as? Int, id == 2, let result = json["result"] as? Bool, result {
            onLog?("🔑", Colors.green, "Authorized!")
            onConnected?()
        }
        
        // Handle job notification
        if let method = json["method"] as? String, method == "mining.notify",
           let params = json["params"] as? [Any], params.count >= 9 {
            let job = StratumJob(
                id: params[0] as? String ?? "",
                prevHash: params[1] as? String ?? "",
                coinbase1: params[2] as? String ?? "",
                coinbase2: params[3] as? String ?? "",
                merkleBranches: params[4] as? [String] ?? [],
                version: params[5] as? String ?? "",
                nbits: params[6] as? String ?? "",
                ntime: params[7] as? String ?? "",
                cleanJobs: params[8] as? Bool ?? false
            )
            currentJob = job
            onJobReceived?(job)
        }
    }
    
    func reconnect() -> Bool {
        disconnect()
        Thread.sleep(forTimeInterval: 3)
        if connect() {
            _ = subscribe()
            return true
        }
        return false
    }
}

// MARK: - Helper Functions
func hexToBytes(_ hex: String) -> [UInt8] {
    var bytes: [UInt8] = []
    var index = hex.startIndex
    while index < hex.endIndex {
        let nextIndex = hex.index(index, offsetBy: 2, limitedBy: hex.endIndex) ?? hex.endIndex
        if let byte = UInt8(hex[index..<nextIndex], radix: 16) {
            bytes.append(byte)
        }
        index = nextIndex
    }
    return bytes
}

func sha256d(_ data: [UInt8]) -> [UInt8] {
    var digest1 = [UInt8](repeating: 0, count: 32)
    var digest2 = [UInt8](repeating: 0, count: 32)
    
    var ctx1 = CC_SHA256_CTX()
    CC_SHA256_Init(&ctx1)
    CC_SHA256_Update(&ctx1, data, CC_LONG(data.count))
    CC_SHA256_Final(&digest1, &ctx1)
    
    var ctx2 = CC_SHA256_CTX()
    CC_SHA256_Init(&ctx2)
    CC_SHA256_Update(&ctx2, digest1, 32)
    CC_SHA256_Final(&digest2, &ctx2)
    
    return digest2
}

// CommonCrypto bridge
typealias CC_LONG = UInt32
struct CC_SHA256_CTX {
    var count: (UInt32, UInt32) = (0, 0)
    var state: (UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32) = (0, 0, 0, 0, 0, 0, 0, 0)
    var buffer: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                 UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                 UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                 UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                 UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                 UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                 UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                 UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
}

@_silgen_name("CC_SHA256_Init")
func CC_SHA256_Init(_ ctx: UnsafeMutablePointer<CC_SHA256_CTX>) -> Int32

@_silgen_name("CC_SHA256_Update")
func CC_SHA256_Update(_ ctx: UnsafeMutablePointer<CC_SHA256_CTX>, _ data: UnsafeRawPointer, _ len: CC_LONG) -> Int32

@_silgen_name("CC_SHA256_Final")
func CC_SHA256_Final(_ digest: UnsafeMutablePointer<UInt8>, _ ctx: UnsafeMutablePointer<CC_SHA256_CTX>) -> Int32

func buildHeader(job: StratumJob, extranonce1: String, extranonce2: String) -> [UInt8] {
    let coinbaseHex = job.coinbase1 + extranonce1 + extranonce2 + job.coinbase2
    let coinbase = hexToBytes(coinbaseHex)
    
    var merkle = sha256d(coinbase)
    for branch in job.merkleBranches {
        merkle = sha256d(merkle + hexToBytes(branch))
    }
    
    var header: [UInt8] = []
    
    let version = UInt32(job.version, radix: 16) ?? 0
    header += withUnsafeBytes(of: version.littleEndian) { Array($0) }
    
    let prevHash = hexToBytes(job.prevHash)
    header += prevHash.reversed()
    
    header += merkle.reversed()
    
    let ntime = UInt32(job.ntime, radix: 16) ?? 0
    header += withUnsafeBytes(of: ntime.littleEndian) { Array($0) }
    
    let nbits = hexToBytes(job.nbits)
    header += nbits.reversed()
    
    return header
}

// MARK: - Main Miner Class
class BitcoinMiner {
    let gpu: GPUMiner
    let stratum: StratumClient
    let address: String
    
    var totalHashes: UInt64 = 0
    var sessionShares: Int = 0
    var allTimeShares: Int = 0
    var blockShares: Int = 0
    var bestDiff: UInt32 = 0
    var startTime: Date
    var lastShareTime: Date?
    var btcPrice: Double = 0
    var blockHeight: Int = 0
    var blockTime: Date = Date()
    var isRunning = true
    var currentNonce: UInt32 = 0
    var reconnects: Int = 0
    var disconnects: Int = 0
    
    var soloWinners: [BlockInfo] = []
    var recentBlocks: [BlockInfo] = []
    var logEntries: [LogEntry] = []
    
    let quotes = [
        "The Times 03/Jan/2009 Chancellor on brink of second bailout",
        "If you don't believe it or don't get it, I don't have time to convince you",
        "Lost coins only make everyone else's coins worth slightly more",
        "It might make sense just to get some in case it catches on",
        "One CPU one vote",
        "Be your own bank",
        "Not your keys, not your coins",
        "HODL!",
        "Stay humble, stack sats",
        "Running bitcoin - Hal Finney"
    ]
    
    let genesisTime = 1231006505
    let halvingBlock = 1050000
    
    init?(address: String) {
        guard let gpu = GPUMiner() else { return nil }
        self.gpu = gpu
        self.address = address
        self.stratum = StratumClient(address: address)
        self.startTime = Date()
        self.allTimeShares = loadShares()
        
        setupStratum()
    }
    
    func loadShares() -> Int {
        let path = NSString(string: "~/.btc_shares.json").expandingTildeInPath
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let total = json["total"] as? Int else {
            return 0
        }
        return total
    }
    
    func saveShares() {
        let path = NSString(string: "~/.btc_shares.json").expandingTildeInPath
        let json: [String: Any] = ["total": allTimeShares, "updated": ISO8601DateFormatter().string(from: Date())]
        if let data = try? JSONSerialization.data(withJSONObject: json) {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }
    
    func addLog(_ icon: String, _ color: String, _ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let entry = LogEntry(time: formatter.string(from: Date()), icon: icon, color: color, message: message)
        logEntries.append(entry)
        if logEntries.count > 3 {
            logEntries.removeFirst()
        }
    }
    
    func setupStratum() {
        stratum.onLog = { [weak self] icon, color, message in
            self?.addLog(icon, color, message)
        }
        
        stratum.onConnected = { [weak self] in
            self?.fetchData()
        }
        
        stratum.onJobReceived = { [weak self] job in
            if job.cleanJobs {
                self?.blockTime = Date()
                self?.blockShares = 0
                self?.addLog("🧱", Colors.orange, "NEW BLOCK!")
                self?.playSound("block")
                self?.fetchData()
            }
        }
    }
    
    func playSound(_ type: String) {
        let sounds: [String: String] = [
            "share": "/System/Library/Sounds/Glass.aiff",
            "block": "/System/Library/Sounds/Blow.aiff",
            "connect": "/System/Library/Sounds/Funk.aiff",
            "start": "/System/Library/Sounds/Purr.aiff"
        ]
        if let path = sounds[type] {
            DispatchQueue.global().async {
                let task = Process()
                task.launchPath = "/usr/bin/afplay"
                task.arguments = ["-v", "1", path]
                try? task.run()
            }
        }
    }
    
    func fetchData() {
        DispatchQueue.global().async { [weak self] in
            self?.fetchPrice()
            self?.fetchSoloWinners()
            self?.fetchRecentBlocks()
        }
    }
    
    func fetchPrice() {
        guard let url = URL(string: "https://api.coinbase.com/v2/prices/BTC-USD/spot") else { return }
        if let data = try? Data(contentsOf: url),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let dataObj = json["data"] as? [String: Any],
           let amount = dataObj["amount"] as? String,
           let price = Double(amount) {
            btcPrice = price
        }
    }
    
    func fetchSoloWinners() {
        guard let url = URL(string: "https://mempool.space/api/v1/mining/pool/solock/blocks") else { return }
        if let data = try? Data(contentsOf: url),
           let blocks = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            soloWinners = blocks.prefix(7).compactMap { block in
                guard let height = block["height"] as? Int,
                      let timestamp = block["timestamp"] as? Int,
                      let extras = block["extras"] as? [String: Any] else { return nil }
                let pool = (extras["pool"] as? [String: Any])?["name"] as? String ?? "Solo"
                let addr = extras["coinbaseAddress"] as? String ?? "?"
                let fees = (extras["totalFees"] as? Double ?? 0) / 100_000_000
                return BlockInfo(height: height, pool: pool, address: addr, reward: 3.125 + fees, timestamp: timestamp)
            }
        }
    }
    
    func fetchRecentBlocks() {
        guard let url = URL(string: "https://mempool.space/api/v1/blocks") else { return }
        if let data = try? Data(contentsOf: url),
           let blocks = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            recentBlocks = blocks.prefix(7).compactMap { block in
                guard let height = block["height"] as? Int,
                      let timestamp = block["timestamp"] as? Int,
                      let extras = block["extras"] as? [String: Any] else { return nil }
                let pool = (extras["pool"] as? [String: Any])?["name"] as? String ?? "?"
                let addr = extras["coinbaseAddress"] as? String ?? "?"
                let fees = (extras["totalFees"] as? Double ?? 0) / 100_000_000
                return BlockInfo(height: height, pool: pool, address: addr, reward: 3.125 + fees, timestamp: timestamp)
            }
            if let first = recentBlocks.first {
                blockHeight = first.height
            }
        }
    }
    
    func run() {
        print("\(Colors.hideCursor)")
        playSound("start")
        
        // Connect
        guard stratum.connect() else {
            print("❌ Failed to connect")
            return
        }
        playSound("connect")
        
        _ = stratum.subscribe()
        
        // Receiver thread
        DispatchQueue.global().async { [weak self] in
            while self?.isRunning == true {
                self?.stratum.handleMessages()
                Thread.sleep(forTimeInterval: 0.01)
            }
        }
        
        // Mining thread
        DispatchQueue.global(qos: .userInteractive).async { [weak self] in
            self?.miningLoop()
        }
        
        // Data update thread
        DispatchQueue.global().async { [weak self] in
            while self?.isRunning == true {
                self?.fetchData()
                Thread.sleep(forTimeInterval: 30)
            }
        }
        
        // UI loop
        while isRunning {
            updateUI()
            Thread.sleep(forTimeInterval: 0.4)
        }
    }
    
    func miningLoop() {
        while isRunning {
            guard stratum.isConnected, let job = stratum.currentJob else {
                Thread.sleep(forTimeInterval: 0.1)
                continue
            }
            
            let extranonce2 = String(format: "%0\(stratum.extranonce2Size * 2)x", arc4random())
            let header = buildHeader(job: job, extranonce1: stratum.extranonce1, extranonce2: extranonce2)
            
            guard header.count == 76 else { continue }
            
            let (hashes, results) = gpu.mine(header: header, nonceStart: currentNonce, targetZeros: 32)
            
            totalHashes += hashes
            currentNonce = currentNonce &+ UInt32(gpu.batchSize)
            
            for (nonce, zeros) in results {
                if zeros > bestDiff {
                    bestDiff = zeros
                }
                
                if zeros >= 32 {
                    sessionShares += 1
                    allTimeShares += 1
                    blockShares += 1
                    lastShareTime = Date()
                    saveShares()
                    addLog("💰", Colors.gold, "SHARE! Zeros: \(zeros) 🎉")
                    playSound("share")
                }
            }
        }
    }
    
    func updateUI() {
        let elapsed = Date().timeIntervalSince(startTime)
        let hashrate = Double(totalHashes) / max(elapsed, 1)
        
        let hrStr: String
        let hrColor: String
        if hashrate > 1_000_000_000 {
            hrStr = String(format: "%.2f GH/s", hashrate / 1_000_000_000)
            hrColor = Colors.pink
        } else if hashrate > 1_000_000 {
            hrStr = String(format: "%.2f MH/s", hashrate / 1_000_000)
            hrColor = Colors.gold
        } else if hashrate > 1000 {
            hrStr = String(format: "%.1f KH/s", hashrate / 1000)
            hrColor = Colors.lime
        } else {
            hrStr = String(format: "%.0f H/s", hashrate)
            hrColor = Colors.cyan
        }
        
        let jackpot = 3.125 * max(btcPrice, 100000)
        let satsPerDollar = 100_000_000 / max(btcPrice, 1)
        let odds = hashrate / 800_000_000_000_000_000
        let oddsStr = odds > 0 ? String(format: "1 in %.0f", 1/odds) : "--"
        
        let blockElapsed = Int(Date().timeIntervalSince(blockTime))
        let blockMin = blockElapsed / 60
        let blockSec = blockElapsed % 60
        let blockColor = blockElapsed < 300 ? Colors.lime : (blockElapsed < 600 ? Colors.yellow : (blockElapsed < 900 ? Colors.orange : Colors.pink))
        
        let lastShareStr: String
        if let lastShare = lastShareTime {
            let since = Int(Date().timeIntervalSince(lastShare))
            lastShareStr = "\(since / 60)m\(String(format: "%02d", since % 60))s"
        } else {
            lastShareStr = "--"
        }
        
        let sharesPerHour = elapsed > 60 ? Double(sessionShares) / (elapsed / 3600) : 0
        let quote = quotes[Int(elapsed) / 30 % quotes.count]
        let uptime = formatDuration(elapsed)
        let elecCost = (120.0 / 1000.0) * (elapsed / 3600.0) * 0.21
        let halvingBlocks = halvingBlock - blockHeight
        let btcAge = Double(Int(Date().timeIntervalSince1970) - genesisTime) / 86400 / 365.25
        
        let connStr = stratum.isConnected ? "\(Colors.lime)● LIVE\(Colors.reset)" : "\(Colors.red)● OFFLINE\(Colors.reset)"
        
        var output = "\u{001B}[H\u{001B}[2J\u{001B}[3J"
        
        // Header
        output += "\(Colors.gold)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\(Colors.reset)\n"
        output += "  \(Colors.bold)\(Colors.gold)₿ MacMetal Miner v1.0\(Colors.reset)  \(Colors.pink)🎮 METAL GPU\(Colors.reset)  \(connStr)  \(hrColor)⚡ \(hrStr)\(Colors.reset)  \(Colors.aqua)🧱 #\(blockHeight)\(Colors.reset)  \(Colors.orange)⛏️\(Colors.reset)\n"
        output += "  \(Colors.gold)💰 $\(String(format: "%.2f", btcPrice))\(Colors.reset)    \(Colors.lime)🪙 \(Int(satsPerDollar)) sats/$1\(Colors.reset)    \(Colors.pink)🎰 Jackpot: $\(String(format: "%.0f", jackpot))\(Colors.reset)    \(Colors.dim)🎲 Odds: \(oddsStr)\(Colors.reset)\n"
        output += "\(Colors.gold)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\(Colors.reset)\n"
        
        // Stats
        output += "  \(Colors.dim)🎯 Best Diff:\(Colors.reset) \(Colors.lime)\(bestDiff)\(Colors.reset)    \(Colors.dim)💸 Cost:\(Colors.reset) \(Colors.red)$\(String(format: "%.4f", elecCost))\(Colors.reset)    \(Colors.dim)⏱️ Uptime:\(Colors.reset) \(Colors.aqua)\(uptime)\(Colors.reset)    \(Colors.dim)⏳ Halving:\(Colors.reset) \(Colors.pink)\(formatNumber(halvingBlocks)) blocks\(Colors.reset)\n"
        output += "  \(Colors.dim)Times Reconnected:\(Colors.reset) \(Colors.yellow)\(reconnects)\(Colors.reset)    \(Colors.dim)Times Disconnected:\(Colors.reset) \(Colors.orange)\(disconnects)\(Colors.reset)\n"
        output += "  \(Colors.dim)💬 \"\(quote)\"\(Colors.reset)\n\n"
        
        // Hashrate & Shares
        output += "\(Colors.magenta)── ⚡ HASHRATE & SHARES ──────────────────────────────────────────────────────────────────────\(Colors.reset)\n"
        output += "  \(Colors.gold)Speed:\(Colors.reset) \(hrColor)\(hrStr)\(Colors.reset)    \(Colors.gold)Hashes:\(Colors.reset) \(Colors.yellow)\(formatNumber(Int(totalHashes)))\(Colors.reset)    \(Colors.gold)Block:\(Colors.reset) \(Colors.yellow)\(blockShares)\(Colors.reset)    \(Colors.gold)Session:\(Colors.reset) \(Colors.lime)\(sessionShares)\(Colors.reset)    \(Colors.gold)Total:\(Colors.reset) \(Colors.pink)\(allTimeShares)\(Colors.reset)    \(Colors.gold)Rate:\(Colors.reset) \(Colors.aqua)\(String(format: "%.1f", sharesPerHour))/hr\(Colors.reset)    \(Colors.gold)Last:\(Colors.reset) \(Colors.cyan)\(lastShareStr)\(Colors.reset)\n\n"
        
        // Block Timer
        output += "\(Colors.violet)── ⏱️ BLOCK #\(blockHeight) ─────────────────────────────────────────────────────────────────────────────────\(Colors.reset)\n"
        output += "  \(blockColor)⏱️ \(String(format: "%02d:%02d", blockMin, blockSec)) since block\(Colors.reset)\n\n"
        
        // GPU Status
        output += "\(Colors.pink)── 🎮 GPU STATUS ─────────────────────────────────────────────────────────────────────────────\(Colors.reset)\n"
        output += "  \(Colors.lime)✅ Metal GPU Active\(Colors.reset)    \(Colors.dim)Device:\(Colors.reset) \(Colors.aqua)\(gpu.device.name)\(Colors.reset)    \(Colors.dim)Batch:\(Colors.reset) \(Colors.yellow)\(formatNumber(gpu.batchSize))\(Colors.reset)\n\n"
        
        // Solo Winners
        output += "\(Colors.gold)── ⭐ SOLO WINNERS ───────────────────────────────────────────────────────────────────────────\(Colors.reset)\n"
        output += "  \(Colors.dim)\("BLOCK".padding(toLength: 10, withPad: " ", startingAt: 0))  \("ADDRESS".padding(toLength: 44, withPad: " ", startingAt: 0))  \("REWARD".padding(toLength: 10, withPad: " ", startingAt: 0))  \("VALUE".padding(toLength: 12, withPad: " ", startingAt: 0))  AGO\(Colors.reset)\n"
        for winner in soloWinners.prefix(7) {
            let ago = (Int(Date().timeIntervalSince1970) - winner.timestamp) / 86400
            let usd = winner.reward * max(btcPrice, 100000)
            let addrShort = String(winner.address.prefix(43))
            output += "  \(Colors.aqua)#\(String(winner.height).padding(toLength: 9, withPad: " ", startingAt: 0))\(Colors.reset)  \(Colors.yellow)\(addrShort.padding(toLength: 44, withPad: " ", startingAt: 0))\(Colors.reset)  \(Colors.lime)\(String(format: "%.3f", winner.reward).padding(toLength: 9, withPad: " ", startingAt: 0))₿\(Colors.reset)  \(Colors.green)$\(String(format: "%.0f", usd).padding(toLength: 11, withPad: " ", startingAt: 0))\(Colors.reset)  \(Colors.dim)\(String(format: "%3d", ago))d\(Colors.reset)\n"
        }
        output += "\n"
        
        // Last 7 Blocks
        output += "\(Colors.orange)── 🧱 LAST 7 BLOCKS ──────────────────────────────────────────────────────────────────────────\(Colors.reset)\n"
        output += "  \(Colors.dim)\("BLOCK".padding(toLength: 10, withPad: " ", startingAt: 0))  \("POOL".padding(toLength: 14, withPad: " ", startingAt: 0))  \("MINER ADDRESS".padding(toLength: 40, withPad: " ", startingAt: 0))  \("REWARD".padding(toLength: 10, withPad: " ", startingAt: 0))  T\(Colors.reset)\n"
        for block in recentBlocks.prefix(7) {
            let poolShort = String(block.pool.prefix(13))
            let addrShort = String(block.address.prefix(39))
            let isSolo = block.pool.contains("Solo") || block.pool.contains("CK")
            let icon = isSolo ? "⭐" : "⛏"
            output += "  \(Colors.aqua)#\(String(block.height).padding(toLength: 9, withPad: " ", startingAt: 0))\(Colors.reset)  \(Colors.yellow)\(poolShort.padding(toLength: 14, withPad: " ", startingAt: 0))\(Colors.reset)  \(Colors.dim)\(addrShort.padding(toLength: 40, withPad: " ", startingAt: 0))\(Colors.reset)  \(Colors.gold)\(String(format: "%.3f", block.reward).padding(toLength: 9, withPad: " ", startingAt: 0))₿\(Colors.reset)  \(icon)\n"
        }
        output += "\n"
        
        // Log
        output += "\(Colors.green)── 📜 LOG ───────────────────────────────────────────────────────────────────────────────────\(Colors.reset)\n"
        for entry in logEntries {
            output += "  \(Colors.dim)\(entry.time)\(Colors.reset)  \(entry.icon)  \(entry.color)\(entry.message)\(Colors.reset)\n"
        }
        output += "\n"
        
        // Footer
        output += "  \(Colors.dim)₿ \(address)    🎂 \(String(format: "%.1f", btcAge)) years    📰 \"The Times 03/Jan/2009\"    ⌨️ Ctrl+C\(Colors.reset)\n"
        
        FileHandle.standardOutput.write(output.data(using: .utf8)!)
        fflush(stdout)
    }
    
    func formatDuration(_ seconds: Double) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d:%02d", h, m, s)
    }
    
    func formatNumber(_ n: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}

// MARK: - Main
let args = CommandLine.arguments
guard args.count >= 2 else {
    print("Usage: BTCMiner <BTC_ADDRESS>")
    exit(1)
}

let address = args[1]
setbuf(stdout, nil)  // Disable output buffering
print("\(Colors.gold)₿ MacMetal Miner v1.0 - Terminal Edition\(Colors.reset)")
print("\(Colors.dim)  Copyright 2025 David Otero / Distributed Ledger Technologies\(Colors.reset)")
print("\(Colors.dim)  GUI version: https://winnertakeall.gumroad.com/l/bitcoin\(Colors.reset)\n")

guard let miner = BitcoinMiner(address: address) else {
    print("❌ Failed to initialize miner")
    exit(1)
}

signal(SIGINT) { _ in
    print("\n\(Colors.showCursor)")
    print("\(Colors.gold)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\(Colors.reset)")
    print("  \(Colors.bold)SESSION COMPLETE 🏁\(Colors.reset)")
    print("\(Colors.gold)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\(Colors.reset)")
    print("  \(Colors.pink)🎰 HODL! 💎🙌\(Colors.reset)\n")
    exit(0)
}

miner.run()
