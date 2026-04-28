# ============================================================================
# Justfile — Task runner para OpenDevin
# ============================================================================
# Uso: just <tarea>
#   just run          — Lanza OpenDevin (usa .env.enc si existe)
#   just dev          — Lanza OpenDevin en modo desarrollo (usa .env sin cifrar)
#   just encrypt      — Cifra .env → .env.enc con sops + age
#   just decrypt      — Descifra .env.enc → .env (solo inspección)
#   just setup        — Setup inicial: copia template, genera clave age
#   just check        — Verifica prerequisitos (age, sops, docker)
#   just logs         — Sigue los logs del contenedor OpenDevin
#   just stop         — Detiene el contenedor OpenDevin
# ============================================================================

# ── Variables ──────────────────────────────────────────────────────────────
project_dir := `pwd`
scripts_dir := project_dir / "scripts"
env_file := project_dir / ".env"
env_enc := project_dir / ".env.enc"
container_name := "opendevin"

# ── Tareas ─────────────────────────────────────────────────────────────────

# Lanza OpenDevin con secretos cifrados (usa .env.enc con sops + age)
run:
    @if [ -f "{{env_enc}}" ]; then \
        echo "🔐 Modo seguro: usando .env.enc cifrado con age + sops"; \
        {{scripts_dir}}/run-opendevin.sh; \
    else \
        echo "⚠️  No se encontró .env.enc. ¿Quieres usar modo desarrollo?"; \
        echo "   just dev    — usa .env sin cifrar"; \
        echo "   just encrypt  — cifra .env primero"; \
        exit 1; \
    fi

# Lanza OpenDevin en modo desarrollo (usa .env sin cifrar)
dev:
    {{scripts_dir}}/run-opendevin.sh --dev

# Cifra .env → .env.enc con sops + age
encrypt:
    @if [ ! -f "{{env_file}}" ]; then \
        echo "❌ No se encontró {{env_file}}."; \
        echo "   Cópialo desde la plantilla:"; \
        echo "     cp {{scripts_dir}}/.env.template {{env_file}}"; \
        exit 1; \
    fi
    @if ! command -v sops &>/dev/null; then echo "❌ sops no instalado"; exit 1; fi
    @if ! command -v age &>/dev/null; then echo "❌ age no instalado"; exit 1; fi
    @if [ -z "$${SOPS_AGE_KEY:-}" ] && [ -z "$${SOPS_AGE_KEY_FILE:-}" ]; then \
        echo "❌ Ni SOPS_AGE_KEY ni SOPS_AGE_KEY_FILE están definidas."; \
        echo "   Exporta tu clave:"; \
        echo "     export SOPS_AGE_KEY_FILE=~/.config/age/keys.txt"; \
        exit 1; \
    fi
    sops --encrypt "{{env_file}}" > "{{env_enc}}"
    @echo "✅ .env cifrado → {{env_enc}}"
    @echo "   ⚠️  No subas .env al repositorio (ya está en .gitignore)"

# Descifra .env.enc → .env (solo para inspección local)
decrypt:
    @if [ ! -f "{{env_enc}}" ]; then \
        echo "❌ No se encontró {{env_enc}}"; \
        exit 1; \
    fi
    @echo "⚠️  Descifrando a {{env_file}}... (nunca subas este archivo al repo)"
    sops --decrypt "{{env_enc}}" > "{{env_file}}"
    @echo "✅ .env.enc descifrado → {{env_file}}"

# Setup inicial: copia template y guía para generar clave age
setup:
    @echo "🔧 Setup inicial de OpenDevin"
    @echo ""
    @echo "Paso 1: Copiar plantilla de entorno"
    @echo "  cp {{scripts_dir}}/.env.template {{env_file}}"
    @echo "  $EDITOR {{env_file}}   # completa LLM_API_KEY"
    @echo ""
    @echo "Paso 2: Generar clave age (si no tienes)"
    @echo "  age-keygen -o ~/.config/age/keys.txt"
    @echo ""
    @echo "Paso 3: Agregar tu clave pública en .sops.yaml"
    @echo "  age-keygen -y ~/.config/age/keys.txt"
    @echo ""
    @echo "Paso 4: Cifrar el .env"
    @echo "  just encrypt"
    @echo ""
    @echo "Paso 5: Ejecutar OpenDevin"
    @echo "  just run"
    @echo "  # o en modo desarrollo:"
    @echo "  just dev"

# Verifica prerequisitos
check:
    @echo "🔍 Verificando prerequisitos..."
    @echo ""
    @for tool in docker age sops; do \
        if command -v $$tool &>/dev/null; then \
            echo "  ✅ $$tool: $$($$tool --version 2>&1 | head -1)"; \
        else \
            echo "  ❌ $$tool: NO INSTALADO"; \
        fi; \
    done
    @echo ""
    @if [ -f "{{env_enc}}" ]; then \
        echo "  ✅ .env.enc: existe"; \
    else \
        echo "  ⚠️  .env.enc: no encontrado (ejecuta 'just encrypt' primero)"; \
    fi
    @if [ -f "{{env_file}}" ]; then \
        echo "  ⚠️  .env: existe (no cifrado — solo para --dev)"; \
    fi

# Sigue los logs del contenedor OpenDevin
logs:
    docker logs -f {{container_name}}

# Detiene el contenedor OpenDevin
stop:
    docker stop {{container_name}} 2>/dev/null && echo "✅ Contenedor detenido" || echo "⚠️  El contenedor no estaba corriendo"

# Muestra todas las tareas disponibles (default)
default:
    @just --list
