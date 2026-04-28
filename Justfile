# ============================================================================
# Justfile — Task executor para OpenDevin
# ============================================================================
# Cada tarea delega en un script dentro de scripts/
# ============================================================================

# ── Variables ──────────────────────────────────────────────────────────────
project_dir := `pwd`
scripts_dir := project_dir / "scripts"
env_file := project_dir / ".env"
env_enc := project_dir / ".env.enc"
container_name := "opendevin"

# ── Tareas ─────────────────────────────────────────────────────────────────

# Lanza OpenDevin con secretos cifrados (.env.enc)
run:
    @{{scripts_dir}}/run-opendevin.sh

# Lanza OpenDevin en modo desarrollo (.env sin cifrar)
dev:
    @{{scripts_dir}}/run-opendevin.sh --dev

# Cifra .env → .env.enc con sops + age
encrypt:
    @{{scripts_dir}}/encrypt.sh "{{env_file}}" "{{env_enc}}"

# Descifra .env.enc → .env (solo inspección local)
decrypt:
    @{{scripts_dir}}/decrypt.sh "{{env_enc}}" "{{env_file}}"

# Setup inicial: copia template, genera clave age, configura sops y cifra
setup:
    @{{scripts_dir}}/setup.sh "{{project_dir}}" "{{scripts_dir}}" "{{env_file}}" "{{env_enc}}"

# Verifica prerequisitos (age, sops, docker, archivos)
check:
    @{{scripts_dir}}/check.sh "{{env_file}}" "{{env_enc}}"

# Sigue los logs del contenedor OpenDevin
logs:
    docker logs -f {{container_name}}

# Detiene el contenedor OpenDevin
stop:
    docker stop {{container_name}} 2>/dev/null && echo "✅ Contenedor detenido" || echo "⚠️  El contenedor no estaba corriendo"

# Muestra todas las tareas disponibles (default)
default:
    @just --list
