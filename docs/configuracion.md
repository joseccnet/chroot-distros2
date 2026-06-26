# Configuración

## Índice

- [chroot.conf — Configuración global](#chrootconf--configuración-global)
- [mychroot.conf — Configuración por jaula](#mychrootconf--configuración-por-jaula)
- [Variables de entorno](#variables-de-entorno)

---

## chroot.conf — Configuración global

Archivo ubicado en la raíz del proyecto. Es compartido por **todos** los scripts mediante `source`.

### Variables principales

| Variable | Default | Descripción |
|---|---|---|
| `ROOTJAIL` | `/opt/jaulas` | Directorio base donde se crean todas las jaulas |
| `TZ_CHROOT` | `America/Mexico_City` | Zona horaria que se configurará dentro de cada jaula |

### Paquetes por distribución

El archivo define paquetes adicionales específicos por versión de cada distro:

**Debian:**
```bash
# Moderno (12+)
paquetesAdicionalesDeb13_trixie="iputils-ping,default-mysql-client,vim,openssh-server,rsyslog,locales,locales-all,libc6,debian-keyring"

# Legacy (6-8): mysql-client en vez de default-mysql-client
paquetesAdicionalesDeb8_jessie="iputils-ping,mysql-client,vim,openssh-server,rsyslog,locales,locales-all,libc6"
```

**Ubuntu:**
```bash
# Moderno (24.04+): ubuntu-keyring incluido
paquetesAdicionalesUbuntu_noble="iputils-ping,default-mysql-client,vim,openssh-server,rsyslog,locales,libc6,ubuntu-keyring"

# Legacy (16.04-22.10): mysql-client
paquetesAdicionalesUbuntu_xenial="iputils-ping,mysql-client,vim,openssh-server,rsyslog,locales,libc6"
```

### URLs para CentOS y Fedora

El archivo contiene las URLs de los RPMs de `centos-release` y `fedora-release` necesarios para bootstrappear, incluyendo hashes SHA256 para verificación de integridad.

```bash
# Ejemplo: CentOS Stream 10
cs10rpm1="https://mirror.stream.centos.org/10-stream/BaseOS/x86_64/os/Packages/..."
sha256_cs10rpm1="32f78b6adec9f0e529eca5ed4a49f9a0e0449b6df5ff7882c8ed9afa94097bce"
```

### Funciones de paquetes

El archivo define funciones como `obtener_paquetes_debian()`, `obtener_paquetes_ubuntu()`, etc., que retornan la lista correcta de paquetes para cada versión.

> [!TIP]
> Puedes personalizar los paquetes editando las variables `paquetesAdicionales*` en `chroot.conf` ANTES de construir una jaula.

---

## mychroot.conf — Configuración por jaula

Cada jaula tiene su propio archivo `/etc/mychroot.conf` generado automáticamente durante la construcción. Define qué filesystems montar y qué servicios iniciar.

### Formato

```ini
# Filesystems a montar (FS:<ruta>):
FS:/proc
FS:/dev
FS:/dev/pts
FS:/sys
FS:/home

# Servicios a iniciar (Service:<ruta>):
Service:/etc/init.d/cron
# Service:/etc/init.d/rsyslog
```

### Filesystems disponibles

| FS | Descripción | Opciones de montaje |
|---|---|---|
| `/proc` | Sistema de procesos | `nosuid,noexec,nodev` |
| `/dev` | Dispositivos (bind) | `slave` |
| `/dev/pts` | Pseudoterminales | `bind` o `newinstance` |
| `/dev/shm` | Memoria compartida | `bind` + `slave` |
| `/sys` | Sistema de kernel | **Solo lectura** — `nosuid,noexec,nodev,ro` |
| `/run` | Archivos de runtime | `bind` + `slave` |
| `/home` | Directorios de usuarios (bind) | `slave` |

### Servicios disponibles

| Service | Descripción | RedHat | Debian/Ubuntu |
|---|---|---|---|
| cron/crond | Programador de tareas | `/etc/init.d/crond` | `/etc/init.d/cron` |
| rsyslog | Log del sistema | `/etc/init.d/rsyslog` | `/etc/init.d/rsyslog` |

> [!NOTE]
> El script detecta automáticamente la distribución y ajusta los nombres de servicios. No necesitas modificar `mychroot.conf` si cambias de distro.

---

## Variables de entorno

### Comunes a todos los scripts

| Variable | Valores | Scripts afectados | Descripción |
|---|---|---|---|
| `DRY_RUN` | `true` | `mount_umount-chroot.sh` | Muestra qué se haría sin ejecutar montajes/desmontajes |
| `ESPACIO_MINIMO_GB` | Número (default: 2) | `build-chroot-*` | Mínimo de GB libres requeridos para construir |

### Específicas de build

| Variable | Valores | Uso |
|---|---|---|
| `SIN_VERIFICACION_GPG` | `true` | Desactiva `--force-check-gpg` en debootstrap (solo desarrollo) |
| `INTERACTIVO` | `true` | Muestra menú interactivo para seleccionar versión |
| `FORZAR_EOL` | `true` | Omite confirmación para versiones EOL |
| `MIRROR_UBUNTU` | URL | Mirror personalizado para Ubuntu |
| `MIRROR_DEBIAN` | URL | Mirror personalizado para Debian |
| `MIRROR_DEVUAN` | URL | Mirror personalizado para Devuan |
| `MIRROR_KALI` | URL | Mirror personalizado para Kali |
| `SIN_DEBORPHAN` | `true` | Omite limpieza con deborphan en Debian |

### Específicas de gestión

| Variable | Valores | Uso |
|---|---|---|
| `FORZAR_ELIMINACION` | `true` | Omite confirmación al eliminar jaulas con `removeVM-chroot.sh` |
| `LOG_FILE` | Ruta (default: `/var/log/chroot-mounts.log`) | Archivo de log de operaciones de montaje/desmontaje |

### Cómo usar variables de entorno

```bash
# Una sola ejecución
sudo ESPACIO_MINIMO_GB=5 MIRROR_UBUNTU=http://mirror.local/ubuntu \
  ./build-chroot-Ubuntu.sh mi-ubuntu noble

# Exportar para toda la sesión
export FORZAR_EOL=true
export DRY_RUN=true
./build-chroot-Debian.sh mi-debian buster
./mount_umount-chroot.sh mi-debian mount
```

---

[Siguiente: Seguridad →](seguridad.md)

[Volver al inicio](../README.md)
