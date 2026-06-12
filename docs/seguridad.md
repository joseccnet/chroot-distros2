# Seguridad

## Índice

- [Hardening aplicado](#hardening-aplicado)
- [Limitaciones de chroot](#limitaciones-de-chroot)
- [Qué funciona bien](#qué-funciona-bien)
- [Qué no funciona](#qué-no-funciona)
- [Buenas prácticas](#buenas-prácticas)

---

## Hardening aplicado

`chroot-distros2` implementa varias capas de seguridad para entornos productivos:

### Montajes seguros

| Medida | Aplicación |
|---|---|
| `nosuid` | Ignora el bit setuid en todos los bind mounts |
| `noexec` | Evita ejecución de binarios en `/proc` y `/sys` |
| `nodev` | Bloquea dispositivos no autorizados |
| `/sys` en **solo lectura** | Impide modificar parámetros del kernel desde la jaula |
| `make-slave` | Aísla la propagación de eventos de montaje (unmount dentro no afecta al host) |

### Gestión de procesos

- Terminación gradual con `fuser -TERM` antes de `-KILL`
- Detección de procesos residuales con `find /proc/*/root -lname`
- Clean-up con lazy unmount como último recurso

### Verificación de integridad

- **GPG forzado** por defecto en debootstrap (`--force-check-gpg`)
- **SHA256** para RPMs de CentOS/Fedora descargados
- Hashes definidos en `chroot.conf` con verificación antes de instalación

### Control de acceso

- **PATH restringido** a directorios del sistema (`/usr/sbin:/usr/bin:/sbin:/bin`)
- **Permiso 640** en archivos de configuración de jaulas (`mychroot.conf`)
- **Validación de nombre** en `removeVM-chroot.sh`: rechaza rutas críticas (`/`, `/etc`, etc.) y path traversal (`..`)
- **Confirmación explícita** escribiendo "ELIMINAR" para borrar una jaula

### Eliminación segura

```
1. Validar nombre de jaula → rechaza rutas del sistema
2. Verificar desmontaje → si hay FS montados, intenta desmontar automáticamente
3. Confirmación → debe escribir "ELIMINAR"
4. Eliminar → rm -rf con verificación post-eliminación
```

---

## Limitaciones de chroot

`chroot` **NO es un contenedor**. Tiene limitaciones de seguridad importantes:

| Limitación | Riesgo |
|---|---|
| **Mismo kernel** | Comportamiento del kernel idéntico al host. No puedes probar módulos de otro kernel |
| **Sin namespaces** | Los procesos dentro ven los PIDs del host. `kill -9` puede matar procesos del host |
| **Sin cgroups** | Un proceso puede consumir toda la RAM/CPU sin límite |
| **Sin seccomp** | No hay filtro de syscalls. Un programa puede llamar a `reboot()` y apagar el host |
| **Sin red aislada** | Un servicio dentro de la jaula escucha en `0.0.0.0` y es accesible desde fuera |
| **Escapabilidad** | Con `root` dentro de la jaula se puede escapar: `mkdir -p /tmp/foo; chroot /tmp/foo` |
| **Dispositivos compartidos** | Si montas `/dev`, la jaula ve los discos del host (`/dev/sda`) |

> [!WARNING]
> `chroot` **no es seguridad**. Fue diseñado para pruebas y aislamiento de dependencias, no como mecanismo de confinamiento. Si necesitas aislamiento real, usa **contenedores** (Docker, LXC, systemd-nspawn).

---

## Qué funciona bien

| Tipo de aplicación | Ejemplos | Recomendación |
|---|---|---|
| Compilación / CI | Compilar paquetes, sbuild, pbuilder | ✅ Excelente — aísla dependencias |
| Base de datos | MySQL, PostgreSQL, MariaDB | ✅ Bueno — ajustar ulimits |
| Servidor web estático | Nginx, Apache (archivos planos) | ✅ Bueno |
| Servicios de red livianos | SSH, rsyslog, cron | ✅ Bueno |
| Entornos de pruebas | Probar configuraciones, scripts | ✅ Excelente — puedes romper sin miedo |
| Servicios legacy | Apache 2.2, PHP 5.x, MySQL 5.6 | ✅ **Caso de uso principal** |
| Entrenamiento Linux | Enseñar administración | ✅ Excelente — sandbox completo |

## Qué no funciona

| Tipo de aplicación | Por qué |
|---|---|
| Docker / contenedores | Necesitan namespaces, cgroups, overlayfs |
| Systemd como init | Espera cgroupfs, dbus, CAP_SYS_ADMIN |
| Aplicaciones GUI | Sin /dev/dri, sin PulseAudio, sin X11 |
| Firewalls (iptables) | Requieren CAP_NET_ADMIN en namespace de red |
| Módulos del kernel | modprobe/insmod — comparten el kernel |
| Monitoreo del sistema | free/top/ps muestran procesos del host |
| Dispositivos físicos | /dev/sda, /dev/ttyUSB0 — ven los del host |
| Alta seguridad | chroot no es seguridad confiable |

---

## Buenas prácticas

### Para producción

1. **No montes `/dev` completo** si no es necesario. Usa solo `/dev/null`, `/dev/random`, etc.
2. **Mantén `/sys` en solo lectura** (ya es el comportamiento por defecto)
3. **Monitorea el consumo de recursos** del host (los procesos del chroot no tienen límite)
4. **Usa `ulimit`** para restringir recursos ([ver configuración de límites](../README.md#límites-del-sistema))
5. **No confíes en chroot como aislamiento de seguridad** — complementa con otras medidas

### Para desarrollo

1. Usa `DRY_RUN=true` para previsualizar montajes
2. Usa `SIN_VERIFICACION_GPG=true` solo en redes locales controladas
3. Prueba primero en jaulas desechables

---

[Volver al inicio](../README.md)
