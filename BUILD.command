#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
#  MacMetal CLI Miner - Build Script
#  Copyright (c) 2025 David Otero / Distributed Ledger Technologies
# ═══════════════════════════════════════════════════════════════════════════════

cd "$(dirname "$0")"

echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║  MacMetal CLI Miner - Build Script                                           ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""

# Check for Xcode Command Line Tools
if ! xcode-select -p &> /dev/null; then
    echo "❌ Xcode Command Line Tools not found!"
    echo "   Install with: xcode-select --install"
    exit 1
fi

echo "🔨 Compiling MacMetalCLI..."
echo ""

# Compile with optimizations
swiftc -O \
    -o macmetal \
    MacMetalCLI.swift \
    -framework Metal \
    -framework CoreGraphics \
    -framework Foundation \
    2>&1

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Build successful!"
    echo ""
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║  USAGE                                                                       ║"
    echo "╠══════════════════════════════════════════════════════════════════════════════╣"
    echo "║  ./macmetal <bitcoin_address>              Interactive pool selection        ║"
    echo "║  ./macmetal <bitcoin_address> --ayedex     Use local Ayedex Pool             ║"
    echo "║  ./macmetal <bitcoin_address> --pool <host:port>  Custom pool                ║"
    echo "║  ./macmetal --test                         Run GPU verification tests        ║"
    echo "║  ./macmetal --help                         Show all options                  ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "Example:"
    echo "  ./macmetal bc1qxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
    echo ""
else
    echo ""
    echo "❌ Build failed!"
    exit 1
fi
