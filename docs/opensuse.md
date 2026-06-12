# openSUSE Chroot

## Versiones Soportadas

| Versión | Tipo | Soporte hasta |
|---|---|---|
| 16.1 | Leap (Beta) | ~Octubre 2026 (futuro) |
| 16.0 | Leap (activo) | Octubre 2027 |
| 15.6 | Leap (activo) | Abril 2026 |
| tumbleweed | Rolling | Siempre actualizado |
| 15.5-15.0 | Leap (EOL) | 2021-2024 |
| 42.3-42.1 | Leap (EOL) | 2017-2019 |
| 13.2-13.1 | openSUSE (EOL) | 2016-2017 |
| 12.3-12.1 | openSUSE (EOL) | 2013-2015 |
| 11.4 | openSUSE (EOL) | 2012 |

## Uso Básico

```bash
# Versión por defecto (Leap 16.0)
sudo ./build-chroot-OpenSuse.sh mi-suse

# openSUSE Leap 16.0
sudo ./build-chroot-OpenSuse.sh mi-suse 16.0

# openSUSE Leap 16.1 Beta
sudo ./build-chroot-OpenSuse.sh mi-suse 16.1

# Tumbleweed (rolling)
sudo ./build-chroot-OpenSuse.sh mi-suse tumbleweed

# Con arquitectura específica
sudo ./build-chroot-OpenSuse.sh mi-suse 16.0 aarch64
```

## Variables de Entorno

| Variable | Descripción |
|---|---|
| `FORZAR_EOL` | Omite confirmación para versiones EOL |

## Características

- **Construcción con yum**: Usa `yum` en el host para bootstrappear, `zypper` dentro de la jaula
- **Configuración de repos**: Repos OSS + Update configurados automáticamente
- **DNS básico**: `8.8.8.8` configurado como nameserver por defecto
- **Soporte i586**: Versiones legacy para arquitectura de 32 bits
- **Advertencia de kernel**: OpenSUSE 13.2 puede fallar en kernels antiguos
- **Mirror fallback**: `mirrors.kernel.org` como alternativa a `download.opensuse.org`

## Ejemplos

```bash
# Leap 16.1 Beta
sudo ./build-chroot-OpenSuse.sh mi-suse 16.1

# Leap 16.0
sudo ./build-chroot-OpenSuse.sh mi-suse 16.0

# Tumbleweed (rolling release)
sudo ./build-chroot-OpenSuse.sh mi-suse tumbleweed

# Leap 15.5 EOL
sudo FORZAR_EOL=true ./build-chroot-OpenSuse.sh mi-suse 15.5
```

## Notas

> [!WARNING]
> Las versiones 13.2 y anteriores pueden tener problemas con kernels muy nuevos o muy antiguos. Verifica la compatibilidad antes de usarlas en producción.

> Tumbleweed es rolling release. Recibe actualizaciones continuas y puede tener cambios que rompan compatibilidad.

## Acceso a la jaula

```bash
sudo ./mount_umount-chroot.sh mi-suse mount
sudo chroot /opt/jaulas2/mi-suse
```

---

[⬅ Volver](../README.md)
