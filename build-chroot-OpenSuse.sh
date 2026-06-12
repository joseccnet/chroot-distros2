#!/bin/bash
#
# Build a chroot with a openSUSE base install.
# Author: josecc@gmail.com
#
# https://www.opensuse.org/
# openSUSE Leap 16.0 - Activo (Oct 2025, EOL Oct 2027)
# openSUSE Leap 15.6 - Activo (Jun 2024, EOL Abr 2026)
# openSUSE Tumbleweed - Rolling
#
# Legacy: Leap 15.x, 42.x, 13.x, 12.x, 11.x (todos EOL)
#
# Usa yum para construir el chroot, zypper dentro.
# --arch x86_64, i586 (legacy), aarch64

set -euo pipefail

source "$(dirname "$0")/chroot.conf"
source "$(dirname "$0")/lib/chroot-lib.sh"

# ==============================================================================
# Verificación de Integridad (SHA256)
# ==============================================================================
verificar_hash() {
    local archivo="$1"
    local hash_esperado="$2"
    
    if [ -z "$hash_esperado" ]; then
        advertencia "Saltando verificación de hash para $archivo (no definido en chroot.conf)"
        return 0
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
    # Actuales
    "16.1"     # Leap 16.1 Beta (en desarrollo, ~Oct 2026)
    "16.0"     # Leap 16.0 (Oct 2025, EOL Oct 2027)
    "15.6"     # Leap 15.6 (Jun 2024, EOL Abr 2026)
    "tumbleweed"  # Rolling
    # Legacy EOL
    "15.5" "15.4" "15.3" "15.2" "15.1" "15.0"
    "42.3" "42.2" "42.1"
    "13.2" "13.1"
    "12.3" "12.2" "12.1"
    "11.4"
)

declare -A VERSIONES_ESTADO=(
    ["16.1"]="Activo (Leap 16.1, ~Oct 2026)"
    ["16.0"]="Activo (EOL Oct 2027)"
    ["15.6"]="Activo (EOL Abr 2026)"
    ["tumbleweed"]="Rolling (siempre actualizado)"
    ["15.5"]="EOL"
    ["15.4"]="EOL"
    ["15.3"]="EOL"
    ["15.2"]="EOL"
    ["15.1"]="EOL"
    ["15.0"]="EOL"
    ["42.3"]="EOL"
    ["42.2"]="EOL"
    ["42.1"]="EOL"
    ["13.2"]="EOL"
    ["13.1"]="EOL"
    ["12.3"]="EOL"
    ["12.2"]="EOL"
    ["12.1"]="EOL"
    ["11.4"]="EOL"
)

declare -A VERSIONES_EOL=(
    ["15.5"]="Nov 2024"
    ["15.4"]="May 2024"
    ["15.3"]="Dic 2023"
    ["15.2"]="Jul 2022"
    ["15.1"]="Ene 2022"
    ["15.0"]="Jul 2021"
    ["42.3"]="Jul 2019"
    ["42.2"]="Ene 2018"
    ["42.1"]="May 2017"
    ["13.2"]="Jul 2017"
    ["13.1"]="Ene 2016"
    ["12.3"]="Ene 2015"
    ["12.2"]="Mar 2014"
    ["12.1"]="May 2013"
    ["11.4"]="Jul 2012"
)

# ==============================================================================
# Auditoría Profesional de Dependencias
# ==============================================================================
# ==============================================================================
# Verificaciones
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
        x86_64|i586|i686|aarch64) ;;
        *)
            error_msg "Arquitectura no soportada: $arch"
            echo "   Soportadas: x86_64, i586, aarch64"
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
Resumen de Construcción del Chroot openSUSE
================================================================================
Fecha:              $(date)
Versión:            openSUSE Leap $version
Estado:             ${VERSIONES_ESTADO[$version]:-desconocido}
Arquitectura:       $arch
Ruta del Chroot:    $CHROOT

Estado: EXITOSO

NOTAS:
- openSUSE usa zypper para gestión de paquetes
- Init system: systemd
- Revise /etc/mychroot.conf para filesystems y servicios
- Configuración de repos en /etc/zypp/repos.d/

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
    echo -e "$0 creará una jaula con openSUSE"
    echo " - - - - - - - - - - - - - - - - - -"
    echo ""
    echo "Versiones soportadas:"
    echo ""
    echo "  Activas:"
    echo "   16.1       - Leap 16.1 (~Oct 2026)"
    echo "   16.0       - Leap 16.0 (EOL Oct 2027)"
    echo "   15.6       - Leap 15.6 (EOL Abr 2026)"
    echo "   tumbleweed - Rolling (siempre actualizado)"
    echo ""
    echo "  Legacy (EOL):"
    echo "   15.5-15.0  - Leap 15.x (todos EOL)"
    echo "   42.x       - Leap 42.x (todos EOL)"
    echo "   13.x       - openSUSE 13.x (todos EOL)"
    echo "   12.x       - openSUSE 12.x (todos EOL)"
    echo "   11.4       - openSUSE 11.4 (EOL)"
    echo ""
    echo "Uso:"
    echo "  $0 NombreJaula [versión [arquitectura]]"
    echo ""
    echo "Ejemplos:"
    echo "  $0 mi-suse 16.0"
    echo "  $0 mi-suse 15.6 x86_64"
    echo "  $0 mi-suse tumbleweed"
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

excludearch="*.i586"
if [ "$arch" == "i586" ] || [ "$arch" == "i686" ]; then
    excludearch="*.x86_64"
fi

if [ -z "$version" ]; then
    version="16.0"
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
    advertencia "openSUSE $version es EOL desde ${VERSIONES_EOL[$version]}"
    if [ "${FORZAR_EOL:-}" != "true" ]; then
        read -p "¿Continuar? (s/N): " r
        [[ "$r" =~ ^[sSyY]$ ]] || { info "Cancelado."; exit 0; }
    fi
fi

# Advertencia kernel para versiones antiguas
if [ "$version" == "13.2" ]; then
    advertencia "openSUSE 13.2 puede no funcionar con kernels antiguos (kernel too old)"
fi

# Resumen
echo ""
echo " - - - - - - - - - - - - - - - - - -"
echo -e "Instalando openSUSE Chroot"
echo -e " - - - - - - - - - - - - - - - - - -"
echo -e "Jaula:        $CHROOT"
echo -e "Versión:      openSUSE Leap $version"
echo -e "Estado:       ${VERSIONES_ESTADO[$version]}"
echo -e "Arquitectura: $arch"
echo " - - - - - - - - - - - - - - - - - -"
echo ""

# ==============================================================================
# Paso 1: Configurar yum para openSUSE
# ==============================================================================
info "Configurando yum para openSUSE..."
mkdir -p "$CHROOT/tmp"

# Copiar y configurar yumsuse.conf
cp "$(dirname "$0")/openSuse/yumsuse.conf" "$CHROOT/tmp/yumsuse.conf" 2>/dev/null || {
    # Crear configuración mínima si no existe
    cat > "$CHROOT/tmp/yumsuse.conf" << 'EOF'
[main]
cachedir=/var/cache/yum
debuglevel=2
logfile=/var/log/yum.log
exactarch=1
obsoletes=1
gpgcheck=0
plugins=0

[basesuse]
name=openSUSE Chroot Base
baseurl=http://download.opensuse.org/distribution/leap/version/repo/oss/
enabled=1
gpgcheck=0

[repo-update]
name=openSUSE Chroot Updates
baseurl=http://download.opensuse.org/update/leap/version/oss/
enabled=1
gpgcheck=0
EOF
}

sed -i "s/versionopensuse/$version/g" "$CHROOT/tmp/yumsuse.conf"
sed -i 's|http://download.opensuse.org/update|http://mirrors.kernel.org/opensuse/update|g' "$CHROOT/tmp/yumsuse.conf" 2>/dev/null || true

# ==============================================================================
# Paso 2: Montar inicialmente
# ==============================================================================
mkdir -p "$CHROOT/etc"
touch "$CHROOT/etc/mychroot.conf"
"$(dirname "$0")/mount_umount-chroot.sh" "$NOMBRE_JAULA" mount 2>/dev/null || true

# ==============================================================================
# Paso 3: Instalar paquetes base con yum
# ==============================================================================
info "Instalando sistema base openSUSE..."

if [ "$version" == "11.4" ] || [ "$version" == "12.3" ] || [ "$version" == "12.2" ] || [ "$version" == "12.1" ]; then
    # Versiones antiguas sin repo-update
    yum -c "$CHROOT/tmp/yumsuse.conf" \
        --disablerepo=* --enablerepo=basesuse \
        --installroot="$CHROOT" --exclude="$excludearch" \
        -y install openSUSE-release zypper iputils openssh cronie rsyslog vim || {
        error_msg "Falló instalación de paquetes base"
        exit 1
    }
    # Reconstruir RPM DB (necesario para versiones antiguas)
    chroot "$CHROOT" rm -rf /var/lib/rpm/*
    chroot "$CHROOT" rpm --rebuilddb
else
    # Versiones modernas
    yum -c "$CHROOT/tmp/yumsuse.conf" \
        --disablerepo=* --enablerepo=basesuse --enablerepo=repo-update \
        --installroot="$CHROOT" --exclude="$excludearch" --exclude="systemd-mini*" \
        -y install openSUSE-release zypper yast2-firstboot iputils openssh cronie rsyslog vim || {
        error_msg "Falló instalación de paquetes base"
        exit 1
    }
fi

exito "Sistema base instalado"

# ==============================================================================
# Paso 4: Configurar repos zypper
# ==============================================================================
info "Configurando repos de zypper..."
cp "$(dirname "$0")/openSuse/"*.repo "$CHROOT/etc/zypp/repos.d/" 2>/dev/null || {
    # Crear repos mínimos si no existen
    mkdir -p "$CHROOT/etc/zypp/repos.d"
    cat > "$CHROOT/etc/zypp/repos.d/repo-oss.repo" << EOF
[repo-oss]
name=openSUSE Leap-$version-OSS
baseurl=http://download.opensuse.org/distribution/leap/$version/repo/oss/
enabled=1
autorefresh=1
type=rpm-md
gpgcheck=0
EOF
    cat > "$CHROOT/etc/zypp/repos.d/repo-update.repo" << EOF
[repo-update]
name=openSUSE Leap-$version-Update
baseurl=http://download.opensuse.org/update/leap/$version/oss/
enabled=1
autorefresh=1
type=rpm-md
gpgcheck=0
EOF
}

sed -i "s/versionopensuse/$version/g" "$CHROOT/etc/zypp/repos.d/"*.repo 2>/dev/null || true
sed -i 's|http://download.opensuse.org/distribution|http://mirrors.kernel.org/opensuse/distribution|g' "$CHROOT/etc/zypp/repos.d/"*.repo 2>/dev/null || true

# DNS básico
echo "nameserver 8.8.8.8" > "$CHROOT/etc/resolv.conf"

# Remover repos de update para 11.4
if [ "$version" == "11.4" ]; then
    rm -f "$CHROOT/etc/zypp/repos.d/"*update*.repo 2>/dev/null || true
fi

# ==============================================================================
# Paso 5: mychroot.conf
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
Service:/etc/init.d/cron
# Service:/etc/init.d/rsyslog
EOFMYCHROOT
chmod 640 "$CHROOT/etc/mychroot.conf"

# ==============================================================================
# Paso 6: Configurar arquitectura
# ==============================================================================
if [ "$arch" == "i586" ]; then
    info "Configurando arquitectura i586..."
    echo "arch = i586" >> "$CHROOT/etc/zypp/zypp.conf" 2>/dev/null || true
fi

# ==============================================================================
# Paso 7: Re-montar y actualizar con zypper
# ==============================================================================
echo ""
info "Re-montando jaula..."
"$(dirname "$0")/mount_umount-chroot.sh" "$NOMBRE_JAULA" umount 2>/dev/null || true
"$(dirname "$0")/mount_umount-chroot.sh" "$NOMBRE_JAULA" mount

# Actualizar con zypper
echo ""
info "Actualizando con zypper..."
chroot "$CHROOT" zypper --non-interactive --no-gpg-checks update || \
    advertencia "La actualización con zypper tuvo errores"

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
exito "Jaula de openSUSE Leap $version creada exitosamente."
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
