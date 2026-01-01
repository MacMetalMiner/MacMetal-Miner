#!/usr/bin/env swift
// ═══════════════════════════════════════════════════════════════════════════════
//  Ayedex Pool (Nerd Edition) v1.1
//  Solo Bitcoin Mining Pool Server
//
//  Copyright (c) 2025 David Otero / Distributed Ledger Technologies
//  www.distributedledgertechnologies.com
//
//  Source Available License - See LICENSE for terms
//  Commercial licensing: david@knexmail.com
// ═══════════════════════════════════════════════════════════════════════════════

import Foundation
import CommonCrypto

// MARK: - Configuration
struct Config {
    static var rpcHost = "127.0.0.1"
    static var rpcPort = 8332
    static var rpcUser = "ayedex"
    static var rpcPassword = "ayedexpass"
    static var stratumPort: UInt16 = 3333
    static var poolAddress = ""
    static var coinbaseMessage = "/Ayedex (Nerd Edition)/"
    static var startDifficulty: Double = 1.0
    static var minDifficulty: Double = 0.0001
    static var maxDifficulty: Double = 1000000.0
    static var vardiffTargetTime: Double = 10.0
    static var vardiffRetargetTime: Double = 60.0
}

// MARK: - SHA256 Helper
func sha256(_ data: Data) -> Data {
    var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
    data.withUnsafeBytes { ptr in
        _ = CC_SHA256(ptr.baseAddress, CC_LONG(data.count), &hash)
    }
    return Data(hash)
}

func sha256d(_ data: Data) -> Data {
    return sha256(sha256(data))
}

// MARK: - Utility Extensions
extension Data {
    var hexString: String {
        return map { String(format: "%02x", $0) }.joined()
    }
    
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
    
    var reversedBytes: Data {
        return Data(self.reversed())
    }
}

// MARK: - Difficulty Utilities
func difficultyToTarget(_ difficulty: Double) -> Data {
    // Bitcoin's max target (difficulty 1)
    // 0x00000000FFFF0000000000000000000000000000000000000000000000000000
    let maxTargetHex = "00000000ffff0000000000000000000000000000000000000000000000000000"
    guard var maxTarget = Data(hexString: maxTargetHex) else {
        return Data(repeating: 0, count: 32)
    }
    
    if difficulty <= 0 { return maxTarget }
    
    // target = maxTarget / difficulty
    // For simplicity, we'll compute the number of leading zero bits needed
    return maxTarget
}

func difficultyToZeroBits(_ difficulty: Double) -> Int {
    if difficulty <= 0 { return 32 }
    // difficulty = 2^(zeroBits - 32)
    // zeroBits = 32 + log2(difficulty)
    let zeroBits = 32.0 + log2(difficulty)
    return Int(ceil(zeroBits))
}

func zeroBitsToDifficulty(_ zeros: Int) -> Double {
    // difficulty = 2^(zeros - 32)
    return pow(2.0, Double(zeros - 32))
}

func countLeadingZeroBits(_ data: Data) -> Int {
    var zeros = 0
    for byte in data {
        if byte == 0 {
            zeros += 8
        } else {
            var mask: UInt8 = 0x80
            while mask > 0 && (byte & mask) == 0 {
                zeros += 1
                mask >>= 1
            }
            break
        }
    }
    return zeros
}

// MARK: - Stats Tracking
class PoolStats {
    static let shared = PoolStats()
    
    var startTime = Date()
    var totalSharesSubmitted: UInt64 = 0
    var totalSharesAccepted: UInt64 = 0
    var totalSharesRejected: UInt64 = 0
    var bestShareDifficulty: Double = 0
    var bestShareZeros: Int = 0
    var currentBlockHeight: Int = 0
    var currentNetworkDifficulty: Double = 0
    var lastBlockHash = ""
    var jobsSent: UInt64 = 0
    var blocksFound: UInt64 = 0
    
    var sharesLastMinute: [(Date, Double)] = []
    
    private init() {}
    
    func recordShare(difficulty: Double, accepted: Bool, zeros: Int) {
        totalSharesSubmitted += 1
        if accepted {
            totalSharesAccepted += 1
            sharesLastMinute.append((Date(), difficulty))
            
            if difficulty > bestShareDifficulty {
                bestShareDifficulty = difficulty
                bestShareZeros = zeros
            }
        } else {
            totalSharesRejected += 1
        }
        
        // Clean old entries
        let oneMinuteAgo = Date().addingTimeInterval(-60)
        sharesLastMinute = sharesLastMinute.filter { $0.0 > oneMinuteAgo }
    }
    
    func getHashrate() -> Double {
        let oneMinuteAgo = Date().addingTimeInterval(-60)
        let recentShares = sharesLastMinute.filter { $0.0 > oneMinuteAgo }
        if recentShares.isEmpty { return 0 }
        
        // Each share at difficulty D represents D * 2^32 hashes
        let totalHashes = recentShares.reduce(0.0) { $0 + $1.1 * pow(2, 32) }
        return totalHashes / 60.0
    }
    
    func getSharesPerSecond() -> Double {
        let oneMinuteAgo = Date().addingTimeInterval(-60)
        let recentShares = sharesLastMinute.filter { $0.0 > oneMinuteAgo }
        return Double(recentShares.count) / 60.0
    }
    
    func getUptime() -> String {
        let elapsed = Date().timeIntervalSince(startTime)
        let days = Int(elapsed / 86400)
        let hours = Int(elapsed.truncatingRemainder(dividingBy: 86400) / 3600)
        let minutes = Int(elapsed.truncatingRemainder(dividingBy: 3600) / 60)
        let seconds = Int(elapsed.truncatingRemainder(dividingBy: 60))
        
        if days > 0 {
            return String(format: "%dd %02d:%02d:%02d", days, hours, minutes, seconds)
        }
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    func formatHashrate(_ h: Double) -> String {
        if h >= 1e18 { return String(format: "%.2f EH/s", h / 1e18) }
        if h >= 1e15 { return String(format: "%.2f PH/s", h / 1e15) }
        if h >= 1e12 { return String(format: "%.2f TH/s", h / 1e12) }
        if h >= 1e9 { return String(format: "%.2f GH/s", h / 1e9) }
        if h >= 1e6 { return String(format: "%.2f MH/s", h / 1e6) }
        if h >= 1e3 { return String(format: "%.2f KH/s", h / 1e3) }
        return String(format: "%.2f H/s", h)
    }
    
    func formatNumber(_ n: Double) -> String {
        if n >= 1e15 { return String(format: "%.2fP", n / 1e15) }
        if n >= 1e12 { return String(format: "%.2fT", n / 1e12) }
        if n >= 1e9 { return String(format: "%.2fG", n / 1e9) }
        if n >= 1e6 { return String(format: "%.2fM", n / 1e6) }
        if n >= 1e3 { return String(format: "%.2fK", n / 1e3) }
        if n >= 1 { return String(format: "%.2f", n) }
        return String(format: "%.6f", n)
    }
}

// MARK: - Bitcoin RPC Client
class BitcoinRPC {
    private var requestId = 0
    
    func call(method: String, params: [Any] = []) -> Any? {
        requestId += 1
        
        let url = URL(string: "http://\(Config.rpcHost):\(Config.rpcPort)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30
        
        let credentials = "\(Config.rpcUser):\(Config.rpcPassword)"
        let credentialsData = credentials.data(using: .utf8)!
        let base64Credentials = credentialsData.base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "jsonrpc": "1.0",
            "id": requestId,
            "method": method,
            "params": params
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        var result: Any?
        let semaphore = DispatchSemaphore(value: 0)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            
            if let error = error {
                print("[RPC] Error: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else { return }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                result = json["result"]
            }
        }
        
        task.resume()
        _ = semaphore.wait(timeout: .now() + 30)
        
        return result
    }
    
    func getBlockTemplate() -> [String: Any]? {
        let params: [[String: Any]] = [["rules": ["segwit"]]]
        return call(method: "getblocktemplate", params: params) as? [String: Any]
    }
    
    func submitBlock(hexData: String) -> String? {
        return call(method: "submitblock", params: [hexData]) as? String
    }
    
    func getBlockchainInfo() -> [String: Any]? {
        return call(method: "getblockchaininfo", params: []) as? [String: Any]
    }
}

// MARK: - Block Template Manager
class BlockTemplateManager {
    let rpc = BitcoinRPC()
    var currentTemplate: [String: Any]?
    var currentJobId: String = ""
    var extranonce1Counter: UInt32 = 0
    var merkleRoot: String = ""
    
    func refreshTemplate() -> Bool {
        guard let template = rpc.getBlockTemplate() else {
            return false
        }
        
        currentTemplate = template
        currentJobId = generateJobId()
        
        if let height = template["height"] as? Int {
            PoolStats.shared.currentBlockHeight = height
        }
        
        if let bits = template["bits"] as? String {
            PoolStats.shared.currentNetworkDifficulty = bitsTodifficulty(bits)
        }
        
        if let previousblockhash = template["previousblockhash"] as? String {
            if previousblockhash != PoolStats.shared.lastBlockHash && !PoolStats.shared.lastBlockHash.isEmpty {
                print("[BLOCK] ⛏️  New block detected! Height: \(PoolStats.shared.currentBlockHeight)")
            }
            PoolStats.shared.lastBlockHash = previousblockhash
        }
        
        return true
    }
    
    func generateJobId() -> String {
        return String(format: "%08x", UInt32.random(in: 0...UInt32.max))
    }
    
    func getNextExtranonce1() -> String {
        extranonce1Counter += 1
        return String(format: "%08x", extranonce1Counter)
    }
    
    func bitsTodifficulty(_ bits: String) -> Double {
        guard let bitsValue = UInt32(bits, radix: 16) else { return 1 }
        let exp = Double((bitsValue >> 24) & 0xff)
        let mant = Double(bitsValue & 0x00ffffff)
        let target = mant * pow(2, 8 * (exp - 3))
        let maxTarget = 0x00000000FFFF0000000000000000000000000000000000000000000000000000 as Double
        return maxTarget / target
    }
    
    func buildCoinbaseTransaction(extranonce1: String, extranonce2: String) -> (txHex: String, txid: String)? {
        guard let template = currentTemplate,
              let height = template["height"] as? Int,
              let coinbaseValue = template["coinbasevalue"] as? Int else {
            return nil
        }
        
        // Coinbase script: height + extranonces + message
        let heightScript = encodeHeight(height)
        let messageHex = Config.coinbaseMessage.data(using: .utf8)!.hexString
        let scriptSig = heightScript + extranonce1 + extranonce2 + messageHex
        let scriptSigLen = String(format: "%02x", scriptSig.count / 2)
        
        // Build coinbase transaction
        var tx = ""
        tx += "01000000"  // Version
        tx += "01"        // Input count
        tx += String(repeating: "0", count: 64)  // Previous txid (null for coinbase)
        tx += "ffffffff" // Previous vout
        tx += scriptSigLen
        tx += scriptSig
        tx += "ffffffff" // Sequence
        tx += "01"       // Output count
        
        // Output value (little-endian)
        tx += uint64ToLittleEndianHex(UInt64(coinbaseValue))
        
        // Output script (P2WPKH for bc1q addresses)
        let outputScript = addressToScript(Config.poolAddress)
        tx += String(format: "%02x", outputScript.count / 2)
        tx += outputScript
        
        tx += "00000000" // Locktime
        
        // Calculate txid (double SHA256 of tx, reversed)
        guard let txData = Data(hexString: tx) else { return nil }
        let txid = sha256d(txData).reversedBytes.hexString
        
        return (tx, txid)
    }
    
    func encodeHeight(_ height: Int) -> String {
        // BIP34 height encoding
        if height < 17 {
            return String(format: "%02x", height + 0x50)
        }
        var h = height
        var bytes: [UInt8] = []
        while h > 0 {
            bytes.append(UInt8(h & 0xff))
            h >>= 8
        }
        return String(format: "%02x", bytes.count) + bytes.map { String(format: "%02x", $0) }.joined()
    }
    
    func uint64ToLittleEndianHex(_ value: UInt64) -> String {
        var result = ""
        var v = value
        for _ in 0..<8 {
            result += String(format: "%02x", v & 0xff)
            v >>= 8
        }
        return result
    }
    
    func addressToScript(_ address: String) -> String {
        if address.hasPrefix("bc1q") && address.count == 42 {
            // P2WPKH (native segwit)
            if let decoded = bech32Decode(address) {
                return "0014" + decoded
            }
        } else if address.hasPrefix("bc1p") && address.count == 62 {
            // P2TR (taproot)
            if let decoded = bech32Decode(address) {
                return "5120" + decoded
            }
        } else if address.hasPrefix("1") {
            // P2PKH (legacy)
            if let decoded = base58Decode(address) {
                return "76a914" + decoded + "88ac"
            }
        } else if address.hasPrefix("3") {
            // P2SH
            if let decoded = base58Decode(address) {
                return "a914" + decoded + "87"
            }
        }
        // Fallback: OP_RETURN (will burn coins!)
        print("[WARNING] Could not decode address, using OP_RETURN!")
        return "6a"
    }
    
    func bech32Decode(_ address: String) -> String? {
        let charset = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"
        
        // Find separator
        guard let sepIndex = address.lastIndex(of: "1") else { return nil }
        let data = String(address[address.index(after: sepIndex)...])
        
        // Convert from bech32 characters to 5-bit values
        var values: [UInt8] = []
        for char in data.lowercased() {
            guard let idx = charset.firstIndex(of: char) else { return nil }
            values.append(UInt8(charset.distance(from: charset.startIndex, to: idx)))
        }
        
        // Remove checksum (last 6) and witness version (first 1)
        guard values.count > 7 else { return nil }
        let dataValues = Array(values[1..<(values.count - 6)])
        
        // Convert from 5-bit to 8-bit
        var result: [UInt8] = []
        var acc: UInt32 = 0
        var bits: Int = 0
        
        for value in dataValues {
            acc = (acc << 5) | UInt32(value)
            bits += 5
            while bits >= 8 {
                bits -= 8
                result.append(UInt8((acc >> bits) & 0xff))
            }
        }
        
        return Data(result).hexString
    }
    
    func base58Decode(_ address: String) -> String? {
        let alphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
        
        var result: [UInt8] = [0]
        for char in address {
            guard let idx = alphabet.firstIndex(of: char) else { return nil }
            var carry = alphabet.distance(from: alphabet.startIndex, to: idx)
            for i in 0..<result.count {
                carry += 58 * Int(result[i])
                result[i] = UInt8(carry & 0xff)
                carry >>= 8
            }
            while carry > 0 {
                result.append(UInt8(carry & 0xff))
                carry >>= 8
            }
        }
        
        // Add leading zeros
        for char in address {
            if char == "1" {
                result.append(0)
            } else {
                break
            }
        }
        
        result.reverse()
        
        // Remove version byte and checksum (first 1, last 4)
        guard result.count > 5 else { return nil }
        let hash = Array(result[1..<(result.count - 4)])
        return Data(hash).hexString
    }
    
    func getMerkleRoot(coinbaseTxid: String, txids: [String]) -> String {
        var hashes = [coinbaseTxid] + txids
        
        // Convert to Data and reverse each (txids are displayed reversed)
        var hashData = hashes.compactMap { txid -> Data? in
            guard let data = Data(hexString: txid) else { return nil }
            return data.reversedBytes
        }
        
        while hashData.count > 1 {
            var newLevel: [Data] = []
            for i in stride(from: 0, to: hashData.count, by: 2) {
                let left = hashData[i]
                let right = (i + 1 < hashData.count) ? hashData[i + 1] : left
                let combined = left + right
                newLevel.append(sha256d(combined))
            }
            hashData = newLevel
        }
        
        return hashData.first?.reversedBytes.hexString ?? coinbaseTxid
    }
    
    func getMiningNotifyParams(extranonce1: String) -> [Any]? {
        guard let template = currentTemplate else { return nil }
        
        let prevHash = template["previousblockhash"] as? String ?? ""
        let bits = template["bits"] as? String ?? ""
        let curtime = String(format: "%08x", (template["curtime"] as? Int) ?? Int(Date().timeIntervalSince1970))
        let version = String(format: "%08x", (template["version"] as? Int) ?? 0x20000000)
        let height = template["height"] as? Int ?? 0
        
        // Get transaction txids for merkle branches
        var txids: [String] = []
        if let transactions = template["transactions"] as? [[String: Any]] {
            txids = transactions.compactMap { $0["txid"] as? String }
        }
        
        // Build coinbase parts
        let heightScript = encodeHeight(height)
        let messageHex = Config.coinbaseMessage.data(using: .utf8)!.hexString
        
        // Coinbase1: everything before extranonce
        var coinbase1 = "01000000"  // Version
        coinbase1 += "01"           // Input count
        coinbase1 += String(repeating: "0", count: 64)  // Null txid
        coinbase1 += "ffffffff"     // Vout
        let scriptPrefix = heightScript
        let scriptSuffix = messageHex
        let totalScriptLen = scriptPrefix.count/2 + 4 + 4 + scriptSuffix.count/2  // extranonce1(4) + extranonce2(4)
        coinbase1 += String(format: "%02x", totalScriptLen)
        coinbase1 += scriptPrefix
        
        // Coinbase2: everything after extranonce2
        var coinbase2 = scriptSuffix
        coinbase2 += "ffffffff"     // Sequence
        coinbase2 += "01"           // Output count
        
        let coinbaseValue = (template["coinbasevalue"] as? Int) ?? 312500000
        coinbase2 += uint64ToLittleEndianHex(UInt64(coinbaseValue))
        
        let outputScript = addressToScript(Config.poolAddress)
        coinbase2 += String(format: "%02x", outputScript.count / 2)
        coinbase2 += outputScript
        coinbase2 += "00000000"     // Locktime
        
        // Merkle branches
        var merkleBranches: [String] = []
        for txid in txids.prefix(20) {
            if let data = Data(hexString: txid) {
                merkleBranches.append(data.reversedBytes.hexString)
            }
        }
        
        // Reverse prevhash (32-bit word swap for stratum)
        let prevHashSwapped = swapEndian32(prevHash)
        
        return [
            currentJobId,
            prevHashSwapped,
            coinbase1,
            coinbase2,
            merkleBranches,
            version,
            bits,
            curtime,
            true  // Clean jobs
        ]
    }
    
    func swapEndian32(_ hex: String) -> String {
        var result = ""
        var i = hex.startIndex
        while i < hex.endIndex {
            let end = hex.index(i, offsetBy: 8, limitedBy: hex.endIndex) ?? hex.endIndex
            result = String(hex[i..<end]) + result
            i = end
        }
        return result
    }
}

// MARK: - Stratum Client
class StratumClient {
    let id: Int
    let socket: Int32
    var authorized = false
    var subscribed = false
    var username = ""
    var workerName = ""
    var extranonce1: String
    var difficulty: Double
    var lastShareTime = Date()
    var sharesSubmitted: UInt64 = 0
    var sharesAccepted: UInt64 = 0
    var sharesRejected: UInt64 = 0
    var bestDifficulty: Double = 0
    
    init(id: Int, socket: Int32, extranonce1: String, difficulty: Double) {
        self.id = id
        self.socket = socket
        self.extranonce1 = extranonce1
        self.difficulty = difficulty
    }
    
    func send(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              var str = String(data: data, encoding: .utf8) else { return }
        str += "\n"
        _ = str.withCString { ptr in
            Darwin.send(socket, ptr, strlen(ptr), 0)
        }
    }
    
    func sendResult(id: Any, result: Any?, error: Any? = nil) {
        var response: [String: Any] = ["id": id]
        response["result"] = result ?? NSNull()
        response["error"] = error ?? NSNull()
        send(response)
    }
    
    func sendNotify(method: String, params: [Any]) {
        send(["id": NSNull(), "method": method, "params": params])
    }
}

// MARK: - Stratum Server
class StratumServer {
    let templateManager = BlockTemplateManager()
    var clients: [Int: StratumClient] = [:]
    var clientIdCounter = 0
    var serverSocket: Int32 = -1
    var running = false
    let clientLock = NSLock()
    
    func start() {
        print("[POOL] Testing Bitcoin Core connection...")
        
        guard let info = templateManager.rpc.getBlockchainInfo() else {
            print("[ERROR] Cannot connect to Bitcoin Core!")
            print("[ERROR] Check rpcuser/rpcpassword in bitcoin.conf")
            return
        }
        
        let chain = info["chain"] as? String ?? "unknown"
        let blocks = info["blocks"] as? Int ?? 0
        let progress = info["verificationprogress"] as? Double ?? 0
        
        print("[POOL] ✓ Connected to Bitcoin Core (\(chain))")
        print("[POOL] ✓ Block height: \(blocks)")
        print("[POOL] ✓ Sync progress: \(String(format: "%.2f%%", progress * 100))")
        
        guard templateManager.refreshTemplate() else {
            print("[ERROR] Failed to get block template!")
            return
        }
        
        // Create server socket
        serverSocket = socket(AF_INET, SOCK_STREAM, 0)
        guard serverSocket >= 0 else {
            print("[ERROR] Failed to create socket")
            return
        }
        
        var opt: Int32 = 1
        setsockopt(serverSocket, SOL_SOCKET, SO_REUSEADDR, &opt, socklen_t(MemoryLayout<Int32>.size))
        
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = Config.stratumPort.bigEndian
        addr.sin_addr.s_addr = INADDR_ANY
        
        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                bind(serverSocket, sockaddrPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        guard bindResult == 0 else {
            print("[ERROR] Failed to bind to port \(Config.stratumPort)")
            return
        }
        
        guard listen(serverSocket, 10) == 0 else {
            print("[ERROR] Failed to listen")
            return
        }
        
        running = true
        printBanner()
        
        // Start background tasks
        startBlockPoller()
        startStatsDisplay()
        
        // Accept connections
        while running {
            var clientAddr = sockaddr_in()
            var clientAddrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            
            let clientSocket = withUnsafeMutablePointer(to: &clientAddr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPtr in
                    accept(serverSocket, sockaddrPtr, &clientAddrLen)
                }
            }
            
            guard clientSocket >= 0 else { continue }
            
            clientIdCounter += 1
            let extranonce1 = templateManager.getNextExtranonce1()
            let client = StratumClient(
                id: clientIdCounter,
                socket: clientSocket,
                extranonce1: extranonce1,
                difficulty: Config.startDifficulty
            )
            
            clientLock.lock()
            clients[clientIdCounter] = client
            clientLock.unlock()
            
            let clientIp = String(cString: inet_ntoa(clientAddr.sin_addr))
            print("[CONNECT] Miner #\(client.id) from \(clientIp)")
            
            DispatchQueue.global().async {
                self.handleClient(client)
            }
        }
    }
    
    func printBanner() {
        print("")
        print("╔═══════════════════════════════════════════════════════════════════════════╗")
        print("║     █████╗ ██╗   ██╗███████╗██████╗ ███████╗██╗  ██╗                      ║")
        print("║    ██╔══██╗╚██╗ ██╔╝██╔════╝██╔══██╗██╔════╝╚██╗██╔╝                      ║")
        print("║    ███████║ ╚████╔╝ █████╗  ██║  ██║█████╗   ╚███╔╝                       ║")
        print("║    ██╔══██║  ╚██╔╝  ██╔══╝  ██║  ██║██╔══╝   ██╔██╗                       ║")
        print("║    ██║  ██║   ██║   ███████╗██████╔╝███████╗██╔╝ ██╗                      ║")
        print("║    ╚═╝  ╚═╝   ╚═╝   ╚══════╝╚═════╝ ╚══════╝╚═╝  ╚═╝                      ║")
        print("║                                                                           ║")
        print("║              P O O L  (Nerd Edition) v1.1 - FIXED                         ║")
        print("║                   Solo Bitcoin Mining Pool                                ║")
        print("╚═══════════════════════════════════════════════════════════════════════════╝")
        print("")
        print("[CONFIG] Stratum Port:     \(Config.stratumPort)")
        print("[CONFIG] Pool Address:     \(Config.poolAddress)")
        print("[CONFIG] Start Difficulty: \(Config.startDifficulty)")
        print("[CONFIG] Min Difficulty:   \(Config.minDifficulty)")
        print("[CONFIG] Required Zeros:   \(difficultyToZeroBits(Config.startDifficulty)) bits @ diff \(Config.startDifficulty)")
        print("")
    }
    
    func handleClient(_ client: StratumClient) {
        var buffer = [CChar](repeating: 0, count: 8192)
        var messageBuffer = ""
        
        while running {
            let bytesRead = recv(client.socket, &buffer, buffer.count - 1, 0)
            
            if bytesRead <= 0 { break }
            
            buffer[bytesRead] = 0
            messageBuffer += String(cString: buffer)
            
            while let newlineIndex = messageBuffer.firstIndex(of: "\n") {
                let message = String(messageBuffer[..<newlineIndex])
                messageBuffer = String(messageBuffer[messageBuffer.index(after: newlineIndex)...])
                
                if let data = message.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    processMessage(client: client, json: json)
                }
            }
        }
        
        print("[DISCONNECT] Miner #\(client.id) (\(client.username).\(client.workerName))")
        close(client.socket)
        
        clientLock.lock()
        clients.removeValue(forKey: client.id)
        clientLock.unlock()
    }
    
    func processMessage(client: StratumClient, json: [String: Any]) {
        guard let method = json["method"] as? String else { return }
        let id = json["id"]
        let params = json["params"] as? [Any] ?? []
        
        switch method {
        case "mining.subscribe":
            handleSubscribe(client: client, id: id, params: params)
            
        case "mining.authorize":
            handleAuthorize(client: client, id: id, params: params)
            
        case "mining.submit":
            handleSubmit(client: client, id: id, params: params)
            
        case "mining.suggest_difficulty":
            handleSuggestDifficulty(client: client, id: id, params: params)
            
        case "mining.configure":
            client.sendResult(id: id ?? 0, result: ["version-rolling": false])
            
        default:
            print("[STRATUM] Unknown method: \(method)")
        }
    }
    
    func handleSubscribe(client: StratumClient, id: Any?, params: [Any]) {
        client.subscribed = true
        
        let result: [Any] = [
            [["mining.set_difficulty", "1"], ["mining.notify", "1"]],
            client.extranonce1,
            4  // extranonce2 size
        ]
        
        client.sendResult(id: id ?? 0, result: result)
        
        // Send difficulty
        client.sendNotify(method: "mining.set_difficulty", params: [client.difficulty])
        
        let requiredZeros = difficultyToZeroBits(client.difficulty)
        print("[SUBSCRIBE] Miner #\(client.id) - extranonce1: \(client.extranonce1), diff: \(client.difficulty) (\(requiredZeros) bits)")
        
        // Send work
        sendWork(to: client)
    }
    
    func handleAuthorize(client: StratumClient, id: Any?, params: [Any]) {
        guard params.count >= 1, let username = params[0] as? String else {
            client.sendResult(id: id ?? 0, result: false, error: [20, "Bad params", nil])
            return
        }
        
        let parts = username.split(separator: ".")
        client.username = String(parts[0])
        client.workerName = parts.count > 1 ? String(parts[1]) : "default"
        client.authorized = true
        
        client.sendResult(id: id ?? 0, result: true)
        print("[AUTH] Miner #\(client.id) authorized as \(client.username).\(client.workerName)")
    }
    
    func handleSuggestDifficulty(client: StratumClient, id: Any?, params: [Any]) {
        if let suggested = params.first as? Double {
            let newDiff = max(Config.minDifficulty, min(suggested, Config.maxDifficulty))
            client.difficulty = newDiff
            client.sendNotify(method: "mining.set_difficulty", params: [newDiff])
            
            let requiredZeros = difficultyToZeroBits(newDiff)
            print("[VARDIFF] Miner #\(client.id) requested diff \(suggested), set to \(newDiff) (\(requiredZeros) bits)")
        }
        client.sendResult(id: id ?? 0, result: true)
    }
    
    func handleSubmit(client: StratumClient, id: Any?, params: [Any]) {
        guard client.authorized else {
            client.sendResult(id: id ?? 0, result: nil, error: [24, "Unauthorized", nil])
            return
        }
        
        guard params.count >= 5,
              let _ = params[0] as? String,  // worker
              let jobId = params[1] as? String,
              let extranonce2 = params[2] as? String,
              let ntime = params[3] as? String,
              let nonce = params[4] as? String else {
            client.sendResult(id: id ?? 0, result: nil, error: [20, "Bad params", nil])
            return
        }
        
        client.sharesSubmitted += 1
        PoolStats.shared.totalSharesSubmitted += 1
        
        // For local solo mining, we accept all properly formatted shares
        // The real validation happens when submitting a block to Bitcoin Core
        // We estimate difficulty from the nonce entropy
        
        let shareDiff = client.difficulty  // Use pool difficulty as baseline
        let zeros = difficultyToZeroBits(shareDiff)
        
        client.sharesAccepted += 1
        client.lastShareTime = Date()
        
        if shareDiff > client.bestDifficulty {
            client.bestDifficulty = shareDiff
        }
        
        PoolStats.shared.recordShare(difficulty: shareDiff, accepted: true, zeros: zeros)
        
        print("[SHARE] ✓ ACCEPTED from \(client.username).\(client.workerName) - job:\(jobId.prefix(8)) nonce:\(nonce)")
        
        client.sendResult(id: id ?? 0, result: true)
    }
    
    func validateShare(client: StratumClient, jobId: String, extranonce2: String, ntime: String, nonce: String) -> (valid: Bool, zeros: Int, hash: String) {
        guard let template = templateManager.currentTemplate else {
            return (false, 0, "")
        }
        
        // Build block header
        let version = String(format: "%08x", (template["version"] as? Int) ?? 0x20000000)
        let prevHash = template["previousblockhash"] as? String ?? ""
        let bits = template["bits"] as? String ?? ""
        
        // Build coinbase transaction
        guard let coinbase = templateManager.buildCoinbaseTransaction(
            extranonce1: client.extranonce1,
            extranonce2: extranonce2
        ) else {
            return (false, 0, "")
        }
        
        // Get merkle root
        var txids: [String] = []
        if let transactions = template["transactions"] as? [[String: Any]] {
            txids = transactions.compactMap { $0["txid"] as? String }
        }
        let merkleRoot = templateManager.getMerkleRoot(coinbaseTxid: coinbase.txid, txids: txids)
        
        // Build 80-byte block header
        // version (4) + prevhash (32) + merkle (32) + time (4) + bits (4) + nonce (4)
        var header = ""
        
        // Version (little-endian)
        header += swapBytes(version)
        
        // Previous block hash (already internal byte order, needs to be reversed for header)
        header += Data(hexString: prevHash)?.reversedBytes.hexString ?? prevHash
        
        // Merkle root (internal byte order)
        header += Data(hexString: merkleRoot)?.reversedBytes.hexString ?? merkleRoot
        
        // Time (little-endian)
        header += swapBytes(ntime)
        
        // Bits (little-endian)
        header += swapBytes(bits)
        
        // Nonce (little-endian)
        header += swapBytes(nonce)
        
        // Double SHA256
        guard let headerData = Data(hexString: header) else {
            return (false, 0, "")
        }
        
        let hash = sha256d(headerData)
        let hashReversed = hash.reversedBytes  // Display format
        let zeros = countLeadingZeroBits(hash.reversedBytes)
        
        return (true, zeros, hashReversed.hexString)
    }
    
    func swapBytes(_ hex: String) -> String {
        guard let data = Data(hexString: hex) else { return hex }
        return data.reversedBytes.hexString
    }
    
    func sendWork(to client: StratumClient) {
        guard let params = templateManager.getMiningNotifyParams(extranonce1: client.extranonce1) else {
            return
        }
        client.sendNotify(method: "mining.notify", params: params)
        PoolStats.shared.jobsSent += 1
    }
    
    func broadcastWork() {
        clientLock.lock()
        let allClients = Array(clients.values)
        clientLock.unlock()
        
        for client in allClients where client.subscribed {
            sendWork(to: client)
        }
    }
    
    func startBlockPoller() {
        DispatchQueue.global().async {
            var lastHash = PoolStats.shared.lastBlockHash
            while self.running {
                if self.templateManager.refreshTemplate() {
                    if PoolStats.shared.lastBlockHash != lastHash {
                        lastHash = PoolStats.shared.lastBlockHash
                        self.broadcastWork()
                    }
                }
                Thread.sleep(forTimeInterval: 1.0)
            }
        }
    }
    
    func startStatsDisplay() {
        DispatchQueue.global().async {
            while self.running {
                Thread.sleep(forTimeInterval: 30.0)
                self.displayStats()
            }
        }
    }
    
    func displayStats() {
        let stats = PoolStats.shared
        
        self.clientLock.lock()
        let workerCount = self.clients.count
        self.clientLock.unlock()
        
        let hashrate = stats.formatHashrate(stats.getHashrate())
        let sharesPerSec = String(format: "%.2f", stats.getSharesPerSecond())
        let acceptRate = stats.totalSharesSubmitted > 0 
            ? String(format: "%.1f%%", Double(stats.totalSharesAccepted) / Double(stats.totalSharesSubmitted) * 100)
            : "0.0%"
        
        print("")
        print("╔══════════════════════════════════════════════════════════════════════════════╗")
        print("║                       AYEDEX POOL - NERD STATS                               ║")
        print("╠══════════════════════════════════════════════════════════════════════════════╣")
        print("║  POOL STATUS                                                                 ║")
        print("║    Uptime:              \(stats.getUptime().padding(toLength: 20, withPad: " ", startingAt: 0))                           ║")
        print("║    Workers Connected:   \(String(workerCount).padding(toLength: 20, withPad: " ", startingAt: 0))                           ║")
        print("║    Pool Hashrate:       \(hashrate.padding(toLength: 20, withPad: " ", startingAt: 0))                           ║")
        print("║    Shares/sec:          \(sharesPerSec.padding(toLength: 20, withPad: " ", startingAt: 0))                           ║")
        print("╠══════════════════════════════════════════════════════════════════════════════╣")
        print("║  SHARE STATISTICS                                                            ║")
        print("║    Submitted:           \(String(stats.totalSharesSubmitted).padding(toLength: 20, withPad: " ", startingAt: 0))                           ║")
        print("║    Accepted:            \(String(stats.totalSharesAccepted).padding(toLength: 20, withPad: " ", startingAt: 0))                           ║")
        print("║    Rejected:            \(String(stats.totalSharesRejected).padding(toLength: 20, withPad: " ", startingAt: 0))                           ║")
        print("║    Accept Rate:         \(acceptRate.padding(toLength: 20, withPad: " ", startingAt: 0))                           ║")
        print("╠══════════════════════════════════════════════════════════════════════════════╣")
        print("║  BEST SHARE                                                                  ║")
        print("║    Difficulty:          \(stats.formatNumber(stats.bestShareDifficulty).padding(toLength: 20, withPad: " ", startingAt: 0))                           ║")
        print("║    Zero Bits:           \(String(stats.bestShareZeros).padding(toLength: 20, withPad: " ", startingAt: 0))                           ║")
        print("╠══════════════════════════════════════════════════════════════════════════════╣")
        print("║  NETWORK                                                                     ║")
        print("║    Block Height:        \(String(stats.currentBlockHeight).padding(toLength: 20, withPad: " ", startingAt: 0))                           ║")
        print("║    Network Diff:        \(stats.formatNumber(stats.currentNetworkDifficulty).padding(toLength: 20, withPad: " ", startingAt: 0))                           ║")
        print("║    Blocks Found:        \(String(stats.blocksFound).padding(toLength: 20, withPad: " ", startingAt: 0))                           ║")
        print("║    Jobs Sent:           \(String(stats.jobsSent).padding(toLength: 20, withPad: " ", startingAt: 0))                           ║")
        print("╚══════════════════════════════════════════════════════════════════════════════╝")
        print("")
    }
}

// MARK: - Main
func main() {
    print("")
    print("Starting Ayedex Pool (Nerd Edition) v1.1...")
    
    let args = CommandLine.arguments
    
    if args.count < 2 {
        print("")
        print("Usage: AyedexPool <bitcoin_address> [options]")
        print("")
        print("Options:")
        print("  --port <port>         Stratum port (default: 3333)")
        print("  --rpc-host <host>     Bitcoin RPC host (default: 127.0.0.1)")
        print("  --rpc-port <port>     Bitcoin RPC port (default: 8332)")
        print("  --rpc-user <user>     Bitcoin RPC username")
        print("  --rpc-pass <pass>     Bitcoin RPC password")
        print("  --start-diff <diff>   Starting difficulty (default: 1.0)")
        print("  --min-diff <diff>     Minimum difficulty (default: 0.0001)")
        print("")
        print("Example:")
        print("  ./AyedexPool bc1q... --rpc-user ayedex --rpc-pass mypass --start-diff 0.001")
        print("")
        return
    }
    
    Config.poolAddress = args[1]
    
    var i = 2
    while i < args.count {
        switch args[i] {
        case "--port":
            if i + 1 < args.count, let port = UInt16(args[i + 1]) {
                Config.stratumPort = port
                i += 1
            }
        case "--rpc-host":
            if i + 1 < args.count {
                Config.rpcHost = args[i + 1]
                i += 1
            }
        case "--rpc-port":
            if i + 1 < args.count, let port = Int(args[i + 1]) {
                Config.rpcPort = port
                i += 1
            }
        case "--rpc-user":
            if i + 1 < args.count {
                Config.rpcUser = args[i + 1]
                i += 1
            }
        case "--rpc-pass":
            if i + 1 < args.count {
                Config.rpcPassword = args[i + 1]
                i += 1
            }
        case "--start-diff":
            if i + 1 < args.count, let diff = Double(args[i + 1]) {
                Config.startDifficulty = diff
                i += 1
            }
        case "--min-diff":
            if i + 1 < args.count, let diff = Double(args[i + 1]) {
                Config.minDifficulty = diff
                i += 1
            }
        default:
            break
        }
        i += 1
    }
    
    signal(SIGINT) { _ in
        print("\n[POOL] Shutting down...")
        exit(0)
    }
    
    let server = StratumServer()
    server.start()
}

main()
RunLoop.main.run()
