# Instalación

## Índice

- [Requisitos del sistema](#requisitos-del-sistema)
- [Dependencias por distribución](#dependencias-por-distribución)
- [Instalación](#instalación)
- [Verificación](#verificación)
- [Configuración inicial](#configuración-inicial)

---

## Requisitos del sistema

- **Sistema operativo:** Cualquier distribución Linux (las jaulas pueden ser de distribuciones diferentes al host)
- **Permisos:** Ejecución como **root** (sudo)
- **Arquitectura:** x86_64, i386, arm64, armhf, ppc64el, s390x (seleccionable por jaula)
- **Bash:** versión 4.3 o superior
- **Disco:** Mínimo 2 GB libres por jaula (configurable con `ESPACIO_MINIMO_GB`)
- **Red:** Acceso a los mirrors de las distribuciones

---

## Dependencias por distribución

### Debian / Ubuntu / Kali / Linux Mint / Devuan

```bash
sudo apt-get update
sudo apt-get install -y debootstrap wget gawk sed grep coreutils psmisc
```

### CentOS / RHEL / Fedora

```bash
sudo yum install -y yum wget coreutils sed grep psmisc
# O con dnf (Fedora moderno):
sudo dnf install -y yum wget coreutils sed grep psmisc
```

### openSUSE

```bash
sudo zypper install -y yum wget coreutils sed grep psmisc
```

> [!TIP]
> Para construir jaulas **Debian/Ubuntu/Kali/Devuan** solo necesitas `debootstrap`.
> Para **CentOS/Fedora/openSUSE** necesitas `yum` en el host (incluso si luegos usas `dnf` o `zypper` dentro de la jaula).

---

## Instalación

```bash
git clone https://github.com/joseccnet/chroot-distros.git
cd chroot-distros
chmod +x *.sh
```

> [!NOTE]
> No es necesaria una instalación como root. Los scripts se ejecutan directamente desde el directorio clonado.

### Verificar que todo funciona

```bash
# Ver sintaxis de todos los scripts
for f in *.sh lib/*.sh; do bash -n "$f" && echo "✓ $f" || echo "✗ $f"; done
```

> [!TIP]
> Todos los scripts pasan `bash -n` sin errores. Si alguno falla, es probable que tengas una versión muy antigua de bash.

---

## Configuración inicial

Antes de crear tu primera jaula, revisa el archivo [`chroot.conf`](configuracion.md#chrootconf) para ajustar:

| Variable | Default | Descripción |
|---|---|---|
| `ROOTJAIL` | `/opt/jaulas` | Directorio donde se crearán las jaulas |
| `TZ_CHROOT` | `America/Mexico_City` | Zona horaria dentro de las jaulas |

```bash
# Ejemplo: cambiar directorio base
ROOTJAIL=/var/chroot

# Ejemplo: cambiar zona horaria
TZ_CHROOT="Europe/Madrid"
```

> [!WARNING]
> Asegúrate de que el directorio `ROOTJAIL` tenga suficiente espacio en disco. Cada jaula consume entre 500 MB y 2 GB.

---

[Siguiente: Uso →](uso.md)

[Volver al inicio](../README.md)
