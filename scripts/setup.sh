#!/usr/bin/env bash
# ============================================================================
# setup.sh — Configura el proyecto OpenDevin automáticamente
# ============================================================================
#
# Crea .env desde template, genera clave age, configura sops y cifra.
#
# Uso:
#   ./scripts/setup.sh <project_dir> <scripts_dir> <env_file> <env_enc>
# ============================================================================

set -euo pipefail

# ── Argumentos ──────────────────────────────────────────────────────────────
PROJECT_DIR="${1:?Uso: setup.sh <project_dir> <scripts_dir> <env_file> <env_enc>}"
SCRIPTS_DIR="${2:?Uso: setup.sh <project_dir> <scripts_dir> <env_file> <env_enc>}"
ENV_FILE="${3:?Uso: setup.sh <project_dir> <scripts_dir> <env_file> <env_enc>}"
ENV_ENC="${4:?Uso: setup.sh <project_dir> <scripts_dir> <env_file> <env_enc>}"
SOPS_YAML="${PROJECT_DIR}/.sops.yaml"

echo "🔧 Setup inicial de OpenDevin"
echo ""

# ── Paso 1: Archivo de entorno ──────────────────────────────────────────────
echo "━━━ Paso 1: Archivo de entorno ━━━"
if [ ! -f "${ENV_FILE}" ]; then
    echo "  📄 Copiando plantilla..."
    cp "${SCRIPTS_DIR}/.env.template" "${ENV_FILE}"
    echo "  ✅ Creado: ${ENV_FILE}"
    echo ""
    echo "  ⚠️  Ahora edítalo y completa LLM_API_KEY:"
    echo "     \$EDITOR ${ENV_FILE}"
else
    echo "  ✅ ${ENV_FILE} ya existe"
fi
echo ""

# ── Paso 2: Clave age ───────────────────────────────────────────────────────
echo "━━━ Paso 2: Clave age ━━━"
if [ ! -f ~/.config/age/keys.txt ]; then
    echo "  🔑 Generando clave age..."
    mkdir -p ~/.config/age
    age-keygen -o ~/.config/age/keys.txt
    echo "  ✅ Creada: ~/.config/age/keys.txt"
else
    echo "  ✅ ~/.config/age/keys.txt ya existe"
fi
echo ""

# ── Paso 3: Clave pública en .sops.yaml ─────────────────────────────────────
echo "━━━ Paso 3: Clave pública en .sops.yaml ━━━"
if grep -v '^#' "${SOPS_YAML}" | grep -q "<TU_CLAVE_PUBLICA_AGE>" 2>/dev/null; then
    echo "  ⚠️  .sops.yaml aún tiene el placeholder."
    echo "     Reemplázalo con tu clave pública:"
    echo "       age-keygen -y ~/.config/age/keys.txt"
    echo "     Copia el resultado en .sops.yaml"
    echo "     Luego ejecuta: just encrypt"
else
    echo "  ✅ .sops.yaml: clave pública configurada"
    echo ""
    echo "  🔐 Cifrando .env..."
    if sops --encrypt --input-type dotenv --output-type dotenv "${ENV_FILE}" > "${ENV_ENC}" 2>/dev/null; then
        echo "  ✅ .env → ${ENV_ENC}"
    else
        echo "  ⚠️  No se pudo cifrar. Revisa: just check"
    fi
fi
echo ""

# ── Paso 4: Directorio de estado de OpenHands ──────────────────────────────
echo "━━━ Paso 4: Directorio de estado ━━━"
if [ ! -d "${HOME}/.openhands" ]; then
    echo "  📁 Creando ~/.openhands..."
    mkdir -p "${HOME}/.openhands"
    echo "  ✅ Creado: ~/.openhands"
else
    echo "  ✅ ~/.openhands ya existe"
fi
echo ""

# ── Paso 5: Siguientes pasos ────────────────────────────────────────────────
echo "━━━ Paso 5: Siguientes pasos ━━━"
echo "  • just run     — Inicia OpenDevin (usa .env.enc)"
echo "  • just dev     — Modo desarrollo (usa .env sin cifrar)"
echo "  • just check   — Verifica prerequisitos"
