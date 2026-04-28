#!/usr/bin/env bash
# ============================================================================
# run-opendevin.sh — Lanza OpenDevin con secretos descifrados vía age + sops
# ============================================================================
#
# Requisitos:
#   - age (https://github.com/FiloSottile/age)
#   - sops (https://github.com/getsops/sops)
#   - Docker
#
# Uso:
#   ./scripts/run-opendevin.sh              # usa .env.enc si existe
#   ./scripts/run-opendevin.sh --dev        # usa .env (sin cifrar, para desarrollo)
#   ./scripts/run-opendevin.sh --help       # muestra esta ayuda
#
# Variables del .env:
#   LLM_API_KEY          — API key del LLM (obligatoria)
#   LLM_BASE_URL         — URL base opcional (ej: para Ollama o proxies)
#   WORKSPACE_DIR        — directorio a montar en /opt/workspace_base
#   OPENDOVIN_PORT       — puerto para la UI (default: 3000)
#   OPENDOVIN_IMAGE      — imagen Docker (default: ghcr.io/opendevin/opendevin:main)
#   OPENDOVIN_VERSION    — tag de versión (alternativa a OPENDOVIN_IMAGE)
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ── Configuración por defecto ──────────────────────────────────────────────
OPENDOVIN_IMAGE="${OPENDOVIN_IMAGE:-ghcr.io/opendevin/opendevin:main}"
OPENDOVIN_PORT="${OPENDOVIN_PORT:-3000}"

# ── Colores para output ────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ── Help ───────────────────────────────────────────────────────────────────
usage() {
    sed -n 's/^# \?//p' "${BASH_SOURCE[0]}" | sed '1,2d' | sed '/^===/q'
    exit 0
}

# ── Parseo de argumentos ───────────────────────────────────────────────────
MODE="encrypted"  # encrypted | dev
for arg in "$@"; do
    case "$arg" in
        --dev)    MODE="dev" ;;
        --help|-h) usage ;;
        *)        error "Argumento desconocido: $arg"; usage ;;
    esac
done

# ── Cargar variables de entorno ────────────────────────────────────────────
load_env() {
    local env_file="$1"

    if [[ ! -f "$env_file" ]]; then
        error "Archivo no encontrado: $env_file"
        echo ""
        echo "  Crea uno a partir de la plantilla:"
        echo "    cp ${SCRIPT_DIR}/.env.template ${env_file}"
        echo "    ${EDITOR:-vi} ${env_file}"
        echo ""
        echo "  Si usas cifrado (age+sops), crea el .env cifrado:"
        echo "    just encrypt"
        exit 1
    fi

    # shellcheck disable=SC1090
    source "${env_file}"

    # Validar variables obligatorias
    if [[ -z "${LLM_API_KEY:-}" ]]; then
        error "LLM_API_KEY no está definida en ${env_file}"
        exit 1
    fi
}

if [[ "$MODE" == "dev" ]]; then
    info "Modo desarrollo: cargando .env sin cifrar..."
    load_env "${PROJECT_DIR}/.env"
else
    info "Modo seguro: descifrando .env.enc con sops..."
    if ! command -v sops &>/dev/null; then
        error "sops no está instalado. Instálalo: https://github.com/getsops/sops"
        exit 1
    fi
    if ! command -v age &>/dev/null; then
        error "age no está instalado. Instálalo: https://github.com/FiloSottile/age"
        exit 1
    fi

    # Verificar clave age
    if [[ -z "${SOPS_AGE_KEY:-}" && -z "${SOPS_AGE_KEY_FILE:-}" ]]; then
        error "Ni SOPS_AGE_KEY ni SOPS_AGE_KEY_FILE están definidas."
        echo ""
        echo "  Exporta tu clave age:"
        echo "    export SOPS_AGE_KEY_FILE=\$(age-keygen -y ~/.config/age/keys.txt 2>/dev/null)"
        echo "    # o directamente:"
        echo "    export SOPS_AGE_KEY=\"AGE-SECRET-KEY-...\""
        exit 1
    fi

    ENC_FILE="${PROJECT_DIR}/.env.enc"
    if [[ ! -f "$ENC_FILE" ]]; then
        error "Archivo cifrado no encontrado: ${ENC_FILE}"
        echo ""
        echo "  Cifra tu .env primero:"
        echo "    just encrypt"
        exit 1
    fi

    # Descifrar a un FD temporal para no escribir en disco
    ENV_CONTENT="$(sops --decrypt "${ENC_FILE}")"
    # shellcheck disable=SC1090
    source <(echo "${ENV_CONTENT}")

    if [[ -z "${LLM_API_KEY:-}" ]]; then
        error "LLM_API_KEY no está definida en ${ENC_FILE}"
        exit 1
    fi
    ok "Secretos descifrados correctamente desde ${ENC_FILE}"
fi

# ── WORKSPACE_DIR: por defecto PROJECT_DIR/workspace ───────────────────────
WORKSPACE_DIR="${WORKSPACE_DIR:-${PROJECT_DIR}/workspace}"
mkdir -p "${WORKSPACE_DIR}"
WORKSPACE_DIR="$(cd "${WORKSPACE_DIR}" && pwd)"  # ruta absoluta

# ── Verificar Docker ───────────────────────────────────────────────────────
if ! command -v docker &>/dev/null; then
    error "Docker no está instalado o no está en el PATH"
    exit 1
fi

if ! docker info &>/dev/null; then
    error "El daemon de Docker no está corriendo"
    exit 1
fi

# ── Pull de la imagen ──────────────────────────────────────────────────────
info "Verificando imagen Docker: ${OPENDOVIN_IMAGE}..."
if ! docker image inspect "${OPENDOVIN_IMAGE}" &>/dev/null; then
    info "Descargando imagen..."
    docker pull "${OPENDOVIN_IMAGE}"
fi

# ── Detener instancia previa si existe ─────────────────────────────────────
CONTAINER_NAME="opendevin"
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    warn "Contenedor '${CONTAINER_NAME}' ya está corriendo. Deteniéndolo..."
    docker stop "${CONTAINER_NAME}" &>/dev/null
    docker rm "${CONTAINER_NAME}" &>/dev/null
    ok "Contenedor anterior detenido y eliminado"
fi

# ── Construir args de Docker ───────────────────────────────────────────────
DOCKER_ARGS=(
    --name "${CONTAINER_NAME}"
    -e LLM_API_KEY
    -e WORKSPACE_MOUNT_PATH="${WORKSPACE_DIR}"
    -v "${WORKSPACE_DIR}:/opt/workspace_base"
    -v /var/run/docker.sock:/var/run/docker.sock
    -p "${OPENDOVIN_PORT}:3000"
)

# LLM_BASE_URL opcional
if [[ -n "${LLM_BASE_URL:-}" ]]; then
    DOCKER_ARGS+=(-e LLM_BASE_URL)
    info "Usando LLM_BASE_URL: ${LLM_BASE_URL}"
fi

# ── Lanzar contenedor ──────────────────────────────────────────────────────
echo ""
info "═══════════════════════════════════════════════════════════════"
info "  Lanzando OpenDevin..."
info "  Imagen:    ${OPENDOVIN_IMAGE}"
info "  Puerto:    ${OPENDOVIN_PORT}"
info "  Workspace: ${WORKSPACE_DIR}"
info "  LLM:       ${LLM_BASE_URL:-OpenAI (por defecto)}"
info "═══════════════════════════════════════════════════════════════"
echo ""

docker run "${DOCKER_ARGS[@]}" "${OPENDOVIN_IMAGE}"

# ── Post-ejecución ─────────────────────────────────────────────────────────
EXIT_CODE=$?
if [[ $EXIT_CODE -ne 0 ]]; then
    error "OpenDevin terminó con código de error: ${EXIT_CODE}"
else
    ok "OpenDevin se detuvo correctamente"
fi
exit $EXIT_CODE
