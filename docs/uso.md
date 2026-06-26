# Uso

## Índice

- [Flujo de trabajo general](#flujo-de-trabajo-general)
- [Para usuarios nuevos](#para-usuarios-nuevos)
- [Para usuarios avanzados](#para-usuarios-avanzados)
- [Para administradores](#para-administradores)
- [Acceso SSH con ChrootDirectory](#acceso-ssh-con-chrootdirectory)

---

## Flujo de trabajo general

```
1. Revisar configuración → chroot.conf
2. Crear jaula         → ./build-chroot-<Distro>.sh nombre [version] [arquitectura]
3. Montar filesystems  → ./mount_umount-chroot.sh nombre mount
4. Entrar a la jaula   → chroot /ruta/de/jaula /bin/bash
5. Trabajar dentro     → instalar paquetes, configurar servicios, etc.
6. Salir de la jaula   → exit
7. Desmontar           → ./mount_umount-chroot.sh nombre umount
```

---

## Para usuarios nuevos

### 1. Crear una jaula

```bash
# Debian 13 (stable)
sudo ./build-chroot-Debian.sh mi-debian trixie

# Ubuntu 24.04 LTS
sudo ./build-chroot-Ubuntu.sh mi-ubuntu noble

# CentOS Stream 9
sudo ./build-chroot-Centos.sh mi-centos stream9
```

| Parámetro | Ejemplo | Explicación |
|---|---|---|
| `NombreJaula` | `mi-debian` | Nombre del directorio dentro de `ROOTJAIL`. Se usará para montar/desmontar |
| `versión` | `trixie`, `noble`, `stream9` | Codename o número de versión. Si se omite, usa la versión por defecto |
| `arquitectura` | `amd64`, `arm64`, `i386` | Si se omite, detecta la del host automáticamente |

**Salida esperada:**
```
ℹ INFO: Auditoría de dependencias del sistema...
✓ ÉXITO: Auditoría de dependencias superada.

 - - - - - - - - - - - - - - - - - -
 Instalando Debian Chroot
 - - - - - - - - - - - - - - - - - -
 Jaula:        /opt/jaulas/mi-debian
 Versión:      trixie
 ...
✓ ÉXITO: La jaula /opt/jaulas/mi-debian fue creada exitosamente.
```

### 2. Ver el estado de las jaulas

```bash
sudo ./mount_umount-chroot.sh status
```

**Salida esperada:**
```
  Reporte de jaulas en /opt/jaulas
  ─────────────────────────────────
  ● /opt/jaulas/mi-debian [MONTADA]
    ├─ Procesos: bash(12345), cron(12346)
    └─ Filesystems:
      ├─ /proc (proc, nosuid,noexec,nodev)
      ├─ /dev (devtmpfs, nosuid,nodev)
      ├─ /sys (sysfs, ro)
      └─ /home (/dev/sda2, rw)

  ○ /opt/jaulas/mi-ubuntu [DESMONTADA]
    ├─ Procesos: ninguno
    └─ Filesystems: ninguno
```

### 3. Montar una jaula existente

```bash
sudo ./mount_umount-chroot.sh mi-debian mount
```

### 4. Entrar a la jaula

```bash
sudo chroot /opt/jaulas/mi-debian /bin/bash
```

Una vez dentro, notarás el prompt de chroot:
```
[(chroot)root@host /]#
```

Dentro puedes instalar paquetes, configurar servicios, compilar, etc.:
```bash
apt-get update
apt-get install -y nginx
service nginx start
```

### 5. Desmontar al terminar

```bash
# Salir de la jaula primero
exit

# Desmontar filesystems
sudo ./mount_umount-chroot.sh mi-debian umount
```

---

## Para usuarios avanzados

### Construcción cruzada (cross-compilation)

Crea una jaula para una arquitectura diferente a la del host:

```bash
# En un host amd64, crear jaula ARM64
sudo ./build-chroot-Ubuntu.sh mi-ubuntu-arm noble arm64
```

Esto ejecuta `debootstrap --foreign`. Después debes completar la segunda etapa manualmente:

```bash
# 1. Montar filesystems
sudo ./mount_umount-chroot.sh mi-ubuntu-arm mount

# 2. Segunda etapa
sudo chroot /opt/jaulas/mi-ubuntu-arm /debootstrap/debootstrap --second-stage

# 3. Actualizar
sudo chroot /opt/jaulas/mi-ubuntu-arm apt-get update && apt-get -y upgrade

# 4. Desmontar
sudo ./mount_umount-chroot.sh mi-ubuntu-arm umount
```

### Mirror personalizado

```bash
sudo MIRROR_UBUNTU=http://mx.archive.ubuntu.com/ubuntu \
  ./build-chroot-Ubuntu.sh mi-ubuntu noble

sudo MIRROR_DEBIAN=http://ftp.debian.org/debian \
  ./build-chroot-Debian.sh mi-debian bookworm
```

### Modo interactivo

Útil cuando no recuerdas los nombres de las versiones:

```bash
sudo INTERACTIVO=true ./build-chroot-Ubuntu.sh mi-ubuntu
```

Te mostrará un menú para seleccionar la versión.

### Modo dry-run

Previsualiza las operaciones de montaje/desmontaje sin ejecutarlas:

```bash
sudo DRY_RUN=true ./mount_umount-chroot.sh mi-debian mount
```

Salida:
```
ℹ INFO: [DRY-RUN] Montaría: /proc → /opt/jaulas/mi-debian/proc
ℹ INFO: [DRY-RUN] Montaría: /dev → /opt/jaulas/mi-debian/dev
...
```

### Sin verificación GPG (solo desarrollo)

```bash
sudo SIN_VERIFICACION_GPG=true ./build-chroot-Ubuntu.sh mi-ubuntu noble
```

> [!WARNING]
> Desactivar GPG **no es seguro** para producción. Usar solo en entornos de pruebas o sin acceso a internet.

### Forzar versión EOL

```bash
sudo FORZAR_EOL=true ./build-chroot-Debian.sh mi-debian buster
```

Omite la confirmación manual para versiones sin soporte.

---

## Para administradores

### Montar / desmontar todas las jaulas

```bash
# Montar todas
sudo ./mount_umount-chroot.sh mountall

# Desmontar todas
sudo ./mount_umount-chroot.sh umountall
```

### Eliminar una jaula

```bash
# Listar jaulas disponibles
sudo ./removeVM-chroot.sh --list

# Eliminar (pide confirmación escribiendo "ELIMINAR")
sudo ./removeVM-chroot.sh mi-debian

# Eliminación forzada (para scripts automatizados)
sudo FORZAR_ELIMINACION=true ./removeVM-chroot.sh mi-debian
```

> [!WARNING]
> `removeVM-chroot.sh` **no se puede deshacer**. Valida que no haya filesystems montados y pide confirmación explícita.

### Solo desmontar sin eliminar

```bash
sudo ./removeVM-chroot.sh mi-debian umountonly
```

---

## Acceso SSH con ChrootDirectory

Para que un usuario remoto (via SSH) quede atrapado dentro de la jaula:

### 1. En el archivo `/etc/ssh/sshd_config`, agrega:

```ini
Match User userbob
        ChrootDirectory /opt/jaulas/mi-debian
        X11Forwarding no
        AllowTcpForwarding no
```

### 2. Reinicia el servicio SSH:

```bash
sudo service sshd restart
# o
sudo systemctl restart sshd
```

### 3. Para usuarios NO root, necesitas `chroot` con capabilities:

```bash
# Como root (una sola vez)
cp /usr/sbin/chroot /usr/sbin/chrootuser
setcap cap_sys_chroot+ep /usr/sbin/chrootuser
```

Luego el usuario puede entrar con:
```bash
/usr/sbin/chrootuser /opt/jaulas/mi-debian
```

---

[Siguiente: Configuración →](configuracion.md)

[Volver al inicio](../README.md)
