# Chroot Distros

![Bash](https://img.shields.io/badge/bash-4.3%2B-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Platform](https://img.shields.io/badge/platform-linux-lightgrey)

> Construye, monta y gestiona jaulas **chroot** con múltiples distribuciones Linux. Profesional, robusto y listo para producción.

Crea entornos aislados con **8+ distribuciones** para compilación, pruebas, servicios legacy, entrenamiento o cualquier necesidad que requiera un sistema de archivos independiente sin el overhead de contenedores completos.

---

## Características clave

- **8 distribuciones** — Debian, Ubuntu, CentOS, Fedora, Devuan, Kali, Mint, openSUSE
- **Multi-arquitectura** — amd64, i386, arm64, armhf, ppc64el, s390x (incluye construcción cruzada)
- **Hardened mounts** — `nosuid,noexec,nodev`, `make-slave`, `/sys` readonly
- **Migración de usuarios** — Sincroniza usuarios del host al chroot (UID ≥ 1000)
- **Idempotente** — No monta dos veces el mismo filesystem
- **Dry-run** — Previsualiza montajes/desmontajes sin ejecutarlos
- **Logging** — Todas las operaciones quedan registradas en `/var/log/chroot-mounts.log`
- **SSH-ready** — Genera configuración lista para `ChrootDirectory` en sshd
- **Gestión de EOL** — Advertencias y mirrors para versiones sin soporte
- **Eliminación segura** — Múltiples capas de protección antes de borrar

---

## Quick Start

```bash
# 1. Clonar
git clone https://github.com/joseccnet/chroot-distros.git
cd chroot-distros

# 2. Crear una jaula
sudo ./build-chroot-Debian.sh mi-debian trixie

# 3. Montar filesystems
sudo ./mount_umount-chroot.sh mi-debian mount

# 4. Entrar y trabajar
sudo chroot /opt/jaulas/mi-debian

# 5. Salir y desmontar
exit
sudo ./mount_umount-chroot.sh mi-debian umount
```

---

## Distribuciones soportadas

| Distribución | Script | Arquitecturas | Rango de versiones |
|---|---|---|---|
| [Ubuntu](docs/ubuntu.md) | `build-chroot-Ubuntu.sh` | amd64, i386, arm64, armhf, ppc64el, s390x | 10.04 → 26.04 LTS |
| [Debian](docs/debian.md) | `build-chroot-Debian.sh` | amd64, i386, arm64, armhf, ppc64el, s390x | 6 → 14 (testing) |
| [Devuan](docs/devuan.md) | `build-chroot-Devuan.sh` | amd64, i386, arm64, armhf | 1 → 6 |
| [Kali Linux](docs/kali.md) | `build-chroot-Kali.sh` | amd64, i386, arm64, armhf | Rolling + legacy |
| [Linux Mint](docs/linuxmint.md) | `build-chroot-LinuxMint.sh` | amd64, i386 | 17.x → 21.x |
| [CentOS](docs/centos.md) | `build-chroot-Centos.sh` | x86_64, aarch64, i386 | 5 → Stream 10 |
| [Fedora](docs/fedora.md) | `build-chroot-Fedora.sh` | x86_64, aarch64, i386 | 19 → 43 |
| [openSUSE](docs/opensuse.md) | `build-chroot-OpenSuse.sh` | x86_64, i586, aarch64 | 11.4 → 16.0 |

---

## Scripts de gestión

| Script | Función |
|---|---|
| `mount_umount-chroot.sh` | Monta/desmonta filesystems de las jaulas. Modos: `mount`, `umount`, `mountall`, `umountall`, `status` |
| `clone-chroot-Distro.sh` | Clona una jaula existente sin reinstalar desde cero |
| `removeVM-chroot.sh` | Elimina jaulas de forma segura con validación de nombre, verificación de desmontaje y confirmación explícita |
| `update_chroot-distros.sh` | Actualiza el repositorio local |

---

## Ejemplos

### Crear una jaula

```bash
# Debian 13 (stable) — versión por defecto
sudo ./build-chroot-Debian.sh mi-debian

# Ubuntu 24.04 LTS con arquitectura específica
sudo ./build-chroot-Ubuntu.sh mi-ubuntu noble amd64

# CentOS Stream 9
sudo ./build-chroot-Centos.sh mi-centos stream9

# Kali Linux rolling
sudo ./build-chroot-Kali.sh mi-kali kali-rolling
```

### Gestionar jaulas

```bash
# Ver estado de todas las jaulas (montadas, procesos, filesystems)
sudo ./mount_umount-chroot.sh status

# Montar una jaula
sudo ./mount_umount-chroot.sh mi-debian mount

# Desmontar
sudo ./mount_umount-chroot.sh mi-debian umount

# Montar/desmontar todas
sudo ./mount_umount-chroot.sh mountall
sudo ./mount_umount-chroot.sh umountall

# Modo dry-run (previsualizar sin ejecutar)
sudo DRY_RUN=true ./mount_umount-chroot.sh mi-debian mount

# Eliminar una jaula (pide confirmación)
sudo ./removeVM-chroot.sh mi-debian

# Listar jaulas disponibles
sudo ./removeVM-chroot.sh --list
```

### Opciones avanzadas

```bash
# Mirror personalizado
sudo MIRROR_UBUNTU=http://mirror.local/ubuntu \
  ./build-chroot-Ubuntu.sh mi-ubuntu noble

# Modo interactivo (menú de selección de versión)
sudo INTERACTIVO=true ./build-chroot-Ubuntu.sh mi-ubuntu

# Construcción cruzada (host amd64 → target arm64)
sudo ./build-chroot-Debian.sh mi-debian-arm trixie arm64

# Versión EOL (sin soporte)
sudo FORZAR_EOL=true ./build-chroot-Debian.sh mi-debian buster

# Sin verificación GPG (solo desarrollo)
sudo SIN_VERIFICACION_GPG=true ./build-chroot-Ubuntu.sh mi-ubuntu noble

# Espacio mínimo personalizado
sudo ESPACIO_MINIMO_GB=10 ./build-chroot-Debian.sh mi-debian trixie
```

---

## Documentación

| Documento | Descripción |
|---|---|
| [Instalación](docs/instalacion.md) | Requisitos, dependencias, instalación y verificación |
| [Uso](docs/uso.md) | Comandos detallados, ejemplos para cada rol |
| [Configuración](docs/configuracion.md) | Variables de entorno, chroot.conf, mychroot.conf |
| [Seguridad](docs/seguridad.md) | Hardening, limitaciones de chroot, buenas prácticas |
| [Solución de problemas](docs/solucion-problemas.md) | Errores comunes y cómo resolverlos |
| [Clonación](docs/clonacion.md) | Clonar jaulas sin reinstalar desde cero |
| [FAQ](docs/faq.md) | Preguntas frecuentes |

---

## Límites del sistema

Los procesos dentro de la jaula **heredan** los límites (`ulimit`) del proceso padre. Para producción con bases de datos, ajusta estos valores en el host antes de hacer chroot:

```bash
# Ver límites actuales
ulimit -a

# Ajustar antes de entrar a la jaula
prlimit --nofile=65536 --memlock=unlimited \
  chroot /opt/jaulas/mi-debian /bin/bash

# Hacerlo permanente (/etc/security/limits.conf)
root    soft    nofile      1048576
root    hard    nofile      1048576
root    soft    memlock     unlimited
root    hard    memlock     unlimited
```

> [!TIP]
> El `open files` (nofile) es el límite más crítico. Con el default de 1024, bases de datos con más de ~90 conexiones fallarán con `too many open files`.

---

## Advertencias

> [!WARNING]
> **NUNCA borres directorios en `ROOTJAIL` manualmente** sin desmontar primero. Usa siempre `removeVM-chroot.sh`.

```bash
# ❌ INCORRECTO — peligroso
sudo rm -rf /opt/jaulas/mi-debian

# ✅ CORRECTO — seguro
sudo ./removeVM-chroot.sh mi-debian
```

> [!IMPORTANT]
> **`chroot` NO es un mecanismo de seguridad.** Un proceso con `root` dentro de la jaula puede potencialmente escapar. Para aislamiento real (red, procesos, recursos), usa contenedores (Docker, LXC).

---

## Licencia

Este proyecto se proporciona "tal cual", sin garantía de ningún tipo. Úselo bajo su propia responsabilidad.

---

**Autor:** [@joseccnet](https://github.com/joseccnet)
