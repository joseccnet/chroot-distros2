# Fedora Chroot

## Versiones Soportadas

| Versión | Estado | Soporte hasta |
|---|---|---|
| 44 | Latest stable | Mayo 2027 |
| 43 | Activo | Mayo 2026 |
| 42 | EOL | Mayo 2026 |
| 41 | EOL | Noviembre 2025 |
| 40-39 | EOL | 2024-2025 |
| 26-19 | Legacy EOL | 2015-2018 |

## Uso Básico

```bash
# Versión por defecto (Fedora 44)
sudo ./build-chroot-Fedora.sh mi-fedora

# Fedora 44 (latest)
sudo ./build-chroot-Fedora.sh mi-fedora 44

# Con arquitectura específica
sudo ./build-chroot-Fedora.sh mi-fedora 44 aarch64

# Versión legacy (EOL)
sudo ./build-chroot-Fedora.sh mi-fedora 43
```

## Variables de Entorno

| Variable | Descripción |
|---|---|
| `FORZAR_EOL` | Omite confirmación para versiones EOL |

## Características

- **Verificación SHA256**: Todos los RPMs verificados contra hashes en `chroot.conf`
- **Soporte aarch64**: Fedora 43+ disponible para ARM64
- **Init híbrido**: Usa `dnf` para Fedora 22+ (moderno), `yum` para legacy
- **Init híbrido**: Usa `dnf` para Fedora 22+ (moderno), `yum` para legacy

## Ejemplos

```bash
# Fedora 44 (latest)
sudo ./build-chroot-Fedora.sh mi-fedora 44

# Fedora 44 ARM64
sudo ./build-chroot-Fedora.sh mi-fedora-arm 44 aarch64

# Fedora 43
sudo ./build-chroot-Fedora.sh mi-fedora 43

# Fedora 41 EOL
sudo FORZAR_EOL=true ./build-chroot-Fedora.sh mi-fedora41 41
```

## Acceso a la jaula

```bash
sudo ./mount_umount-chroot.sh mi-fedora mount
sudo chroot /opt/jaulas/mi-fedora
```

---

[⬅ Volver](../README.md)
