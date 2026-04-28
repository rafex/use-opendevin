# use-opendevin

> Lanzador seguro y reproducible para [OpenDevin](https://github.com/All-Hands-AI/OpenHands) — el agente de IA que escribe código autónomamente.

## ⚡ Inicio rápido

```bash
cp scripts/.env.template .env   # completa LLM_API_KEY
just encrypt                     # cifra secretos
just run                         # lanza OpenDevin
```

Abre [http://localhost:3000](http://localhost:3000).

---

## Documentación

Toda la documentación está en [`docs/`](docs/), dividida por responsabilidad:

| Sección | Descripción |
|---------|-------------|
| [📗 Inicio rápido](docs/QUICKSTART.md) | Puesta en marcha en 5 minutos |
| [🔧 Instalación detallada](docs/SETUP.md) | Configuración paso a paso, prerequisitos, solución de problemas |
| [🔒 Seguridad](docs/SECURITY.md) | Modelo de cifrado age + sops, buenas prácticas |
| [📖 Referencia](docs/REFERENCE.md) | Todos los comandos `just`, `make` y scripts |
| [🏗️ Arquitectura](docs/ARCHITECTURE.md) | Decisiones técnicas, capas, árbol de archivos |

## Requisitos

- [Docker](https://docs.docker.com/get-docker/)
- [age](https://github.com/FiloSottile/age)
- [sops](https://github.com/getsops/sops)
- [just](https://github.com/casey/just)

```bash
# macOS
brew install docker age sops just
```

## Comandos principales

```bash
just check     # verifica prerequisitos
just setup     # guía de configuración inicial
just encrypt   # cifra .env → .env.enc
just run       # ejecuta OpenDevin (modo seguro)
just dev       # ejecuta OpenDevin (modo desarrollo)
just logs      # sigue logs del contenedor
just stop      # detiene el contenedor
```

Ver [referencia completa](docs/REFERENCE.md).

## Licencia

MIT
