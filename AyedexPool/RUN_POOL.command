#!/bin/bash
# Ayedex Pool (Nerd Edition) v2.0 - Run Script
# Copyright (c) 2025 David Otero / Distributed Ledger Technologies

cd "$(dirname "$0")"

# Check if AyedexPool exists, if not build it
if [ ! -f "./AyedexPool" ]; then
    echo "Building AyedexPool..."
    swiftc -O -o AyedexPool AyedexPool_v2.0.swift
fi

# Run the pool
./AyedexPool bc1qagznhy7yckwjcc2cchh2808ufufhsy94qvz80x \
    --rpc-user ayedex \
    --rpc-pass 'AyedexPool2026!'
