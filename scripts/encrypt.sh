#!/usr/bin/env bash
# ============================================================================
# encrypt.sh — Cifra .env → .env.enc con sops + age
# ============================================================================
#
# Uso:
#   ./scripts/encrypt.sh <env_file> <env_enc>
#
# Argumentos:
#   env_file   — ruta al .env sin cifrar
#   env_enc    — ruta de salida para el .env.enc cifrado
# ============================================================================

set -euo pipefail

# ── Argumentos ──────────────────────────────────────────────────────────────
ENV_FILE="${1:?Uso: encrypt.sh <env_file> <env_enc>}"
ENV_ENC="${2:?Uso: encrypt.sh <env_file> <env_enc>}"

# ── Validaciones ────────────────────────────────────────────────────────────
if [ ! -f "${ENV_FILE}" ]; then
    echo "❌ No se encontró ${ENV_FILE}."
    echo "   Cópialo desde la plantilla:"
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    echo "     cp ${SCRIPT_DIR}/.env.template ${ENV_FILE}"
    exit 1
fi

if ! command -v sops &>/dev/null; then
    echo "❌ sops no instalado. Instálalo: https://github.com/getsops/sops"
    exit 1
fi

if ! command -v age &>/dev/null; then
    echo "❌ age no instalado. Instálalo: https://github.com/FiloSottile/age"
    exit 1
fi

# ── Cifrado ─────────────────────────────────────────────────────────────────
sops --encrypt "${ENV_FILE}" > "${ENV_ENC}"
echo "✅ .env cifrado → ${ENV_ENC}"
echo "   ⚠️  No subas .env al repositorio (ya está en .gitignore)"
