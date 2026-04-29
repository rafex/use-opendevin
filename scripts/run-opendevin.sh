#!/usr/bin/env bash
# ============================================================================
# run-opendevin.sh — Lanza OpenHands con secretos descifrados vía age + sops
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
#   ./scripts/run-opendevin.sh --no-pull    # omite docker pull (más rápido si la imagen ya existe)
#   ./scripts/run-opendevin.sh --help       # muestra esta ayuda
#
# Variables del .env:
#   LLM_API_KEY                    — API key del LLM (obligatoria)
#   LLM_BASE_URL                   — URL base opcional (ej: para Ollama)
#   OPENHANDS_IMAGE                — imagen Docker (default: docker.openhands.dev/openhands/openhands:1.6)
#   OPENHANDS_PORT                 — puerto para la UI (default: 3000)
#   AGENT_SERVER_IMAGE_REPOSITORY  — imagen del agent-server (default: ghcr.io/openhands/agent-server)
#   AGENT_SERVER_IMAGE_TAG         — tag del agent-server (default: 1.15.0-python)
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ── Configuración por defecto ──────────────────────────────────────────────
OPENHANDS_IMAGE="${OPENHANDS_IMAGE:-docker.openhands.dev/openhands/openhands:1.6}"
OPENHANDS_PORT="${OPENHANDS_PORT:-3000}"

# ── Colores para output ────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

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
MODE="encrypted"
PULL_POLICY="always"
for arg in "$@"; do
    case "$arg" in
        --dev)      MODE="dev" ;;
        --no-pull)  PULL_POLICY="never" ;;
        --help|-h)  usage ;;
        *)          error "Argumento desconocido: $arg"; usage ;;
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

    # Descifrar a archivo temporal (bash 3.2 en macOS no soporta source <())
    ENV_TMP=$(mktemp)
    trap 'rm -f "${ENV_TMP}"' EXIT
    sops --decrypt --input-type dotenv --output-type dotenv "${ENC_FILE}" > "${ENV_TMP}"
    # shellcheck disable=SC1090
    source "${ENV_TMP}"

    if [[ -z "${LLM_API_KEY:-}" ]]; then
        error "LLM_API_KEY no está definida en ${ENC_FILE}"
        exit 1
    fi
    ok "Secretos descifrados correctamente desde ${ENC_FILE}"
fi

# ── Verificar Docker ───────────────────────────────────────────────────────
if ! command -v docker &>/dev/null; then
    error "Docker no está instalado o no está en el PATH"
    exit 1
fi

# Resolver socket real de Docker (macOS con Podman usa symlinks)
resolve_socket() {
    local s="$1" d
    for _ in 1 2 3 4 5; do
        if [ -L "${s}" ]; then
            d=$(readlink "${s}")
            case "${d}" in
                /*) s="${d}" ;;
                *)  s="$(dirname "${s}")/${d}" ;;
            esac
        else
            echo "${s}"
            return 0
        fi
    done
    echo "${s}"
}

DOCKER_SOCK=$(resolve_socket "/var/run/docker.sock")
if [ "${DOCKER_SOCK}" != "/var/run/docker.sock" ]; then
    info "Socket Docker resuelto: ${DOCKER_SOCK}"
fi

# Asegurar permisos del socket (Podman en macOS crea socket 600)
if [ -S "${DOCKER_SOCK}" ]; then
    SOCK_PERMS=$(stat -f '%Lp' "${DOCKER_SOCK}" 2>/dev/null || echo "0")
    if [ "${SOCK_PERMS}" != "666" ]; then
        info "Ajustando permisos del socket (${SOCK_PERMS} → 666)..."
        if ! chmod 666 "${DOCKER_SOCK}" 2>/dev/null; then
            warn "No se pudieron cambiar permisos sin sudo."
            warn "Ejecuta: sudo chmod 666 ${DOCKER_SOCK}"
            warn "O añade a tu shell: export DOCKER_HOST=unix://${DOCKER_SOCK}"
        fi
    fi
fi

if ! docker info &>/dev/null; then
    error "El daemon de Docker no está corriendo"
    exit 1
fi

# ── Detener instancia previa si existe ─────────────────────────────────────
CONTAINER_NAME="openhands-app"
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    warn "Contenedor '${CONTAINER_NAME}' ya está corriendo. Deteniéndolo..."
    docker stop "${CONTAINER_NAME}" &>/dev/null
    docker rm "${CONTAINER_NAME}" &>/dev/null
    ok "Contenedor anterior detenido y eliminado"
fi

# ── Construir args de Docker ───────────────────────────────────────────────
DOCKER_ARGS=(
    --name "${CONTAINER_NAME}"
    --rm
    --pull="${PULL_POLICY}"
    -e LLM_API_KEY
    -e AGENT_SERVER_IMAGE_REPOSITORY="${AGENT_SERVER_IMAGE_REPOSITORY:-ghcr.io/openhands/agent-server}"
    -e AGENT_SERVER_IMAGE_TAG="${AGENT_SERVER_IMAGE_TAG:-1.15.0-python}"
    -e LOG_ALL_EVENTS=true
    -e DOCKER_HOST="unix:///var/run/docker.sock"
    -v "${DOCKER_SOCK}:/var/run/docker.sock"
    -v "${HOME}/.openhands:/.openhands"
    -v "${PROJECT_DIR}/config/config.toml:/app/config.toml"
    -p "${OPENHANDS_PORT}:3000"
    --add-host host.docker.internal:host-gateway
)

# LLM_BASE_URL opcional
if [[ -n "${LLM_BASE_URL:-}" ]]; then
    DOCKER_ARGS+=(-e LLM_BASE_URL)
    info "Usando LLM_BASE_URL: ${LLM_BASE_URL}"
fi

# ── Lanzar contenedor ──────────────────────────────────────────────────────
echo ""
info "═══════════════════════════════════════════════════════════════"
info "  Lanzando OpenHands..."
info "  Imagen:    ${OPENHANDS_IMAGE}"
info "  Puerto:    ${OPENHANDS_PORT}"
info "  Config:    ${PROJECT_DIR}/config/config.toml"
info "  Socket:    ${DOCKER_SOCK}"
info "  Pull:      ${PULL_POLICY}"
info "═══════════════════════════════════════════════════════════════"
echo ""

docker run "${DOCKER_ARGS[@]}" "${OPENHANDS_IMAGE}"

# ── Post-ejecución ─────────────────────────────────────────────────────────
EXIT_CODE=$?
if [[ $EXIT_CODE -ne 0 ]]; then
    error "OpenHands terminó con código de error: ${EXIT_CODE}"
else
    ok "OpenHands se detuvo correctamente"
fi
exit $EXIT_CODE
