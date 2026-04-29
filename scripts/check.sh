#!/usr/bin/env bash
# ============================================================================
# check.sh — Verifica prerequisitos del proyecto OpenDevin
# ============================================================================
#
# Uso:
#   ./scripts/check.sh <env_file> <env_enc>
# ============================================================================

set -euo pipefail

# ── Argumentos ──────────────────────────────────────────────────────────────
ENV_FILE="${1:?Uso: check.sh <env_file> <env_enc>}"
ENV_ENC="${2:?Uso: check.sh <env_file> <env_enc>}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_TOML="${PROJECT_DIR}/config/config.toml"

echo "🔍 Verificando prerequisitos..."
echo ""

# ── Herramientas ────────────────────────────────────────────────────────────
for tool in docker age sops; do
    if command -v "${tool}" &>/dev/null; then
        echo "  ✅ ${tool}: $(${tool} --version 2>&1 | head -1)"
    else
        echo "  ❌ ${tool}: NO INSTALADO"
    fi
done

echo ""

# ── Archivos ────────────────────────────────────────────────────────────────
if [ -f "${ENV_ENC}" ]; then
    echo "  ✅ .env.enc: existe"
else
    echo "  ⚠️  .env.enc: no encontrado (ejecuta 'just encrypt' primero)"
fi

if [ -f "${ENV_FILE}" ]; then
    echo "  ⚠️  .env: existe (no cifrado — solo para --dev)"
fi

if [ -f "${CONFIG_TOML}" ]; then
    echo "  ✅ config/config.toml: existe"
else
    echo "  ❌ config/config.toml: NO ENCONTRADO (requerido para lanzar OpenHands)"
fi
