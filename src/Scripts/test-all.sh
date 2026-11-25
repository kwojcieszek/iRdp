#!/bin/bash
# Runs the unit tests of every package (same tests as Product > Test of the iRdp scheme in Xcode).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
for package in RdpProtocol IRdpConfiguration RdpServer MacIntegration IRdpServiceCore; do
    echo "== $package"
    swift test --package-path "$ROOT/Packages/$package"
done
