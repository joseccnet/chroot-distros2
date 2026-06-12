# Linux Mint Chroot

## Versiones Soportadas

| Versión Mint | Codename | Base Ubuntu | Estado |
|---|---|---|---|
| 22.3 | Zena | 24.04 Noble | LTS activa (hasta Abr 2029) |
| 22.2 | Zara | 24.04 Noble | LTS activa (hasta Abr 2029) |
| 22.1 | Xia | 24.04 Noble | LTS activa (hasta Abr 2029) |
| 22.0 | Wilma | 24.04 Noble | LTS activa (hasta Abr 2029) |
| 21.3 | Virginia | 22.04 Jammy | LTS activa (hasta Abr 2027) |
| 21.2 | Vera | 22.04 Jammy | LTS activa (hasta Abr 2027) |
| 21.1 | Victoria | 22.04 Jammy | LTS activa (hasta Abr 2027) |
| 21.0 | Vanessa | 22.04 Jammy | LTS activa (hasta Abr 2027) |
| 20.3-20.0 | Una-Ulyana | 20.04 Focal | EOL |
| 19.3-19.0 | Tricia-Tara | 18.04 Bionic | EOL |
| 18.3-18.0 | Sylvia-Sarah | 16.04 Xenial | EOL |
| 17.3-17.0 | Rosa-Qiana | 14.04 Trusty | EOL |

## Uso Básico

```bash
# Versión por defecto (wilma 22.0 - LTS activa)
sudo ./build-chroot-LinuxMint.sh mi-mint

# Versión específica
sudo ./build-chroot-LinuxMint.sh mi-mint zena
sudo ./build-chroot-LinuxMint.sh mi-mint wilma

# Versiones legacy EOL (requiere confirmación)
sudo ./build-chroot-LinuxMint.sh mi-mint vanessa
```

## Variables de Entorno

| Variable | Default | Descripción |
|---|---|---|
| `FORZAR_EOL` | `false` | Omite confirmación para versiones EOL |
| `MIRROR_UBUNTU` | `http://archive.ubuntu.com/ubuntu` | Mirror personalizado de Ubuntu |
| `MIRROR_MINT` | `http://packages.linuxmint.com` | Mirror personalizado de Linux Mint |
| `ESPACIO_MINIMO_GB` | `2` | Mínimo de GB requeridos |

## Características

- **Construcción en 2 pasos**: Primero construye la base Ubuntu con `build-chroot-Ubuntu.sh`, luego agrega los repositorios Mint
- **Repositorios Mint**: Archivos de configuración para versiones modernas en `linuxMint/`, generación dinámica para versiones sin archivo
- **Importación de claves**: `mint-keyring` instalado automáticamente para verificación GPG
- **Paquete mintsystem**: Instalado automáticamente para configuración base Mint
- **Workaround libpam-systemd**: Fix automático para error de postinst en jaulas sin systemd completo
- **Repos dinámicos**: Cuando no existe archivo de repos predefinido, se genera automáticamente con mirrors personalizables

## Ejemplos

```bash
# Linux Mint 22.3 Zena (latest)
sudo ./build-chroot-LinuxMint.sh mi-mint zena

# Linux Mint 22.0 Wilma
sudo ./build-chroot-LinuxMint.sh mi-mint wilma

# Linux Mint 21.3 Virginia
sudo ./build-chroot-LinuxMint.sh mi-mint virginia

# Mirror personalizado de Mint
sudo MIRROR_MINT=http://mirror.local/linuxmint \
  ./build-chroot-LinuxMint.sh mi-mint wilma

# Mirror personalizado de Ubuntu
sudo MIRROR_UBUNTU=http://mirror.local/ubuntu \
  ./build-chroot-LinuxMint.sh mi-mint wilma
```

## Acceso a la jaula

```bash
sudo ./mount_umount-chroot.sh mi-mint mount
sudo chroot /opt/jaulas2/mi-mint
```

---

[⬅ Volver](../README.md)
