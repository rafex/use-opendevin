# Modelo de seguridad

Este proyecto usa [age](https://github.com/FiloSottile/age) + [sops](https://github.com/getsops/sops) para proteger secretos (API keys) y Docker como entorno de ejecución aislado.

## Índice

- [Arquitectura de seguridad](#arquitectura-de-seguridad)
- [Flujo de cifrado](#flujo-de-cifrado)
- [Protección en ejecución](#protección-en-ejecución)
- [Buenas prácticas](#buenas-prácticas)
- [Preguntas frecuentes](#preguntas-frecuentes)

---

## Arquitectura de seguridad

```
┌─────────────────────────────────────────────────────┐
│                  Repositorio                         │
│                                                      │
│  .env (NO versionado)    .env.enc (SÍ versionable)   │
│  ┌──────────────┐        ┌──────────────────────┐   │
│  │ LLM_API_KEY  │  ───→  │ sops --encrypt       │   │
│  │ = "sk-..."   │  cifra  │ ├─ age1: clave pub   │   │
│  └──────────────┘        │ └─ datos cifrados    │   │
│                          └──────────────────────┘   │
│                                  ↑                   │
│                          .sops.yaml                  │
│                          (configuración)             │
└─────────────────────────────────────────────────────┘
```

### Componentes

| Componente | Rol |
|------------|-----|
| **age** | Cifrado asimétrico (clave pública/privada) |
| **sops** | Orquestador: cifra/descifra archivos estructurados |
| **.sops.yaml** | Configuración: qué clave age usar y para qué archivos |
| **.env** | Secretos en texto plano (local, no versionado) |
| **.env.enc** | Secretos cifrados (versionable, seguro en repositorio) |

---

## Flujo de cifrado

### Cifrado (`just encrypt`)

```
1. age-keygen -o keys.txt     → genera par de claves
2. .sops.yaml                 → configura clave pública
3. sops --encrypt .env        → produce .env.enc
4. .env.enc se puede committear (seguro)
```

El archivo `.env.enc` es un documento JSON cifrado:

```json
{
  "data": "...cifrado con age...",
  "sops": {
    "age": [{"recipient": "age1abc...", "encrypted": "..."}],
    "lastmodified": "2026-04-28T..."
  }
}
```

### Descifrado (`just run` o `just decrypt`)

```
1. sops --decrypt .env.enc    → requiere clave privada age
2. La clave privada NUNCA está en el repositorio
3. Solo quien tiene keys.txt puede descifrar
```

---

## Protección en ejecución

### El script `run-opendevin.sh`

Cuando ejecutas `just run` (modo seguro):

1. **Verifica** que `sops` y `age` están instalados
2. **Verifica** que `SOPS_AGE_KEY` o `SOPS_AGE_KEY_FILE` está definida
3. **Descifra** `.env.enc` a un file descriptor temporal (`source <(echo ...)`)
4. **Nunca escribe** el contenido descifrado en disco
5. **Inyecta** `LLM_API_KEY` como variable de entorno de Docker
6. **Ejecuta** el contenedor con los secretos en memoria

```
                    ┌──────────────┐
  .env.enc ───────→ │  sops --decrypt  │ ─→ stdout (pipe)
                    └──────────────┘
                           │
                           ↓
                    ┌──────────────┐
                    │  source <()  │ ─→ variables en memoria
                    └──────────────┘
                           │
                           ↓
                    ┌──────────────┐
                    │  docker run  │ ─→ -e LLM_API_KEY
                    └──────────────┘
```

### Modo desarrollo (`just dev`)

Usa `.env` directamente. Recomendado solo para entornos locales de confianza donde no haya riesgo de exposición del archivo.

---

## Buenas prácticas

### ✅ Hacer

- Versionar `.env.enc` (está cifrado, es seguro)
- Mantener `~/.config/age/keys.txt` respaldado pero seguro
- Usar `just run` (modo seguro) por defecto
- Rotar la API key periódicamente
- Agregar nuevas claves age en `.sops.yaml` si hay múltiples desarrolladores

### ❌ No hacer

- ❌ Subir `.env` al repositorio
- ❌ Compartir `keys.txt` por canales no seguros
- ❌ Usar `--dev` en entornos compartidos
- ❌ Poner la API key directamente en `run-opendevin.sh`
- ❌ Comprometer `.env.enc` sin verificar que no contiene claves adicionales

### Múltiples desarrolladores

Para que varias personas puedan descifrar `.env.enc`, agrega todas las claves públicas en `.sops.yaml`:

```yaml
creation_rules:
  - path_regex: \.env\.enc$
    key_groups:
      - age:
        - "age1abc123..."  # clave de Alice
        - "age1def456..."  # clave de Bob
```

Luego re-cifra:

```bash
sops --encrypt .env > .env.enc
```

Cada persona podrá descifrar con su propia clave privada.

---

## Preguntas frecuentes

### ¿Por qué age y no GPG?

age es más simple, moderno y seguro por defecto. GPG tiene una superficie de ataque mayor y una curva de aprendizaje más pronunciada. age tiene ~1500 líneas de código contra las ~300,000 de GPG.

### ¿Por qué sops y no age directamente?

sops permite cifrado determinista (mismo input → mismo output cifrado), integración con múltiples backends (age, AWS KMS, GCP KSM) y trabaja con archivos estructurados manteniendo el formato original.

### ¿Qué pasa si pierdo la clave age?

Si pierdes `keys.txt`, **no podrás descifrar `.env.enc`** y tendrás que regenerar las API keys. Por eso es importante respaldar la clave.

### ¿Es seguro versionar .env.enc?

Sí. `.env.enc` está cifrado con age usando tu clave pública. Sin la clave privada correspondiente, el contenido es ilegible.

### ¿El script deja rastros de la API key?

No. El script descifra a un file descriptor en memoria (`source <(echo ...)`), no escribe en disco. La única copia en texto plano está en `.env` (no versionado, local).
