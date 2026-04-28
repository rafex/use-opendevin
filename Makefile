# ============================================================================
# Makefile — Orquestación de build (placeholder)
# ============================================================================
# Este proyecto no requiere compilación. El Makefile existe por política
# de separación build/tasks (ver build-policy):
#   - Makefile  → orquestación de build
#   - Justfile  → tareas de desarrollo (run, encrypt, logs...)
#
# Comandos útiles:
#   make build    — no-op (sin compilación)
#   make test     — no-op (sin tests aún)
#   make clean    — limpia workspace y contenedores
# ============================================================================

.PHONY: build test clean

build:
	@echo "[Makefile] No hay compilación necesaria para este proyecto."
	@echo "           Usa 'just' para tareas de desarrollo: just --list"

test:
	@echo "[Makefile] No hay tests definidos aún."

clean:
	@echo "[Makefile] Limpiando..."
	-docker stop opendevin 2>/dev/null || true
	-docker rm opendevin 2>/dev/null || true
	rm -rf workspace/ 2>/dev/null || true
	@echo "[Makefile] Limpieza completada."
