# Arquitectura del proyecto

## Propósito

Este repositorio proporciona un **lanzador seguro y reproducible** para [OpenDevin](https://github.com/All-Hands-AI/OpenHands), un agente de IA que escribe código de forma autónoma. El proyecto no modifica OpenDevin — lo encapsula.

## Vista general

```
┌──────────────────────────────────────────────────────────┐
│                    use-opendevin                          │
│                                                          │
│  just  ─→  scripts/run-opendevin.sh  ─→  docker run      │
│   ↑              ↑                            ↑          │
│   │         descifra                          │          │
│   │              ↑                            │          │
│  Justfile    .env.enc (sops+age)         ghcr.io/       │
│  (tasks)                                    opendevin/   │
│                                             opendevin    │
│  Makefile                                               │
│  (build)                                                │
└──────────────────────────────────────────────────────────┘
```

## Capas

### 1. Task runner — Justfile

El `Justfile` es la interfaz de usuario principal. Define tareas de alto nivel:

- `just run` / `just dev` — ejecutar OpenDevin
- `just encrypt` / `just decrypt` — gestionar secretos
- `just setup` / `just check` — configuración y diagnóstico
- `just logs` / `just stop` — gestionar el contenedor

Cada tarea delega en `scripts/run-opendevin.sh` o ejecuta comandos directamente. Sigue la [política de separación build/tasks](https://specnative-d.rafex.io/en/decisions/build-policy).

### 2. Build system — Makefile

El `Makefile` existe solo por política de arquitectura. Este proyecto no requiere compilación, pero tener un Makefile garantiza consistencia en el CI/CD y en equipos que esperan `make build` / `make test` / `make clean`.

### 3. Script de lanzamiento — `scripts/run-opendevin.sh`

Script bash que orquesta todo el proceso:

1. **Carga de secretos**: descifra `.env.enc` con sops+age o lee `.env` directo
2. **Validación**: verifica Docker, imagen, variables obligatorias
3. **Ejecución**: construye y lanza el contenedor con los parámetros correctos

`config/config.toml` se monta en `/app/config.toml` dentro del contenedor — ruta relativa desde la que OpenHands busca el archivo al arrancar.

### 4. Gestión de secretos — age + sops

- **age**: cifrado asimétrico (clave pública para cifrar, privada para descifrar)
- **sops**: orquestador que usa age para cifrar archivos estructurados
- **`.sops.yaml`**: configuración que vincula archivos `.env.enc` con claves age

Ver [documentación de seguridad](SECURITY.md) para detalles.

---

## Separación build vs tareas

| Herramienta | Responsabilidad | Propósito |
|-------------|----------------|-----------|
| **Makefile** | Build system | `make build`, `make test`, `make clean` (compatibilidad CI) |
| **Justfile** | Task runner | `just run`, `just encrypt`, `just logs` (desarrollo local) |

Makefile **no** ejecuta tareas de desarrollo. Justfile **no** ejecuta builds. Esta separación evita el mal uso histórico de Makefile como task runner genérico.

---

## Árbol de archivos

```
use-opendevin/
├── .gitignore           ← ignora secretos sin cifrar y workspace
├── .sops.yaml           ← configuración de cifrado
├── .env.enc             ← secretos cifrados (versionado)
├── Justfile             ← task runner (uso diario)
├── Makefile             ← build system (CI/CD)
├── README.md            ← índice de documentación
├── config/
│   └── config.toml      ← configuración de OpenHands (LLM, sandbox)
├── docs/
│   ├── QUICKSTART.md    ← inicio rápido (5 min)
│   ├── SETUP.md         ← instalación detallada
│   ├── SECURITY.md      ← modelo de seguridad
│   ├── REFERENCE.md     ← referencia de comandos
│   └── ARCHITECTURE.md  ← este documento
├── scripts/
│   ├── .env.template    ← plantilla de variables
│   ├── check.sh         ← verificación de prerequisitos
│   ├── decrypt.sh       ← descifrado .env.enc → .env
│   ├── encrypt.sh       ← cifrado .env → .env.enc
│   ├── run-opendevin.sh ← script de lanzamiento principal
│   └── setup.sh         ← configuración inicial guiada
└── workspace/           ← directorio de trabajo (ignorado en git)
```

---

## Decisiones técnicas

| Decisión | Alternativa considerada | Por qué se eligió esta |
|----------|------------------------|----------------------|
| age + sops | GPG, dotenv, Vault | age es más simple y seguro que GPG; sops permite versionar secretos; Vault es sobredimensionado para un solo desarrollador |
| just | npm scripts, Makefile puro | Justfile es más legible que Makefile para tareas; npm scripts no aplica (no es proyecto Node) |
| Bash script | Python, Go | Bash es cero-dependencia para el propósito; el script es simple y no requiere compilación |
| Docker run | Docker Compose, Kubernetes | Un solo contenedor no justifica Compose; K8s es sobredimensionado |
