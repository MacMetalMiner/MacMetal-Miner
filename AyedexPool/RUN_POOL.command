#!/bin/bash
# Ayedex Pool (Nerd Edition) v2.0 - Run Script
# Copyright (c) 2025 David Otero / Distributed Ledger Technologies

cd "$(dirname "$0")"

# Check if AyedexPool exists, if not build it
if [ ! -f "./AyedexPool" ]; then
    echo "Building AyedexPool..."
    swiftc -O -o AyedexPool AyedexPool_v2.0.swift
fi

# Run the pool — supply RPC password via NEX_RPC_PASSWORD env var.
# Example: NEX_RPC_PASSWORD=xxx ./RUN_POOL.command
./AyedexPool nx1q0rq2yah7kq6tqq2e6y2uqv6vmk52w5xc5y7afs \
    --rpc-user nex \
    --rpc-pass "${NEX_RPC_PASSWORD:?NEX_RPC_PASSWORD env var required}"
