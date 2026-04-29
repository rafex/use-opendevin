# Guía de inicio rápido

Ejecuta OpenHands localmente en menos de 5 minutos.

## Prerequisitos

- [Docker](https://docs.docker.com/get-docker/)
- [age](https://github.com/FiloSottile/age) — `brew install age`
- [sops](https://github.com/getsops/sops) — `brew install sops`
- [just](https://github.com/casey/just) — `brew install just`

## 1. Setup automático

Un solo comando configura todo:

```bash
just setup
```

Esto hace automáticamente:

| Paso | Acción |
|------|--------|
| 1. Archivo de entorno | Copia `scripts/.env.template` → `.env` si no existe |
| 2. Clave age | Genera `~/.config/age/keys.txt` si no existe |
| 3. Clave pública | Verifica `.sops.yaml` y **cifra `.env` → `.env.enc`** |

Después de `just setup`, abre `.env` y completa `LLM_API_KEY`:

```bash
$EDITOR .env
```

Luego vuelve a cifrar con los valores actualizados:

```bash
just encrypt
```

## 2. Exportar clave para sops

Agrega esta línea a tu `~/.bashrc` (o `~/.zshrc`):

```bash
export SOPS_AGE_KEY_FILE="$HOME/.config/age/keys.txt"
```

Y recarga la terminal o ejecuta `source ~/.bashrc`.

## 3. Ejecutar OpenHands

```bash
# Modo seguro (usa .env.enc cifrado)
just run

# O modo desarrollo (usa .env sin cifrar)
just dev
```

Abre [http://localhost:3000](http://localhost:3000) en tu navegador.

## 4. Detener

```bash
just stop
```

## Referencia rápida de comandos

| Comando | Descripción |
|---------|-------------|
| `just setup` | Setup inicial completo (template, clave age, cifrado) |
| `just encrypt` | Cifra `.env` → `.env.enc` |
| `just decrypt` | Descifra `.env.enc` → `.env` (solo inspección) |
| `just check` | Verifica prerequisitos |
| `just run` | Lanza OpenHands (usa `.env.enc` cifrado) |
| `just dev` | Modo desarrollo (usa `.env` sin cifrar) |
| `just logs` | Sigue los logs del contenedor |
| `just stop` | Detiene el contenedor |

## Siguientes pasos

- [Instalación detallada](SETUP.md) — configuración paso a paso
- [Modelo de seguridad](SECURITY.md) — cómo funciona age + sops
