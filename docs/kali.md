# Kali Linux Chroot

## Versiones Soportadas

| Versión | Tipo | Soporte |
|---|---|---|
| kali-rolling | Rolling release | Activa |
| sana | EOL (Kali 2.0 - 2015) | Sin soporte |

## Uso Básico

```bash
# Kali rolling (recomendado)
sudo ./build-chroot-Kali.sh mi-kali

# Con arquitectura específica
sudo ./build-chroot-Kali.sh mi-kali kali-rolling
sudo ./build-chroot-Kali.sh mi-kali kali-rolling arm64

# Kali sana (legacy EOL)
sudo FORZAR_EOL=true ./build-chroot-Kali.sh mi-kali sana
```

## Variables de Entorno

| Variable | Default | Descripción |
|---|---|---|
| `SIN_VERIFICACION_GPG` | `false` | Desactiva GPG (solo desarrollo) |
| `MIRROR_KALI` | `http://http.kali.org/kali` | Mirror personalizado |
| `FORZAR_EOL` | `false` | Omite confirmación para versiones EOL |
| `ESPACIO_MINIMO_GB` | `2` | Mínimo de GB requeridos |

## Características

- **Rolling release**: Actualizaciones continuas de herramientas de seguridad
- **Kali-archive-keyring**: Descargado automáticamente con 3 métodos de fallback (wget directo, descarga .deb, keyserver)
- **Sources.list dinámico**: kali-rolling no tiene repositorio updates separado
- **Fallback de mirrors**: Bucle sobre 3 mirrors (personalizado → http.kali.org → kali.download)
- **Construcción cruzada**: Soporte para arm64, armhf, i386

## Ejemplos

```bash
# Por defecto (kali-rolling)
sudo ./build-chroot-Kali.sh mi-kali

# Mirror personalizado
sudo MIRROR_KALI=http://kali.download/kali \
  ./build-chroot-Kali.sh mi-kali

# Arquitectura ARM64
sudo ./build-chroot-Kali.sh mi-kali-arm kali-rolling arm64

# Sin GPG (desarrollo local)
sudo SIN_VERIFICACION_GPG=true ./build-chroot-Kali.sh mi-kali
```

## Notas

> [!WARNING]
> Kali Linux es una distribución especializada en **pruebas de penetración y auditoría de seguridad**. Úsala de manera responsable y solo en sistemas que tengas autorización para auditar.

> [!TIP]
> Si `apt-get update` dentro de la jaula falla con `NO_PUBKEY`, la clave GPG se importa automáticamente. Si aún así falla, ejecuta manualmente:
> ```bash
> sudo chroot /ruta/jaula apt-key adv --keyserver keyserver.ubuntu.com --recv-keys ED444FF07D8D0BF6
> ```

## Acceso a la jaula

```bash
sudo ./mount_umount-chroot.sh mi-kali mount
sudo chroot /opt/jaulas2/mi-kali
```

---

[⬅ Volver](../README.md)
