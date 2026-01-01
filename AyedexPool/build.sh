#!/bin/bash
# Ayedex Pool (Nerd Edition) v1.1 - Build Script
# Copyright (c) 2025 David Otero / Distributed Ledger Technologies

echo "Building Ayedex Pool..."
swiftc -O -o AyedexPool AyedexPool.swift

if [ $? -eq 0 ]; then
    echo "✅ AyedexPool built successfully!"
    chmod +x AyedexPool
    echo ""
    echo "Usage:"
    echo "  ./AyedexPool <bitcoin_address> --rpc-user <user> --rpc-pass <pass> [options]"
    echo ""
    echo "Example:"
    echo "  ./AyedexPool bc1q... --rpc-user ayedex --rpc-pass 'AyedexPool2025!' --start-diff 0.001"
else
    echo "❌ Build failed!"
fi
