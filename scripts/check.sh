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
