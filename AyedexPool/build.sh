#!/bin/bash
# Ayedex Pool (Nerd Edition) v2.0 - Build Script
# Copyright (c) 2025 David Otero / Distributed Ledger Technologies

echo "Building Ayedex Pool (Nerd Edition) v2.0..."
swiftc -O -o AyedexPool AyedexPool_v2.0.swift

if [ $? -eq 0 ]; then
    echo "✅ AyedexPool v2.0 built successfully!"
    chmod +x AyedexPool
    echo ""
    echo "Usage:"
    echo "  ./AyedexPool <bitcoin_address> --rpc-user <user> --rpc-pass <pass>"
    echo ""
    echo "Or use: ./RUN_POOL.command"
else
    echo "❌ Build failed!"
fi
