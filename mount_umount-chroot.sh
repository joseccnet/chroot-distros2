#!/bin/bash
#
# Monta/Desmonta los filesystems de las jaulas chroot.
# Lee la configuración /etc/mychroot.conf en cada jaula.
# Compatible con: Ubuntu, Debian, Kali, Linux Mint, Devuan, CentOS, Fedora, OpenSuse
#
# Author: josecc@gmail.com
#

# ==============================================================================
# Modo estricto: salir en error, variable indefinida, fallo en tubería
# ==============================================================================
set -euo pipefail

source "$(dirname "$0")/chroot.conf"

source "$(dirname "$0")/lib/chroot-lib.sh"

# ==============================================================================
# Pre-flight Checks (Verificaciones Previas)
# ==============================================================================
preflight_checks() {
    local chroot_path="$1"
    local log_prefix="[PREFLIGHT]"

    [ ! -d "$chroot_path" ] && {
        error_msg "El chroot no existe: $chroot_path"
        log_operation "preflight" "$chroot_path" "ERROR:chroot_not_exists"
        return 1
    }

    local orphan_mounts
    orphan_mounts=$(mount | grep "^$chroot_path/" | awk '{print $3}' || true)
    if [ -n "$orphan_mounts" ]; then
        advertencia "${log_prefix} Mounts huérfanos detectados en $chroot_path:"
        echo "$orphan_mounts" | while read -r m; do
            echo "   - $m"
        done
        echo "   Limpie manualmente antes de continuar:"
        echo "   $0 $(basename "$chroot_path") umount"
        log_operation "preflight" "$chroot_path" "ERROR:orphan_mounts"
        return 1
    fi

    [ ! -d /proc ] && {
        error_msg "/proc del host no disponible"
        return 1
    }

    [ ! -d /dev ] && {
        error_msg "/dev del host no disponible"
        return 1
    }

    [ ! -d /sys ] && {
        error_msg "/sys del host no disponible"
        return 1
    }

    return 0
}

# ==============================================================================
# Función de limpieza ante errores
# ==============================================================================
limpieza() {
    local codigo_salida=$?
    if [ $codigo_salida -ne 0 ]; then
        error_msg "Operación falló con código de salida $codigo_salida"
        echo "   Revise los mensajes anteriores para diagnosticar el problema."
        if [ -n "${CHROOT:-}" ] && [ -d "${CHROOT:-}" ]; then
            echo "   Jaula afectada: $CHROOT"
            echo "   Si hay filesystems montados, ejecute:"
            echo "   $0 $(basename "$CHROOT") umount"
        elif [ -n "${NOMBRE_JAULA:-}" ] && [ -d "${ROOTJAIL:-}/${NOMBRE_JAULA:-}" ]; then
            echo "   Jaula afectada: $ROOTJAIL/$NOMBRE_JAULA"
        fi
    fi
    exit $codigo_salida
}
trap limpieza EXIT

# ==============================================================================
# Funciones de resumen
# ==============================================================================
mostrar_resumen_mount() {
    echo ""
    echo " - - - - - - - - - - RESUMEN - - - - - - - - - -"
    echo ""
    exito "Filesystems montados exitosamente"
    echo ""
    echo -e "${CIAN}Puntos de montaje activos:${NC}"
    mount | grep "$CHROOT/" | awk '{print "   " $3}' | sort
    echo ""
    info "Revise $CHROOT/etc/mychroot.conf para ajustar la configuración según sus necesidades."
    echo " - - - - - - - - - - - - - - - - - -"
    echo ""
}

mostrar_resumen_umount() {
    echo ""
    echo " - - - - - - - - - - RESUMEN - - - - - - - - - -"
    echo ""
    exito "Jaula $NOMBRE_JAULA desmontada exitosamente"
    echo ""

    # Verificar si quedó algo montado
    restantes=$(mount | grep "$CHROOT/" | awk '{print $3}' 2>/dev/null || true)
    if [ -n "$restantes" ]; then
        advertencia "Algunos filesystems no se desmontaron:"
        echo "$restantes" | awk '{print "   " $1}'
    fi
    echo " - - - - - - - - - - - - - - - - - -"
    echo ""
}

# Auditoría de dependencias (ejecución inmediata)
declare -A DEPENDENCIAS_MOUNT=(
    ["fuser"]="psmisc"
    ["mountpoint"]="util-linux"
    ["mount"]="util-linux"
    ["umount"]="util-linux"
    ["chroot"]="coreutils"
    ["awk"]="gawk"
    ["sed"]="sed"
    ["grep"]="grep"
    ["cp"]="coreutils"
    ["rm"]="coreutils"
    ["mkdir"]="coreutils"
    ["wget"]="wget"
    ["sleep"]="coreutils"
    ["sort"]="coreutils"
    ["basename"]="coreutils"
    ["dirname"]="coreutils"
    ["find"]="findutils"
    ["date"]="coreutils"
)
auditar_dependencias DEPENDENCIAS_MOUNT

# ==============================================================================
# Funciones de detección de distribución
# ==============================================================================
detectar_distro() {
    local chroot_path="$1"

    if [ -f "$chroot_path/etc/os-release" ]; then
        local id
        id=$(. "$chroot_path/etc/os-release" 2>/dev/null && echo "${ID:-unknown}" || echo "unknown")
        case "$id" in
            ubuntu|debian|kali|linuxmint|devuan)
                echo "debian"
                return
                ;;
            centos|rhel|fedora|rocky|almalinux)
                echo "redhat"
                return
                ;;
            opensuse*|sles|sled)
                echo "suse"
                return
                ;;
        esac
    fi

    # Fallback: detectar por archivos específicos
    if [ -f "$chroot_path/etc/debian_version" ]; then
        echo "debian"
    elif [ -f "$chroot_path/etc/redhat-release" ] || [ -f "$chroot_path/etc/fedora-release" ]; then
        echo "redhat"
    elif [ -f "$chroot_path/etc/SuSE-release" ] || [ -f "$chroot_path/etc/SUSE-brand" ]; then
        echo "suse"
    else
        echo "unknown"
    fi
}

# Obtener UID límite según distribución
obtener_uid_limit() {
    local distro="$1"
    case "$distro" in
        redhat)
            echo 500    # CentOS/RHEL/Fedora usan UID >= 500
            ;;
        debian|suse|unknown)
            echo 1000   # Debian/Ubuntu/Kali/Mint/Devuan/OpenSuse usan UID >= 1000
            ;;
    esac
}

# Normalizar nombre de servicio según distribución
normalizar_servicio() {
    local servicio="$1"
    local distro="$2"

    case "$servicio" in
        */cron|*/cron*|cron)
            if [ "$distro" == "redhat" ]; then
                echo "/etc/init.d/crond"
            else
                echo "/etc/init.d/cron"
            fi
            ;;
        */syslog*|*/rsyslog*|rsyslog)
            echo "/etc/init.d/rsyslog"
            ;;
        *)
            echo "$servicio"
            ;;
    esac
}

# ==============================================================================
# Migración segura de archivos de usuarios
# ==============================================================================
migrar_archivo() {
    local archivo="$1"
    local chroot_path="$2"
    local uid_limit="$3"
    local archivo_temp
    archivo_temp=$(mktemp /tmp/chroot_mig_XXXXXXXXXX)

    # Verificar que el archivo exista en el chroot
    if [ ! -f "$chroot_path$archivo" ]; then
        info "Archivo $archivo no existe en el chroot, omitiendo migración"
        return 0
    fi

    # Verificar que el archivo del host exista
    if [ ! -f "$archivo" ]; then
        info "Archivo $archivo no existe en el host, omitiendo migración"
        return 0
    fi

    case "$archivo" in
        /etc/passwd|/etc/group)
            # Extraer usuarios con UID >= uid_limit y != 65534 (nobody)
            awk -v LIMIT="$uid_limit" -F: '($3>=LIMIT) && ($3!=65534)' "$archivo" > "$archivo_temp"
            ;;
        /etc/shadow|/etc/gshadow)
            # Extraer nombres de usuarios del chroot que cumplan el criterio
            local usuarios
            usuarios=$(awk -v LIMIT="$uid_limit" -F: '($3>=LIMIT) && ($3!=65534) {print $1}' "$chroot_path/etc/passwd" 2>/dev/null || true)
            if [ -z "$usuarios" ]; then
                rm -f "$archivo_temp"
                return 0
            fi
            # Filtrar shadow/gshadow del host por esos nombres
            grep -E "^($(echo "$usuarios" | tr '\n' '|' | sed 's/|$//')):" "$archivo" > "$archivo_temp" 2>/dev/null || true
            ;;
        *)
            error_msg "Tipo de archivo no soportado para migración: $archivo"
            rm -f "$archivo_temp"
            return 1
            ;;
    esac

    # Verificar que se extrajo algo
    if [ ! -s "$archivo_temp" ]; then
        rm -f "$archivo_temp"
        return 0
    fi

    # Migrar entradas que no existan en el chroot
    local migrados=0
    while IFS= read -r linea; do
        local campo1
        campo1=$(echo "$linea" | awk -F: '{print $1}')
        if ! grep -q "^${campo1}:" "$chroot_path$archivo" 2>/dev/null; then
            echo "$linea" >> "$chroot_path$archivo"
            migrados=$((migrados + 1))
        fi
    done < "$archivo_temp"

    rm -f "$archivo_temp"

    if [ $migrados -gt 0 ]; then
        info "Migrados $migrados usuarios/grupos a $archivo"
    fi

    return 0
}

# ==============================================================================
# Configurar archivos de red y sistema
# ==============================================================================
configurar_red() {
    local chroot_path="$1"

    # Copiar archivos de resolución de nombres
    for archivo in /etc/resolv.conf /etc/hosts; do
        if [ -f "$archivo" ]; then
            cp -f "$archivo" "$chroot_path/etc/" 2>/dev/null || \
                advertencia "No se pudo copiar $archivo al chroot"
        fi
    done

    # Copiar fstab si existe
    if [ -f /etc/fstab ]; then
        cp -f /etc/fstab "$chroot_path/etc/" 2>/dev/null || \
            advertencia "No se pudo copiar /etc/fstab al chroot"
    fi

    # Copiar configuración de red para sistemas RedHat
    if [ -d "$chroot_path/etc/sysconfig" ] && [ -f /etc/sysconfig/network ]; then
        cp -f /etc/sysconfig/network "$chroot_path/etc/sysconfig/" 2>/dev/null || \
            advertencia "No se pudo copiar /etc/sysconfig/network al chroot"
    fi
}

configurar_timezone() {
    local chroot_path="$1"
    local timezone="${TZ_CHROOT:-America/Mexico_City}"

    # No sobrescribir si el usuario ya configuró tzdata manualmente dentro de la jaula
    if [ -f "$chroot_path/etc/timezone" ]; then
        local tz_actual
        tz_actual=$(cat "$chroot_path/etc/timezone" 2>/dev/null || echo "")
        if [ -n "$tz_actual" ] && [ "$tz_actual" != "Etc/UTC" ]; then
            info "Timezone ya configurado manualmente: $tz_actual (omitido)"
            return 0
        fi
    fi

    local timezone_file="/usr/share/zoneinfo/$timezone"
    if [ ! -f "$timezone_file" ]; then
        advertencia "Zona horaria no encontrada: $timezone, usando UTC"
        timezone="UTC"
        timezone_file="/usr/share/zoneinfo/UTC"
        if [ ! -f "$timezone_file" ]; then
            error_msg "No se encontró ningún archivo de timezone válido"
            return 1
        fi
    fi

    # Respaldar timezone actual si existe
    if [ -f "$chroot_path/etc/localtime" ] || [ -L "$chroot_path/etc/localtime" ]; then
        chroot "$chroot_path" mv -f /etc/localtime /etc/localtime.ori 2>/dev/null || true
    fi

    # Crear enlace simbólico (corregido: apunta a la zona real, no a sí mismo)
    chroot "$chroot_path" ln -sf "/usr/share/zoneinfo/$timezone" /etc/localtime 2>/dev/null || {
        cp -f "$timezone_file" "$chroot_path/etc/localtime" 2>/dev/null || \
            advertencia "No se pudo configurar el timezone"
    }

    # Escribir /etc/timezone (lo usa dpkg-reconfigure tzdata para mostrar la zona actual)
    echo "$timezone" > "$chroot_path/etc/timezone" 2>/dev/null || true

    exito "Timezone configurado: $timezone"
    return 0
}

configurar_mtab() {
    local chroot_path="$1"

    if ! [ -f "$chroot_path/etc/mtab" ]; then
        chroot "$chroot_path" ln -sf /proc/mounts /etc/mtab 2>/dev/null || \
            advertencia "No se pudo crear enlace simbólico para /etc/mtab"
    fi
}

configurar_perfil_root() {
    local chroot_path="$1"

    # Crear directorio root si no existe
    mkdir -p "$chroot_path/root" 2>/dev/null || true

    # Copiar archivos ocultos de skel si existen
    if ls "$chroot_path/etc/skel/".??* 1> /dev/null 2>&1; then
        cp -a "$chroot_path/etc/skel/".??* "$chroot_path/root/" 2>/dev/null || \
            info "No se pudieron copiar archivos de /etc/skel"
    fi

    # Configurar PS1 en .bashrc si no está configurado
    if [ -f "$chroot_path/root/.bashrc" ]; then
        if ! grep -q "if.*mychroot.conf.*PS1.*chroot" "$chroot_path/root/.bashrc" 2>/dev/null; then
            echo "" >> "$chroot_path/root/.bashrc"
            echo "if [ -f /etc/mychroot.conf ] ; then PS1='\[\e[1;31m\][(chroot)\u@\h \W]#\[\e[0m\] '; fi ; cd" >> "$chroot_path/root/.bashrc"
            info "Prompt PS1 configurado en /root/.bashrc"
        fi
    else
        # Crear .bashrc básico
        cat > "$chroot_path/root/.bashrc" << 'EOF'
# ~/.bashrc: executed by bash(1) for non-login shells.

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# Prompt personalizado para chroot
if [ -f /etc/mychroot.conf ] ; then
    PS1='\[\e[1;31m\][(chroot)\u@\h \W]#\[\e[0m\] '
fi

cd
EOF
        info "Archivo /root/.bashrc creado con configuración básica"
    fi
}

# ==============================================================================
# Montaje de filesystems con Hardening Industrial + Propagation Control
# ==============================================================================
montar_filesystem() {
    local punto_montaje="$1"
    local chroot_path="$2"
    local ruta_completa="$chroot_path$punto_montaje"
    local opciones="nosuid,nodev"

    if [ "${DRY_RUN:-}" == "true" ]; then
        info "[DRY-RUN] Montaría: $punto_montaje → $ruta_completa"
        return 0
    fi

    # Crear punto de montaje si no existe
    mkdir -p "$ruta_completa" 2>/dev/null || {
        error_msg "No se pudo crear directorio: $ruta_completa"
        log_operation "mount" "$chroot_path" "ERROR:cannot_create_dir:$punto_montaje"
        return 1
    }

    # Verificar si ya está montado (Idempotencia robusta)
    # Usa /proc/mounts en vez de mountpoint para detectar montajes anidados/acumulados
    if grep -qF " $ruta_completa " /proc/mounts 2>/dev/null; then
        info "$punto_montaje ya está montado (idempotente)"
        log_operation "mount" "$chroot_path" "SKIP:already_mounted:$punto_montaje"
        return 0
    fi

    # Verificar que el directorio no tenga archivos REGULARES antes del bind
    # Se cuentan solo archivos regulares (-type f). Directorios, dispositivos,
    # symlinks y lost+found son infraestructura del sistema creada por
    # debootstrap/mkfs. Los archivos regulares indican contenido real de usuario
    # que se perdería al hacer el bind mount.
    contenido_real=$(find "$ruta_completa" -xdev -maxdepth 1 -type f 2>/dev/null | wc -l)
    if [ "${contenido_real:-0}" -gt 0 ]; then
        advertencia "$punto_montaje contiene archivos antes del montaje. Serán ocultados por el bind mount."
    fi

    # Montaje especializado por tipo de FS
    case "$punto_montaje" in
        /dev)
            info "Montando /dev con aislamiento..."
            mount --bind /dev "$ruta_completa" 2>/dev/null && {
                mount --make-slave "$ruta_completa" 2>/dev/null || true
                exito "/dev montado con aislamiento"
                log_operation "mount" "$chroot_path" "OK:/dev"
                return 0
            }
            ;;
        /dev/pts)
            # Limpiar montajes previos acumulados (por fallos de idempotencia anteriores)
            while grep -qF " $ruta_completa " /proc/mounts 2>/dev/null; do
                umount "$ruta_completa" 2>/dev/null || break
            done
            info "Montando /dev/pts con aislamiento..."
            mount --bind /dev/pts "$ruta_completa" 2>/dev/null && {
                mount --make-slave "$ruta_completa" 2>/dev/null || true
                exito "/dev/pts montado"
                log_operation "mount" "$chroot_path" "OK:/dev/pts"
                return 0
            }
            # Fallback: newinstance
            mount -t devpts devpts "$ruta_completa" -o "newinstance,ptmxmode=0666,mode=620" 2>/dev/null && {
                mount --make-slave "$ruta_completa" 2>/dev/null || true
                exito "/dev/pts montado (newinstance)"
                log_operation "mount" "$chroot_path" "OK:/dev/pts:newinstance"
                return 0
            }
            ;;
        /dev/shm)
            info "Montando /dev/shm con aislamiento..."
            mount --bind /dev/shm "$ruta_completa" 2>/dev/null && {
                mount --make-slave "$ruta_completa" 2>/dev/null || true
                exito "/dev/shm montado"
                log_operation "mount" "$chroot_path" "OK:/dev/shm"
                return 0
            }
            ;;
        /run)
            info "Montando /run con aislamiento..."
            mount --bind /run "$ruta_completa" 2>/dev/null && {
                mount --make-slave "$ruta_completa" 2>/dev/null || true
                exito "/run montado"
                log_operation "mount" "$chroot_path" "OK:/run"
                return 0
            }
            ;;
        /proc)
            info "Montando /proc (nosuid,noexec,nodev)..."
            mount -t proc proc "$ruta_completa" -o "nosuid,noexec,nodev" 2>/dev/null && {
                mount --make-slave "$ruta_completa" 2>/dev/null || true
                exito "/proc montado"
                log_operation "mount" "$chroot_path" "OK:/proc"
                return 0
            }
            ;;
        /sys)
            info "Montando /sys (ro - solo lectura - producción)..."
            mount -t sysfs sys "$ruta_completa" -o "nosuid,noexec,nodev,ro" 2>/dev/null && {
                mount --make-slave "$ruta_completa" 2>/dev/null || true
                exito "/sys montado (solo lectura)"
                log_operation "mount" "$chroot_path" "OK:/sys:ro"
                return 0
            }
            ;;
    esac

    # Fallback: bind mount con hardening
    info "Aplicando bind mount a $punto_montaje..."
    if mount --bind -o "$opciones" "$punto_montaje" "$ruta_completa" 2>/dev/null; then
        mount --make-slave "$ruta_completa" 2>/dev/null || true
        exito "$punto_montaje montado"
        log_operation "mount" "$chroot_path" "OK:$punto_montaje:bind"
        return 0
    fi

    # Fallback sin opciones
    advertencia "Montaje con flags falló, intentando bind simple..."
    if mount --bind "$punto_montaje" "$ruta_completa" 2>/dev/null; then
        mount --make-slave "$ruta_completa" 2>/dev/null || true
        exito "$punto_montaje montado (bind simple)"
        log_operation "mount" "$chroot_path" "OK:$punto_montaje:simple"
        return 0
    fi

    error_msg "No se pudo montar $punto_montaje en $ruta_completa"
    log_operation "mount" "$chroot_path" "ERROR:$punto_montaje"
    return 1
}

# ==============================================================================
# Inicio de servicios
# ==============================================================================
iniciar_servicio() {
    local servicio="$1"
    local chroot_path="$2"
    local distro="$3"

    # Normalizar nombre de servicio
    local servicio_norm
    servicio_norm=$(normalizar_servicio "$servicio" "$distro")

    # Verificar que el script de servicio exista
    if [ ! -f "$chroot_path$servicio_norm" ]; then
        advertencia "Script de servicio no encontrado: $servicio_norm"
        return 0
    fi

    # Verificar si systemd está disponible
    if [ -d "$chroot_path/etc/systemd" ] && [ -f "$chroot_path/bin/systemctl" ]; then
        # Sistemas con systemd: iniciar manualmente
        local nombre_servicio
        nombre_servicio=$(basename "$servicio_norm")

        case "$nombre_servicio" in
            cron*|crond)
                local cron_bin
                cron_bin=$(chroot "$chroot_path" which crond 2>/dev/null || chroot "$chroot_path" which cron 2>/dev/null || echo "")
                if [ -n "$cron_bin" ]; then
                    if chroot "$chroot_path" "$cron_bin" 2>/dev/null; then
                        exito "Servicio $nombre_servicio iniciado (systemd manual)"
                    else
                        advertencia "Falló el inicio de $nombre_servicio"
                    fi
                else
                    advertencia "Binario de cron no encontrado en el chroot"
                fi
                ;;
            syslog*|rsyslog*)
                local rsyslog_bin
                rsyslog_bin=$(chroot "$chroot_path" which rsyslogd 2>/dev/null || echo "")
                if [ -n "$rsyslog_bin" ]; then
                    if chroot "$chroot_path" "$rsyslog_bin" -f /etc/rsyslog.conf 2>/dev/null; then
                        exito "Servicio $nombre_servicio iniciado (systemd manual)"
                    else
                        advertencia "Falló el inicio de $nombre_servicio"
                    fi
                else
                    advertencia "Binario de rsyslogd no encontrado en el chroot"
                fi
                ;;
            *)
                info "Servicio $nombre_servicio detectado en systemd, pero no hay regla de inicio automático"
                ;;
        esac
    else
        # SysV init: iniciar directamente
        if chroot "$chroot_path" "$servicio_norm" start 2>/dev/null; then
            exito "Servicio $servicio_norm iniciado (SysV init)"
        else
            advertencia "Falló el inicio del servicio $servicio_norm"
        fi
    fi

    return 0
}

# ==============================================================================
# Detener servicios antes de desmontar
# ==============================================================================
detener_servicio() {
    local servicio="$1"
    local chroot_path="$2"
    local distro="$3"

    local servicio_norm
    servicio_norm=$(normalizar_servicio "$servicio" "$distro")

    if [ ! -f "$chroot_path$servicio_norm" ]; then
        return 0
    fi

    # Verificar si systemd está disponible
    if [ -d "$chroot_path/etc/systemd" ] && [ -f "$chroot_path/bin/systemctl" ]; then
        # En systemd, simplemente matar procesos asociados
        fuser -vk "$chroot_path" 2>/dev/null || true
    else
        # SysV init: detener servicio
        chroot "$chroot_path" "$servicio_norm" stop 2>/dev/null || \
            advertencia "Falló la detención de $servicio_norm"
    fi

    return 0
}

# ==============================================================================
# Desmontaje seguro con retry y logging
# ==============================================================================
desmontar_filesystem() {
    local punto_montaje="$1"
    local intentos="${2:-3}"

    if [ "${DRY_RUN:-}" == "true" ]; then
        info "[DRY-RUN] Desmontaría: $punto_montaje"
        return 0
    fi

    # Verificar si está montado (revisa /proc/mounts para detectar capas acumuladas)
    if ! grep -qF " $punto_montaje " /proc/mounts 2>/dev/null; then
        return 0
    fi

    for intento in $(seq 1 $intentos); do
        echo " + Desmontando $punto_montaje (intento $intento/$intentos)..."

        # Desmontar todas las capas acumuladas del mismo punto
        capas=0
        while grep -qF " $punto_montaje " /proc/mounts 2>/dev/null; do
            if umount "$punto_montaje" 2>/dev/null; then
                capas=$((capas + 1))
            else
                break
            fi
        done

        if [ $capas -gt 0 ]; then
            exito "$punto_montaje desmontado ($capas capa(s))"
            log_operation "umount" "$(dirname "$punto_montaje")" "OK:$punto_montaje"
            return 0
        fi

        # Terminar procesos y reintentar
        if [ $intento -lt $intentos ]; then
            advertencia "No se pudo desmontar. Terminando procesos..."
            fuser -TERM -k "$punto_montaje" 2>/dev/null || true
            sleep 1
            fuser -KILL -k "$punto_montaje" 2>/dev/null || true
            sleep 1
        fi
    done

    # Fallback: lazy unmount (último recurso)
    advertencia "Intentando lazy unmount para $punto_montaje..."
    if umount -l "$punto_montaje" 2>/dev/null; then
        exito "$punto_montaje desmontado (lazy)"
        log_operation "umount" "$(dirname "$punto_montaje")" "OK:$punto_montaje:lazy"
        return 0
    fi

    error_msg "No se pudo desmontar $punto_montaje después de $intentos intentos"
    fuser -v "$punto_montaje" 2>/dev/null || true
    log_operation "umount" "$(dirname "$punto_montaje")" "ERROR:$punto_montaje"
    return 1
}

# ==============================================================================
# Clean-up completo del chroot
# ==============================================================================
clean_chroot() {
    local chroot_path="$1"
    local intentos="${2:-3}"

    info "Iniciando clean-up de $chroot_path..."

    # 1. Terminar todos los procesos en el chroot
    info "Terminando procesos en $chroot_path..."
    fuser -TERM -k "$chroot_path" 2>/dev/null || true
    sleep 1
    fuser -KILL -k "$chroot_path" 2>/dev/null || true
    sleep 1

    # 2. Obtener todos los mounts en orden inverso
    local puntos_mount
    puntos_mount=$(mount | grep "^$chroot_path/" | awk '{print $3}' | sort -r || true)

    if [ -z "$puntos_mount" ]; then
        info "No hay mounts que desmontar"
        return 0
    fi

    # 3. Desmontar cada uno
    local errores=0
    while IFS= read -r mp; do
        [ -z "$mp" ] && continue
        if ! desmontar_filesystem "$mp" "$intentos"; then
            errores=$((errores + 1))
        fi
    done <<< "$puntos_mount"

    # 4. Verificar limpieza completa
    if mount | grep -q "^$chroot_path/"; then
        error_msg "Limpieza incompleta para $chroot_path"
        log_operation "clean" "$chroot_path" "ERROR:incomplete"
        return 1
    fi

    if [ $errores -gt 0 ]; then
        advertencia "$errores mounts no se pudieron desmontar"
        log_operation "clean" "$chroot_path" "WARN:${errores}"
        return 1
    fi

    exito "Clean-up completado para $chroot_path"
    log_operation "clean" "$chroot_path" "OK"
    return 0
}

# ==============================================================================
# Mostrar mensaje de ayuda
# ==============================================================================
mostrar_ayuda() {
    echo " - - - - - - - - - - - - - - - - - -"
    echo -e "Monta/Desmonta filesystems del chroot"
    echo " - - - - - - - - - - - - - - - - - -"
    echo ""
    echo "Uso:"
    echo "  $0 NombreJaula [mount|umount]"
    echo "  $0 mountall          # Monta todas las jaulas"
    echo "  $0 umountall         # Desmonta todas las jaulas"
    echo "  $0 status [-v|--verbose]"
    echo "  $0 status            # Muestra estado de todas las jaulas"
    echo "  $0 status -v         # Muestra todos los procesos (sin límite)"
    echo "  $0 status --verbose  # Muestra todos los procesos (sin límite)"
    echo ""
    echo "Lee la configuración de /etc/mychroot.conf en cada jaula."
    echo ""
    echo "Formato de /etc/mychroot.conf:"
    echo "  FS:/proc            # Filesystem a montar"
    echo "  FS:/dev"
    echo "  FS:/dev/pts"
    echo "  FS:/sys"
    echo "  FS:/home"
    echo "  Service:/etc/init.d/cron   # Servicio a iniciar"
    exit 0
}

# ==============================================================================
# INICIO DEL SCRIPT PRINCIPAL
# ==============================================================================

# Verificar si no hay argumentos (ayuda no requiere root)
if [ $# -eq 0 ] || [ "${1:-}" == "--help" ] || [ "${1:-}" == "-h" ]; then
    mostrar_ayuda
fi

# Verificar privilegios de root
if [ "$(id -u)" -ne 0 ]; then
    error_msg "Este script debe ejecutarse como root"
    echo "   Ejecute: sudo $0 $*"
    exit 1
fi

# ==============================================================================
# Comando: status
# ==============================================================================
if [ "${1:-}" == "status" ]; then
    echo ""
    echo -e "${CIAN}Reporte de jaulas en $ROOTJAIL${NC}"
    echo -e "${AZUL}────────────────────────────────────────────────────────────────────────────────${NC}"

    # Modo verbose: muestra todos los procesos sin límite
    #   ./mount_umount-chroot.sh status           → max 12 procesos
    #   ./mount_umount-chroot.sh status -v        → todos
    #   ./mount_umount-chroot.sh status --verbose  → todos
    #   STATUS_MAX_PROC=999 ./mount_umount-chroot.sh status → límite personalizado
    max_procesos="${STATUS_MAX_PROC:-12}"
    if [ "${2:-}" == "--verbose" ] || [ "${2:-}" == "-v" ]; then
        max_procesos=0
    fi

    # Pre-obtener montajes para evitar múltiples llamadas pesadas en el bucle
    # Guardamos en una variable local por rendimiento
    all_mounts=$(cat /proc/mounts 2>/dev/null || true)
    
    if [ -d "$ROOTJAIL" ]; then
        for jaula_path in "$ROOTJAIL"/*; do
            [ -d "$jaula_path" ] || continue
            # Inicialización de variables para seguridad 'nounset'
            esta_montada=false
            estado_str=""
            icono=""
            procesos_str=""
            fs_list_output=""
            pids=""

            # 1. Obtener filesystems montados (Detección robusta de grado industrial)
            fs_data=$(echo "$all_mounts" | awk -v jp="$jaula_path" '($2 == jp || index($2, jp"/") == 1) {print $2, $3, $4}' | sort)
            
            if [ -n "$fs_data" ]; then
                esta_montada=true
                estado_str="[${VERDE}MONTADA${NC}]"
                icono="${VERDE}●${NC}"
            else
                esta_montada=false
                estado_str="[${AMARILLO}DESMONTADA${NC}]"
                icono="${AMARILLO}○${NC}"
            fi

            # 2. Obtener procesos específicos para esta jaula
            pids=$(find /proc/[0-9]*/root -lname "$jaula_path" 2>/dev/null | awk -F'/' '{print $3}' | sort -u || true)
            
            procesos_str=""
            count=0
            if [ -n "$pids" ]; then
                # Si hay procesos pero no detectamos montajes, es un estado anómalo o jaula huérfana
                if [ "$esta_montada" = false ]; then
                    estado_str="[${CIAN}ACTIVA (SIN FS)${NC}]"
                    icono="${CIAN}●${NC}"
                else
                    # Si está montada y tiene procesos, usamos CIAN para resaltar actividad
                    icono="${CIAN}●${NC}"
                fi

                for p in $pids; do
                    if [ $max_procesos -gt 0 ] && [ $count -ge $max_procesos ]; then
                        procesos_str+="${AZUL}... (+)${NC}"
                        break
                    fi
                    pname=$(cat "/proc/$p/comm" 2>/dev/null || echo "unknown")
                    procesos_str+="${pname}(${p}), "
                    count=$((count + 1))
                done
                procesos_str=${procesos_str%, }
            else
                procesos_str="${AZUL}ninguno${NC}"
            fi

            # 3. Formatear lista de filesystems (si existen)
            fs_list_output=""
            if [ -n "$fs_data" ]; then
                while read -r mp type opts; do
                    # Normalizar ruta (relativa a la jaula)
                    rel_mp=${mp#$jaula_path}
                    [ -z "$rel_mp" ] && rel_mp="/"
                    
                    # Resaltar rw/ro
                    if [[ "$opts" == *"ro"* ]] && [[ "$opts" != *"rw"* ]]; then
                        opts_str="${AMARILLO}$opts${NC}"
                    else
                        opts_str="$opts"
                    fi
                    
                    fs_list_output+="      ├─ ${AZUL}$rel_mp${NC} ($type, $opts_str)\n"
                done <<< "$fs_data"
                # Cambiar el último carácter de árbol
                fs_list_output=$(echo -e "$fs_list_output" | sed '$s/├─/└─/')
            fi

            # 4. Imprimir reporte por jaula
            echo -e "  $icono ${CIAN}${jaula_path}${NC} $estado_str"
            echo -e "    ├─ ${AZUL}Procesos:${NC} $procesos_str"
            if [ -n "$fs_list_output" ]; then
                echo -e "    └─ ${AZUL}Filesystems:${NC}"
                echo -e "$fs_list_output"
            else
                echo -e "    └─ ${AZUL}Filesystems:${NC} ninguno"
            fi
            echo ""
        done
    else
        error_msg "El directorio base $ROOTJAIL no existe."
    fi

    echo -e "${AZUL}────────────────────────────────────────────────────────────────────────────────${NC}"
    echo ""
    exit 0
fi

# ==============================================================================
# Comando: mountall
# ==============================================================================
if [ "${1:-}" == "mountall" ]; then
    echo ""
    info "Montando todas las jaulas..."
    echo ""

    if [ ! -d "$ROOTJAIL" ]; then
        error_msg "Directorio $ROOTJAIL no existe"
        exit 1
    fi

    errores=0
    for jaula in $(ls "$ROOTJAIL" 2>/dev/null | grep -v '^X'); do
        # Verificar que sea un directorio válido
        [ -d "$ROOTJAIL/$jaula" ] || continue

        echo -e "${AZUL}─────────────────────────────────────${NC}"
        echo "Montando jaula: $jaula ..."
        if "$0" "$jaula" mount; then
            exito "Jaula $jaula montada exitosamente"
        else
            errores=$((errores + 1))
            error_msg "Falló el montaje de la jaula $jaula"
        fi
        echo ""
        sleep 0.2
    done

    echo -e "${AZUL}─────────────────────────────────────${NC}"
    if [ $errores -eq 0 ]; then
        exito "Todas las jaulas montadas exitosamente"
    else
        advertencia "$errores jaula(s) fallaron al montar. Revise los mensajes anteriores."
        exit 1
    fi
    exit 0
fi

# ==============================================================================
# Comando: umountall
# ==============================================================================
if [ "${1:-}" == "umountall" ]; then
    echo ""
    info "Desmontando todas las jaulas..."
    echo ""

    if [ ! -d "$ROOTJAIL" ]; then
        error_msg "Directorio $ROOTJAIL no existe"
        exit 1
    fi

    errores=0
    for jaula in $(ls "$ROOTJAIL" 2>/dev/null | grep -v '^X'); do
        # Verificar que sea un directorio válido
        [ -d "$ROOTJAIL/$jaula" ] || continue

        echo -e "${AZUL}─────────────────────────────────────${NC}"
        echo "Desmontando jaula: $jaula ..."
        if "$0" "$jaula" umount; then
            exito "Jaula $jaula desmontada exitosamente"
        else
            errores=$((errores + 1))
            error_msg "Falló el desmontaje de la jaula $jaula"
        fi
        echo ""
    done

    echo -e "${AZUL}─────────────────────────────────────${NC}"
    if [ $errores -eq 0 ]; then
        exito "Todas las jaulas desmontadas exitosamente"
    else
        advertencia "$errores jaula(s) fallaron al desmontar. Revise los mensajes anteriores."
        exit 1
    fi
    exit 0
fi

# ==============================================================================
# Comando: mount / umount
# ==============================================================================
if [ "${1:-}" == "" ] || [ "${2:-}" == "" ]; then
    error_msg "Atención!!! Nombre de Jaula y acción requeridos"
    echo ""
    echo "Ejecute:"
    echo "  $0 NombreJaula [mount|umount]"
    echo "  $0 mountall"
    echo "  $0 umountall"
    echo "  $0 status"
    exit 1
fi

NOMBRE_JAULA="${1:-}"
ACCION="${2:-}"
CHROOT="$ROOTJAIL/$NOMBRE_JAULA"

# Verificar que la jaula exista
if [ ! -d "$CHROOT" ]; then
    error_msg "La jaula no existe: $CHROOT"
    echo "   Verifique el nombre de la jaula o créela primero con el script correspondiente."
    echo "   Jaulas disponibles:"
    if [ -d "$ROOTJAIL" ]; then
        for j in "$ROOTJAIL"/*/; do
            [ -d "$j" ] && echo "   - $(basename "$j")"
        done
    fi
    exit 1
fi

# Verificar que mychroot.conf exista para mount
if [ "$ACCION" == "mount" ] && [ ! -f "$CHROOT/etc/mychroot.conf" ]; then
    error_msg "No existe archivo de configuración: $CHROOT/etc/mychroot.conf"
    echo "   Este archivo es necesario para montar la jaula."
    echo "   Revise la documentación del script build-chroot correspondiente."
    exit 1
fi

# ==============================================================================
# Acción: umount
# ==============================================================================
if [ "$ACCION" == "umount" ]; then
    echo ""
    echo " - - - - - - - - - - - - - - - - - -"
    info "Desmontando jaula: $NOMBRE_JAULA"
    echo " - - - - - - - - - - - - - - - - - -"
    echo ""

    # Detectar distribución
    distro=$(detectar_distro "$CHROOT")
    info "Distribución detectada: $distro"

    # Detener servicios
    echo ""
    info "Deteniendo servicios ..."
    if [ -f "$CHROOT/etc/mychroot.conf" ]; then
        while IFS= read -r servicio; do
            [ -z "$servicio" ] && continue
            echo " + $CHROOT$servicio ..."
            detener_servicio "$servicio" "$CHROOT" "$distro"
        done < <(grep "^Service:" "$CHROOT/etc/mychroot.conf" 2>/dev/null | awk -F: '{print $2}')
    else
        info "No se encontró mychroot.conf, omitiendo detención de servicios"
    fi

    # Desmontar filesystems en orden inverso
    echo ""
    info "Desmontando filesystems ..."

    # Obtener puntos de montaje montados, ordenados inversamente
    puntos_montados=$(mount | grep "$CHROOT/" | awk '{print $3}' | sort -r)

    if [ -z "$puntos_montados" ]; then
        info "No hay filesystems montados para esta jaula"
    else
        errores_umount=0
        for punto in $puntos_montados; do
            if ! desmontar_filesystem "$punto" 2; then
                errores_umount=$((errores_umount + 1))
            fi
        done

        if [ $errores_umount -gt 0 ]; then
            echo ""
            advertencia "$errores_umount filesystem(s) no se pudieron desmontar"
            echo "   Ejecute nuevamente el comando para reintentar"
            exit 1
        fi
    fi

    # Forzar terminación de procesos residuales
    info "Terminando procesos residuales en $CHROOT..."
    fuser -TERM -k "$CHROOT" 2>/dev/null || true
    sleep 1
    fuser -KILL -k "$CHROOT" 2>/dev/null || true

    echo ""
    mostrar_resumen_umount
    log_operation "umount" "$CHROOT" "OK:complete"
    exit 0

# ==============================================================================
# Acción: mount
# ==============================================================================
elif [ "$ACCION" == "mount" ]; then
    echo ""
    echo " - - - - - - - - - - - - - - - - - -"
    info "Montando jaula: $NOMBRE_JAULA"
    echo " - - - - - - - - - - - - - - - - - -"
    echo ""

    # Detectar distribución
    distro=$(detectar_distro "$CHROOT")
    uid_limit=$(obtener_uid_limit "$distro")
    info "Distribución detectada: $distro (UID límite: $uid_limit)"

    echo "Montando [$(date)] ..."
    echo ""

    # Pre-flight checks
    info "Ejecutando verificaciones previas..."
    if ! preflight_checks "$CHROOT"; then
        error_msg "Pre-flight checks fallaron"
        exit 1
    fi

    # Montar filesystems desde mychroot.conf
    info "Montando filesystems ..."
    errores_mount=0
    while IFS= read -r punto_montaje; do
        [ -z "$punto_montaje" ] && continue
        echo " + $CHROOT$punto_montaje"
        if ! montar_filesystem "$punto_montaje" "$CHROOT"; then
            errores_mount=$((errores_mount + 1))
        fi
    done < <(grep "^FS:" "$CHROOT/etc/mychroot.conf" 2>/dev/null | awk -F: '{print $2}')

    if [ $errores_mount -gt 0 ]; then
        echo ""
        error_msg "$errores_mount filesystem(s) fallaron al montar"
        exit 1
    fi

    echo ""

    # Migrar usuarios y grupos
    info "Migrando usuarios y grupos del host..."
    migrar_archivo /etc/passwd "$CHROOT" "$uid_limit"
    migrar_archivo /etc/group "$CHROOT" "$uid_limit"
    migrar_archivo /etc/shadow "$CHROOT" "$uid_limit"
    migrar_archivo /etc/gshadow "$CHROOT" "$uid_limit"

    # Configurar archivos de red
    info "Configurando archivos de red..."
    configurar_red "$CHROOT"

    # Configurar timezone
    info "Configurando timezone..."
    configurar_timezone "$CHROOT"

    # Configurar mtab
    configurar_mtab "$CHROOT"

    # Configurar perfil de root
    info "Configurando perfil de root..."
    configurar_perfil_root "$CHROOT"

    # Iniciar servicios
    echo ""
    info "Iniciando servicios ..."
    if [ -f "$CHROOT/etc/mychroot.conf" ]; then
        while IFS= read -r servicio; do
            [ -z "$servicio" ] && continue
            echo " + $CHROOT$servicio"
            iniciar_servicio "$servicio" "$CHROOT" "$distro"
        done < <(grep "^Service:" "$CHROOT/etc/mychroot.conf" 2>/dev/null | awk -F: '{print $2}')
    fi

    # Ejecutar script personalizado myinit.d si existe
    if [ -f "$CHROOT/etc/init.d/myinit.d" ]; then
        echo ""
        info "Script $CHROOT/etc/init.d/myinit.d encontrado, ejecutando ..."
        chmod 750 "$CHROOT/etc/init.d/myinit.d"
        if chroot "$CHROOT" /etc/init.d/myinit.d 2>/dev/null; then
            exito "myinit.d ejecutado exitosamente"
        else
            advertencia "Falló la ejecución de myinit.d"
        fi
    fi

    echo ""
    mostrar_resumen_mount
    log_operation "mount" "$CHROOT" "OK:complete"
    exit 0
else
    error_msg "Opción no válida: $ACCION"
    echo "   Opciones válidas: mount, umount"
    exit 1
fi
