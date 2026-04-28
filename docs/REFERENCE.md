# Referencia de comandos

Todas las operaciones del proyecto se ejecutan a través de `just` (tareas de desarrollo) o `make` (build). Consulta la [política de separación](ARCHITECTURE.md#separación-build-vs-tareas) para entender por qué.

## Índice

- [Comandos just](#comandos-just)
- [Comandos make](#comandos-make)
- [Scripts](#scripts)
- [Referencia rápida de Docker](#referencia-rápida-de-docker)

---

## Comandos just

| Comando | Descripción | Requiere |
|---------|-------------|----------|
| `just run` | Lanza OpenDevin con secretos cifrados (usa `.env.enc`) | `.env.enc`, Docker |
| `just dev` | Lanza OpenDevin en modo desarrollo (usa `.env` sin cifrar) | `.env`, Docker |
| `just encrypt` | Cifra `.env` → `.env.enc` con sops + age | `.env`, clave age |
| `just decrypt` | Descifra `.env.enc` → `.env` (inspección local) | `.env.enc`, clave age |
| `just setup` | Muestra guía paso a paso de configuración inicial | — |
| `just check` | Verifica prerequisitos (age, sops, docker, archivos) | — |
| `just logs` | Sigue los logs del contenedor OpenDevin | Contenedor activo |
| `just stop` | Detiene el contenedor OpenDevin | Contenedor activo |
| `just --list` | Lista todas las tareas disponibles | — |

### Ejemplos

```bash
# Verificar que todo está listo
just check

# Configuración inicial (guía interactiva)
just setup

# Cifrar secretos
export SOPS_AGE_KEY_FILE=~/.config/age/keys.txt
just encrypt

# Ejecutar
just run

# En otra terminal, ver logs
just logs

# Detener
just stop
```

---

## Comandos make

| Comando | Descripción |
|---------|-------------|
| `make build` | No-op (proyecto sin compilación) |
| `make test` | No-op (sin tests definidos) |
| `make clean` | Detiene contenedor y elimina `workspace/` |

```bash
make clean
```

---

## Scripts

### `scripts/run-opendevin.sh`

Script principal que encapsula el lanzamiento de OpenDevin.

**Uso directo:**

```bash
# Modo seguro (usa .env.enc)
./scripts/run-opendevin.sh

# Modo desarrollo (usa .env)
./scripts/run-opendevin.sh --dev

# Ayuda
./scripts/run-opendevin.sh --help
```

**Variables de entorno que acepta:**

| Variable | Default | Descripción |
|----------|---------|-------------|
| `LLM_API_KEY` | — | API key del LLM (obligatoria) |
| `LLM_BASE_URL` | — | URL base para LLM alternativo (Ollama, etc.) |
| `WORKSPACE_DIR` | `<proyecto>/workspace` | Directorio a montar en el contenedor |
| `OPENDOVIN_PORT` | `3000` | Puerto de la UI web |
| `OPENDOVIN_IMAGE` | `ghcr.io/opendevin/opendevin:main` | Imagen Docker |

**Flujo interno:**

1. Determina modo (encrypted / dev)
2. Carga variables de entorno (descifrando si es necesario)
3. Crea el directorio de workspace si no existe
4. Verifica Docker y la imagen
5. Detiene instancia previa si existe
6. Lanza el contenedor con `docker run`

### `scripts/.env.template`

Plantilla para crear el archivo `.env`. Contiene todas las variables documentadas con valores por defecto.

```bash
cp scripts/.env.template .env
```

---

## Referencia rápida de Docker

### Inspeccionar el contenedor

```bash
# Estado
docker ps --filter name=opendevin

# Logs
docker logs opendevin

# Shell dentro del contenedor
docker exec -it opendevin bash
```

### Ejecución manual

Si prefieres no usar el script, puedes ejecutar Docker directamente:

```bash
docker run \
  --name opendevin \
  -e LLM_API_KEY="sk-..." \
  -e WORKSPACE_MOUNT_PATH="$(pwd)/workspace" \
  -v "$(pwd)/workspace:/opt/workspace_base" \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -p 3000:3000 \
  ghcr.io/opendevin/opendevin:main
```

### Limpieza total

```bash
docker stop opendevin 2>/dev/null || true
docker rm opendevin 2>/dev/null || true
make clean
```
