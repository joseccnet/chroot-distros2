# ==============================================================================
# Librería compartida para chroot-distros2
# Funciones de color, mensajes, auditoría y verificación
# ==============================================================================

# PATH seguro
export PATH="/usr/sbin:/usr/bin:/sbin:/bin"

# ==============================================================================
# Colores para salida
# ==============================================================================
ROJO='\033[0;31m'
VERDE='\033[0;32m'
AMARILLO='\033[1;33m'
AZUL='\033[0;34m'
CIAN='\033[0;36m'
NC='\033[0m'

# ==============================================================================
# Funciones de mensajes
# ==============================================================================
info() {
    echo -e "${CIAN}ℹ INFO:${NC} $1"
}

exito() {
    echo -e "${VERDE}✓ ÉXITO:${NC} $1"
}

advertencia() {
    echo -e "${AMARILLO}⚠ ADVERTENCIA:${NC} $1"
}

error_msg() {
    echo -e "${ROJO}✗ ERROR:${NC} $1" >&2
}

# ==============================================================================
# Logging de operaciones
# ==============================================================================
LOG_FILE="${LOG_FILE:-/var/log/chroot-mounts.log}"

log_operation() {
    local operacion="$1"
    local chroot="$2"
    local resultado="$3"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp}|${operacion}|${chroot}|${resultado}" >> "$LOG_FILE" 2>/dev/null || true
}

# ==============================================================================
# Conjuntos predefinidos de dependencias
# Se usan como base para los arrays específicos de cada script
# ==============================================================================

# Herramientas base de coreutils (presentes en todo Linux)
declare -A DEP_COREUTILS=(
    ["cp"]="coreutils" ["rm"]="coreutils" ["mkdir"]="coreutils"
    ["cat"]="coreutils" ["chmod"]="coreutils" ["date"]="coreutils"
    ["sort"]="coreutils" ["basename"]="coreutils" ["dirname"]="coreutils"
    ["sleep"]="coreutils" ["ln"]="coreutils" ["realpath"]="coreutils"
    ["chroot"]="coreutils" ["id"]="coreutils" ["df"]="coreutils"
    ["echo"]="coreutils" ["uname"]="coreutils"
)

# Herramientas de texto
declare -A DEP_TEXT=(
    ["awk"]="gawk" ["sed"]="sed" ["grep"]="grep"
)

# Herramientas de red
declare -A DEP_NET=(
    ["wget"]="wget"
)

# Herramientas para sistemas basados en Debian
declare -A DEP_DEBIAN=(
    ["debootstrap"]="debootstrap"
    ["gpg"]="gnupg"
)

# Herramientas para sistemas basados en RPM
declare -A DEP_RPM=(
    ["yum"]="yum" ["rpm"]="rpm" ["sha256sum"]="coreutils"
)

# Herramientas de gestión de jaulas
declare -A DEP_JAULA=(
    ["mount"]="util-linux" ["umount"]="util-linux"
    ["mountpoint"]="util-linux" ["fuser"]="psmisc"
)

# ==============================================================================
# Auditoría de dependencias
# Recibe un nombre de variable (nameref) con un array asociativo
#   declare -A DEPS=([cmd]="package" ...)
#   auditar_dependencias DEPS
# ==============================================================================
auditar_dependencias() {
    local -n deps="$1"
    local faltantes=0

    info "Auditoría de dependencias del sistema..."

    for cmd in "${!deps[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            error_msg "Falta comando crítico: '$cmd' (Paquete: ${deps[$cmd]})"
            faltantes=$((faltantes + 1))
        fi
    done

    if [ "$faltantes" -gt 0 ]; then
        echo ""
        error_msg "Auditoría fallida. Faltan $faltantes herramientas necesarias."
        echo "   Para solucionar esto, instale los paquetes mencionados arriba."
        exit 1
    fi

    exito "Auditoría de dependencias superada."
}

# ==============================================================================
# Verificar ejecución como root
# ==============================================================================
verificar_root() {
    if [ "$(id -u)" -ne 0 ]; then
        error_msg "Este script debe ejecutarse como root"
        echo "   Ejecute: sudo $0 $*"
        exit 1
    fi
}

# ==============================================================================
# Verificar espacio en disco
#   verificar_espacio_disco /ruta [minimo_gb]
# ==============================================================================
verificar_espacio_disco() {
    local ruta="$1"
    local minimo="${2:-2}"
    local disponible

    disponible=$(df -BG "$ruta" 2>/dev/null | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ -z "$disponible" ]; then
        error_msg "No se pudo determinar el espacio disponible en $ruta"
        exit 1
    fi
    if [ "$disponible" -lt "$minimo" ]; then
        error_msg "Espacio en disco insuficiente en $ruta"
        echo "   Se necesitan al menos ${minimo}GB, hay ${disponible}GB disponibles"
        exit 1
    fi
}

# ==============================================================================
# Validar nombre de jaula (seguridad)
# ==============================================================================
validar_nombre_jaula() {
    local nombre="$1"

    if [ -z "$nombre" ]; then
        error_msg "Nombre de jaula no puede estar vacío"
        exit 1
    fi

    case "$nombre" in
        "/"|"/root"|"/etc"|"/usr"|"/var"|"/home"|"/bin"|"/sbin"|"/lib"|"/boot")
            error_msg "Nombre de jaula inválido: '$nombre' es una ruta crítica del sistema"
            exit 1
            ;;
        ".."|"."|""|"\\"|"*")
            error_msg "Nombre de jaula inválido: '$nombre' contiene caracteres especiales peligrosos"
            exit 1
            ;;
    esac

    if [[ "$nombre" == *".."* ]]; then
        error_msg "Nombre de jaula inválido: no se permite '..' en el nombre"
        exit 1
    fi
}

# ==============================================================================
# Verificar conectividad a mirror
# ==============================================================================
verificar_mirror() {
    local url="$1"
    local nombre="${2:-mirror}"

    if ! wget --spider -q "$url" 2>/dev/null; then
        advertencia "No se pudo contactar $nombre: $url"
        return 1
    fi
    return 0
}

# ==============================================================================
# Mostrar separador
# ==============================================================================
mostrar_separador() {
    echo -e "${AZUL}─────────────────────────────────────${NC}"
}
