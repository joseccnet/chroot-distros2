# Devuan Chroot (Debian sin systemd)

## Versiones Soportadas

| Versión | Codename | Base Debian | Soporte |
|---|---|---|---|
| 7 (testing) | Freia | 14 Forky | Testing |
| 6 | Excalibur | 13 Trixie | Stable |
| 5 | Daedalus | 12 Bookworm | Oldstable |
| unstable | Ceres | sid | Rolling |
| 4 | Chimaera | 11 Bullseye | EOL |
| 3 | Beowulf | 10 Buster | EOL |
| 2 | ASCII | 9 Stretch | EOL |
| 1 | Jessie | 8 Jessie | EOL |

## Uso Básico

```bash
# Por defecto (daedalus 5 - oldstable)
sudo ./build-chroot-Devuan.sh mi-devuan

# Devuan 6 Excalibur (stable)
sudo ./build-chroot-Devuan.sh mi-devuan excalibur

# Devuan 7 Freia (testing)
sudo ./build-chroot-Devuan.sh mi-devuan freia

# Devuan 5 Daedalus
sudo ./build-chroot-Devuan.sh mi-devuan daedalus

# Ceres (unstable)
sudo ./build-chroot-Devuan.sh mi-devuan ceres

# Con arquitectura
sudo ./build-chroot-Devuan.sh mi-devuan excalibur arm64
```

## Variables de Entorno

| Variable | Default | Descripción |
|---|---|---|
| `SIN_VERIFICACION_GPG` | `false` | Desactiva GPG |
| `MIRROR_DEVUAN` | `http://deb.devuan.org/merged` | Mirror personalizado |
| `FORZAR_EOL` | `false` | Omite confirmación EOL |
| `ESPACIO_MINIMO_GB` | `2` | Mínimo de GB requeridos |

## Características

- **Sin systemd**: Usa **sysvinit** como init por defecto (runit y OpenRC disponibles)
- **Devuan-keyring**: Incluido en versiones modernas
- **Sources.list dinámico**: Configura repos correctos por versión
- **Compatible con scripts Debian**: Usa `debootstrap` igual que Debian
- **Mirror alternativo**: Fallback automático si el principal falla

## Ejemplos

```bash
# Mirror personalizado
sudo MIRROR_DEVUAN=http://mirror.devuan.org/merged \
  ./build-chroot-Devuan.sh mi-devuan daedalus

# Versión EOL
sudo FORZAR_EOL=true ./build-chroot-Devuan.sh mi-devuan chimaera

# Espacio personalizado
sudo ESPACIO_MINIMO_GB=5 ./build-chroot-Devuan.sh mi-devuan excalibur
```

## Notas

> Devuan es un fork de Debian que reemplaza systemd por sysvinit. Ideal si prefieres init clásico o necesitas compatibilidad con scripts SysV. Los servicios dentro de la jaula se inician con `/etc/init.d/` en vez de `systemctl`.

## Acceso a la jaula

```bash
sudo ./mount_umount-chroot.sh mi-devuan mount
sudo chroot /opt/jaulas2/mi-devuan
```

---

[⬅ Volver](../README.md)
