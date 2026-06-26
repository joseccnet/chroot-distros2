#!/bin/bash
#
# Build a chroot with a Ubuntu base install.
# Author: josecc@gmail.com
#
# http://archive.ubuntu.com/ubuntu/dists/ && https://old-releases.ubuntu.com/ubuntu/dists/
# --arch amd64, i386, arm64, armhf, ppc64el, s390x
#
# Variables de entorno opcionales:
#   SIN_VERIFICACION_GPG=true    : Desactiva verificación GPG (solo pruebas/desarrollo)
#   MIRROR_UBUNTU=<url>          : Usa un mirror personalizado
#   INTERACTIVO=true             : Modo interactivo para seleccionar versión
#   ESPACIO_MINIMO_GB=<n>        : Espacio mínimo requerido en GB (default: 2)
#

set -euo pipefail

source "$(dirname "$0")/chroot.conf"
source "$(dirname "$0")/lib/chroot-lib.sh"

# ==============================================================================
# Función de limpieza ante errores
# ==============================================================================
limpieza() {
    local codigo_salida=$?
    if [ $codigo_salida -ne 0 ] && [ -n "${CHROOT:-}" ] && [ -d "${CHROOT:-}" ]; then
        error_msg "La construcción falló con código de salida $codigo_salida"
        echo "   Puede existir un chroot parcial en: $CHROOT"
        echo "   Limpiar con: rm -rf $CHROOT"
        echo ""
        echo "   Si hay filesystems montados, desmontar primero:"
        echo "   $(dirname "$0")/mount_umount-chroot.sh $(basename "$CHROOT") umount"
    fi
    exit $codigo_salida
}
trap limpieza EXIT

# ==============================================================================
# Versiones soportadas de Ubuntu
# ==============================================================================
VERSIONES_SOPORTADAS=(
    # LTS con soporte activo
    "resolute" "noble" "jammy"
    # Versiones estándar recientes
    "questing" "plucky" "oracular" "mantic" "lunar" "kinetic"
    # Versiones EOL (legado, con advertencia)
    "impish" "hirsute" "groovy" "focal" "eoan" "disco" "cosmic"
    "artful" "zesty" "yakkety" "xenial" "wily" "vivid" "utopic"
    "trusty" "precise" "lucid"
)

# Mapa de versiones EOL y sus fechas de fin de soporte
declare -A VERSIONES_EOL=(
    ["lucid"]="Mayo 2015"
    ["precise"]="Abril 2017"
    ["trusty"]="Abril 2019"
    ["utopic"]="Julio 2015"
    ["vivid"]="Febrero 2016"
    ["wily"]="Julio 2016"
    ["xenial"]="Abril 2021"
    ["yakkety"]="Julio 2017"
    ["zesty"]="Enero 2018"
    ["artful"]="Julio 2018"
    ["cosmic"]="Julio 2019"
    ["disco"]="Enero 2020"
    ["eoan"]="Julio 2020"
    ["focal"]="Mayo 2025"
    ["groovy"]="Julio 2021"
    ["hirsute"]="Enero 2022"
    ["impish"]="Julio 2022"
    ["kinetic"]="Julio 2023"
    ["lunar"]="Enero 2024"
    ["mantic"]="Julio 2024"
    ["oracular"]="Julio 2025"
)

# Información de versiones LTS activas
declare -A VERSIONES_LTS_ACTIVAS=(
    ["jammy"]="Junio 2027 (LTS)"
    ["noble"]="Junio 2029 (LTS)"
    ["resolute"]="Mayo 2031 (LTS)"
)

# ==============================================================================
# Funciones de validación
# ==============================================================================
validar_version() {
    local version="${1:-}"
    for soportada in "${VERSIONES_SOPORTADAS[@]}"; do
        if [ "$version" == "$soportada" ]; then
            return 0
        fi
    done
    return 1
}

advertir_eol() {
    local version="${1:-}"
    if [[ -n "${VERSIONES_EOL[$version]+x}" ]]; then
        echo ""
        advertencia "Ubuntu $version llegó al fin de vida (EOL) en ${VERSIONES_EOL[$version]}"
        echo "   - Las actualizaciones de seguridad ya NO están disponibles"
        echo "   - Pueden existir vulnerabilidades sin parchar"
        echo ""
        echo "   Versiones LTS con soporte activo recomendadas:"
        for lts in "${!VERSIONES_LTS_ACTIVAS[@]}"; do
            echo "   - $lts (soporte hasta ${VERSIONES_LTS_ACTIVAS[$lts]})"
        done
        echo ""

        # Solo pedir confirmación si no es modo no interactivo forzado
        if [ "${FORZAR_EOL:-}" != "true" ]; then
            read -p "¿Desea continuar de todos modos? (s/N): " respuesta
            if [[ ! "$respuesta" =~ ^[sSyY]$ ]]; then
                info "Operación cancelada por el usuario."
                exit 0
            fi
        fi
    fi
}

es_version_lts() {
    local version="${1:-}"
    [[ -n "${VERSIONES_LTS_ACTIVAS[$version]+x}" ]]
}

# Verificación adicional de scripts de debootstrap
verificar_debootstrap() {
    if [ ! -d /usr/share/debootstrap/scripts ]; then
        error_msg "Directorio /usr/share/debootstrap/scripts no encontrado"
        echo "   La versión de debootstrap no soporta instalar Ubuntu Linux."
        exit 1
    fi
}

# ==============================================================================
# Verificaciones previas (pre-flight checks)
# ==============================================================================
verificaciones_previas() {
    info "Iniciando verificaciones de sistema..."

    declare -A DEPENDENCIAS_BUILD=(
        ["debootstrap"]="debootstrap"
        ["wget"]="wget"
        ["chroot"]="coreutils"
        ["awk"]="gawk"
        ["sed"]="sed"
        ["grep"]="grep"
        ["id"]="coreutils"
        ["df"]="coreutils"
        ["cp"]="coreutils"
        ["rm"]="coreutils"
        ["mkdir"]="coreutils"
    )
    auditar_dependencias DEPENDENCIAS_BUILD
    verificar_debootstrap

    verificar_root

    verificar_espacio_disco "$ROOTJAIL" "${ESPACIO_MINIMO_GB:-2}"

    # Validar arquitectura
    case "$arch" in
        amd64|i386|arm64|armhf|ppc64el|s390x)
            ;;
        x86_64)
            arch="amd64"
            ;;
        aarch64)
            arch="arm64"
            ;;
        *)
            error_msg "Arquitectura no soportada: $arch"
            echo "   Arquitecturas soportadas: amd64, i386, arm64, armhf, ppc64el, s390x"
            exit 1
            ;;
    esac

    # Verificar que fuser esté disponible (necesario para mount_umount-chroot.sh)
    if ! command -v fuser &> /dev/null; then
        error_msg "fuser no encontrado. Instale el paquete psmisc:"
        echo "   - yum install psmisc    # RHEL/CentOS"
        echo "   - apt-get install psmisc # Debian/Ubuntu"
        exit 1
    fi

    exito "Verificaciones previas completadas"
    echo ""
}

# ==============================================================================
# Descargar y configurar keyring de Ubuntu (necesario cuando el host es Debian)
# ==============================================================================
KEYRING_FLAG=""
verificar_keyring_ubuntu() {
    local version="$1"
    local keyring="/usr/share/keyrings/ubuntu-archive-keyring.gpg"

    # Descargar keyring de Ubuntu (siempre el más reciente)
    # En hosts Debian, debootstrap usa el keyring de Debian por defecto,
    # que no reconoce las claves de Ubuntu. Descargamos el keyring de Ubuntu
    # y lo pasamos explícitamente a debootstrap con --keyring.
    local temp_keyring
    temp_keyring=$(mktemp)

    info "Descargando keyring de Ubuntu..."
    if wget -qO "$temp_keyring" "http://archive.ubuntu.com/ubuntu/project/ubuntu-archive-keyring.gpg" 2>/dev/null; then
        cp "$temp_keyring" "$keyring"
        KEYRING_FLAG="--keyring=$keyring"
        exito "Keyring de Ubuntu descargado"
    else
        advertencia "No se pudo descargar el keyring de Ubuntu"
        echo "   Si el host es Debian, la verificación GPG puede fallar."
        echo "   Use SIN_VERIFICACION_GPG=true como alternativa."
    fi
    rm -f "$temp_keyring"
}

# ==============================================================================
# Verificar si es construcción cruzada
# ==============================================================================
verificar_construccion_cruzada() {
    local arch_host
    arch_host=$(uname -m)
    case "$arch_host" in
        x86_64) arch_host="amd64" ;;
        aarch64) arch_host="arm64" ;;
        i686|i386) arch_host="i386" ;;
    esac

    if [ "$arch_host" != "$arch" ]; then
        CONSTRUCCION_CRUZADA="Sí ($arch_host -> $arch)"
        return 0  # Es construcción cruzada
    fi
    return 1  # No es construcción cruzada
}

# ==============================================================================
# Generar resumen de construcción
# ==============================================================================
generar_resumen() {
    local archivo_resumen="$CHROOT/etc/resumen-construccion.txt"
    local tipo_version="Estándar"
    if es_version_lts "$version"; then
        tipo_version="LTS (Soporte hasta ${VERSIONES_LTS_ACTIVAS[$version]})"
    fi

    cat > "$archivo_resumen" << EOF
================================================================================
Resumen de Construcción del Chroot Ubuntu
================================================================================
Fecha:              $(date)
Versión:            $version
Tipo:               $tipo_version
Arquitectura:       $arch
Ruta del Chroot:    $CHROOT
Mirror utilizado:   http://${archiveSite}.ubuntu.com/ubuntu
Paquetes instalados: $paquetes_ubuntu
Verificación GPG:   $VERIFICACION_GPG
Construcción cruzada: $CONSTRUCCION_CRUZADA

Estado: EXITOSO
================================================================================

NOTAS IMPORTANTES:
- Revise /etc/mychroot.conf para configurar filesystems y servicios
- Actualice repositorios en /etc/apt/sources.list según sus necesidades
- Para acceso SSH con ChrootDirectory, consulte las instrucciones al final
  de la salida de este script

FIN DEL RESUMEN
================================================================================
EOF
    chmod 644 "$archivo_resumen"
    echo ""
    info "Resumen de construcción guardado en: $archivo_resumen"
}

# ==============================================================================
# Mostrar mensaje de ayuda
# ==============================================================================
mostrar_ayuda() {
    echo " - - - - - - - - - - - - - - - - - -"
    echo -e "$0 creará una jaula dentro del directorio $ROOTJAIL/\$NOMBRE\n"
    echo " - - - - - - - - - - - - - - - - - -"
    echo ""
    echo "Versiones de Ubuntu soportadas:"
    echo ""
    echo "  LTS (Soporte Largo):"
    echo "   resolute  - 26.04 LTS  (Resolute Raccoon)   - Soporte hasta Abril 2031"
    echo "   noble     - 24.04 LTS  (Noble Numbat)       - Soporte hasta Abril 2029"
    echo "   jammy     - 22.04 LTS  (Jammy Jellyfish)    - Soporte hasta Abril 2027"
    echo ""
    echo "  Estándar (9 meses de soporte):"
    echo "   questing  - 25.10      (Questing Quokka)"
    echo "   plucky    - 25.04      (Plucky Puffin)"
    echo "   oracular  - 24.10      (Oracular Oriole)    [EOL]"
    echo "   mantic    - 23.10      (Mantic Minotaur)    [EOL]"
    echo "   lunar     - 23.04      (Lunar Lobster)      [EOL]"
    echo "   kinetic   - 22.10      (Kinetic Kudu)       [EOL]"
    echo ""
    echo "  Legacy (EOL - Solo para compatibilidad):"
    echo "   focal     - 20.04 LTS  (Focal Fossa)        [EOL Mayo 2025]"
    echo "   bionic    - 18.04 LTS  (Bionic Beaver)      [EOL]"
    echo "   xenial    - 16.04 LTS  (Xenial Xerus)       [EOL]"
    echo "   trusty    - 14.04 LTS  (Trusty Tahr)        [EOL]"
    echo "   precise   - 12.04 LTS  (Precise Pangolin)   [EOL]"
    echo "   lucid     - 10.04 LTS  (Lucid Lynx)         [EOL]"
    echo "   ... y más versiones legacy (ver código fuente)"
    echo ""
    echo "Uso:"
    echo "  $0 NombreJaula [versión [arquitectura]]"
    echo ""
    echo "  NombreJaula  : Nombre del directorio de la jaula"
    echo "  versión      : Codename de Ubuntu (ej: noble, jammy, resolute)"
    echo "  arquitectura : amd64, i386, arm64, armhf, ppc64el, s390x (default: host)"
    echo ""
    echo "Ejemplos:"
    echo "  $0 mi-ubuntu noble"
    echo "  $0 mi-ubuntu jammy amd64"
    echo "  $0 mi-ubuntu resolute arm64"
    echo "  $0 mi-ubuntu focal i386"
    echo ""
    echo "Variables de entorno opcionales:"
    echo "  SIN_VERIFICACION_GPG=true   : Desactiva verificación GPG (solo pruebas)"
    echo "  MIRROR_UBUNTU=<url>         : Usa un mirror personalizado"
    echo "  INTERACTIVO=true            : Modo interactivo para seleccionar versión"
    echo "  FORZAR_EOL=true             : Omite confirmación para versiones EOL"
    echo "  ESPACIO_MINIMO_GB=<n>       : Espacio mínimo requerido en GB (default: 2)"
    echo ""
    exit 1
}

# ==============================================================================
# INICIO DEL SCRIPT PRINCIPAL
# ==============================================================================

# Verificar si se necesita mostrar ayuda
if [ "${1:-}" == "" ] || [ "${1:-}" == "--help" ] || [ "${1:-}" == "-h" ]; then
    mostrar_ayuda
fi

# Configuración de GPG
VERIFICACION_GPG="activada"
if [ "${SIN_VERIFICACION_GPG:-}" == "true" ]; then
    FLAG_GPG="--no-check-gpg"
    VERIFICACION_GPG="desactivada (modo pruebas)"
    advertencia "Verificación GPG desactivada - NO usar en producción"
else
    FLAG_GPG="--force-check-gpg"
fi

# Configuración de mirror personalizado
MIRROR_PRINCIPAL="http://archive.ubuntu.com/ubuntu"
if [ -n "${MIRROR_UBUNTU:-}" ]; then
    MIRROR_PRINCIPAL="$MIRROR_UBUNTU"
    info "Usando mirror personalizado: $MIRROR_PRINCIPAL"
fi

# Crear directorio ROOTJAIL si no existe
if [ ! -d "$ROOTJAIL" ]; then
    mkdir -vp "$ROOTJAIL"
    chmod 755 "$ROOTJAIL"
fi

# Parsear argumentos
NOMBRE_JAULA="${1:-}"
CHROOT="$ROOTJAIL/$NOMBRE_JAULA"
version="${2:-}"
arch="${3:-$(uname -m)}"

# Modo interactivo
if [ "$version" == "interactive" ] || [ "${INTERACTIVO:-}" == "true" ]; then
    echo ""
    echo "Seleccione versión de Ubuntu:"
    echo ""
    PS3="Seleccione una opción: "
    select version in "${VERSIONES_SOPORTADAS[@]}"; do
        if [ -n "$version" ]; then
            exito "Versión seleccionada: $version"
            break
        fi
        error_msg "Selección inválida. Intente nuevamente."
    done
    echo ""
fi

# Si aún no hay versión, usar noble como default
if [ -z "$version" ]; then
    version="noble"
    info "Usando versión por defecto: $version (Noble Numbat - 24.04 LTS)"
fi

# Validar versión
if ! validar_version "$version"; then
    error_msg "Versión de Ubuntu no soportada: $version"
    echo "   Versiones soportadas: ${VERSIONES_SOPORTADAS[*]}"
    exit 1
fi

# Verificar espacio en disco antes de continuar
verificaciones_previas

# Advertencia EOL
advertir_eol "$version"

# Obtener paquetes específicos para esta versión
paquetes_ubuntu=$(obtener_paquetes_ubuntu "$version")

# Agregar libc6-i386 para arquitectura amd64
if [ "$arch" == "amd64" ]; then
    paquetes_ubuntu="$paquetes_ubuntu,libc6-i386"
fi

# Verificar construcción cruzada
CONSTRUCCION_CRUZADA="No"
if verificar_construccion_cruzada; then
    info "Construcción cruzada detectada"
fi

# Resumen de la operación
echo ""
echo " - - - - - - - - - - - - - - - - - -"
echo -e "Instalando Ubuntu Chroot"
echo -e " - - - - - - - - - - - - - - - - - -"
echo -e "Jaula:       $CHROOT"
echo -e "Versión:     $version"
echo -e "Arquitectura: $arch"
echo -e "Mirror:      $MIRROR_PRINCIPAL"
echo -e "GPG:         $VERIFICACION_GPG"
echo -e "Paquetes:    $paquetes_ubuntu"
echo " - - - - - - - - - - - - - - - - - -"
echo ""

# Crear symlink para debootstrap si no existe
if [ ! -f "/usr/share/debootstrap/scripts/$version" ]; then
    info "Creando symlink de debootstrap para $version"
    ln -sf /usr/share/debootstrap/scripts/sid "/usr/share/debootstrap/scripts/$version"
fi

# Verificar o actualizar keyring de Ubuntu
verificar_keyring_ubuntu "$version"

# Construcción cruzada: modo --foreign
if verificar_construccion_cruzada; then
    info "Modo construcción cruzada (--foreign)"
    echo "   Primera etapa: extrayendo archivos base..."
    debootstrap --merged-usr --arch "$arch" --verbose $FLAG_GPG $KEYRING_FLAG \
        --include="$paquetes_ubuntu" "$version" "$CHROOT" "$MIRROR_PRINCIPAL" || {
        echo ""
        echo "   Intentando con mirror alternativo..."
        local_mirror_alt="http://old-releases.ubuntu.com/ubuntu"
        if [[ -n "${VERSIONES_EOL[$version]+x}" ]]; then
            local_mirror_alt="http://old-releases.ubuntu.com/ubuntu"
        else
            local_mirror_alt="http://archive.ubuntu.com/ubuntu"
        fi
        debootstrap --merged-usr --arch "$arch" --verbose $FLAG_GPG $KEYRING_FLAG \
            --include="$paquetes_ubuntu" "$version" "$CHROOT" "$local_mirror_alt" || {
            error_msg "Falló debootstrap (primera etapa). Revise los mensajes anteriores."
            exit 1
        }
        archiveSite="$local_mirror_alt"
    }

    info "Primera etapa completada exitosamente"
    echo ""
    echo "   ⚠️  CONSTRUCCIÓN CRUZADA - SEGUNDA ETAPA REQUERIDA"
    echo "   Para completar la instalación, ejecute:"
    echo ""
    echo "   1. Montar filesystems:"
    echo "      $(dirname "$0")/mount_umount-chroot.sh $NOMBRE_JAULA mount"
    echo ""
    echo "   2. Ejecutar segunda etapa:"
    echo "      chroot $CHROOT /debootstrap/debootstrap --second-stage"
    echo ""
    echo "   3. Actualizar paquetes:"
    echo "      chroot $CHROOT apt-get update && apt-get -y upgrade && apt-get clean all"
    echo ""
    echo "   4. Desmontar:"
    echo "      $(dirname "$0")/mount_umount-chroot.sh $NOMBRE_JAULA umount"
    echo ""

    # Crear mychroot.conf básico
    mkdir -p "$CHROOT/etc"
    cat > "$CHROOT/etc/mychroot.conf" << EOFMYCHROOT
# Configuracion inicial de Filesystems a montar para la Jaula $CHROOT.
# El archivo $CHROOT/etc/mychroot.conf segun necesidades.

# Filesystems a montar:
FS:/proc
FS:/dev
FS:/dev/pts
FS:/sys
FS:/home

# Configuracion inicial de Servicios a iniciar:
# Service:/etc/init.d/cron
# Service:/etc/init.d/rsyslog
EOFMYCHROOT
    chmod 640 "$CHROOT/etc/mychroot.conf"

    exito "Primera etapa de construcción cruzada completada"
    exit 0
fi

# Construcción normal (misma arquitectura)
info "Intentando mirror principal: $MIRROR_PRINCIPAL/dists/$version/ ..."
if debootstrap --merged-usr --components=main,universe --arch "$arch" --verbose $FLAG_GPG $KEYRING_FLAG \
    --include="$paquetes_ubuntu" "$version" "$CHROOT" "$MIRROR_PRINCIPAL"; then
    archiveSite="archive"
    exito "debootstrap completado exitosamente"
else
    # Solo usar old-releases para versiones EOL, no para la actual (resolute, noble, etc.)
    if [[ -n "${VERSIONES_EOL[$version]+x}" ]]; then
        advertencia "Mirror principal falló, intentando old-releases..."
        if debootstrap --merged-usr --arch "$arch" --verbose $FLAG_GPG $KEYRING_FLAG \
            --include="$paquetes_ubuntu" "$version" "$CHROOT" "http://old-releases.ubuntu.com/ubuntu"; then
            archiveSite="old-releases"
        else
            error_msg "Falló debootstrap en ambos intentos. Revise los mensajes anteriores."
            exit 1
        fi
    else
        error_msg "Falló debootstrap. Revise el mirror o la conexión a internet."
        echo "   Mirror: $MIRROR_PRINCIPAL"
        echo "   Versión: $version"
        exit 1
    fi
fi

# Crear archivo de configuración mychroot.conf
mkdir -p "$CHROOT/etc"
cat > "$CHROOT/etc/mychroot.conf" << EOFMYCHROOT
# Configuracion inicial de Filesystems a montar para la Jaula $CHROOT.
# El archivo $CHROOT/etc/mychroot.conf segun necesidades.

# Filesystems a montar:
FS:/proc
FS:/dev
FS:/dev/pts
FS:/sys
FS:/home

# Configuracion inicial de Servicios a iniciar:
Service:/etc/init.d/cron
# Service:/etc/init.d/rsyslog
EOFMYCHROOT
chmod 640 "$CHROOT/etc/mychroot.conf"

# Configurar repositorios
info "Configurando repositorios de Apt..."
cat > "$CHROOT/etc/apt/sources.list" << EOFREPO
deb http://${archiveSite}.ubuntu.com/ubuntu $version main restricted universe multiverse
deb http://${archiveSite}.ubuntu.com/ubuntu $version-security main restricted universe multiverse
deb http://${archiveSite}.ubuntu.com/ubuntu $version-updates main restricted universe multiverse
EOFREPO

exito "Repositorios configurados en /etc/apt/sources.list"

# Montar filesystems
echo ""
info "Montando filesystems para el chroot..."
"$(dirname "$0")/mount_umount-chroot.sh" "$NOMBRE_JAULA" mount

# Aplicar workarounds para trusty (14.04)
if [ "$version" == "trusty" ]; then
    echo ""
    advertencia "Aplicando workaround para 'udev' y 'cron' en Trusty (14.04)..."
    cp "$CHROOT/etc/init.d/cron" "$CHROOT/etc/init.d/cron.original"
    cp "$CHROOT/etc/init.d/udev" "$CHROOT/etc/init.d/udev.original"
    rm -vf "$CHROOT/etc/init.d/cron" "$CHROOT/etc/init.d/udev"
    cp -vf "$(dirname "$0")/ubuntu/trusty_etc_init.d_cron" "$CHROOT/etc/init.d/cron"
    cp -vf "$(dirname "$0")/ubuntu/trusty_etc_init.d_udev" "$CHROOT/etc/init.d/udev"
    chmod 750 "$CHROOT/etc/init.d/cron" "$CHROOT/etc/init.d/udev"

    info "Re-montando filesystems después del workaround..."
    "$(dirname "$0")/mount_umount-chroot.sh" "$NOMBRE_JAULA" umount
    "$(dirname "$0")/mount_umount-chroot.sh" "$NOMBRE_JAULA" mount
fi

# Actualizar y upgrading del sistema
echo ""
info "Actualizando paquetes del sistema (apt-get update && upgrade)..."
if chroot "$CHROOT" /bin/bash -c "apt-get update && apt-get -y upgrade && apt-get clean all"; then
    exito "Actualización de paquetes completada"
else
    error_msg "Falló la actualización de paquetes. Revise los mensajes anteriores."
fi

# Generar resumen de construcción
generar_resumen

# Mostrar resumen final
echo ""
echo " - - - - - - - - - - RESUMEN - - - - - - - - - -"
echo ""
echo -e "${VERDE}Dispositivos montados:${NC}"
mount | grep "$CHROOT" | awk '{print $3}' | sort -r
echo ""
echo "IMPORTANTE!!! Revisa el archivo $CHROOT/etc/mychroot.conf y configúralo según tus necesidades."
echo ""
exito "La jaula $CHROOT fue creada exitosamente."
echo "   Revise la salida de las líneas anteriores por errores y corrija si es necesario."
echo ""
echo "Para que un usuario <userbob> pueda hacer uso de esta jaula, agregar en"
echo "el archivo de configuración /etc/ssh/sshd_config lo siguiente:"
echo ""
conf="
Match User userbob
        ChrootDirectory $CHROOT
        X11Forwarding no
        AllowTcpForwarding no
"
echo -e "$conf"
echo "Y reinicie el servicio ssh: service sshd restart"
echo " - - - - - - - - - - - - - - - - - - - - - - - -"

# Información opcional
opt="
# Opcional:
#
# + Como usuario root:
#   chroot $CHROOT
#
# + Usuarios NO root:
#   cp /usr/sbin/chroot /usr/sbin/chrootuser    (como root, una sola vez)
#   setcap cap_sys_chroot+ep /usr/sbin/chrootUser (como root, una sola vez)
#   /usr/sbin/chrootUser $CHROOT                 (como NO root, ya puede usar la jaula)
#
# Nota: Antes de utilizar la jaula, considere agregar los repositorios necesarios
#       en /etc/apt/sources.list. Puede generarlos en:
#       http://repogen.simplylinux.ch/index.php
#       Luego: apt-get update, apt-get install ...
"
echo -e "$opt"

exit 0
