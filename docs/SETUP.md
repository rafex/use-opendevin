# Instalación y configuración

Guía detallada para poner en marcha el proyecto desde cero.

## Índice

- [Prerequisitos](#prerequisitos)
- [Instalación de herramientas](#instalación-de-herramientas)
- [Configuración de entorno](#configuración-de-entorno)
- [Generación de clave age](#generación-de-clave-age)
- [Configuración de SOPS](#configuración-de-sops)
- [Verificación](#verificación)

---

## Prerequisitos

| Herramienta | Versión mínima | Propósito |
|-------------|---------------|-----------|
| Docker | 24+ | Contenedor de OpenDevin |
| age | 1.1+ | Cifrado de secretos |
| sops | 3.8+ | Orquestación de cifrado |
| just | 1.30+ | Task runner |
| bash | 4+ | Ejecución de scripts |

### Verificar instalaciones

```bash
just check
```

Salida esperada:

```
🔍 Verificando prerequisitos...

  ✅ docker: Docker version 27.x
  ✅ age: age 1.2.1
  ✅ sops: sops 3.9.0
```

---

## Instalación de herramientas

### macOS (Homebrew)

```bash
brew install docker age sops just
```

### Linux (apt)

```bash
# Docker: https://docs.docker.com/engine/install/
sudo apt install age jq
# sops: descargar de https://github.com/getsops/sops/releases
# just: https://github.com/casey/just#installation
```

### Verificar Docker

Asegúrate de que el daemon de Docker esté corriendo:

```bash
docker info
```

---

## Configuración de entorno

### 1. Crear archivo .env

```bash
cp scripts/.env.template .env
```

### 2. Editar variables

Abre `.env` con tu editor y completa al menos `LLM_API_KEY`:

```bash
# Obligatoria
LLM_API_KEY="sk-proj-..."

# Opcionales
LLM_BASE_URL="http://localhost:11434/v1"   # para Ollama
WORKSPACE_DIR="/ruta/absoluta/a/mi/proyecto"
OPENDOVIN_PORT="8080"
OPENDOVIN_IMAGE="ghcr.io/opendevin/opendevin:main"
```

> ⚠️ **Nunca subas .env al repositorio.** Está en `.gitignore`, pero verifica antes de hacer commit.

---

## Generación de clave age

age (actually good encryption) es la herramienta de cifrado asimétrico que usamos para proteger secretos.

### Generar clave

```bash
age-keygen -o ~/.config/age/keys.txt
```

Esto crea dos archivos:
- `~/.config/age/keys.txt` — **clave privada** (nunca compartir)
- Una clave pública impresa en pantalla (comienza con `age1...`)

### Obtener clave pública

```bash
age-keygen -y ~/.config/age/keys.txt
# Output: age1abc123def456...
```

### Agregar clave pública en .sops.yaml

Edita `.sops.yaml` y reemplaza `<TU_CLAVE_PUBLICA_AGE>`:

```yaml
creation_rules:
  - path_regex: \.env\.enc$
    key_groups:
      - age:
        - "age1abc123def456..."
```

---

## Configuración de SOPS

SOPS (Secrets OPerationS) es el orquestador que usa age para cifrar/descifrar archivos estructurados.

### Exportar clave

Cada vez que uses `just encrypt` o `just run`, necesitas tener la clave age accesible:

```bash
export SOPS_AGE_KEY_FILE=~/.config/age/keys.txt
```

Para no tener que hacerlo manualmente, agrega esta línea a tu `~/.bashrc` o `~/.zshrc`:

```bash
echo 'export SOPS_AGE_KEY_FILE=~/.config/age/keys.txt' >> ~/.zshrc
```

### Cifrar

```bash
just encrypt
```

Esto genera `.env.enc` — un archivo cifrado que SÍ se puede versionar (contiene los mismos datos que `.env` pero protegidos).

### Verificar cifrado

```bash
# El archivo cifrado NO es texto plano
head -c 100 .env.enc
# Output: ���encrypted��... (ilegible)

# Se puede descifrar solo con la clave privada
sops --decrypt .env.enc
```

---

## Verificación

Una vez configurado todo, ejecuta:

```bash
just check
```

Si todo está en orden:

```bash
🔍 Verificando prerequisitos...
  ✅ docker: Docker version 27.4.0
  ✅ age: age 1.2.1
  ✅ sops: sops 3.9.3
  ✅ .env.enc: existe
```

Ya puedes ejecutar `just run`.

---

## Solución de problemas

| Problema | Causa | Solución |
|----------|-------|----------|
| `sops: command not found` | sops no instalado | `brew install sops` |
| `age: command not found` | age no instalado | `brew install age` |
| `SOPS_AGE_KEY` no definida | Clave age no exportada | `export SOPS_AGE_KEY_FILE=~/.config/age/keys.txt` |
| `.env.enc: no encontrado` | No se ha cifrado el .env | `just encrypt` |
| `Docker no está corriendo` | Daemon Docker caído | Inicia Docker Desktop o `systemctl start docker` |
| Puerto 3000 en uso | Otro servicio ocupando el puerto | Cambia `OPENDOVIN_PORT` en `.env` |
