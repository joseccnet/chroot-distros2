#!/bin/bash
#
# Build a chroot with a CentOS Stream base install.
# Author: josecc@gmail.com
#
# CentOS Stream: https://www.centos.org/
# CentOS Stream 10 - Activo (EOL 2030)
# CentOS Stream 9  - Activo (EOL 2027)
#
# Legacy (EOL):
# CentOS Linux 7 - EOL Jun 2024
# CentOS Linux 6 - EOL Nov 2020
# CentOS Linux 5 - EOL Mar 2017
#
# Usa yum para construir el chroot.
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
        if [[ "$version_actual" == "stream"* ]]; then
            error_msg "Hash SHA256 NO definido en chroot.conf para la versión moderna: $version_actual"
            echo "   Por seguridad (Grado Industrial), las versiones Stream DEBEN ser verificadas."
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
# Limpieza ante errores
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
# Versiones soportadas
# ==============================================================================
VERSIONES_SOPORTADAS=(
    "stream10" "stream9"  # CentOS Stream activas
    "7" "6" "5"           # CentOS Linux legacy (EOL)
)

declare -A VERSIONES_ESTADO=(
    ["stream10"]="Activo (EOL 2030)"
    ["stream9"]="Activo (EOL Mayo 2027)"
    ["7"]="EOL (Jun 2024)"
    ["6"]="EOL (Nov 2020)"
    ["5"]="EOL (Mar 2017)"
)

declare -A VERSIONES_EOL=(
    ["7"]="Junio 2024"
    ["6"]="Noviembre 2020"
    ["5"]="Marzo 2017"
)

# ==============================================================================
# Verificaciones previas
# ==============================================================================
verificaciones_previas() {
    info "Iniciando verificaciones de sistema..."

    declare -A DEPENDENCIAS_BUILD=(
        ["yum"]="yum"
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
# Generar resumen
# ==============================================================================
generar_resumen() {
    local archivo="$CHROOT/etc/resumen-construccion.txt"
    cat > "$archivo" << EOF
================================================================================
Resumen de Construcción del Chroot CentOS
================================================================================
Fecha:              $(date)
Versión:            $version
Estado:             ${VERSIONES_ESTADO[$version]:-desconocido}
Arquitectura:       $arch
Ruta del Chroot:    $CHROOT

Estado: EXITOSO

NOTAS:
- CentOS usa yum/dnf para gestión de paquetes
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
    echo -e "$0 creará una jaula con CentOS"
    echo " - - - - - - - - - - - - - - - - - -"
    echo ""
    echo "Versiones soportadas:"
    echo ""
    echo "  CentOS Stream (Activas):"
    echo "   stream10  - CentOS Stream 10 (EOL 2030)"
    echo "   stream9   - CentOS Stream 9 (EOL Mayo 2027)"
    echo ""
    echo "  CentOS Linux (EOL - Legacy):"
    echo "   7         - CentOS 7 (EOL Jun 2024)"
    echo "   6         - CentOS 6 (EOL Nov 2020)"
    echo "   5         - CentOS 5 (EOL Mar 2017)"
    echo ""
    echo "Uso:"
    echo "  $0 NombreJaula [versión [arquitectura]]"
    echo ""
    echo "Ejemplos:"
    echo "  $0 mi-centos stream9"
    echo "  $0 mi-centos stream10 x86_64"
    echo "  $0 mi-centos 7"
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

if [ -z "$version" ]; then
    version="stream9"
    info "Versión por defecto: $version"
fi

if ! [[ " ${VERSIONES_SOPORTADAS[*]} " =~ " $version " ]]; then
    error_msg "Versión no soportada: $version"
    echo "   Soportadas: ${VERSIONES_SOPORTADAS[*]}"
    exit 1
fi

verificaciones_previas

# Advertencia EOL
if [[ -n "${VERSIONES_EOL[$version]+x}" ]]; then
    advertencia "CentOS $version es EOL desde ${VERSIONES_EOL[$version]}"
    echo "   Sin actualizaciones de seguridad"
    if [ "${FORZAR_EOL:-}" != "true" ]; then
        read -p "¿Continuar? (s/N): " r
        [[ "$r" =~ ^[sSyY]$ ]] || { info "Cancelado."; exit 0; }
    fi
fi

# Determinar URLs y Hashes
case "$version" in
    stream10)
        rpm1="$cs10rpm1"; rpm2="$cs10rpm2"
        sha256_rpm1="${sha256_cs10rpm1:-}"; sha256_rpm2="${sha256_cs10rpm2:-}"
        ;;
    stream9)
        if [ "$arch" == "aarch64" ]; then
            rpm1="$cs9rpm1_aarch64"; rpm2="$cs9rpm2_aarch64"
            sha256_rpm1="${sha256_cs9rpm1_aarch64:-}"; sha256_rpm2="${sha256_cs9rpm2_aarch64:-}"
        else
            rpm1="$cs9rpm1"; rpm2="$cs9rpm2"
            sha256_rpm1="${sha256_cs9rpm1:-}"; sha256_rpm2="${sha256_cs9rpm2:-}"
        fi
        ;;
    7)
        rpm1="$c7rpm1"; rpm2="$c7rpm2"
        sha256_rpm1="${sha256_c7rpm1:-}"; sha256_rpm2="${sha256_c7rpm2:-}"
        ;;
    6)
        if [ "$arch" == "i386" ]; then
            rpm1="$c6rpm1_i386"
            sha256_rpm1="${sha256_c6rpm1_i386:-}"
        else
            rpm1="$c6rpm1"
        fi
        ;;
    5)
        if [ "$arch" == "i386" ]; then
            rpm1="$c5rpm1_i386"
            rpm2="$c5rpm2_i386"
        else
            rpm1="$c5rpm1"
            rpm2="$c5rpm2"
        fi
        ;;
esac

# Resumen
echo ""
echo " - - - - - - - - - - - - - - - - - -"
echo -e "Instalando CentOS Chroot"
echo -e " - - - - - - - - - - - - - - - - - -"
echo -e "Jaula:        $CHROOT"
echo -e "Versión:      $version"
echo -e "Estado:       ${VERSIONES_ESTADO[$version]}"
echo -e "Arquitectura: $arch"
echo " - - - - - - - - - - - - - - - - - -"
echo ""

# ==============================================================================
# Paso 1: Preparar RPM database
# ==============================================================================
info "Preparando base de datos RPM..."
mkdir -p "$CHROOT/var/lib/rpm"
rpm --rebuilddb --root="$CHROOT" 2>/dev/null || true

# ==============================================================================
# Paso 2: Descargar centos-release RPM
# ==============================================================================
info "Descargando paquetes centos-release..."
rm -f ./centos-release-*.rpm 2>/dev/null || true

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

# Instalar RPM en chroot
mkdir -p "$CHROOT/tmp"
cp centos-release-*.rpm "$CHROOT/tmp/" 2>/dev/null || true
rpm -ivh --root="$CHROOT" --nodeps "$CHROOT/tmp/centos-release-"*.rpm 2>/dev/null || {
    error_msg "Falló instalación de centos-release RPM"
    exit 1
}

# ==============================================================================
# Paso 3: Configurar yum
# ==============================================================================
info "Configurando yum para el chroot..."

# Copiar configuración de yum
cp "$(dirname "$0")/centos/yumcentos.conf" "$CHROOT/tmp/yumcentos.conf" 2>/dev/null || {
    # Crear configuración mínima si no existe
    cat > "$CHROOT/tmp/yumcentos.conf" << 'EOF'
[main]
cachedir=/var/cache/yum
debuglevel=2
logfile=/var/log/yum.log
exactarch=1
obsoletes=1
gpgcheck=0
plugins=0
installonly_limit=3

[basecentoschroot]
name=CentOS Chroot Base
baseurl=http://mirror.centos.org/centos/$releasever/os/$basearch/
enabled=1
gpgcheck=0

[updatescentoschroot]
name=CentOS Chroot Updates
baseurl=http://mirror.centos.org/centos/$releasever/updates/$basearch/
enabled=1
gpgcheck=0
EOF
}

if [ "$arch" == "i386" ]; then
    sed -i 's/\$basearch/i386/g' "$CHROOT/tmp/yumcentos.conf" 2>/dev/null || true
fi

# Configuración especial para CentOS 5
if [ "$version" == "5" ] || [ "$version" == "5-i386" ]; then
    rm -f "$CHROOT/etc/yum.repos.d/"*.repo 2>/dev/null || true
    cp -f "$(dirname "$0")/centos/"*.repo "$CHROOT/etc/yum.repos.d/" 2>/dev/null || true
    echo "" > "$CHROOT/etc/yum/pluginconf.d/fastestmirror.conf" 2>/dev/null || true

    yum --nogpgcheck -c "$CHROOT/tmp/yumcentos.conf" \
        --disablerepo=* --enablerepo=C5.11-base \
        --installroot="$CHROOT" install -y yum yum-utils || {
        error_msg "Falló instalación de yum en chroot"
        exit 1
    }
else
    yum --nogpgcheck -c "$CHROOT/tmp/yumcentos.conf" \
        --disablerepo=* --enablerepo=basecentoschroot --enablerepo=updatescentoschroot \
        --installroot="$CHROOT" install -y yum yum-utils || {
        error_msg "Falló instalación de yum en chroot"
        exit 1
    }
fi

exito "yum configurado en el chroot"

# ==============================================================================
# Paso 4: Crear mychroot.conf
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
# Paso 5: Montar y configurar
# ==============================================================================
echo ""
info "Montando filesystems..."
"$(dirname "$0")/mount_umount-chroot.sh" "$NOMBRE_JAULA" mount

# Reinstalar centos-release dentro del chroot
chroot "$CHROOT" rpm -ivh --nodeps /tmp/centos-release-*.rpm 2>/dev/null || true

# Configurar repos para CentOS 5
if [ "$version" == "5" ] || [ "$version" == "5-i386" ]; then
    rm -f "$CHROOT/etc/yum.repos.d/"*.repo 2>/dev/null || true
    cp -f "$(dirname "$0")/centos/"*.repo "$CHROOT/etc/yum.repos.d/" 2>/dev/null || true
fi

# Ajustar arquitectura en repos
if [ "$arch" == "i386" ]; then
    sed -i 's/\$basearch/i386/g' "$CHROOT/etc/yum.repos.d/"*.repo 2>/dev/null || true
fi

# ==============================================================================
# Paso 6: Instalar paquetes
# ==============================================================================
echo ""
info "Instalando paquetes adicionales..."
chroot "$CHROOT" yum -y install $paquetesAdicionales || \
    advertencia "Algunos paquetes fallaron, continuando..."

# ==============================================================================
# Paso 7: Actualizar
# ==============================================================================
echo ""
info "Actualizando sistema..."
chroot "$CHROOT" yum -y update || advertencia "La actualización tuvo errores"
chroot "$CHROOT" yum clean all

# Limpieza yum host
yum --nogpgcheck -c "$CHROOT/tmp/yumcentos.conf" \
    --disablerepo=* --enablerepo=basecentoschroot --enablerepo=updatescentoschroot \
    --installroot="$CHROOT" clean all 2>/dev/null || true

# Workaround para CentOS 5
if [ "$version" == "5" ] || [ "$version" == "5-i386" ]; then
    info "Aplicando workaround para CentOS 5..."
    cp centos-release-*.rpm "$CHROOT/tmp/" 2>/dev/null || true
    chroot "$CHROOT" rm -rf /var/lib/rpm/*
    chroot "$CHROOT" rpm --rebuilddb
    chroot "$CHROOT" rpm -i --nodeps /tmp/centos-release-* 2>/dev/null || true
fi

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
exito "Jaula de CentOS $version creada exitosamente."
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

rm -f ./centos-release-*.rpm 2>/dev/null || true

exit 0
