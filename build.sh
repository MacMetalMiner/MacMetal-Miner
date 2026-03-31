#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
#  MacMetal CLI Miner v2.1 - GPU Edition
#  Build Script for Apple Silicon Macs
#
#  Copyright (c) 2025 David Otero / Distributed Ledger Technologies
#  www.distributedledgertechnologies.com
# ═══════════════════════════════════════════════════════════════════════════════

echo ""
echo "╔══════════════════════════════════════════════════════════════════════════╗"
echo "║           MacMetal CLI Miner v2.1 - GPU Edition                          ║"
echo "║                      Build Script                                        ║"
echo "╚══════════════════════════════════════════════════════════════════════════╝"
echo ""

# Check for Swift
if ! command -v swiftc &> /dev/null; then
    echo "❌ Swift compiler not found!"
    echo "   Please install Xcode Command Line Tools:"
    echo "   xcode-select --install"
    exit 1
fi

echo "[BUILD] Compiling main.swift with Metal GPU support..."
swiftc -O -o MacMetalCLI main.swift -framework Metal -framework CoreGraphics 2>&1

if [ $? -eq 0 ]; then
    echo "[BUILD] ✅ MacMetalCLI built successfully!"
    chmod +x MacMetalCLI
    echo ""
    echo "═══════════════════════════════════════════════════════════════════════════"
    echo "BUILD COMPLETE!"
    echo "═══════════════════════════════════════════════════════════════════════════"
    echo ""
    echo "Usage:"
    echo "  ./MacMetalCLI <bitcoin_address> --pool <host:port>"
    echo ""
    echo "Examples:"
    echo "  # Connect to Ayedex Pool (local)"
    echo "  ./MacMetalCLI bc1q... --pool 127.0.0.1:3333"
    echo ""
    echo "  # Connect to public pool"
    echo "  ./MacMetalCLI bc1q... --pool public-pool.io:21496"
    echo ""
else
    echo "[BUILD] ❌ Build failed!"
    exit 1
fi
