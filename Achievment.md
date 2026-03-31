# 🏆 The First 300+ MH/s Bitcoin Miner for Apple Silicon

## They Said It Couldn't Be Done.

**We Did It Anyway.**

---

## 🚀 World's First Native Metal GPU Bitcoin Miner Breaking 300 MH/s

For years, the experts claimed that **Bitcoin mining on Mac was impossible**. They said Apple's Metal GPU framework wasn't designed for cryptocurrency mining. They said you'd be lucky to get a few kilohashes per second. They said to stick with NVIDIA CUDA or give up.

**They were wrong.**

On **December 18, 2024**, we achieved what was thought to be impossible:

```
⚡ 352.07 MH/s on Apple M3 Pro
```

This is the **first open-source Bitcoin miner** to break the 300 MH/s barrier using Apple's native Metal compute shaders on Apple Silicon.

---

## 📊 The Numbers Don't Lie

| Metric | Achievement |
|--------|-------------|
| **Peak Hashrate** | 352.07 MH/s |
| **GPU** | Apple M3 Pro (14-core) |
| **Framework** | Native Metal Compute Shaders |
| **Improvement over Python** | 352x faster |
| **Batch Size** | 16,777,216 hashes per dispatch |

### Before vs After

| Method | Hashrate | Status |
|--------|----------|--------|
| Python CPU Mining | ~1 MH/s | ❌ Too slow |
| Python "GPU" (failed bindings) | 0 H/s | ❌ Didn't work |
| OpenCL on Mac | Deprecated | ❌ Not supported |
| CUDA on Mac | N/A | ❌ NVIDIA only |
| **MacMetal Miner** | **352 MH/s** | ✅ **IT WORKS** |

---

## 🎯 Why This Matters

### The Problem

Apple Silicon Macs have incredibly powerful GPUs. The M3 Pro has 14 GPU cores capable of 4.3 teraflops. But until now, there was **no way to use this power for Bitcoin mining**.

- ❌ CUDA doesn't exist on Mac
- ❌ OpenCL is deprecated on macOS
- ❌ Python GPU bindings don't work properly
- ❌ No native Metal miners existed

### The Solution

We built **MacMetal Miner** from scratch:

- ✅ Pure Swift + Metal implementation
- ✅ Native Apple frameworks only
- ✅ Full SHA256d implementation in Metal Shading Language
- ✅ Stratum protocol for pool connectivity
- ✅ 100% open source (MIT License)

---

## 🔬 Technical Achievement

### What We Built

1. **Metal Compute Shader** (`SHA256.metal`)
   - Complete SHA256 implementation from scratch
   - Double SHA256 (SHA256d) for Bitcoin
   - Parallel nonce testing (16M per batch)
   - Optimized for Apple GPU architecture

2. **Native Swift Host** (`main.swift`)
   - BSD socket networking (no dependencies)
   - Full Stratum protocol implementation
   - Real-time terminal UI
   - Cross-session statistics

3. **Performance Optimizations**
   - Batch size tuned for M-series GPUs
   - Memory-efficient buffer management
   - Atomic counters for parallel results
   - Zero-copy data transfers

---

## 🏅 The Achievement

### December 18, 2024

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ₿ BITCOIN LOTTERY v7.4  🎮 METAL GPU  ● LIVE  ⚡ 352.07 MH/s
  💰 $104,000    🪙 961 sats/$1    🎰 Jackpot: $325,000
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ✅ Metal GPU Active    Device: Apple M3 Pro    Batch: 16,777,216
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Verified. Documented. Open Source.**

---

## 🌟 Why You Should Care

### For Developers
- Learn Metal compute shader programming
- Understand Bitcoin's SHA256d algorithm
- See real Stratum protocol implementation
- Study high-performance Swift networking

### For Mac Users
- Finally use your M-series GPU for mining
- Run a lottery miner in the background
- Support Bitcoin decentralization
- Have fun with your hardware

### For the Bitcoin Community
- More diverse mining hardware
- Proves Apple Silicon is mining-capable
- Open source contribution
- Educational resource

---

## 📈 Expected Performance by Mac Model

| Mac | GPU Cores | Expected Hashrate |
|-----|-----------|-------------------|
| M1 | 8 | ~120 MH/s |
| M1 Pro | 14-16 | ~200 MH/s |
| M1 Max | 24-32 | ~400 MH/s |
| M1 Ultra | 48-64 | ~800 MH/s |
| M2 | 10 | ~150 MH/s |
| M2 Pro | 16-19 | ~280 MH/s |
| M2 Max | 30-38 | ~550 MH/s |
| M2 Ultra | 60-76 | ~1.1 GH/s |
| **M3 Pro** | **14-18** | **352 MH/s ✓** |
| M3 Max | 30-40 | ~600 MH/s |
| M4 | 10 | ~180 MH/s |
| M4 Pro | 20 | ~350 MH/s |
| M4 Max | 40 | ~700 MH/s |

*M2 Ultra and M4 Max could potentially break 1 GH/s!*

---

## 🔗 Get It Now

### GitHub Repository

**[github.com/SystemThreat/Mac-Pro-Bitcoin-Mining](https://github.com/SystemThreat/Mac-Pro-Bitcoin-Mining)**

### Quick Start

```bash
git clone https://github.com/SystemThreat/Mac-Pro-Bitcoin-Mining.git
cd Mac-Pro-Bitcoin-Mining
swiftc -O -o BTCMiner main.swift -framework Metal -framework Foundation
./BTCMiner YOUR_BITCOIN_ADDRESS
```

---

## 🏷️ Keywords

`bitcoin miner mac` `apple silicon mining` `metal gpu bitcoin` `m3 pro mining` `macos bitcoin miner` `swift bitcoin` `metal compute shader` `sha256 metal` `apple m1 m2 m3 m4 mining` `native mac miner` `gpu mining macos` `352 mh/s mac` `fastest mac bitcoin miner` `open source bitcoin miner mac` `stratum mac` `solo mining mac`

---

## 📜 License

MIT License - Free to use, modify, and distribute.

---

## 🙏 Credits

Built by **SystemThreat**

*"The experts said Metal GPU mining couldn't break 300 MH/s. We hit 352."*

---

**⚡ Powered by Apple Silicon | Built with Metal | Mining Bitcoin**

[![Star on GitHub](https://img.shields.io/github/stars/SystemThreat/Mac-Pro-Bitcoin-Mining?style=social)](https://github.com/SystemThreat/Mac-Pro-Bitcoin-Mining)

---

*December 2024 - The day Mac mining changed forever.*
