# Solución de problemas

## Índice

- [Error de GPG en Kali Linux](#error-de-gpg-en-kali-linux)
- [FATAL: kernel too old en OpenSUSE 13.2](#fatal-kernel-too-old-en-opensuse-132)
- [Error de yum en Debian 7](#error-de-yum-en-debian-7)
- [pycurl.error al instalar Fedora desde Ubuntu 14.10](#pycurlerror-al-instalar-fedora-desde-ubuntu-1410)
- [Fallo de mirror / conexión](#fallo-de-mirror--conexión)
- [Espacio en disco insuficiente](#espacio-en-disco-insuficiente)
- [No se puede desmontar (device busy)](#no-se-puede-desmontar-device-busy)
- [Jaula sin desmontar antes de borrar](#jaula-sin-desmontar-antes-de-borrar)
- [Error: "No existe archivo de configuración: /etc/mychroot.conf"](#error-no-existe-archivo-de-configuración-etcmychrootconf)

---

## Error de GPG en Kali Linux

**Síntoma:**
```
W: GPG error: http://http.kali.org kali Release: The following signatures
couldn't be verified because the public key is not available: NO_PUBKEY ED444FF07D8D0BF6
```

**Solución:**

```bash
# Dentro de la jaula de Kali
sudo chroot /opt/jaulas2/mi-kali /bin/bash
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys ED444FF07D8D0BF6
apt-get update
```

> [!NOTE]
> Reemplaza `ED444FF07D8D0BF6` por el código de la llave que aparezca en tu error. Si el keyserver no responde, intenta con `hkp://pool.sks-keyservers.net`.

---

## FATAL: kernel too old en OpenSUSE 13.2

**Síntoma:** Al construir una jaula OpenSUSE 13.2 desde CentOS 6.x:
```
FATAL: kernel too old
```

**Causa:** OpenSUSE 13.2 requiere un kernel más reciente que CentOS 6. El kernel del host es la versión que usan todas las jaulas.

**Soluciones:**
- Usar un host con kernel más reciente (CentOS 7+, Debian 8+, Ubuntu 16.04+)
- Actualizar el kernel del host (no siempre posible)
- La jaula de OpenSUSE 13.2 funciona desde hosts con kernel 3.x o superior

---

## Error de yum en Debian 7

**Síntoma:**
```
EOFError: compressed file ended before the logical end-of-stream was detected
```

Al construir una jaula Fedora desde Debian 7.

**Causa:** La versión de yum en Debian 7 (wheezy) es muy antigua y tiene problemas de compatibilidad.

**Solución:**

```bash
# Agregar backports de wheezy
echo 'deb http://http.debian.net/debian wheezy-backports main' >> /etc/apt/sources.list
apt-get update
apt-get -t wheezy-backports install yum
```

O mejor, actualiza tu sistema a Debian 8+ o Ubuntu 16.04+.

---

## pycurl.error al instalar Fedora desde Ubuntu 14.10

**Síntoma:**
```
pycurl.error: (43, 'CURLOPT_SSL_VERIFYHOST no longer supports 1 as value!')
```

**Causa:** Incompatibilidad entre Python 2.7 y pycurl en Ubuntu 14.10.

**Solución:**

Editar `/usr/lib/python2.7/dist-packages/urlgrabber/grabber.py` línea 1193:

```python
# Cambiar:
self.curl_obj.setopt(pycurl.SSL_VERIFYHOST, opts.ssl_verify_host)
# Por:
self.curl_obj.setopt(pycurl.SSL_VERIFYHOST, 0)
```

> [!WARNING]
> Esta solución deshabilita la verificación del host SSL. Usa solo para pruebas locales.

---

## Fallo de mirror / conexión

**Síntoma:**
```
✗ ERROR: Falló debootstrap en todos los mirrors.
```

**Causas posibles:**

- El mirror está caído o bloquea tu IP
- No tienes conexión a internet
- El mirror no tiene la versión solicitada (versiones EOL)

**Soluciones:**

```bash
# 1. Usar un mirror personalizado
sudo MIRROR_UBUNTU=http://mirror.local/ubuntu \
  ./build-chroot-Ubuntu.sh mi-ubuntu noble

# 2. Verificar conectividad
ping -c 3 archive.ubuntu.com

# 3. Si es una versión EOL, el script ya intenta old-releases automáticamente
#    También puedes forzar:
sudo FORZAR_EOL=true ./build-chroot-Debian.sh mi-debian buster
```

---

## Espacio en disco insuficiente

**Síntoma:**
```
✗ ERROR: Espacio en disco insuficiente en /opt/jaulas2
```

**Solución:**

```bash
# 1. Verificar espacio disponible
df -h /opt/jaulas2

# 2. Aumentar el mínimo requerido (si tienes espacio pero el cálculo falla)
sudo ESPACIO_MINIMO_GB=1 ./build-chroot-Debian.sh mi-debian trixie

# 3. Limpiar jaulas viejas
sudo ./removeVM-chroot.sh --list
sudo ./removeVM-chroot.sh jaula-vieja

# 4. Cambiar directorio base a una partición con más espacio
# Editar ROOTJAIL en chroot.conf
```

---

## No se puede desmontar (device busy)

**Síntoma:**
```
⚠ ADVERTENCIA: No se pudo desmontar. Terminando procesos...
✗ ERROR: No se pudo desmontar después de 3 intentos
```

**Solución:**

```bash
# 1. El script ya intenta terminar procesos automáticamente
# 2. Si falla, puedes forzar desmontaje lazy:
sudo umount -l /opt/jaulas2/mi-debian/proc
sudo umount -l /opt/jaulas2/mi-debian/dev
# ... repetir para cada FS montado

# 3. O usar el script de clean-up
sudo ./mount_umount-chroot.sh mi-debian umount
```

> [!WARNING]
> El desmontaje lazy (`umount -l`) deja el filesystem en un estado inconsistente. Es un último recurso.

---

## Jaula sin desmontar antes de borrar

**Síntoma:** Intentas borrar y el sistema falla o queda inestable.

**Causa:** Borrar manualmente los directorios mientras los filesystems están montados.

**Solución:**

```bash
# ❌ INCORRECTO (peligroso)
sudo rm -rf /opt/jaulas2/mi-debian

# ✅ CORRECTO
sudo ./removeVM-chroot.sh mi-debian
```

Este script:
1. Verifica que no haya filesystems montados
2. Si los hay, intenta desmontarlos automáticamente
3. Pide confirmación explícita
4. Elimina de forma segura

---

## Error: "No existe archivo de configuración: /etc/mychroot.conf"

**Síntoma:**
```
✗ ERROR: No existe archivo de configuración: /opt/jaulas2/mi-debian/etc/mychroot.conf
```

**Causa:** La jaula se construyó con una versión antigua del script o el archivo fue borrado manualmente.

**Solución:**

```bash
# Crear el archivo manualmente
sudo tee /opt/jaulas2/mi-debian/etc/mychroot.conf << 'EOF'
FS:/proc
FS:/dev
FS:/dev/pts
FS:/sys
FS:/home

Service:/etc/init.d/cron
EOF
```

O, si la jaula está intacta, puedes reconstruir solo el archivo de configuración:
```bash
sudo mkdir -p /opt/jaulas2/mi-debian/etc
# Editar con tu editor favorito
sudo nano /opt/jaulas2/mi-debian/etc/mychroot.conf
```

---

[Volver al inicio](../README.md)
