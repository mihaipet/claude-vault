#!/usr/bin/env bash
# Regression: run the existing test suite and report results.

SCRIPT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
echo ""
echo "Running test/run.sh..."
echo ""
bash "$SCRIPT_DIR/test/run.sh"
