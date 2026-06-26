#!/bin/bash
#
# Build a chroot with a Debian base install.
# Author: josecc@gmail.com
#
# https://deb.debian.org/debian/dists/ && https://archive.debian.org/debian/dists/
# --variant=minbase|buildd|fakechroot|scratchbox
# --arch amd64, i386, arm64, armhf, ppc64el, s390x
#
# Variables de entorno opcionales:
#   SIN_VERIFICACION_GPG=true    : Desactiva verificación GPG (solo pruebas/desarrollo)
#   MIRROR_DEBIAN=<url>          : Usa un mirror personalizado
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
# Versiones soportadas de Debian
# ==============================================================================
VERSIONES_SOPORTADAS=(
    # Estable, Testing y Futuras
    "trixie" "forky" "sid" "duke"
    # Oldstable y anteriores (con soporte o LTS)
    "bookworm" "bullseye"
    # Versiones EOL (legado, con advertencia)
    "buster" "stretch" "jessie" "wheezy" "squeeze"
)

# Mapa de versiones EOL y sus fechas de fin de soporte
declare -A VERSIONES_EOL=(
    ["squeeze"]="Febrero 2016 (LTS: Febrero 2020)"
    ["wheezy"]="Junio 2018 (LTS: Junio 2020)"
    ["jessie"]="Junio 2020 (LTS: Junio 2022)"
    ["stretch"]="Julio 2022"
    ["buster"]="Junio 2024"
)

# Información de versiones con soporte activo
declare -A VERSIONES_ACTIVAS=(
    ["trixie"]="Ago 2028 (Stable - Debian 13)"
    ["forky"]="2027 (Testing - Debian 14)"
    ["duke"]="Futuro (Debian 15 - codename anunciado)"
    ["bookworm"]="Jun 2026 (Oldstable - Debian 12)"
    ["bullseye"]="Ago 2026 (LTS - Debian 11)"
)

# Estado de cada versión
declare -A VERSIONES_ESTADO=(
    ["trixie"]="stable"
    ["forky"]="testing"
    ["sid"]="unstable"
    ["duke"]="future"
    ["bookworm"]="oldstable"
    ["bullseye"]="oldoldstable"
    ["buster"]="EOL"
    ["stretch"]="EOL"
    ["jessie"]="EOL"
    ["wheezy"]="EOL"
    ["squeeze"]="EOL"
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
        advertencia "Debian $version llegó al fin de vida (EOL): ${VERSIONES_EOL[$version]}"
        echo "   - Las actualizaciones de seguridad ya NO están disponibles (o son limitadas)"
        echo "   - Pueden existir vulnerabilidades sin parchar"
        echo ""
        echo "   Versiones con soporte activo recomendadas:"
        for activa in "${!VERSIONES_ACTIVAS[@]}"; do
            echo "   - $activa (${VERSIONES_ACTIVAS[$activa]})"
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

es_version_estable() {
    local version="${1:-}"
    [[ "${VERSIONES_ESTADO[$version]:-}" == "stable" ]]
}

es_version_testing() {
    local version="${1:-}"
    [[ "${VERSIONES_ESTADO[$version]:-}" == "testing" ]]
}

es_version_unstable() {
    local version="${1:-}"
    [[ "${VERSIONES_ESTADO[$version]:-}" == "unstable" ]]
}

es_version_eol() {
    local version="${1:-}"
    [[ -n "${VERSIONES_EOL[$version]+x}" ]]
}

# Verificación adicional de scripts de debootstrap
verificar_debootstrap() {
    if [ ! -d /usr/share/debootstrap/scripts ]; then
        error_msg "Directorio /usr/share/debootstrap/scripts no encontrado"
        echo "   La versión de debootstrap no soporta instalar Debian Linux."
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
# Verificar/actualizar keyring para versiones de Debian
# ==============================================================================
verificar_keyring_debian() {
    local version="$1"
    local keyring="/usr/share/keyrings/debian-archive-keyring.gpg"

    if [ ! -f "$keyring" ]; then
        info "Keyring de Debian no encontrado, descargando..."
        wget -qO "$keyring" "https://keyring.debian.org/keyrings/debian-archive-keyring.gpg" 2>/dev/null || {
            error_msg "No se pudo descargar el keyring de Debian"
            exit 1
        }
        exito "Keyring de Debian descargado"
        return 0
    fi

    if debootstrap --dry-run --keyring="$keyring" "$version" /tmp/.test-keyring 2>/dev/null; then
        return 0
    fi

    info "Keyring local desactualizado para Debian $version, descargando actualización..."
    local temp_keyring
    temp_keyring=$(mktemp)

    if wget -qO "$temp_keyring" "https://keyring.debian.org/keyrings/debian-archive-keyring.gpg" 2>/dev/null ||
       wget -qO "$temp_keyring" "https://ftp-master.debian.org/keys/archive-key-$(echo "$version" | sed 's/[0-9]//g').asc" 2>/dev/null; then
        cp "$temp_keyring" "$keyring"
        rm -f "$temp_keyring"
        exito "Keyring de Debian actualizado para $version"
    else
        rm -f "$temp_keyring"
        advertencia "No se pudo actualizar el keyring automáticamente"
        echo "   Puede continuar con SIN_VERIFICACION_GPG=true (solo desarrollo)"
        echo "   O instale: sudo apt-get install --reinstall debian-keyring"
    fi
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
        return 0  # Es construcción cruzada
    fi
    return 1  # No es construcción cruzada
}

# ==============================================================================
# Generar resumen de construcción
# ==============================================================================
generar_resumen() {
    local archivo_resumen="$CHROOT/etc/resumen-construccion.txt"
    local estado="${VERSIONES_ESTADO[$version]:-desconocido}"
    local tipo_info="Debian $estado"
    if es_version_eol "$version"; then
        tipo_info="Debian EOL (fin de vida: ${VERSIONES_EOL[$version]})"
    fi

    cat > "$archivo_resumen" << EOF
================================================================================
Resumen de Construcción del Chroot Debian
================================================================================
Fecha:              $(date)
Versión:            $version
Tipo:               $tipo_info
Arquitectura:       $arch
Ruta del Chroot:    $CHROOT
Mirror utilizado:   $MIRROR_PRINCIPAL
Paquetes instalados: $paquetes_debian
Verificación GPG:   $VERIFICACION_GPG
Construcción cruzada: $CONSTRUCCION_CRUZADA
Limpieza deborphan: $REALIZO_LIMPIEZA

Estado: EXITOSO
================================================================================

NOTAS IMPORTANTES:
- Revise /etc/mychroot.conf para configurar filesystems y servicios
- Actualice repositorios en /etc/apt/sources.list según sus necesidades
- Para acceso SSH con ChrootDirectory, consulte las instrucciones al final
  de la salida de este script
- Si deshabilitó deborphan, puede ejecutarlo manualmente:
    chroot $CHROOT apt-get install deborphan && chroot $CHROOT deborphan

FIN DEL RESUMEN
================================================================================
EOF
    chmod 644 "$archivo_resumen"
    echo ""
    info "Resumen de construcción guardado en: $archivo_resumen"
}

# ==============================================================================
# Determinar mirror y repositorios según versión
# ==============================================================================
obtener_mirror() {
    local version="${1:-}"

    if es_version_eol "$version"; then
        echo "http://archive.debian.org/debian"
    else
        echo "http://deb.debian.org/debian"
    fi
}

obtener_mirror_seguridad() {
    local version="${1:-}"

    if es_version_eol "$version"; then
        echo "http://archive.debian.org/debian-security"
    else
        echo "http://security.debian.org/debian-security"
    fi
}

generar_sources_list() {
    local version="${1:-}"
    local chroot_path="$2"
    local mirror
    mirror=$(obtener_mirror "$version")
    local mirror_seguridad
    mirror_seguridad=$(obtener_mirror_seguridad "$version")

    # sid (unstable) no tiene updates ni security
    if es_version_unstable "$version"; then
        cat > "$chroot_path/etc/apt/sources.list" << EOF
deb $mirror $version main contrib non-free non-free-firmware
EOF
        return
    fi

    # Para versiones EOL muy antiguas (wheezy, squeeze), no hay updates
    if [[ "$version" == "wheezy" || "$version" == "squeeze" ]]; then
        cat > "$chroot_path/etc/apt/sources.list" << EOF
deb $mirror $version main contrib non-free
EOF
        # squeeze necesita desactivar Check-Valid-Until
        if [ "$version" == "squeeze" ]; then
            mkdir -p "$chroot_path/etc/apt/apt.conf.d"
            echo "Acquire::Check-Valid-Until \"false\";" > "$chroot_path/etc/apt/apt.conf.d/99no-check-valid-until"
        fi
        return
    fi

    # Versiones normales con updates y security
    cat > "$chroot_path/etc/apt/sources.list" << EOF
deb $mirror $version main contrib non-free non-free-firmware
deb $mirror $version-updates main contrib non-free non-free-firmware
deb $mirror_seguridad ${version}-security main contrib non-free non-free-firmware
EOF
}

# ==============================================================================
# Limpieza con deborphan (opcional)
# ==============================================================================
limpieza_deborphan() {
    local chroot_path="$1"
    local version="$2"

    # Saltar limpieza para versiones muy antiguas o si se deshabilitó
    if [ "${SIN_DEBORPHAN:-}" == "true" ]; then
        info "Limpieza con deborphan deshabilitada (SIN_DEBORPHAN=true)"
        echo "   false"
        return 0
    fi

    # No ejecutar deborphan en sid (cambios constantes)
    if es_version_unstable "$version"; then
        info "Omitiendo deborphan en sid (inestable)"
        echo "   false"
        return 0
    fi

    info "Instalando y ejecutando deborphan para limpiar paquetes huérfanos..."

    # Instalar deborphan
    if ! chroot "$chroot_path" apt-get -y install deborphan 2>/dev/null; then
        advertencia "No se pudo instalar deborphan, omitiendo limpieza"
        echo "   false"
        return 0
    fi

    # Obtener lista de huérfanos, excluyendo paquetes esenciales
    local exclusiones="deborphan|wget|openssh-|rsyslog|vim|apt"
    local huerfanos
    huerfanos=$(chroot "$chroot_path" deborphan --lib-packages 2>/dev/null | grep -vE "$exclusiones" || true)

    if [ -z "$huerfanos" ]; then
        info "No se encontraron paquetes huérfanos para eliminar"
        echo "   false"
        return 0
    fi

    local contador=0
    while IFS= read -r paquete; do
        [ -z "$paquete" ] && continue
        if chroot "$chroot_path" apt-get -y remove --purge "$paquete" 2>/dev/null; then
            contador=$((contador + 1))
        fi
    done <<< "$huerfanos"

    if [ $contador -gt 0 ]; then
        exito "Eliminados $contador paquetes huérfanos"
    else
        info "No se eliminaron paquetes huérfanos"
    fi

    echo "   true"
    return 0
}

# ==============================================================================
# Mostrar mensaje de ayuda
# ==============================================================================
mostrar_ayuda() {
    echo " - - - - - - - - - - - - - - - - - -"
    echo -e "$0 creará una jaula dentro del directorio $ROOTJAIL/\$NOMBRE\n"
    echo " - - - - - - - - - - - - - - - - - -"
    echo ""
    echo "Versiones de Debian soportadas:"
    echo ""
    echo "  Actuales:"
    echo "   trixie    - 13         (Stable)        - Soporte hasta Ago 2028"
    echo "   forky     - 14         (Testing)       - Será Stable en 2027"
    echo "   sid       - unstable   (Unstable)      - Desarrollo continuo"
    echo "   duke      - 15         (Futuro)        - Codename anunciado"
    echo ""
    echo "  Con soporte:"
    echo "   bookworm  - 12         (Oldstable)     - Soporte hasta Jun 2026"
    echo "   bullseye  - 11         (Oldoldstable)  - LTS hasta Ago 2026"
    echo ""
    echo "  Legacy (EOL - Solo para compatibilidad):"
    echo "   buster    - 10         [EOL Jun 2024]"
    echo "   stretch   - 9          [EOL Jul 2022]"
    echo "   jessie    - 8          [EOL Jun 2022]"
    echo "   wheezy    - 7          [EOL Jun 2020]"
    echo "   squeeze   - 6          [EOL Feb 2020]"
    echo ""
    echo "Uso:"
    echo "  $0 NombreJaula [versión [arquitectura]]"
    echo ""
    echo "  NombreJaula  : Nombre del directorio de la jaula"
    echo "  versión      : Codename de Debian (ej: trixie, bookworm, sid)"
    echo "  arquitectura : amd64, i386, arm64, armhf, ppc64el, s390x (default: host)"
    echo ""
    echo "Ejemplos:"
    echo "  $0 mi-debian trixie"
    echo "  $0 mi-debian bookworm amd64"
    echo "  $0 mi-debian sid arm64"
    echo "  $0 mi-debian bullseye i386"
    echo ""
    echo "Variables de entorno opcionales:"
    echo "  SIN_VERIFICACION_GPG=true   : Desactiva verificación GPG (solo pruebas)"
    echo "  MIRROR_DEBIAN=<url>         : Usa un mirror personalizado"
    echo "  INTERACTIVO=true            : Modo interactivo para seleccionar versión"
    echo "  FORZAR_EOL=true             : Omite confirmación para versiones EOL"
    echo "  SIN_DEBORPHAN=true          : Omite limpieza con deborphan"
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
MIRROR_PRINCIPAL=""
if [ -n "${MIRROR_DEBIAN:-}" ]; then
    MIRROR_PRINCIPAL="$MIRROR_DEBIAN"
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
    echo "Seleccione versión de Debian:"
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

# Si aún no hay versión, usar trixie (stable) como default
if [ -z "$version" ]; then
    version="trixie"
    info "Usando versión por defecto: $version (Debian 13 - Stable)"
fi

# Validar versión
if ! validar_version "$version"; then
    error_msg "Versión de Debian no soportada: $version"
    echo "   Versiones soportadas: ${VERSIONES_SOPORTADAS[*]}"
    exit 1
fi

# Determinar mirror si no se proporcionó uno personalizado
if [ -z "$MIRROR_PRINCIPAL" ]; then
    MIRROR_PRINCIPAL=$(obtener_mirror "$version")
fi

# Verificaciones previas
verificaciones_previas

# Advertencia EOL
advertir_eol "$version"

# Obtener paquetes específicos para esta versión
paquetes_debian=$(obtener_paquetes_debian "$version")

# Agregar libc6-i386 para arquitectura amd64
if [ "$arch" == "amd64" ]; then
    paquetes_debian="$paquetes_debian,libc6-i386"
fi

# Verificar construcción cruzada
CONSTRUCCION_CRUZADA="No"
if verificar_construccion_cruzada; then
    arch_host=$(uname -m)
    case "$arch_host" in
        x86_64) arch_host="amd64" ;;
        aarch64) arch_host="arm64" ;;
        i686|i386) arch_host="i386" ;;
    esac
    CONSTRUCCION_CRUZADA="Sí ($arch_host -> $arch)"
    info "Construcción cruzada detectada: $arch_host -> $arch"
fi

# Información de la versión
local_estado="${VERSIONES_ESTADO[$version]:-desconocido}"
if es_version_eol "$version"; then
    local_estado="EOL (${VERSIONES_EOL[$version]})"
elif [[ -n "${VERSIONES_ACTIVAS[$version]+x}" ]]; then
    local_estado="${VERSIONES_ACTIVAS[$version]}"
fi

# Resumen de la operación
echo ""
echo " - - - - - - - - - - - - - - - - - -"
echo -e "Instalando Debian Chroot"
echo -e " - - - - - - - - - - - - - - - - - -"
echo -e "Jaula:        $CHROOT"
echo -e "Versión:      $version"
echo -e "Estado:       $local_estado"
echo -e "Arquitectura:  $arch"
echo -e "Mirror:       $MIRROR_PRINCIPAL"
echo -e "GPG:          $VERIFICACION_GPG"
echo -e "Paquetes:     $paquetes_debian"
echo " - - - - - - - - - - - - - - - - - -"
echo ""

# Crear symlink para debootstrap si no existe
if [ ! -f "/usr/share/debootstrap/scripts/$version" ]; then
    info "Creando symlink de debootstrap para $version"
    ln -sf /usr/share/debootstrap/scripts/sid "/usr/share/debootstrap/scripts/$version"
fi

# Verificar o actualizar keyring de Debian
verificar_keyring_debian "$version"

# Construcción cruzada: modo --foreign
if verificar_construccion_cruzada; then
    info "Modo construcción cruzada (--foreign)"
    echo "   Primera etapa: extrayendo archivos base..."
    debootstrap --arch "$arch" --verbose $FLAG_GPG \
        --include="$paquetes_debian" "$version" "$CHROOT" "$MIRROR_PRINCIPAL" || {
        echo ""
        error_msg "Falló debootstrap (primera etapa). Revise los mensajes anteriores."
        exit 1
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
    echo "   3. Configurar repositorios y actualizar:"
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
local_mirrors=("$MIRROR_PRINCIPAL")
if [ "$MIRROR_PRINCIPAL" == "http://deb.debian.org/debian" ]; then
    local_mirrors+=("http://httpredir.debian.org/debian")
fi
if ! es_version_eol "$version"; then
    local_mirrors+=("http://archive.debian.org/debian")
fi

archiveSource=""
for mirror in "${local_mirrors[@]}"; do
    info "Intentando mirror: $mirror/dists/$version/ ..."
    if debootstrap --arch "$arch" --verbose $FLAG_GPG \
        --include="$paquetes_debian" "$version" "$CHROOT" "$mirror"; then
        case "$mirror" in
            *archive*) archiveSource="archive" ;;
            *httpredir*) archiveSource="fallback" ;;
            *) archiveSource="deb" ;;
        esac
        exito "debootstrap completado exitosamente desde $mirror"
        break
    fi
    advertencia "Mirror $mirror falló."
done

if [ -z "$archiveSource" ]; then
    error_msg "Falló debootstrap en todos los mirrors. Revise los mensajes anteriores."
    exit 1
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
generar_sources_list "$version" "$CHROOT"
exito "Repositorios configurados en /etc/apt/sources.list"

# Montar filesystems
echo ""
info "Montando filesystems para el chroot..."
"$(dirname "$0")/mount_umount-chroot.sh" "$NOMBRE_JAULA" mount

# Actualizar y upgrade del sistema
echo ""
info "Actualizando paquetes del sistema (apt-get update && upgrade)..."
if chroot "$CHROOT" /bin/bash -c "apt-get update && apt-get -y upgrade && apt-get clean all"; then
    exito "Actualización de paquetes completada"
else
    error_msg "Falló la actualización de paquetes. Revise los mensajes anteriores."
fi

# Limpieza con deborphan
echo ""
REALIZO_LIMPIEZA="false"
resultado_deborphan=$(limpieza_deborphan "$CHROOT" "$version")
if [[ "$resultado_deborphan" == *"true"* ]]; then
    REALIZO_LIMPIEZA="true"
    # Actualizar después de limpieza
    chroot "$CHROOT" /bin/bash -c "apt-get -y upgrade && apt-get clean all" 2>/dev/null || true
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
#       en /etc/apt/sources.list.
"
echo -e "$opt"

exit 0
