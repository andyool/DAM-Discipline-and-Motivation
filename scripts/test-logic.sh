#!/usr/bin/env bash
# Compiles the app's game logic (DAM/Model, Foundation only) together with the
# logic test harness and runs it. Works on macOS and Linux with a Swift toolchain.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="$(mktemp -d)/dam-logic-tests"
swiftc -swift-version 5 DAM/Model/*.swift Tests/LogicTests/main.swift -o "$OUT"
"$OUT"
