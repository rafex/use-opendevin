# Guía de inicio rápido

Ejecuta OpenDevin localmente en menos de 5 minutos.

## Prerequisitos

- [Docker](https://docs.docker.com/get-docker/)
- [age](https://github.com/FiloSottile/age) — `brew install age`
- [sops](https://github.com/getsops/sops) — `brew install sops`
- [just](https://github.com/casey/just) — `brew install just`

## 1. Configurar entorno

Copia la plantilla y completa tu API key:

```bash
cp scripts/.env.template .env
# Edita .env con tu LLM_API_KEY
```

## 2. Cifrar secretos (recomendado)

Genera tu clave age y cifra el archivo:

```bash
# Generar clave age (solo la primera vez)
age-keygen -o ~/.config/age/keys.txt

# Obtener clave pública y agregarla en .sops.yaml
age-keygen -y ~/.config/age/keys.txt

# Exportar la clave para sops
export SOPS_AGE_KEY_FILE=~/.config/age/keys.txt

# Cifrar
just encrypt
```

## 3. Ejecutar OpenDevin

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

## Siguientes pasos

- [Instalación detallada](SETUP.md) — configuración paso a paso
- [Modelo de seguridad](SECURITY.md) — cómo funciona age + sops
- [Referencia de comandos](REFERENCE.md) — todos los comandos disponibles
