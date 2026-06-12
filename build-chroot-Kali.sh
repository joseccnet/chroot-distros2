#!/bin/bash
#
# Build a chroot with a Kali Linux base install.
# Author: josecc@gmail.com
#
# https://www.kali.org/get-kali/#kali-installer-images
# Kali es rolling release - solo kali-rolling está activo actualmente
# --arch amd64, i386, arm64, armhf
#
# Variables de entorno opcionales:
#   SIN_VERIFICACION_GPG=true    : Desactiva verificación GPG (solo pruebas/desarrollo)
#   MIRROR_KALI=<url>            : Usa un mirror personalizado
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
# Versiones soportadas de Kali
# ==============================================================================
VERSIONES_SOPORTADAS=(
    "kali-rolling"  # Rolling release (activa)
    "sana"          # Kali 2.0 (legacy)
)

declare -A VERSIONES_ESTADO=(
    ["kali-rolling"]="rolling (activa)"
    ["sana"]="EOL (Kali 2.0 - 2015)"
)

# ==============================================================================
# Verificación adicional de scripts de debootstrap
# ==============================================================================
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
        ["gpg"]="gnupg"
        ["dpkg"]="dpkg"
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

    exito "Requisitos de sistema validados correctamente."
    echo ""
}

# ==============================================================================
# Importar clave GPG de Kali
# ==============================================================================
importar_clave_kali() {
    local chroot_path="$1"

    if [ -f "$chroot_path/usr/share/keyrings/kali-archive-keyring.gpg" ]; then
        info "Keyring de Kali ya presente"
        return 0
    fi

    info "Descargando llave pública de Kali..."
    local key_urls=(
        "https://archive.kali.org/archive-key.asc"
        "https://http.kali.org/kali/pool/main/k/kali-archive-keyring/kali-archive-keyring_latest_all.deb"
    )
    local key_imported=false

    for url in "${key_urls[@]}"; do
        case "$url" in
            *.asc)
                if wget -qO /tmp/kali-key.asc "$url" 2>/dev/null; then
                    gpg --no-default-keyring --keyring "$chroot_path/usr/share/keyrings/kali-archive-keyring.gpg" \
                        --import /tmp/kali-key.asc 2>/dev/null && { key_imported=true; break; }
                    rm -f /tmp/kali-key.asc
                fi
                ;;
            *.deb)
                if wget -qO /tmp/kali-keyring.deb "$url" 2>/dev/null; then
                    dpkg -x /tmp/kali-keyring.deb /tmp/kali-keyring-extract 2>/dev/null
                    local found_key
                    found_key=$(find /tmp/kali-keyring-extract -name 'kali-archive-keyring.gpg' 2>/dev/null | head -1)
                    if [ -n "$found_key" ]; then
                        mkdir -p "$chroot_path/usr/share/keyrings"
                        cp "$found_key" "$chroot_path/usr/share/keyrings/kali-archive-keyring.gpg"
                        key_imported=true
                    fi
                    rm -rf /tmp/kali-keyring.deb /tmp/kali-keyring-extract
                    $key_imported && break
                fi
                ;;
        esac
    done

    if ! $key_imported; then
        advertencia "No se pudo descargar la llave, intentando vía keyserver..."
        gpg --no-default-keyring --keyring "$chroot_path/usr/share/keyrings/kali-archive-keyring.gpg" \
            --keyserver keyserver.ubuntu.com --recv-keys ED444FF07D8D0BF6 2>/dev/null || \
            advertencia "No se pudo importar clave de Kali. Puede requerir intervención manual."
    fi
}

# ==============================================================================
# Generar resumen
# ==============================================================================
generar_resumen() {
    local archivo="$CHROOT/etc/resumen-construccion.txt"
    cat > "$archivo" << EOF
===============================================================================
Resumen de Construcción del Chroot Kali Linux
===============================================================================
Fecha:              $(date)
Versión:            $version
Estado:             ${VERSIONES_ESTADO[$version]:-desconocido}
Arquitectura:       $arch
Ruta del Chroot:    $CHROOT
Mirror:             $MIRROR_KALI
Verificación GPG:   $VERIFICACION_GPG

Estado: EXITOSO

NOTAS:
- Kali Linux es una distribución para pruebas de penetración y auditoría
- Use responsabilidad y solo en sistemas autorizados
- Revise /etc/mychroot.conf para filesystems y servicios
- Repositorios en /etc/apt/sources.list

FIN DEL RESUMEN
===============================================================================
EOF
    chmod 644 "$archivo"
    info "Resumen guardado en: $archivo"
}

# ==============================================================================
# Ayuda
# ==============================================================================
mostrar_ayuda() {
    echo " - - - - - - - - - - - - - - - - - -"
    echo -e "$0 creará una jaula con Kali Linux"
    echo " - - - - - - - - - - - - - - - - - -"
    echo ""
    echo "Versiones de Kali Linux soportadas:"
    echo ""
    echo "  Activa:"
    echo "   kali-rolling  - Rolling Release (actualizada continuamente)"
    echo ""
    echo "  Legacy (EOL):"
    echo "   sana          - Kali 2.0 (2015)"
    echo ""
    echo "Uso:"
    echo "  $0 NombreJaula [versión [arquitectura]]"
    echo ""
    echo "Ejemplos:"
    echo "  $0 mi-kali kali-rolling"
    echo "  $0 mi-kali kali-rolling amd64"
    echo "  $0 mi-kali kali-rolling arm64"
    echo ""
    echo "Variables de entorno:"
    echo "  SIN_VERIFICACION_GPG=true  : Desactiva GPG (solo pruebas)"
    echo "  MIRROR_KALI=<url>          : Mirror personalizado"
    echo "  FORZAR_EOL=true            : Omite confirmación para versiones EOL"
    echo "  ESPACIO_MINIMO_GB=<n>      : Espacio mínimo en GB (default: 2)"
    echo ""
    exit 1
}

# ==============================================================================
# INICIO DEL SCRIPT PRINCIPAL
# ==============================================================================

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

# Mirror
MIRROR_KALI="${MIRROR_KALI:-http://http.kali.org/kali}"

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

# Default a kali-rolling
if [ -z "$version" ]; then
    version="kali-rolling"
    info "Usando versión por defecto: $version"
fi

# Validar versión
if ! [[ " ${VERSIONES_SOPORTADAS[*]} " =~ " $version " ]]; then
    error_msg "Versión de Kali no soportada: $version"
    echo "   Soportadas: ${VERSIONES_SOPORTADAS[*]}"
    exit 1
fi

verificaciones_previas

# Advertencia EOL para sana
if [ "$version" == "sana" ]; then
    echo ""
    advertencia "Kali $version es una versión EOL (2015)"
    echo "   Sin actualizaciones de seguridad"
    echo ""
    if [ "${FORZAR_EOL:-}" != "true" ]; then
        read -p "¿Continuar? (s/N): " resp
        [[ "$resp" =~ ^[sSyY]$ ]] || { info "Cancelado."; exit 0; }
    fi
fi

# Obtener paquetes
paquetes_kali=$(obtener_paquetes_kali "$version")
if [ "$arch" == "amd64" ]; then
    paquetes_kali="$paquetes_kali,libc6-i386"
fi

# Crear symlinks de debootstrap
for kver in "$version" "kali-current"; do
    if [ ! -f "/usr/share/debootstrap/scripts/$kver" ]; then
        info "Creando symlink de debootstrap para $kver"
        ln -sf /usr/share/debootstrap/scripts/sid "/usr/share/debootstrap/scripts/$kver"
    fi
done

# Resumen
echo ""
echo " - - - - - - - - - - - - - - - - - -"
echo -e "Instalando Kali Linux Chroot"
echo " - - - - - - - - - - - - - - - - - -"
echo -e "Jaula:        $CHROOT"
echo -e "Versión:      $version"
echo -e "Estado:       ${VERSIONES_ESTADO[$version]}"
echo -e "Arquitectura: $arch"
echo -e "Mirror:       $MIRROR_KALI"
echo -e "GPG:          $VERIFICACION_GPG"
echo -e "Paquetes:     $paquetes_kali"
echo " - - - - - - - - - - - - - - - - - -"
echo ""

# Debootstrap con fallback de mirrors
info "Ejecutando debootstrap..."
local_mirrors=("$MIRROR_KALI" "http://http.kali.org/kali" "http://kali.download/kali")

debootstrap_ok=false
for mirror in "${local_mirrors[@]}"; do
    if debootstrap --arch "$arch" --verbose $FLAG_GPG \
        --include="$paquetes_kali" "$version" "$CHROOT" "$mirror"; then
        exito "debootstrap completado exitosamente desde $mirror"
        debootstrap_ok=true
        break
    fi
    advertencia "Mirror $mirror falló, intentando siguiente..."
done

if ! $debootstrap_ok; then
    error_msg "Falló debootstrap en todos los mirrors. Revise los mensajes anteriores."
    exit 1
fi

# Crear mychroot.conf
mkdir -p "$CHROOT/etc"
cat > "$CHROOT/etc/mychroot.conf" << EOFMYCHROOT
# Configuracion inicial de Filesystems para la Jaula $CHROOT

# Filesystems a montar:
FS:/proc
FS:/dev
FS:/dev/pts
FS:/sys
FS:/home

# Servicios a iniciar:
Service:/etc/init.d/cron
# Service:/etc/init.d/rsyslog
EOFMYCHROOT
chmod 640 "$CHROOT/etc/mychroot.conf"

# Configurar repositorios
info "Configurando repositorios..."
if [ "$version" == "kali-rolling" ]; then
    cat > "$CHROOT/etc/apt/sources.list" << EOF
deb [signed-by=/usr/share/keyrings/kali-archive-keyring.gpg] $MIRROR_KALI kali-rolling main contrib non-free non-free-firmware
EOF
else
    cat > "$CHROOT/etc/apt/sources.list" << EOF
deb [signed-by=/usr/share/keyrings/kali-archive-keyring.gpg] $MIRROR_KALI $version main contrib non-free non-free-firmware
deb [signed-by=/usr/share/keyrings/kali-archive-keyring.gpg] http://security.kali.org/kali-security $version/updates main contrib non-free
EOF
fi
exito "Repositorios configurados"

# Importar clave de Kali
importar_clave_kali "$CHROOT"

# Montar filesystems
echo ""
info "Montando filesystems..."
"$(dirname "$0")/mount_umount-chroot.sh" "$NOMBRE_JAULA" mount

# Actualizar y limpiar
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
exito "Jaula de Kali Linux $version creada exitosamente."
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

# Limpieza de symlink temporal (solo si se creó para versión distinta)
if [ -f /usr/share/debootstrap/scripts/kali ] && [ "$version" != "kali" ]; then
    rm -f /usr/share/debootstrap/scripts/kali 2>/dev/null || true
fi

exit 0
