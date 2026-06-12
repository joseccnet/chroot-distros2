#!/bin/bash
#
# Build a chroot with a Fedora base install.
# Author: josecc@gmail.com
#
# https://fedoraproject.org/
# Fedora 43 - Latest (Oct 2025)
# Fedora 42 - Activo (Abr 2025, EOL ~May 2026)
# Fedora 41 - EOL (Nov 2025)
#
# Usa yum/dnf para construir el chroot.
# --arch x86_64, aarch64, i386 (legacy)

set -euo pipefail

source "$(dirname "$0")/chroot.conf"
source "$(dirname "$0")/lib/chroot-lib.sh"

# ==============================================================================
# Verificación de Integridad (SHA256)
# ==============================================================================
verificar_hash() {
    local archivo="$1"
    local hash_esperado="$2"
    local version_actual="${version:-}"
    
    if [ -z "$hash_esperado" ]; then
        if [[ "$version_actual" =~ ^(42|43|44)$ ]]; then
            error_msg "Hash SHA256 NO definido en chroot.conf para la versión moderna: $version_actual"
            echo "   Por seguridad (Grado Industrial), las versiones modernas DEBEN ser verificadas."
            exit 1
        else
            advertencia "Saltando verificación de hash para $archivo (no definido en chroot.conf)"
            return 0
        fi
    fi
    
    info "Verificando SHA256 para $archivo..."
    echo "$hash_esperado  $archivo" | sha256sum -c - >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        exito "Hash verificado correctamente."
    else
        error_msg "Falla de integridad: El hash de $archivo no coincide con el esperado."
        exit 1
    fi
}

# ==============================================================================
# Limpieza
# ==============================================================================
limpieza() {
    local codigo_salida=$?
    if [ $codigo_salida -ne 0 ] && [ -n "${CHROOT:-}" ] && [ -d "${CHROOT:-}" ]; then
        error_msg "Construcción falló (código: $codigo_salida)"
        echo "   Chroot parcial: $CHROOT"
        echo "   Limpiar: rm -rf $CHROOT"
    fi
    exit $codigo_salida
}
trap limpieza EXIT

# ==============================================================================
# Versiones
# ==============================================================================
VERSIONES_SOPORTADAS=(
    "44" "43" "42" "41"  # Fedora modernas
    "40" "39"           # EOL recientes
    "26" "25" "24" "23" "22" "21" "20" "19"  # Legacy
)

declare -A VERSIONES_ESTADO=(
    ["44"]="Activo (Latest Stable, EOL ~May 2027)"
    ["43"]="Activo (EOL ~May 2026)"
    ["42"]="EOL (Mayo 2026)"
    ["41"]="EOL (Nov 2025)"
    ["40"]="EOL"
    ["39"]="EOL"
    ["26"]="EOL"
    ["25"]="EOL"
    ["24"]="EOL"
    ["23"]="EOL"
    ["22"]="EOL"
    ["21"]="EOL"
    ["20"]="EOL"
    ["19"]="EOL"
)

declare -A VERSIONES_EOL=(
    ["41"]="Noviembre 2025"
    ["40"]="Mayo 2025"
    ["39"]="Noviembre 2024"
    ["26"]="Diciembre 2018"
    ["25"]="Noviembre 2017"
    ["24"]="Agosto 2017"
    ["23"]="Diciembre 2016"
    ["22"]="Julio 2016"
    ["21"]="Enero 2016"
    ["20"]="Junio 2015"
    ["19"]="Enero 2015"
)

# ==============================================================================
# Verificaciones
# ==============================================================================
verificaciones_previas() {
    info "Iniciando verificaciones de sistema..."

    declare -A DEPENDENCIAS_BUILD=(
        ["yum"]="yum (o dnf-yum)"
        ["rpm"]="rpm"
        ["wget"]="wget"
        ["sha256sum"]="coreutils"
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

    verificar_root

    verificar_espacio_disco "$ROOTJAIL" 2

    case "$arch" in
        x86_64|aarch64|i386|i686) ;;
        *)
            error_msg "Arquitectura no soportada: $arch"
            echo "   Soportadas: x86_64, aarch64, i386"
            exit 1
            ;;
    esac

    exito "Requisitos de sistema validados correctamente."
    echo ""
}

# ==============================================================================
# Resumen
# ==============================================================================
generar_resumen() {
    local archivo="$CHROOT/etc/resumen-construccion.txt"
    cat > "$archivo" << EOF
================================================================================
Resumen de Construcción del Chroot Fedora
================================================================================
Fecha:              $(date)
Versión:            Fedora $version
Estado:             ${VERSIONES_ESTADO[$version]:-desconocido}
Arquitectura:       $arch
Ruta del Chroot:    $CHROOT

Estado: EXITOSO

NOTAS:
- Fedora usa dnf/yum para gestión de paquetes
- Revise /etc/mychroot.conf para filesystems y servicios
- Configuración de repos en /etc/yum.repos.d/

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
    echo -e "$0 creará una jaula con Fedora"
    echo " - - - - - - - - - - - - - - - - - -"
    echo ""
    echo "Versiones soportadas:"
    echo ""
    echo "  Activas:"
    echo "   43  - Fedora 43 (Latest, Oct 2025)"
    echo "   42  - Fedora 42 (EOL ~May 2026)"
    echo ""
    echo "  EOL:"
    echo "   41  - EOL Nov 2025"
    echo "   40  - EOL Mayo 2025"
    echo "   39  - EOL Nov 2024"
    echo "   26-19 - Legacy EOL"
    echo ""
    echo "Uso:"
    echo "  $0 NombreJaula [versión [arquitectura]]"
    echo ""
    echo "Ejemplos:"
    echo "  $0 mi-fedora 43"
    echo "  $0 mi-fedora 42 x86_64"
    echo "  $0 mi-fedora 41 aarch64"
    echo ""
    exit 1
}

# ==============================================================================
# INICIO
# ==============================================================================

if [ "${1:-}" == "" ] || [ "${1:-}" == "--help" ] || [ "${1:-}" == "-h" ]; then
    mostrar_ayuda
fi

if [ ! -d "$ROOTJAIL" ]; then
    mkdir -vp "$ROOTJAIL"
    chmod 755 "$ROOTJAIL"
fi

NOMBRE_JAULA="${1:-}"
CHROOT="$ROOTJAIL/$NOMBRE_JAULA"
version="${2:-}"
arch="${3:-x86_64}"
excludearch="*.i*86"

if [ "$arch" == "i386" ] || [ "$arch" == "i686" ]; then
    excludearch="*.x86_64"
fi

if [ -z "$version" ]; then
    version="44"
    info "Versión por defecto: $version (Fedora 44 - Latest)"
fi

if ! [[ " ${VERSIONES_SOPORTADAS[*]} " =~ " $version " ]]; then
    error_msg "Versión no soportada: $version"
    echo "   Soportadas: ${VERSIONES_SOPORTADAS[*]}"
    exit 1
fi

verificaciones_previas

# Advertencia EOL
if [[ -n "${VERSIONES_EOL[$version]+x}" ]]; then
    advertencia "Fedora $version es EOL desde ${VERSIONES_EOL[$version]}"
    if [ "${FORZAR_EOL:-}" != "true" ]; then
        read -p "¿Continuar? (s/N): " r
        [[ "$r" =~ ^[sSyY]$ ]] || { info "Cancelado."; exit 0; }
    fi
fi

# Determinar URLs y Hashes
case "$version" in
    44)
        if [ "$arch" == "aarch64" ]; then
            rpm1="$f44rpm1_aarch64"; rpm2="$f44rpm2_aarch64"
            sha256_rpm1="${sha256_f44rpm1_aarch64:-}"; sha256_rpm2="${sha256_f44rpm2_aarch64:-}"
        else
            rpm1="$f44rpm1"; rpm2="$f44rpm2"
            sha256_rpm1="${sha256_f44rpm1:-}"; sha256_rpm2="${sha256_f44rpm2:-}"
        fi
        ;;
    43)
        if [ "$arch" == "aarch64" ]; then
            rpm1="$f43rpm1_aarch64"; rpm2="$f43rpm2_aarch64"
            sha256_rpm1="${sha256_f43rpm1_aarch64:-}"; sha256_rpm2="${sha256_f43rpm2_aarch64:-}"
        else
            rpm1="$f43rpm1"; rpm2="$f43rpm2"
            sha256_rpm1="${sha256_f43rpm1:-}"; sha256_rpm2="${sha256_f43rpm2:-}"
        fi
        ;;
    42)
        if [ "$arch" == "aarch64" ]; then
            rpm1="$f42rpm1_aarch64"; rpm2="$f42rpm2_aarch64"
            sha256_rpm1="${sha256_f42rpm1_aarch64:-}"; sha256_rpm2="${sha256_f42rpm2_aarch64:-}"
        else
            rpm1="$f42rpm1"; rpm2="$f42rpm2"
            sha256_rpm1="${sha256_f42rpm1:-}"; sha256_rpm2="${sha256_f42rpm2:-}"
        fi
        ;;
    41)
        rpm1="$f41rpm1"; rpm2="$f41rpm2"
        sha256_rpm1="${sha256_f41rpm1:-}"; sha256_rpm2="${sha256_f41rpm1:-}"
        ;;
esac

# Resumen
echo ""
echo " - - - - - - - - - - - - - - - - - -"
echo -e "Instalando Fedora Chroot"
echo -e " - - - - - - - - - - - - - - - - - -"
echo -e "Jaula:        $CHROOT"
echo -e "Versión:      Fedora $version"
echo -e "Estado:       ${VERSIONES_ESTADO[$version]}"
echo -e "Arquitectura: $arch"
echo " - - - - - - - - - - - - - - - - - -"
echo ""

# ==============================================================================
# Paso 1: Preparar RPM DB
# ==============================================================================
info "Preparando base de datos RPM..."
mkdir -p "$CHROOT/var/lib/rpm"
rpm --rebuilddb --root="$CHROOT" 2>/dev/null || true

# ==============================================================================
# Paso 2: Descargar fedora-release RPMs
# ==============================================================================
info "Descargando paquetes fedora-release..."
rm -f ./fedora-re*.rpm 2>/dev/null || true

if [ -n "${rpm1:-}" ]; then
    wget -c "$rpm1" || {
        error_msg "Falló descarga de $rpm1"
        exit 1
    }
    local_rpm1=$(basename "$rpm1")
    verificar_hash "$local_rpm1" "${sha256_rpm1:-}"
fi
if [ -n "${rpm2:-}" ]; then
    wget -c "$rpm2" || advertencia "Falló descarga de $rpm2"
    local_rpm2=$(basename "$rpm2")
    verificar_hash "$local_rpm2" "${sha256_rpm2:-}"
fi

# Instalar en chroot
mkdir -p "$CHROOT/tmp"
cp fedora-re*.rpm "$CHROOT/tmp/" 2>/dev/null || true
rpm -ivh --root="$CHROOT" --nodeps "$CHROOT/tmp/fedora-re"*.rpm 2>/dev/null || {
    error_msg "Falló instalación de fedora-release RPM"
    exit 1
}

# ==============================================================================
# Paso 3: Configurar yum
# ==============================================================================
info "Configurando yum para el chroot..."

# Copiar configuraciones
mkdir -p "$CHROOT/tmp"
cp "$(dirname "$0")/fedora/yumfedorax86_64.conf" "$CHROOT/tmp/yumfedorax86_64.conf" 2>/dev/null || true
cp "$(dirname "$0")/fedora/yumfedorai386.conf" "$CHROOT/tmp/yumfedorai386.conf" 2>/dev/null || true

if [ "$arch" == "i386" ]; then
    yumfedoraconf="$CHROOT/tmp/yumfedorai386.conf"
else
    yumfedoraconf="$CHROOT/tmp/yumfedorax86_64.conf"
fi

# Instalar yum en chroot
yum --nogpgcheck -c "$yumfedoraconf" \
    --exclude="$excludearch" \
    --disablerepo=* --enablerepo=fedorachroot --enablerepo=updatesfedorachroot \
    --installroot="$CHROOT" install -y yum || {
    error_msg "Falló instalación de yum en chroot"
    exit 1
}

exito "yum configurado"

# ==============================================================================
# Paso 4: mychroot.conf
# ==============================================================================
mkdir -p "$CHROOT/etc"
cat > "$CHROOT/etc/mychroot.conf" << EOFMYCHROOT
# Configuracion de Filesystems para la Jaula $CHROOT

# Filesystems a montar:
FS:/proc
FS:/dev
FS:/dev/pts
FS:/sys
FS:/home

# Servicios a iniciar:
Service:/etc/init.d/crond
# Service:/etc/init.d/rsyslog
EOFMYCHROOT
chmod 640 "$CHROOT/etc/mychroot.conf"

# ==============================================================================
# Paso 5: Montar
# ==============================================================================
echo ""
info "Montando filesystems..."
"$(dirname "$0")/mount_umount-chroot.sh" "$NOMBRE_JAULA" mount

# Ajustar arquitectura i386
if [[ "$version" =~ ^(43|42|41|40|39|26|25|24|23|22|21|20|19)-i386$ ]] || [ "$arch" == "i386" ]; then
    sed -i 's/\$basearch/i386/g' "$CHROOT/etc/yum.repos.d/"*.repo 2>/dev/null || true
fi

# ==============================================================================
# Paso 6: Instalar fedora-release con dnf (Fedora 22+)
# ==============================================================================
if [ "$version" -ge 22 ] 2>/dev/null; then
    info "Instalando fedora-repos con dnf..."
    chroot "$CHROOT" /usr/bin/dnf -y --releasever="$version" install fedora-repos fedora-release 2>/dev/null || \
        advertencia "Falló instalación de fedora-repos con dnf"
fi

# ==============================================================================
# Paso 7: Instalar paquetes y actualizar
# ==============================================================================
echo ""
info "Instalando paquetes..."
chroot "$CHROOT" rpm -ivh /tmp/fedora-re*.rpm 2>/dev/null || true
chroot "$CHROOT" yum -y install $paquetesAdicionales fedora-release fedora-repos || \
    advertencia "Algunos paquetes fallaron"

echo ""
info "Actualizando sistema..."
chroot "$CHROOT" yum -y update || advertencia "La actualización tuvo errores"
chroot "$CHROOT" yum clean all

# Limpieza yum host
yum --nogpgcheck -c "$yumfedoraconf" \
    --exclude="$excludearch" \
    --disablerepo=* --enablerepo=fedorachroot --enablerepo=updatesfedorachroot \
    --installroot="$CHROOT" clean all 2>/dev/null || true

# ==============================================================================
# Paso 8: Re-montar
# ==============================================================================
echo ""
info "Re-montando jaula..."
"$(dirname "$0")/mount_umount-chroot.sh" "$NOMBRE_JAULA" umount 2>/dev/null || true
"$(dirname "$0")/mount_umount-chroot.sh" "$NOMBRE_JAULA" mount

# ==============================================================================
# Resumen
# ==============================================================================
generar_resumen

echo ""
echo " - - - - - - - - - - RESUMEN - - - - - - - - - -"
echo ""
echo -e "${VERDE}Dispositivos montados:${NC}"
mount | grep "$CHROOT" | awk '{print $3}' | sort -r
echo ""
echo "IMPORTANTE!!! Revisa $CHROOT/etc/mychroot.conf"
echo ""
exito "Jaula de Fedora $version creada exitosamente."
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

rm -f ./fedora-re*.rpm 2>/dev/null || true

exit 0
