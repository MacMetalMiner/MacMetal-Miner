#!/bin/bash
#
# MacMetal Miner v1.0 - Build Script
# Copyright (c) 2025 David Otero / Distributed Ledger Technologies
# www.distributedledgertechnologies.com
#
# SOURCE-AVAILABLE - See LICENSE for terms
#

set -e

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║           MacMetal Miner v1.0 - Build Script               ║"
echo "║     Copyright 2025 David Otero / Distributed Ledger Tech   ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Check for Xcode command line tools
if ! command -v swiftc &> /dev/null; then
    echo "❌ Swift compiler not found!"
    echo "   Please install Xcode Command Line Tools:"
    echo "   xcode-select --install"
    exit 1
fi

# Check macOS version
MACOS_VERSION=$(sw_vers -productVersion)
echo "✓ macOS version: $MACOS_VERSION"

# Check for Apple Silicon
ARCH=$(uname -m)
echo "✓ Architecture: $ARCH"

# Check for Metal shader
if [ ! -f "SHA256.metal" ]; then
    echo "❌ SHA256.metal not found in current directory!"
    exit 1
fi
echo "✓ Metal shader found"

# Compile
echo ""
echo "Compiling..."
swiftc -O -o BTCMiner main.swift \
    -framework Metal \
    -framework Foundation \
    -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker /dev/null

# Check result
if [ -f "BTCMiner" ]; then
    echo ""
    echo "✅ Build successful!"
    echo ""
    echo "Binary size: $(du -h BTCMiner | cut -f1)"
    echo ""
    echo "Usage:"
    echo "  ./BTCMiner <BITCOIN_ADDRESS>"
    echo ""
    echo "Example:"
    echo "  ./BTCMiner bc1qYourBitcoinAddressHere"
    echo ""
    echo "GUI version with auto-start: https://winnertakeall.gumroad.com/l/bitcoin"
    echo ""
else
    echo "❌ Build failed!"
    exit 1
fi
