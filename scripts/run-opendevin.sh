#!/usr/bin/env bash
# ============================================================================
# run-opendevin.sh — Lanza OpenHands con secretos descifrados vía age + sops
# ============================================================================
#
# Requisitos:
#   - age (https://github.com/FiloSottile/age)
#   - sops (https://github.com/getsops/sops)
#   - Docker o Podman Desktop
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
#   PODMAN_API_PORT                — puerto TCP para API de Podman rootless (default: 12375)
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ── Configuración por defecto ──────────────────────────────────────────────
OPENHANDS_IMAGE="${OPENHANDS_IMAGE:-docker.openhands.dev/openhands/openhands:1.6}"
OPENHANDS_PORT="${OPENHANDS_PORT:-3000}"
PODMAN_API_PORT="${PODMAN_API_PORT:-12375}"

# ── Estado global para cleanup ─────────────────────────────────────────────
ENV_TMP=""
PODMAN_SVC_PID=""

cleanup() {
    [[ -n "${PODMAN_SVC_PID}" ]] && kill "${PODMAN_SVC_PID}" 2>/dev/null || true
    [[ -n "${ENV_TMP}" ]]        && rm -f "${ENV_TMP}"                   || true
}
trap cleanup EXIT

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

DOCKER_SOCK_MOUNT="/var/run/docker.sock"

if [ ! -e "${DOCKER_SOCK_MOUNT}" ]; then
    error "Socket Docker no encontrado en ${DOCKER_SOCK_MOUNT}"
    error "Asegúrate de que Docker/Podman Desktop esté corriendo"
    exit 1
fi

if ! docker info &>/dev/null; then
    error "El daemon de Docker no está corriendo"
    exit 1
fi

# ── Detectar motor de contenedores (Docker vs Podman) ─────────────────────
# Podman se detecta por el campo 'buildahVersion' en `docker info`.
EXTRA_SECURITY_OPTS=()
IS_PODMAN=false
USE_TCP_DOCKER=false
DOCKER_CONN_INFO=""   # se muestra en el banner final

if docker info 2>/dev/null | grep -q 'buildahVersion'; then
    IS_PODMAN=true
fi

if [[ "${IS_PODMAN}" == "true" ]]; then
    # --security-opt label=disable es necesario en todos los modos Podman
    # (evita que SELinux bloquee accesos del sandbox)
    EXTRA_SECURITY_OPTS=(--security-opt label=disable)

    PODMAN_ROOTFUL=$(podman machine inspect --format '{{.Rootful}}' 2>/dev/null || echo "unknown")

    if [[ "${PODMAN_ROOTFUL}" == "true" ]]; then
        # ── Podman rootful: socket Unix funciona directamente ──────────────
        info "Motor detectado: Podman (rootful)"
        local_target=$(readlink -f "${DOCKER_SOCK_MOUNT}" 2>/dev/null || echo "${DOCKER_SOCK_MOUNT}")
        local_perms=$(stat -f '%Lp' "${local_target}" 2>/dev/null || echo "0")
        if [[ "${local_perms}" != "666" ]]; then
            info "Ajustando permisos del socket (${local_perms} → 666): ${local_target}"
            if chmod 666 "${local_target}" 2>/dev/null; then
                ok "Permisos ajustados correctamente"
            else
                warn "No se pudieron cambiar permisos sin sudo."
                warn "Ejecuta antes de lanzar: sudo chmod 666 ${local_target}"
            fi
        fi
        DOCKER_CONN_INFO="socket  ${DOCKER_SOCK_MOUNT}"
    else
        # ── Podman rootless: virtiofs no puede montar sockets Unix activos ─
        # Solución: exponer la API de Podman sobre TCP para que el contenedor
        # pueda conectarse via red (host.docker.internal) sin necesitar el
        # socket montado. 'podman system service' actúa como proxy a la VM.
        info "Motor detectado: Podman (rootless)"
        info "Iniciando Podman API TCP en 0.0.0.0:${PODMAN_API_PORT}..."
        podman system service --time=0 "tcp:0.0.0.0:${PODMAN_API_PORT}" &
        PODMAN_SVC_PID=$!

        # Esperar a que el servicio esté listo (máx 5 s)
        local_waited=0
        until curl -sf "http://127.0.0.1:${PODMAN_API_PORT}/_ping" &>/dev/null; do
            sleep 1
            local_waited=$((local_waited + 1))
            if [[ ${local_waited} -ge 5 ]]; then
                error "El servicio Podman TCP no respondió en 5 segundos"
                exit 1
            fi
        done
        ok "Podman API TCP escuchando en puerto ${PODMAN_API_PORT}"
        USE_TCP_DOCKER=true
        DOCKER_CONN_INFO="tcp     host.docker.internal:${PODMAN_API_PORT}"
    fi
else
    # ── Docker nativo: arreglar permisos del socket si es necesario ────────
    local_target=$(readlink -f "${DOCKER_SOCK_MOUNT}" 2>/dev/null || echo "${DOCKER_SOCK_MOUNT}")
    local_perms=$(stat -f '%Lp' "${local_target}" 2>/dev/null || echo "0")
    if [[ "${local_perms}" != "666" ]]; then
        info "Ajustando permisos del socket (${local_perms} → 666): ${local_target}"
        if chmod 666 "${local_target}" 2>/dev/null; then
            ok "Permisos ajustados correctamente"
        else
            warn "No se pudieron cambiar permisos sin sudo."
            warn "Ejecuta: sudo chmod 666 ${local_target}"
        fi
    fi
    DOCKER_CONN_INFO="socket  ${DOCKER_SOCK_MOUNT}"
fi

# ── Detener instancia previa si existe ─────────────────────────────────────
CONTAINER_NAME="openhands-app"
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    warn "Contenedor '${CONTAINER_NAME}' ya está corriendo. Deteniéndolo..."
    docker stop "${CONTAINER_NAME}" &>/dev/null
    docker rm   "${CONTAINER_NAME}" &>/dev/null
    ok "Contenedor anterior detenido y eliminado"
fi

# ── Construir args de Docker ───────────────────────────────────────────────
DOCKER_ARGS=(
    --name "${CONTAINER_NAME}"
    --rm
    --pull="${PULL_POLICY}"
    ${EXTRA_SECURITY_OPTS[@]+"${EXTRA_SECURITY_OPTS[@]}"}
    -e LLM_API_KEY
    -e AGENT_SERVER_IMAGE_REPOSITORY="${AGENT_SERVER_IMAGE_REPOSITORY:-ghcr.io/openhands/agent-server}"
    -e AGENT_SERVER_IMAGE_TAG="${AGENT_SERVER_IMAGE_TAG:-1.15.0-python}"
    -e LOG_ALL_EVENTS=true
    -v "${HOME}/.openhands:/.openhands"
    -p "${OPENHANDS_PORT}:3000"
    --add-host host.docker.internal:host-gateway
)

if [[ "${USE_TCP_DOCKER}" == "true" ]]; then
    # Podman rootless: conectar via TCP, sin montar socket
    DOCKER_ARGS+=(-e DOCKER_HOST="tcp://host.docker.internal:${PODMAN_API_PORT}")
else
    # Docker o Podman rootful: montar socket Unix
    DOCKER_ARGS+=(
        -e DOCKER_HOST="unix:///var/run/docker.sock"
        -v "${DOCKER_SOCK_MOUNT}:/var/run/docker.sock"
    )
fi

# ── Variables LLM opcionales ───────────────────────────────────────────────
# LLM_MODEL y LLM_BASE_URL se pueden configurar también desde la UI de
# OpenHands (Settings). Si están definidas en .env, tienen precedencia.
[[ -n "${LLM_MODEL:-}"            ]] && DOCKER_ARGS+=(-e LLM_MODEL)            && info "LLM_MODEL:             ${LLM_MODEL}"
[[ -n "${LLM_BASE_URL:-}"         ]] && DOCKER_ARGS+=(-e LLM_BASE_URL)         && info "LLM_BASE_URL:          ${LLM_BASE_URL}"
[[ -n "${LLM_TEMPERATURE:-}"      ]] && DOCKER_ARGS+=(-e LLM_TEMPERATURE)      && info "LLM_TEMPERATURE:       ${LLM_TEMPERATURE}"
[[ -n "${LLM_MAX_OUTPUT_TOKENS:-}"  ]] && DOCKER_ARGS+=(-e LLM_MAX_OUTPUT_TOKENS) && info "LLM_MAX_OUTPUT_TOKENS: ${LLM_MAX_OUTPUT_TOKENS}"
[[ -n "${SANDBOX_TIMEOUT:-}"      ]] && DOCKER_ARGS+=(-e SANDBOX_TIMEOUT)      && info "SANDBOX_TIMEOUT:       ${SANDBOX_TIMEOUT}"

# ── Lanzar contenedor ──────────────────────────────────────────────────────
echo ""
info "═══════════════════════════════════════════════════════════════"
info "  Lanzando OpenHands..."
info "  Imagen:    ${OPENHANDS_IMAGE}"
info "  Puerto:    ${OPENHANDS_PORT}"
info "  Estado:    ${HOME}/.openhands"
info "  Daemon:    ${DOCKER_CONN_INFO}"
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
