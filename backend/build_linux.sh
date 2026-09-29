#!/usr/bin/env bash
set -e

echo "Compiling Seanime Go server for Linux..."

export GOEXPERIMENT="nojsonv2"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$SCRIPT_DIR"

go build -tags "http2legacy" -ldflags="-s -w" -o seanime .

echo -e "\033[0;32mBuild succeeded: $SCRIPT_DIR/seanime\033[0m"

# Sync to build output folders if they exist
DEBUG_BUNDLE="$SCRIPT_DIR/../build/linux/x64/debug/bundle"
if [ -d "$DEBUG_BUNDLE" ]; then
    cp "$SCRIPT_DIR/seanime" "$DEBUG_BUNDLE/seanime"
    echo -e "\033[0;36mCopied to $DEBUG_BUNDLE/seanime\033[0m"
fi

RELEASE_BUNDLE="$SCRIPT_DIR/../build/linux/x64/release/bundle"
if [ -d "$RELEASE_BUNDLE" ]; then
    cp "$SCRIPT_DIR/seanime" "$RELEASE_BUNDLE/seanime"
    echo -e "\033[0;36mCopied to $RELEASE_BUNDLE/seanime\033[0m"
fi
