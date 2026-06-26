# CentOS Chroot

## Versiones Soportadas

| Versión | Tipo | Soporte hasta |
|---|---|---|
| Stream 10 | Activo | 2030 |
| Stream 9 | Activo | Mayo 2027 |
| 7 | EOL | Junio 2024 |
| 6 | EOL | Noviembre 2020 |
| 5 | EOL | Marzo 2017 |

## Uso Básico

```bash
# CentOS Stream 9
sudo ./build-chroot-Centos.sh mi-centos stream9

# CentOS Stream 10
sudo ./build-chroot-Centos.sh mi-centos stream10

# CentOS 7 (EOL)
sudo ./build-chroot-Centos.sh mi-centos7 7

# Con arquitectura específica
sudo ./build-chroot-Centos.sh mi-centos stream9 aarch64
```

## Variables de Entorno

| Variable | Descripción |
|---|---|
| `FORZAR_EOL` | Omite confirmación para versiones EOL |

## Características

- **Verificación SHA256**: Todos los RPMs de `centos-release` se verifican contra hashes definidos en `chroot.conf`
- **Soporte aarch64**: Stream 9 y 10 disponibles para ARM64
- **Soporte i386**: CentOS 5 y 6 legacy en 32 bits
- **Workaround CentOS 5**: Reconstrucción automática de RPM DB para compatibilidad
- **Configuración de repos**: Repos base + updates configurados automáticamente
- **Paquetes adicionales**: Incluye yum, vim, openssh-server, cronie, rsyslog

## Ejemplos

```bash
# Stream 9 con arquitectura específica
sudo ./build-chroot-Centos.sh mi-centos stream9 x86_64

# CentOS 7 legacy (EOL)
sudo FORZAR_EOL=true ./build-chroot-Centos.sh mi-centos7 7

# CentOS 5 (32 bits)
sudo ./build-chroot-Centos.sh mi-centos5 5 i386
```

## Notas

> CentOS Stream es un rolling release entre Fedora y RHEL. Recibe actualizaciones continuas. Las versiones "CentOS Linux" (5-7) son EOL y solo están disponibles desde vault.centos.org.

## Acceso a la jaula

```bash
sudo ./mount_umount-chroot.sh mi-centos mount
sudo chroot /opt/jaulas/mi-centos
```

---

[⬅ Volver](../README.md)
