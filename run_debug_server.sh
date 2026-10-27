#!/usr/bin/env bash
set -e

echo "========================================================"
echo "  Ejecutando Aniting (Con servidor Go embebido) - Debug"
echo "========================================================"

flutter run -PincludeBackend=true "$@"
