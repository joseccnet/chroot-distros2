#!/bin/bash
#
# Build a chroot with a Devuan base install (Debian Without systemd).
# Author: josecc@gmail.com
#
# https://www.devuan.org/
# https://deb.devuan.org/devuan/dists/
#
# Devuan 6 Excalibur (Nov 2025) → Debian 13 Trixie
# Devuan 5 Daedalus (May 2023)   → Debian 12 Bookworm
# Devuan 4 Chimaera (Aug 2021)   → Debian 11 Bullseye
# Devuan 3 Beowulf (Jun 2020)    → Debian 10 Buster
# Devuan 2 ASCII (Jun 2018)      → Debian 9 Stretch
# Devuan 1 Jessie (May 2017)     → Debian 8 Jessie
#
# --arch amd64, i386, arm64, armhf
#
# Variables de entorno opcionales:
#   SIN_VERIFICACION_GPG=true    : Desactiva verificación GPG (solo pruebas)
#   MIRROR_DEVUAN=<url>          : Usa un mirror personalizado
#   ESPACIO_MINIMO_GB=<n>        : Espacio mínimo requerido en GB (default: 2)
#

set -euo pipefail

source "$(dirname "$0")/chroot.conf"
source "$(dirname "$0")/lib/chroot-lib.sh"

# ==============================================================================
# Limpieza ante errores
# ==============================================================================
limpieza() {
    local codigo_salida=$?
    if [ $codigo_salida -ne 0 ] && [ -n "${CHROOT:-}" ] && [ -d "${CHROOT:-}" ]; then
        error_msg "La construcción falló con código de salida $codigo_salida"
        echo "   Chroot parcial en: $CHROOT"
        echo "   Limpiar: rm -rf $CHROOT"
        echo "   Desmontar: $(dirname "$0")/mount_umount-chroot.sh $(basename "$CHROOT") umount"
    fi
    exit $codigo_salida
}
trap limpieza EXIT

# ==============================================================================
# Versiones soportadas de Devuan
# ==============================================================================
VERSIONES_SOPORTADAS=(
    # Actuales
    "excalibur"   # 6 - Debian 13 Trixie (Stable)
    "freia"       # 7 - Debian 14 Forky (Testing)
    "ceres"       # Unstable (Rolling)
    "daedalus"    # 5 - Debian 12 Bookworm (Oldstable)
    # Legacy
    "chimaera"    # 4 - Debian 11 Bullseye (EOL)
    "beowulf"     # 3 - Debian 10 Buster (EOL)
    "ascii"       # 2 - Debian 9 Stretch (EOL)
    "jessie"      # 1 - Debian 8 Jessie (EOL)
)

declare -A VERSIONES_ESTADO=(
    ["excalibur"]="Stable (Devuan 6 - Trixie)"
    ["freia"]="Testing (Devuan 7 - Forky)"
    ["ceres"]="Unstable (Rolling)"
    ["daedalus"]="Oldstable (Devuan 5 - Bookworm)"
    ["chimaera"]="EOL (Devuan 4 - Ago 2024)"
    ["beowulf"]="EOL (Devuan 3 - Jun 2024)"
    ["ascii"]="EOL (Devuan 2 - Jul 2022)"
    ["jessie"]="EOL (Devuan 1 - Jun 2022)"
)

declare -A VERSIONES_EOL=(
    ["chimaera"]="Agosto 2024"
    ["beowulf"]="Junio 2024"
    ["ascii"]="Julio 2022"
    ["jessie"]="Junio 2022"
)

# Verificación adicional de scripts de debootstrap
verificar_debootstrap() {
    if [ ! -d /usr/share/debootstrap/scripts ]; then
        error_msg "Directorio /usr/share/debootstrap/scripts no encontrado"
        exit 1
    fi
}

# ==============================================================================
# Verificaciones previas
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

    case "$arch" in
        amd64|i386|arm64|armhf) ;;
        x86_64) arch="amd64" ;;
        aarch64) arch="arm64" ;;
        *)
            error_msg "Arquitectura no soportada: $arch"
            echo "   Soportadas: amd64, i386, arm64, armhf"
            exit 1
            ;;
    esac

    exito "Verificaciones previas completadas"
    echo ""
}

# ==============================================================================
# Verificar/actualizar keyring para Devuan
# ==============================================================================
verificar_keyring_devuan() {
    local version="$1"
    local keyring="/usr/share/keyrings/devuan-archive-keyring.gpg"
    local debian_keyring="/usr/share/keyrings/debian-archive-keyring.gpg"

    # Devuan usa keyring propio o el de Debian como fallback
    for kr in "$keyring" "$debian_keyring"; do
        if [ -f "$kr" ] && debootstrap --dry-run --keyring="$kr" "$version" /tmp/.test-keyring 2>/dev/null; then
            return 0
        fi
    done

    # Intentar descargar keyring de Devuan
    info "Keyring para Devuan no encontrado o desactualizado, descargando..."
    mkdir -p "$(dirname "$keyring")"
    local temp_keyring
    temp_keyring=$(mktemp)

    if wget -qO "$temp_keyring" "https://deb.devuan.org/devuan/pool/main/d/devuan-keyring/devuan-keyring_latest_all.deb" 2>/dev/null; then
        dpkg -x "$temp_keyring" /tmp/devuan-keyring-extract 2>/dev/null
        local found_key
        found_key=$(find /tmp/devuan-keyring-extract -name 'devuan-archive-keyring.gpg' 2>/dev/null | head -1)
        if [ -n "$found_key" ]; then
            cp "$found_key" "$keyring"
            exito "Keyring de Devuan descargado"
        fi
        rm -rf /tmp/devuan-keyring-extract
    fi
    rm -f "$temp_keyring"

    if [ ! -f "$keyring" ]; then
        advertencia "No se pudo obtener keyring de Devuan. Use SIN_VERIFICACION_GPG=true si es necesario."
    fi
}

# ==============================================================================
# Generar resumen
# ==============================================================================
generar_resumen() {
    local archivo="$CHROOT/etc/resumen-construccion.txt"
    cat > "$archivo" << EOF
================================================================================
Resumen de Construcción del Chroot Devuan (Debian sin systemd)
================================================================================
Fecha:              $(date)
Versión:            $version
Estado:             ${VERSIONES_ESTADO[$version]:-desconocido}
Arquitectura:       $arch
Ruta del Chroot:    $CHROOT
Mirror:             $MIRROR_DEVUAN
Verificación GPG:   $VERIFICACION_GPG

Estado: EXITOSO

NOTAS:
- Devuan es Debian GNU/Linux sin systemd (usa sysvinit, runit o OpenRC)
- Init por defecto: sysvinit
- Revise /etc/mychroot.conf para filesystems y servicios
- Repositorios en /etc/apt/sources.list

FIN DEL RESUMEN
================================================================================
EOF
    chmod 644 "$archivo"
    info "Resumen guardado en: $archivo"
}

# ==============================================================================
# Ayuda
# ==============================================================================
mostrar_ayuda() {
    echo " - - - - - - - - - - - - - - - - - -"
    echo -e "$0 creará una jaula con Devuan (Debian sin systemd)"
    echo " - - - - - - - - - - - - - - - - - -"
    echo ""
    echo "Versiones de Devuan soportadas:"
    echo ""
    echo "  Actuales:"
    echo "   excalibur  - 6  (Stable, basado en Debian 13 Trixie)"
    echo "   freia      - 7  (Testing, basado en Debian 14 Forky)"
    echo "   ceres      - unstable (Rolling, desarrollo continuo)"
    echo "   daedalus   - 5  (Oldstable, basado en Debian 12 Bookworm)"
    echo ""
    echo "  Legacy (EOL):"
    echo "   chimaera   - 4  [EOL Ago 2024]"
    echo "   beowulf    - 3  [EOL Jun 2024]"
    echo "   ascii      - 2  [EOL Jul 2022]"
    echo "   jessie     - 1  [EOL Jun 2022]"
    echo ""
    echo "Uso:"
    echo "  $0 NombreJaula [versión [arquitectura]]"
    echo ""
    echo "Ejemplos:"
    echo "  $0 mi-devuan excalibur"
    echo "  $0 mi-devuan daedalus amd64"
    echo "  $0 mi-devuan ceres arm64"
    echo ""
    echo "Variables de entorno:"
    echo "  SIN_VERIFICACION_GPG=true  : Desactiva GPG (solo pruebas)"
    echo "  MIRROR_DEVUAN=<url>        : Mirror personalizado"
    echo "  ESPACIO_MINIMO_GB=<n>      : Espacio mínimo en GB (default: 2)"
    echo ""
    exit 1
}

# ==============================================================================
# Determinar mirror y generar sources.list
# ==============================================================================
generar_sources_list() {
    local version="${1:-}"
    local chroot_path="$2"
    local mirror="$MIRROR_DEVUAN"

    case "$version" in
        excalibur)
            cat > "$chroot_path/etc/apt/sources.list" << EOF
deb $mirror excalibur main contrib non-free non-free-firmware
deb $mirror excalibur-security main contrib non-free non-free-firmware
deb $mirror excalibur-updates main contrib non-free non-free-firmware
EOF
            ;;
        freia)
            cat > "$chroot_path/etc/apt/sources.list" << EOF
deb $mirror freia main contrib non-free non-free-firmware
deb $mirror freia-security main contrib non-free non-free-firmware
deb $mirror freia-updates main contrib non-free non-free-firmware
EOF
            ;;
        daedalus)
            cat > "$chroot_path/etc/apt/sources.list" << EOF
deb $mirror daedalus main contrib non-free non-free-firmware
deb $mirror daedalus-security main contrib non-free non-free-firmware
deb $mirror daedalus-updates main contrib non-free non-free-firmware
EOF
            ;;
        chimaera)
            cat > "$chroot_path/etc/apt/sources.list" << EOF
deb $mirror chimaera main contrib non-free
deb $mirror chimaera-security main contrib non-free
deb $mirror chimaera-updates main contrib non-free
EOF
            ;;
        beowulf)
            cat > "$chroot_path/etc/apt/sources.list" << EOF
deb $mirror beowulf main contrib non-free
deb $mirror beowulf-security main contrib non-free
deb $mirror beowulf-updates main contrib non-free
EOF
            ;;
        ascii)
            cat > "$chroot_path/etc/apt/sources.list" << EOF
deb $mirror ascii main contrib non-free
deb $mirror ascii-security main contrib non-free
deb $mirror ascii-updates main contrib non-free
EOF
            ;;
        jessie)
            cat > "$chroot_path/etc/apt/sources.list" << EOF
deb $mirror jessie main contrib non-free
deb $mirror jessie-security main contrib non-free
EOF
            ;;
        ceres)
            # Ceres (unstable) no tiene updates/security separados
            cat > "$chroot_path/etc/apt/sources.list" << EOF
deb $mirror ceres main contrib non-free non-free-firmware
EOF
            ;;
    esac
}

# ==============================================================================
# INICIO DEL SCRIPT PRINCIPAL
# ==============================================================================

if [ "${1:-}" == "" ] || [ "${1:-}" == "--help" ] || [ "${1:-}" == "-h" ]; then
    mostrar_ayuda
fi

# GPG
VERIFICACION_GPG="activada"
if [ "${SIN_VERIFICACION_GPG:-}" == "true" ]; then
    FLAG_GPG="--no-check-gpg"
    VERIFICACION_GPG="desactivada (modo pruebas)"
    advertencia "Verificación GPG desactivada"
else
    FLAG_GPG="--force-check-gpg"
fi

# Mirror
MIRROR_DEVUAN="${MIRROR_DEVUAN:-http://deb.devuan.org/merged}"

# Crear ROOTJAIL
if [ ! -d "$ROOTJAIL" ]; then
    mkdir -vp "$ROOTJAIL"
    chmod 755 "$ROOTJAIL"
fi

# Parsear argumentos
NOMBRE_JAULA="${1:-}"
CHROOT="$ROOTJAIL/$NOMBRE_JAULA"
version="${2:-}"
arch="${3:-$(uname -m)}"

# Default a daedalus (oldstable estable)
if [ -z "$version" ]; then
    version="daedalus"
    info "Usando versión por defecto: $version (Devuan 5 - Oldstable)"
fi

# Validar versión
if ! [[ " ${VERSIONES_SOPORTADAS[*]} " =~ " $version " ]]; then
    error_msg "Versión de Devuan no soportada: $version"
    echo "   Soportadas: ${VERSIONES_SOPORTADAS[*]}"
    exit 1
fi

verificaciones_previas

# Advertencia EOL
if [[ -n "${VERSIONES_EOL[$version]+x}" ]]; then
    advertencia "Devuan $version es EOL desde ${VERSIONES_EOL[$version]}"
    echo ""
    if [ "${FORZAR_EOL:-}" != "true" ]; then
        read -p "¿Continuar? (s/N): " resp
        [[ "$resp" =~ ^[sSyY]$ ]] || { info "Cancelado."; exit 0; }
    fi
fi

# Paquetes
paquetes_devuan=$(obtener_paquetes_devuan "$version")
if [ "$arch" == "amd64" ]; then
    paquetes_devuan="$paquetes_devuan,libc6-i386"
fi

# Crear symlinks de debootstrap
case "$version" in
    excalibur)
        if [ ! -f "/usr/share/debootstrap/scripts/excalibur" ]; then
            ln -sf /usr/share/debootstrap/scripts/sid /usr/share/debootstrap/scripts/excalibur
        fi
        ;;
    freia)
        if [ ! -f "/usr/share/debootstrap/scripts/freia" ]; then
            ln -sf /usr/share/debootstrap/scripts/sid /usr/share/debootstrap/scripts/freia
        fi
        ;;
    daedalus)
        if [ ! -f "/usr/share/debootstrap/scripts/daedalus" ]; then
            ln -sf /usr/share/debootstrap/scripts/sid /usr/share/debootstrap/scripts/daedalus
        fi
        ;;
    chimaera)
        if [ ! -f "/usr/share/debootstrap/scripts/chimaera" ]; then
            ln -sf /usr/share/debootstrap/scripts/sid /usr/share/debootstrap/scripts/chimaera
        fi
        ;;
    beowulf|ascii)
        if [ ! -f "/usr/share/debootstrap/scripts/$version" ]; then
            ln -sf /usr/share/debootstrap/scripts/sid /usr/share/debootstrap/scripts/$version
        fi
        ;;
    ceres)
        # ceres → sid
        if [ ! -f "/usr/share/debootstrap/scripts/ceres" ]; then
            ln -sf /usr/share/debootstrap/scripts/sid /usr/share/debootstrap/scripts/ceres
        fi
        ;;
    jessie)
        # jessie ya tiene script en debootstrap
        ;;
esac

# Resumen
echo ""
echo " - - - - - - - - - - - - - - - - - -"
echo -e "Instalando Devuan Chroot (Debian sin systemd)"
echo " - - - - - - - - - - - - - - - - - -"
echo -e "Jaula:        $CHROOT"
echo -e "Versión:      $version"
echo -e "Estado:       ${VERSIONES_ESTADO[$version]}"
echo -e "Arquitectura: $arch"
echo -e "Mirror:       $MIRROR_DEVUAN"
echo -e "GPG:          $VERIFICACION_GPG"
echo -e "Paquetes:     $paquetes_devuan"
echo " - - - - - - - - - - - - - - - - - -"
echo ""

# Verificar o actualizar keyring de Devuan
verificar_keyring_devuan "$version"

# Debootstrap
info "Ejecutando debootstrap..."
local_version_debootstrap="$version"

if debootstrap --arch "$arch" --verbose $FLAG_GPG \
    --include="$paquetes_devuan" "$local_version_debootstrap" "$CHROOT" "$MIRROR_DEVUAN"; then
    exito "debootstrap completado"
else
    advertencia "Mirror principal falló, intentando alternativa..."
    debootstrap --arch "$arch" --verbose $FLAG_GPG \
        --include="$paquetes_devuan" "$local_version_debootstrap" "$CHROOT" "http://deb.devuan.org/devuan" || {
        error_msg "Falló debootstrap en todos los mirrors"
        exit 1
    }
    exito "debootstrap completado (mirror alternativo)"
fi

# Crear mychroot.conf
mkdir -p "$CHROOT/etc"
cat > "$CHROOT/etc/mychroot.conf" << EOFMYCHROOT
# Configuracion inicial de Filesystems para la Jaula $CHROOT
# Devuan usa sysvinit (sin systemd)

# Filesystems a montar:
FS:/proc
FS:/dev
FS:/dev/pts
FS:/sys
FS:/home

# Servicios a iniciar (sysvinit):
Service:/etc/init.d/cron
# Service:/etc/init.d/rsyslog
EOFMYCHROOT
chmod 640 "$CHROOT/etc/mychroot.conf"

# Configurar repositorios
info "Configurando repositorios..."
generar_sources_list "$version" "$CHROOT"
exito "Repositorios configurados"

# Montar filesystems
echo ""
info "Montando filesystems..."
"$(dirname "$0")/mount_umount-chroot.sh" "$NOMBRE_JAULA" mount

# Actualizar
echo ""
info "Actualizando paquetes..."
chroot "$CHROOT" /bin/bash -c "apt-get update && apt-get -y upgrade && apt-get clean all" || \
    advertencia "La actualización tuvo errores. Revise manualmente."

# Generar resumen
generar_resumen

# Resumen final
echo ""
echo " - - - - - - - - - - RESUMEN - - - - - - - - - -"
echo ""
echo -e "${VERDE}Dispositivos montados:${NC}"
mount | grep "$CHROOT" | awk '{print $3}' | sort -r
echo ""
echo "IMPORTANTE!!! Revisa $CHROOT/etc/mychroot.conf"
echo ""
exito "Jaula de Devuan $version creada exitosamente."
echo "   Init system: sysvinit (sin systemd)"
echo ""
conf="
Match User userbob
        ChrootDirectory $CHROOT
        X11Forwarding no
        AllowTcpForwarding no
"
echo "Para SSH chroot, agregar en /etc/ssh/sshd_config:"
echo -e "$conf"
echo "Y reinicie: service sshd restart"
echo " - - - - - - - - - - - - - - - - - - - - - - - -"

exit 0
