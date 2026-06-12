#!/bin/bash
#
# Build a chroot with a Linux Mint base install.
# Linux Mint se construye sobre una base Ubuntu + repositorios Mint.
# Author: josecc@gmail.com
#
# Linux Mint = Ubuntu base + paquetes Mint
# LM 22.x  → Ubuntu 24.04 (Noble)
# LM 21.x  → Ubuntu 22.04 (Jammy)
# LM 20.x  → Ubuntu 20.04 (Focal)
# LM 19.x  → Ubuntu 18.04 (Bionic)
# LM 18.x  → Ubuntu 16.04 (Xenial)
# LM 17.x  → Ubuntu 14.04 (Trusty)
#
# --arch amd64, i386

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
# Versiones soportadas de Linux Mint
# ==============================================================================
VERSIONES_SOPORTADAS=(
    # Mint 22.x (basado en Ubuntu 24.04 Noble) — LTS activas
    "zena"        # 22.3
    "zara"        # 22.2
    "xia"         # 22.1
    "wilma"       # 22.0
    # Mint 21.x (basado en Ubuntu 22.04 Jammy) — LTS activas
    "virginia"    # 21.3
    "vera"        # 21.2
    "victoria"    # 21.1
    "vanessa"     # 21.0
    # Versiones legacy (EOL)
    "una"         # 20.3 - Ubuntu 20.04 Focal
    "uma"         # 20.2 - Ubuntu 20.04 Focal
    "ulyssa"      # 20.1 - Ubuntu 20.04 Focal
    "ulyana"      # 20.0 - Ubuntu 20.04 Focal
    "tricia"      # 19.3 - Ubuntu 18.04 Bionic
    "tina"        # 19.2 - Ubuntu 18.04 Bionic
    "tessa"       # 19.1 - Ubuntu 18.04 Bionic
    "tara"        # 19.0 - Ubuntu 18.04 Bionic
    "sylvia"      # 18.3 - Ubuntu 16.04 Xenial
    "sonya"       # 18.2 - Ubuntu 16.04 Xenial
    "serena"      # 18.1 - Ubuntu 16.04 Xenial
    "sarah"       # 18.0 - Ubuntu 16.04 Xenial
    "rosa"        # 17.3 - Ubuntu 14.04 Trusty
    "rafaela"     # 17.2 - Ubuntu 14.04 Trusty
    "rebecca"     # 17.1 - Ubuntu 14.04 Trusty
    "qiana"       # 17.0 - Ubuntu 14.04 Trusty
)

# Mapa de versión Mint → Ubuntu base
declare -A MINT_A_UBUNTU=(
    # Mint 22.x — Noble (24.04)
    ["zena"]="noble"
    ["zara"]="noble"
    ["xia"]="noble"
    ["wilma"]="noble"
    # Mint 21.x — Jammy (22.04)
    ["virginia"]="jammy"
    ["vera"]="jammy"
    ["victoria"]="jammy"
    ["vanessa"]="jammy"
    # Mint 20.x
    ["una"]="focal"
    ["uma"]="focal"
    ["ulyssa"]="focal"
    ["ulyana"]="focal"
    # Mint 19.x
    ["tricia"]="bionic"
    ["tina"]="bionic"
    ["tessa"]="bionic"
    ["tara"]="bionic"
    # Mint 18.x
    ["sylvia"]="xenial"
    ["sonya"]="xenial"
    ["serena"]="xenial"
    ["sarah"]="xenial"
    # Mint 17.x
    ["rosa"]="trusty"
    ["rafaela"]="trusty"
    ["rebecca"]="trusty"
    ["qiana"]="trusty"
)

# Estado de versiones
declare -A VERSIONES_ESTADO=(
    # Mint 22.x — LTS activas
    ["zena"]="LTS activa (Ubuntu 24.04 Noble, soporte hasta Abr 2029)"
    ["zara"]="LTS activa (Ubuntu 24.04 Noble, soporte hasta Abr 2029)"
    ["xia"]="LTS activa (Ubuntu 24.04 Noble, soporte hasta Abr 2029)"
    ["wilma"]="LTS activa (Ubuntu 24.04 Noble, soporte hasta Abr 2029)"
    # Mint 21.x — LTS activas
    ["virginia"]="LTS activa (Ubuntu 22.04 Jammy, soporte hasta Abr 2027)"
    ["vera"]="LTS activa (Ubuntu 22.04 Jammy, soporte hasta Abr 2027)"
    ["victoria"]="LTS activa (Ubuntu 22.04 Jammy, soporte hasta Abr 2027)"
    ["vanessa"]="LTS activa (Ubuntu 22.04 Jammy, soporte hasta Abr 2027)"
    # Legacy EOL
    ["una"]="EOL"
    ["uma"]="EOL"
    ["ulyssa"]="EOL"
    ["ulyana"]="EOL"
    ["tricia"]="EOL"
    ["tina"]="EOL"
    ["tessa"]="EOL"
    ["tara"]="EOL"
    ["sylvia"]="EOL"
    ["sonya"]="EOL"
    ["serena"]="EOL"
    ["sarah"]="EOL"
    ["rosa"]="EOL"
    ["rafaela"]="EOL"
    ["rebecca"]="EOL"
    ["qiana"]="EOL"
)

# Información de versiones
declare -A VERSIONES_INFO=(
    # Mint 22.x
    ["zena"]="22.3 - Ubuntu 24.04 Noble"
    ["zara"]="22.2 - Ubuntu 24.04 Noble"
    ["xia"]="22.1 - Ubuntu 24.04 Noble"
    ["wilma"]="22.0 - Ubuntu 24.04 Noble"
    # Mint 21.x
    ["virginia"]="21.3 - Ubuntu 22.04 Jammy"
    ["vera"]="21.2 - Ubuntu 22.04 Jammy"
    ["victoria"]="21.1 - Ubuntu 22.04 Jammy"
    ["vanessa"]="21.0 - Ubuntu 22.04 Jammy"
    # Legacy
    ["una"]="20.3 - Ubuntu 20.04 Focal (EOL)"
    ["uma"]="20.2 - Ubuntu 20.04 Focal (EOL)"
    ["ulyssa"]="20.1 - Ubuntu 20.04 Focal (EOL)"
    ["ulyana"]="20.0 - Ubuntu 20.04 Focal (EOL)"
    ["tricia"]="19.3 - Ubuntu 18.04 Bionic (EOL)"
    ["tina"]="19.2 - Ubuntu 18.04 Bionic (EOL)"
    ["tessa"]="19.1 - Ubuntu 18.04 Bionic (EOL)"
    ["tara"]="19.0 - Ubuntu 18.04 Bionic (EOL)"
    ["sylvia"]="18.3 - Ubuntu 16.04 Xenial (EOL)"
    ["sonya"]="18.2 - Ubuntu 16.04 Xenial (EOL)"
    ["serena"]="18.1 - Ubuntu 16.04 Xenial (EOL)"
    ["sarah"]="18.0 - Ubuntu 16.04 Xenial (EOL)"
    ["rosa"]="17.3 - Ubuntu 14.04 Trusty (EOL)"
    ["rafaela"]="17.2 - Ubuntu 14.04 Trusty (EOL)"
    ["rebecca"]="17.1 - Ubuntu 14.04 Trusty (EOL)"
    ["qiana"]="17.0 - Ubuntu 14.04 Trusty (EOL)"
)

# Versiones EOL (para advertencia)
declare -A VERSIONES_EOL=(
    ["una"]="1"
    ["uma"]="1"
    ["ulyssa"]="1"
    ["ulyana"]="1"
    ["tricia"]="1"
    ["tina"]="1"
    ["tessa"]="1"
    ["tara"]="1"
    ["sylvia"]="1"
    ["sonya"]="1"
    ["serena"]="1"
    ["sarah"]="1"
    ["rosa"]="1"
    ["rafaela"]="1"
    ["rebecca"]="1"
    ["qiana"]="1"
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

obtener_ubuntu_base() {
    local version="${1:-}"
    echo "${MINT_A_UBUNTU[$version]:-noble}"
}

es_version_eol() {
    local version="${1:-}"
    [[ -n "${VERSIONES_EOL[$version]+x}" ]]
}

# ==============================================================================
# Generar repositorio Mint dinámicamente
# ==============================================================================
generar_repos_mint() {
    local chroot_path="$1"
    local version="$2"
    local ubuntu_base="$3"
    local mirror_ubuntu="${MIRROR_UBUNTU:-http://archive.ubuntu.com/ubuntu}"
    local mirror_seguridad="${MIRROR_SEGURIDAD:-http://security.ubuntu.com/ubuntu}"
    local mirror_canonical="${MIRROR_CANONICAL:-http://archive.canonical.com/ubuntu}"
    local mirror_mint="${MIRROR_MINT:-http://packages.linuxmint.com}"

    mkdir -p "$chroot_path/etc/apt/preferences.d"
    mkdir -p "$chroot_path/etc/apt/sources.list.d"

    # Generar sources.list para repos Mint
    cat > "$chroot_path/etc/apt/sources.list.d/official-package-repositories.list" << SOURCES
# Do not edit this file manually, use Software Sources instead.

deb $mirror_mint $version main upstream import backport #id:linuxmint_main

deb $mirror_ubuntu $ubuntu_base main restricted universe multiverse
deb $mirror_ubuntu $ubuntu_base-updates main restricted universe multiverse
deb $mirror_ubuntu $ubuntu_base-backports main restricted universe multiverse

deb $mirror_seguridad/ $ubuntu_base-security main restricted universe multiverse
deb $mirror_canonical/ $ubuntu_base partner
SOURCES

    # Generar preferences (prioridades apt)
    cat > "$chroot_path/etc/apt/preferences.d/official-package-repositories.pref" << PREFERENCES
Package: *
Pin: origin live.linuxmint.com
Pin-Priority: 750

Package: *
Pin: release o=linuxmint,c=upstream
Pin-Priority: 700

Package: *
Pin: release o=Ubuntu
Pin-Priority: 500
PREFERENCES

    exito "Repositorios de Linux Mint generados dinámicamente"
}

# ==============================================================================
# Verificaciones previas
# ==============================================================================
verificaciones_previas() {
    info "Iniciando verificaciones de sistema..."

    declare -A DEPENDENCIAS_BUILD=(
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

    verificar_root

    verificar_espacio_disco "$ROOTJAIL" 2

    case "$arch" in
        amd64|i386) ;;
        x86_64) arch="amd64" ;;
        *)
            error_msg "Arquitectura no soportada: $arch"
            echo "   Soportadas: amd64, i386"
            exit 1
            ;;
    esac

    exito "Verificaciones previas completadas"
    echo ""
}

# ==============================================================================
# Generar resumen
# ==============================================================================
generar_resumen() {
    local archivo_resumen="$CHROOT/etc/resumen-construccion.txt"
    local info_version="${VERSIONES_INFO[$version]:-desconocida}"
    local ubuntu_base
    ubuntu_base=$(obtener_ubuntu_base "$version")

    cat > "$archivo_resumen" << EOF
===============================================================================
Resumen de Construcción del Chroot Linux Mint
===============================================================================
Fecha:              $(date)
Versión Mint:       $version ($info_version)
Base Ubuntu:        $ubuntu_base
Arquitectura:       $arch
Ruta del Chroot:    $CHROOT

Estado: EXITOSO

NOTAS:
- Linux Mint es una instalación base mínima sobre Ubuntu
- Para paquetes adicionales: apt-cache search mint | grep ^mint
- Revise /etc/mychroot.conf para configurar filesystems y servicios
- Repositorios Mint configurados en:
    /etc/apt/sources.list.d/official-package-repositories.list
    /etc/apt/preferences.d/official-package-repositories.pref

FIN DEL RESUMEN
===============================================================================
EOF
    chmod 644 "$archivo_resumen"
    info "Resumen guardado en: $archivo_resumen"
}

# ==============================================================================
# Ayuda
# ==============================================================================
mostrar_ayuda() {
    echo " - - - - - - - - - - - - - - - - - -"
    echo -e "$0 creará una jaula con Linux Mint"
    echo " - - - - - - - - - - - - - - - - - -"
    echo ""
    echo "Versiones de Linux Mint soportadas:"
    echo ""
    echo "  Mint 22.x (Ubuntu 24.04 Noble) — LTS activa:"
    echo "   zena      - 22.3  (latest)"
    echo "   zara      - 22.2"
    echo "   xia       - 22.1"
    echo "   wilma     - 22.0"
    echo ""
    echo "  Mint 21.x (Ubuntu 22.04 Jammy) — LTS activa:"
    echo "   virginia  - 21.3"
    echo "   vera      - 21.2"
    echo "   victoria  - 21.1"
    echo "   vanessa   - 21.0"
    echo ""
    echo "  Legacy (EOL):"
    echo "   20.x (una, uma, ulyssa, ulyana)"
    echo "   19.x (tricia, tina, tessa, tara)"
    echo "   18.x (sylvia, sonya, serena, sarah)"
    echo "   17.x (rosa, rafaela, rebecca, qiana)"
    echo ""
    echo "Uso:"
    echo "  $0 NombreJaula [versión [arquitectura]]"
    echo ""
    echo "Ejemplos:"
    echo "  $0 mi-mint                 # Por defecto: wilma (22.0)"
    echo "  $0 mi-mint zena"
    echo "  $0 mi-mint vanessa amd64"
    echo "  $0 mi-mint virginia i386"
    echo ""
    echo "Variables de entorno:"
    echo "  FORZAR_EOL=true            : Omite confirmación para versiones EOL"
    echo "  MIRROR_UBUNTU=<url>        : Mirror personalizado de Ubuntu"
    echo "  MIRROR_MINT=<url>          : Mirror personalizado de Linux Mint"
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

# Validar arquitectura
case "$arch" in
    x86_64) arch="amd64" ;;
    amd64|i386) ;;
    *)
        error_msg "Arquitectura no soportada: $arch"
        echo "   Soportadas: amd64, i386"
        exit 1
        ;;
esac

# Si no hay versión, usar wilma (22.0 - LTS activa)
if [ -z "$version" ]; then
    version="wilma"
    info "Usando versión por defecto: $version (Linux Mint 22.0 - LTS)"
fi

# Validar versión
if ! validar_version "$version"; then
    error_msg "Versión de Linux Mint no soportada: $version"
    echo "   Versiones soportadas: ${VERSIONES_SOPORTADAS[*]}"
    exit 1
fi

# Verificaciones previas
verificaciones_previas

# Obtener Ubuntu base
ubuntu_base=$(obtener_ubuntu_base "$version")
info "Linux Mint $version se basa en Ubuntu $ubuntu_base"

# Advertencia de EOL solo para versiones legacy
if es_version_eol "$version"; then
    echo ""
    advertencia "Linux Mint $version (${VERSIONES_INFO[$version]}) es una versión EOL"
    echo "   - Sin actualizaciones de seguridad garantizadas"
    echo "   - Considere usar una versión activa de Linux Mint"
    echo ""
    if [ "${FORZAR_EOL:-}" != "true" ]; then
        read -p "¿Desea continuar de todos modos? (s/N): " respuesta
        if [[ ! "$respuesta" =~ ^[sSyY]$ ]]; then
            info "Operación cancelada."
            exit 0
        fi
    fi
fi

# Resumen de operación
echo ""
echo " - - - - - - - - - - - - - - - - - -"
echo -e "Instalando Linux Mint Chroot"
echo -e " - - - - - - - - - - - - - - - - - -"
echo -e "Jaula:        $CHROOT"
echo -e "Versión Mint: $version (${VERSIONES_INFO[$version]})"
echo -e "Base Ubuntu:  $ubuntu_base"
echo -e "Arquitectura: $arch"
echo " - - - - - - - - - - - - - - - - - -"
echo ""

# ==============================================================================
# Paso 1: Construir base Ubuntu
# ==============================================================================
info "Paso 1: Construyendo base Ubuntu $ubuntu_base..."
if "$(dirname "$0")/build-chroot-Ubuntu.sh" "$NOMBRE_JAULA" "$ubuntu_base" "$arch"; then
    exito "Base Ubuntu construida exitosamente"
else
    error_msg "Falló la construcción de la base Ubuntu"
    exit 1
fi

# ==============================================================================
# Paso 2: Configurar repositorios Mint
# ==============================================================================
info "Paso 2: Configurando repositorios de Linux Mint..."

# Buscar archivos de repos predefinidos, o generarlos dinámicamente
pref_dir="$(dirname "$0")/linuxMint"

# Determinar el prefijo de archivo según la versión
declare -A PREFIJOS_ARCHIVOS=(
    ["zena"]="22_zena"
    ["zara"]="22_zara"
    ["xia"]="22_xia"
    ["wilma"]="22_wilma"
    ["virginia"]="21_virginia"
    ["vera"]="21_vera"
    ["victoria"]="21_victoria"
    ["vanessa"]="21_vanessa"
    ["una"]="20.3_una"
    ["uma"]="20.2_uma"
    ["ulyssa"]="20.1_ulyssa"
    ["ulyana"]="20_ulyana"
    ["tricia"]="19.3_tricia"
    ["tina"]="19.2_tina"
    ["tessa"]="19.1_tessa"
    ["tara"]="19_tara"
    ["sylvia"]="18.3_sylvia"
    ["sonya"]="18.2_sonya"
    ["serena"]="18.1_serena"
    ["sarah"]="18_sarah"
    ["rosa"]="17.3_rosa"
    ["rafaela"]="17.2_rafaela"
    ["rebecca"]="17.1_rebecca"
    ["qiana"]="17_qiana"
)

prefijo="${PREFIJOS_ARCHIVOS[$version]:-19_tara}"
pref_file="$pref_dir/${prefijo}_etc_apt_preferences.d_official-package-repositories.pref"
sources_file="$pref_dir/${prefijo}_etc_apt_sources.list.d_official-package-repositories.list"

if [ -f "$pref_file" ] && [ -f "$sources_file" ]; then
    mkdir -p "$CHROOT/etc/apt/preferences.d"
    mkdir -p "$CHROOT/etc/apt/sources.list.d"

    cp -vf "$pref_file" "$CHROOT/etc/apt/preferences.d/official-package-repositories.pref"
    cp -vf "$sources_file" "$CHROOT/etc/apt/sources.list.d/official-package-repositories.list"

    exito "Repositorios de Linux Mint configurados desde archivos"
else
    info "Generando repositorios de Linux Mint dinámicamente para $version..."
    generar_repos_mint "$CHROOT" "$version" "$ubuntu_base"
fi

# ==============================================================================
# Paso 3: Actualizar sistema y paquetes Mint
# ==============================================================================
echo ""
info "Paso 3: Actualizando sistema y configurando Linux Mint..."

# Limpiar cache
chroot "$CHROOT" /bin/bash -c "apt-get clean all" 2>/dev/null || true

# Importar claves GPG de Mint y configurar paquetes base
chroot "$CHROOT" /bin/bash -c "
    apt-get -y update 2>/dev/null || true
    apt-get -y install --reinstall mintsystem mint-keyring base-files 2>/dev/null || true
    apt-get -y dist-upgrade 2>/dev/null || true
    apt-get clean all 2>/dev/null || true
" || advertencia "Algunos pasos de configuración de Mint fallaron, pero la instalación continúa"

# Workaround para error con libpam-systemd
local_pam_postinst=$(find "$CHROOT/var/lib/dpkg/info/" -name 'libpam-systemd*postinst' 2>/dev/null | head -1)
if [ -n "$local_pam_postinst" ]; then
    info "Aplicando workaround para libpam-systemd..."
    sed -i -e 's/exit \$?/exit 0/' "$local_pam_postinst" 2>/dev/null || true
fi

# Actualización final
chroot "$CHROOT" /bin/bash -c "apt-get -y update && apt-get -y upgrade && apt-get clean all" 2>/dev/null || \
    advertencia "La actualización final tuvo errores. Revise manualmente dentro del chroot."

# ==============================================================================
# Paso 4: Re-montar jaula
# ==============================================================================
echo ""
info "Paso 4: Re-montando jaula..."
fuser -TERM -k "$CHROOT/" 2>/dev/null || true
sleep 1
fuser -KILL -k "$CHROOT/" 2>/dev/null || true
"$(dirname "$0")/mount_umount-chroot.sh" "$NOMBRE_JAULA" umount 2>/dev/null || true
"$(dirname "$0")/mount_umount-chroot.sh" "$NOMBRE_JAULA" mount

# ==============================================================================
# Resumen final
# ==============================================================================
generar_resumen

echo ""
echo " - - - - - - - - - - RESUMEN - - - - - - - - - -"
echo ""
echo -e "${VERDE}Dispositivos montados:${NC}"
mount | grep "$CHROOT" | awk '{print $3}' | sort -r
echo ""
echo "IMPORTANTE!!! Revisa el archivo $CHROOT/etc/mychroot.conf y configúralo según tus necesidades."
echo ""
exito "La jaula de Linux Mint $version fue creada exitosamente."
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

opt="
# Opcional:
#
# + Como usuario root:
#   chroot $CHROOT
#
# + Usuarios NO root:
#   cp /usr/sbin/chroot /usr/sbin/chrootuser    (como root, una sola vez)
#   setcap cap_sys_chroot+ep /usr/sbin/chrootUser (como root, una sola vez)
#   /usr/sbin/chrootUser $CHROOT                 (como NO root)
#
# Nota: Linux Mint es una instalación base mínima.
#       Para paquetes adicionales:
#       - apt-cache search mint | grep ^mint
#       - apt-get update, apt-get install ...
"
echo -e "$opt"

exit 0
