#!/usr/bin/env bash
# ============================================================================
# decrypt.sh — Descifra .env.enc → .env (solo para inspección local)
# ============================================================================
#
# Uso:
#   ./scripts/decrypt.sh <env_enc> <env_file>
#
# Argumentos:
#   env_enc    — ruta al .env.enc cifrado
#   env_file   — ruta de salida para el .env descifrado
# ============================================================================

set -euo pipefail

# ── Argumentos ──────────────────────────────────────────────────────────────
ENV_ENC="${1:?Uso: decrypt.sh <env_enc> <env_file>}"
ENV_FILE="${2:?Uso: decrypt.sh <env_enc> <env_file>}"

# ── Validaciones ────────────────────────────────────────────────────────────
if [ ! -f "${ENV_ENC}" ]; then
    echo "❌ No se encontró ${ENV_ENC}"
    exit 1
fi

# ── Descifrado ──────────────────────────────────────────────────────────────
echo "⚠️  Descifrando a ${ENV_FILE}... (nunca subas este archivo al repo)"
sops --decrypt --input-type dotenv --output-type dotenv "${ENV_ENC}" > "${ENV_FILE}"
echo "✅ .env.enc descifrado → ${ENV_FILE}"
