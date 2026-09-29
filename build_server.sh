#!/usr/bin/env bash
set -e

echo "========================================================"
echo "  Compilando servidor Seanime para Linux (Go Backend)"
echo "========================================================"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/backend/build_linux.sh"

echo ""
echo "[OK] Servidor compilado y configurado exitosamente."
