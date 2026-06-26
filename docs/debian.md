# Debian Chroot

## Versiones Soportadas

| Versión | Codename | Tipo | Soporte hasta |
|---|---|---|---|
| 15 | Duke | Futuro | Codename anunciado |
| 14 | Forky | Testing | 2027 (será stable) |
| 13 | Trixie | Stable | Agosto 2028 |
| sid | Sid | Unstable | Rolling |
| 12 | Bookworm | Oldstable | Junio 2026 |
| 11 | Bullseye | Oldoldstable (LTS) | Agosto 2026 |
| 10-8 | Buster-Stretch-Jessie | EOL | Sin soporte (ELTS pago) |
| 7-6 | Wheezy-Squeeze | EOL | Sin soporte |

## Uso Básico

```bash
# Versión por defecto (trixie - Debian 13 stable)
sudo ./build-chroot-Debian.sh mi-debian

# Versión específica
sudo ./build-chroot-Debian.sh mi-debian bookworm

# Debian 14 (testing)
sudo ./build-chroot-Debian.sh mi-debian forky

# Con arquitectura
sudo ./build-chroot-Debian.sh mi-debian trixie arm64

# Versión EOL (requiere confirmación)
sudo ./build-chroot-Debian.sh mi-debian buster
```

## Variables de Entorno

| Variable | Default | Descripción |
|---|---|---|
| `SIN_VERIFICACION_GPG` | `false` | Desactiva GPG (solo desarrollo) |
| `MIRROR_DEBIAN` | auto | Mirror personalizado |
| `INTERACTIVO` | `false` | Menú interactivo |
| `FORZAR_EOL` | `false` | Omite confirmación EOL |
| `SIN_DEBORPHAN` | `false` | Omite limpieza con deborphan |
| `ESPACIO_MINIMO_GB` | `2` | Mínimo de GB requeridos |

## Características

- **Mirror inteligente**: Usa `deb.debian.org` para activas, `archive.debian.org` para EOL
- **Sources.list dinámico**: Genera repos correctos según versión (incluyendo updates/security)
- **Deborphan**: Limpieza automática de paquetes huérfanos (excepto en sid)
- **Debian-keyring**: Incluido automáticamente en versiones 13+
- **libc6-i386**: Agregado automáticamente en arquitectura amd64
- **Fallback de mirrors**: 3 intentos (principal → httpredir → archive)
- **Squeeze especial**: Desactiva `Check-Valid-Until` para repositorios EOL antiguos

## Ejemplos

```bash
# Mirror personalizado
sudo MIRROR_DEBIAN=http://ftp.debian.org/debian \
  ./build-chroot-Debian.sh mi-debian trixie

# Sid (unstable)
sudo ./build-chroot-Debian.sh mi-sid sid

# Debian 14 Forky (testing)
sudo ./build-chroot-Debian.sh mi-debian forky

# Sin deborphan (construcción más rápida)
sudo SIN_DEBORPHAN=true ./build-chroot-Debian.sh mi-debian bookworm

# Con espacio extra
sudo ESPACIO_MINIMO_GB=10 ./build-chroot-Debian.sh mi-debian trixie
```

## Acceso a la jaula

```bash
sudo ./mount_umount-chroot.sh mi-debian mount
sudo chroot /opt/jaulas/mi-debian
```

---

[⬅ Volver](../README.md)
