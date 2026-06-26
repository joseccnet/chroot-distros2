# Ubuntu Chroot

## Versiones Soportadas

| Versión | Codename | Tipo | Soporte hasta |
|---|---|---|---|
| 26.04 LTS | Resolute Raccoon | LTS | Mayo 2031 |
| 24.04 LTS | Noble Numbat | LTS | Junio 2029 |
| 22.04 LTS | Jammy Jellyfish | LTS | Junio 2027 |
| 25.10 | Questing Quokka | Estándar | Julio 2026 |
| 25.04 | Plucky Puffin | Estándar | Enero 2026 |
| 24.10 | Oracular Oriole | Estándar | EOL |
| 23.10-20.04 | Varias | EOL | Sin soporte |
| 18.04-10.04 | Legacy | EOL | Sin soporte |

## Uso Básico

```bash
# Versión por defecto (noble 24.04 LTS)
sudo ./build-chroot-Ubuntu.sh mi-ubuntu

# Versión específica
sudo ./build-chroot-Ubuntu.sh mi-ubuntu noble

# Con arquitectura específica
sudo ./build-chroot-Ubuntu.sh mi-ubuntu noble arm64

# Construcción cruzada (host amd64 → target arm64)
sudo ./build-chroot-Ubuntu.sh mi-ubuntu-arm noble arm64

# Versión EOL (requiere confirmación)
sudo ./build-chroot-Ubuntu.sh mi-ubuntu focal
```

## Variables de Entorno

| Variable | Default | Descripción |
|---|---|---|
| `SIN_VERIFICACION_GPG` | `false` | Desactiva verificación GPG (solo desarrollo) |
| `MIRROR_UBUNTU` | `http://archive.ubuntu.com/ubuntu` | Mirror personalizado |
| `INTERACTIVO` | `false` | Menú interactivo para seleccionar versión |
| `FORZAR_EOL` | `false` | Omite confirmación para versiones EOL |
| `ESPACIO_MINIMO_GB` | `2` | Espacio mínimo requerido en GB |

## Características

- **Paquetes por versión**: `default-mysql-client` en modernas, `mysql-client` en legacy
- **ubuntu-keyring**: Incluido automáticamente en versiones 22.04+
- **libc6-i386**: Agregado automáticamente en arquitectura amd64
- **Workaround Trusty** (14.04): fix automático para udev y cron
- **Mirrors**: `archive.ubuntu.com` (activo) → `old-releases.ubuntu.com` (fallback EOL)
- **Construcción cruzada**: Soporte `--foreign` para arm64, armhf, ppc64el, s390x

## Ejemplos

```bash
# Mirror personalizado
sudo MIRROR_UBUNTU=http://mx.archive.ubuntu.com/ubuntu \
  ./build-chroot-Ubuntu.sh mi-ubuntu noble

# Modo interactivo
sudo INTERACTIVO=true ./build-chroot-Ubuntu.sh mi-ubuntu

# Sin GPG (desarrollo local)
sudo SIN_VERIFICACION_GPG=true ./build-chroot-Ubuntu.sh mi-ubuntu noble

# Espacio mínimo personalizado
sudo ESPACIO_MINIMO_GB=5 ./build-chroot-Ubuntu.sh mi-ubuntu noble

# Modo seco (previsualizar montajes)
sudo DRY_RUN=true ./mount_umount-chroot.sh mi-ubuntu mount
```

## Acceso a la jaula

```bash
sudo ./mount_umount-chroot.sh mi-ubuntu mount
sudo chroot /opt/jaulas/mi-ubuntu
```

---

[⬅ Volver](../README.md)
