# Preguntas Frecuentes

## Índice

- [General](#general)
- [Uso](#uso)
- [Seguridad](#seguridad)
- [Técnico](#técnico)

---

## General

### ¿Qué es chroot?

`chroot` es una operación de Unix que cambia el directorio raíz aparente para un proceso y sus hijos. Crea un ambiente aislado con su propio sistema de archivos, diferente al del sistema anfitrión.

### ¿Cuál es la diferencia con Docker?

| Aspecto | chroot-distros2 | Docker |
|---|---|---|
| Aislamiento | Solo sistema de archivos | Namespaces, cgroups, seccomp |
| Kernel | Compartido con el host | Compartido (pero con syscalls filtrados) |
| Red | Compartida (mismo stack) | Aislada (IP propia, NAT, bridge) |
| Recursos | Sin límites | CPU/memoria/IO controlados |
| Imágenes | Directorios en disco | Capas, registry, Dockerfile |
| Init | Manual o sysvinit | Entrypoint configurable |
| Ideal para | Servicios legacy, compilación | Microservicios, cloud, CI/CD |

> chroot-distros2 **no compite con Docker**. Son herramientas complementarias. Úsalas según tu necesidad.

### ¿Por qué elegir chroot en vez de Docker?

- **No necesitas Docker daemon** — solo bash y herramientas estándar de Linux
- **Arranque instantáneo** — no hay pull de imágenes, no hay layers
- **Sistema de archivos real** — puedes montar, particionar, y acceder a dispositivos
- **Menor overhead** — sin capas de red, sin storage drivers, sin orchestrators
- **Versiones EOL** — instala distribuciones que Docker ya no ofrece (Debian 6, CentOS 5, Ubuntu 12.04)
- **Legacy perfecto** — servicios antiguos que no funcionan en contenedores modernos

---

## Uso

### ¿Cómo entro a la jaula?

```bash
sudo chroot /opt/jaulas/mi-debian /bin/bash
```

Para salir, escribe `exit`.

### ¿Cómo instalo paquetes dentro de la jaula?

Una vez dentro:

```bash
# Debian/Ubuntu/Kali/Mint/Devuan
apt-get update
apt-get install -y nginx

# CentOS/Fedora
yum install -y httpd

# OpenSUSE
zypper install -y nginx
```

### ¿Cómo accedo a mis archivos del host desde la jaula?

Si agregaste `FS:/home` en `/etc/mychroot.conf`, tu `/home` del host está montado dentro de la jaula en `/home`. Si necesitas otras rutas, agrégalas como:

```ini
# En /etc/mychroot.conf
FS:/data
FS:/opt/compartido
```

### ¿Cómo hago backup de una jaula?

```bash
# Desmontar primero
sudo ./mount_umount-chroot.sh mi-debian umount

# Comprimir
sudo tar -czf mi-debian-backup.tar.gz -C /opt/jaulas mi-debian

# Restaurar
sudo tar -xzf mi-debian-backup.tar.gz -C /opt/jaulas
```

### ¿Puedo tener varias versiones de la misma distro?

Sí. Cada jaula es independiente:

```bash
sudo ./build-chroot-Debian.sh debian-11 bullseye
sudo ./build-chroot-Debian.sh debian-12 bookworm
sudo ./build-chroot-Debian.sh debian-13 trixie
```

### ¿Puedo mover una jaula a otro servidor?

Sí, siempre que el otro servidor tenga el mismo kernel o uno más nuevo:

```bash
# En el origen
sudo ./mount_umount-chroot.sh mi-debian umount
sudo tar -czf mi-debian.tar.gz -C /opt/jaulas mi-debian

# En el destino
sudo tar -xzf mi-debian.tar.gz -C /opt/jaulas
sudo ./mount_umount-chroot.sh mi-debian mount
sudo chroot /opt/jaulas/mi-debian /bin/bash
```

---

## Seguridad

### ¿Es seguro chroot para producción?

Depende del contexto. Para **aislar servicios legacy** (Apache 2.2, PHP 5.x) es aceptable con las mitigaciones que aplica este proyecto (mounts readonly, nosuid, noexec). Para **confinar usuarios no confiables**, NO.

### ¿Puedo escapar de una jaula chroot?

Sí, si tienes `root` dentro de la jaula:
```bash
mkdir -p /tmp/breakout
chroot /tmp/breakout
```
También si tienes acceso a `/dev`, `/proc`, o `CAP_SYS_CHROOT`.

### ¿Cómo mitigan esto los scripts?

- `/sys` montado en **solo lectura**
- Bind mounts con **make-slave** (evita propagación)
- Verificación de integridad SHA256 en RPMs
- GPG forzado en debootstrap
- PATH restringido en librería compartida

---

## Técnico

### ¿Qué kernel usa la jaula?

El **mismo que el host**. `chroot` no cambia el kernel. `uname -r` devuelve lo mismo dentro y fuera de la jaula.

### ¿Cómo verifico los límites de recursos dentro de la jaula?

Los límites (ulimit) se **heredan del proceso padre**:

```bash
# Ver desde el host
ulimit -n

# Entrar a la jaula y verificar (debe ser el mismo valor)
sudo chroot /opt/jaulas/mi-debian /bin/bash -c "ulimit -n"
```

Para cambiarlos:
```bash
# Temporal, antes de hacer chroot
prlimit --nofile=65536 chroot /opt/jaulas/mi-debian /bin/bash

# Permanente: editar /etc/security/limits.conf del host
```

[Ver guía completa de límites](../README.md#límites-del-sistema)

### ¿Por qué `free -m` dentro de la jaula muestra la RAM del host?

Porque el kernel es el mismo. `free`, `top`, `ps` muestran información del sistema host, no de la jaula.

### ¿Puedo usar systemd dentro de la jaula?

Parcialmente. `systemd` como init (PID 1) no funciona bien. Los servicios individuales que usan systemd pueden arrancarse manualmente, pero `systemctl` tendrá problemas. Los scripts detectan si hay systemd y ofrecen alternativas de inicio manual.

### ¿Qué archivos de log genera?

| Archivo | Descripción |
|---|---|
| `/var/log/chroot-mounts.log` | Todas las operaciones de montaje/desmontaje con timestamp |
| `$CHROOT/etc/resumen-construccion.txt` | Resumen de la construcción (fecha, versión, paquetes) |

### ¿Qué pasa si se interrumpe una construcción?

El `trap` de `EXIT` captura el error y muestra instrucciones de limpieza. Puedes:

```bash
# 1. Ver el estado
sudo ./mount_umount-chroot.sh status

# 2. Desmontar si quedó algo montado
sudo ./mount_umount-chroot.sh jaula-parcial umount

# 3. Eliminar el chroot parcial
sudo rm -rf /opt/jaulas/jaula-parcial

# 4. Reintentar la construcción
```

---

[Volver al inicio](../README.md)
