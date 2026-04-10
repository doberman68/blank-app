#!/usr/bin/env bash
# PickleCam – Xcode project generator
# Run this once on macOS after cloning, then open PickleCam.xcodeproj.
set -euo pipefail

# ── 1. Require macOS ──────────────────────────────────────────────────────────
if [[ "$(uname)" != "Darwin" ]]; then
  echo "Error: This script must run on macOS." >&2
  exit 1
fi

# ── 2. Install XcodeGen if missing ───────────────────────────────────────────
if ! command -v xcodegen &>/dev/null; then
  echo "XcodeGen not found – installing via Homebrew..."
  if ! command -v brew &>/dev/null; then
    echo "Error: Homebrew is required. Install it from https://brew.sh" >&2
    exit 1
  fi
  brew install xcodegen
fi

XCODEGEN_VERSION=$(xcodegen --version 2>&1 | head -1)
echo "Using $XCODEGEN_VERSION"

# ── 3. Change to the project root (same directory as this script) ─────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ── 4. Generate the Xcode project ────────────────────────────────────────────
echo "Generating PickleCam.xcodeproj..."
xcodegen generate --spec project.yml

echo ""
echo "Done! Open the project with:"
echo "  open PickleCam.xcodeproj"
echo ""
echo "Before building:"
echo "  1. Set your DEVELOPMENT_TEAM in project.yml (search for the empty string next to DEVELOPMENT_TEAM)"
echo "  2. Change com.yourteam to your own bundle ID prefix throughout project.yml"
echo "  3. Pair a real iPhone + Apple Watch (Simulator does not fully support WatchConnectivity)"
