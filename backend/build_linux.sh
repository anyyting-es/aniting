#!/usr/bin/env bash
set -e

echo "Compiling Aniting Go server for Linux..."

export GOEXPERIMENT="nojsonv2"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "$SCRIPT_DIR"

go build -tags "http2legacy" -ldflags="-s -w" -o aniting .

echo -e "\033[0;32mBuild succeeded: $SCRIPT_DIR/aniting\033[0m"

# Sync to build output folders if they exist
DEBUG_BUNDLE="$SCRIPT_DIR/../build/linux/x64/debug/bundle"
if [ -d "$DEBUG_BUNDLE" ]; then
    cp "$SCRIPT_DIR/aniting" "$DEBUG_BUNDLE/aniting"
    echo -e "\033[0;36mCopied to $DEBUG_BUNDLE/aniting\033[0m"
fi

RELEASE_BUNDLE="$SCRIPT_DIR/../build/linux/x64/release/bundle"
if [ -d "$RELEASE_BUNDLE" ]; then
    cp "$SCRIPT_DIR/aniting" "$RELEASE_BUNDLE/aniting"
    echo -e "\033[0;36mCopied to $RELEASE_BUNDLE/aniting\033[0m"
fi
