# Clonación de jaulas

Clona una jaula chroot existente para crear una copia independiente sin ejecutar `debootstrap` desde cero.

## Uso

```bash
sudo ./clone-chroot-Distro.sh origen destino
```

## Ejemplos

```bash
# Clonar mi-debian como copia-seguridad
sudo ./clone-chroot-Distro.sh mi-debian copia-seguridad

# Clonar producción a entorno de pruebas
sudo ./clone-chroot-Distro.sh prod-debian test-debian
```

## Flujo

1. **Validación**: Verifica que origen exista y destino NO exista
2. **Confirmación**: Pide permiso explícito antes de desmontar
3. **Desmontaje**: Desmonta la jaula origen (si está montada)
4. **Clonación**: `rsync -aHAX` preservando permisos, hardlinks, ACLs y atributos extendidos
5. **Ajuste**: Actualiza el resumen de construcción en el clon

## Directorios excluidos

Estos directorios NO se copian (son virtuales o temporales):

- `/proc` — sistema de procesos del kernel
- `/dev` — dispositivos
- `/sys` — sistema de archivos del kernel
- `/tmp` — archivos temporales
- `/run` — archivos de runtime
- `/mnt`, `/media` — puntos de montaje
- `/lost+found` — recuperación del sistema de archivos

## Después de clonar

Las jaulas quedan **desmontadas**. Debes montarlas manualmente:

```bash
sudo ./mount_umount-chroot.sh origen mount
sudo ./mount_umount-chroot.sh destino mount
```

> [!NOTE]
> El archivo `mychroot.conf` se copia tal cual del origen. Revísalo si necesitas cambios para la nueva jaula.

---

[⬅ Volver](../README.md)
