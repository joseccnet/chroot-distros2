#!/bin/bash
#
# Elimina una jaula chroot de forma segura.
# Autor: josecc@gmail.com
#
# IMPORTANTE: Este script elimina permanentemente la jaula y todos sus archivos.
# Se requiere confirmación explícita y verificación de desmontaje previo.
#
# Uso:
#   $0 NombreJaula           # Desmonta y elimina la jaula
#   $0 NombreJaula umountonly # Solo desmonta sin eliminar
#   $0 --list                # Lista todas las jaulas disponibles
#

set -euo pipefail

source "$(dirname "$0")/chroot.conf"
source "$(dirname "$0")/lib/chroot-lib.sh"

# ==============================================================================
# Función de limpieza ante errores
# ==============================================================================
limpieza() {
    local codigo_salida=$?
    if [ $codigo_salida -ne 0 ]; then
        error_msg "Operación falló con código de salida $codigo_salida"
        if [ -n "${CHROOT:-}" ]; then
            echo "   Jaula afectada: $CHROOT"
            echo "   Verifique el estado con: $0 --list"
        fi
    fi
    exit $codigo_salida
}
trap limpieza EXIT

# ==============================================================================
# Auditoría de dependencias
# ==============================================================================
declare -A DEPENDENCIAS_RM=(
    ["rm"]="coreutils"
    ["mount"]="util-linux"
    ["grep"]="grep"
    ["awk"]="gawk"
    ["realpath"]="coreutils"
    ["du"]="coreutils"
    ["sleep"]="coreutils"
    ["basename"]="coreutils"
    ["dirname"]="coreutils"
)
auditar_dependencias DEPENDENCIAS_RM

# ==============================================================================
# Verificar privilegios de root
# ==============================================================================
if [ "$(id -u)" -ne 0 ]; then
    error_msg "Este script debe ejecutarse como root"
    echo "   Ejecute: sudo $0 $*"
    exit 1
fi

# ==============================================================================
# Listar jaulas disponibles
# ==============================================================================
listar_jaulas() {
    echo ""
    echo -e "${CIAN}+ Jaulas disponibles en $ROOTJAIL :${NC}"
    echo ""

    if [ ! -d "$ROOTJAIL" ]; then
        info "Directorio $ROOTJAIL no existe. No hay jaulas creadas."
        exit 0
    fi

    local contador=0
    for jaula in "$ROOTJAIL"/*/; do
        # Verificar que sea un directorio válido
        [ -d "$jaula" ] || continue

        local nombre
        nombre=$(basename "$jaula")
        contador=$((contador + 1))

        # Verificar si tiene filesystems montados
        if mount | grep -q "on $ROOTJAIL/$nombre "; then
            echo -e "  ${AMARILLO}●${NC} $nombre ${AMARILLO}(montada)${NC}"
        else
            echo -e "  ${VERDE}○${NC} $nombre (desmontada)"
        fi
    done

    if [ $contador -eq 0 ]; then
        info "No se encontraron jaulas en $ROOTJAIL"
    else
        echo ""
        info "Total: $contador jaula(s)"
    fi

    echo ""
    exit 0
}

# ==============================================================================
# Verificar que no hay filesystems montados
# ==============================================================================
verificar_desmontado() {
    local chroot_path="$1"
    local nombre="$2"

    local montados
    montados=$(mount | grep "$chroot_path" | awk '{print $3}' 2>/dev/null || true)

    if [ -n "$montados" ]; then
        error_msg "La jaula '$nombre' aún tiene filesystems montados:"
        echo "$montados" | while read -r punto; do
            echo "   $punto"
        done
        echo ""
        info "Intentando desmontar automáticamente..."

        if ! "$(dirname "$0")/mount_umount-chroot.sh" "$nombre" umount; then
            error_msg "No se pudo desmontar automáticamente"
            echo ""
            echo "   Desmonte manualmente antes de eliminar:"
            echo "   $(dirname "$0")/mount_umount-chroot.sh $nombre umount"
            echo ""
            echo "   O fuerce el desmontaje:"
            echo "   umount -l $chroot_path"
            exit 1
        fi

        # Verificar nuevamente
        sleep 1
        montados=$(mount | grep "$chroot_path" | awk '{print $3}' 2>/dev/null || true)
        if [ -n "$montados" ]; then
            error_msg "FileSystem aún montados después del intento"
            echo "$montados" | while read -r punto; do
                echo "   $punto"
            done
            exit 1
        fi

        exito "Filesystems desmontados exitosamente"
    fi

    return 0
}

# ==============================================================================
# Validar nombre de jaula
# ==============================================================================
validar_nombre() {
    local nombre="$1"

    # Verificar que no esté vacío
    if [ -z "$nombre" ]; then
        error_msg "Nombre de jaula no puede estar vacío"
        exit 1
    fi

    # Protecciones contra borrado accidental del sistema
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

    # Verificar que no contenga ".."
    if [[ "$nombre" == *".."* ]]; then
        error_msg "Nombre de jaula inválido: no se permite '..' en el nombre"
        exit 1
    fi

    # Verificar que sea un directorio relativo a ROOTJAIL
    local ruta_completa="$ROOTJAIL/$nombre"
    local ruta_real
    ruta_real=$(realpath "$ruta_completa" 2>/dev/null || echo "$ruta_completa")

    # Verificar que la ruta real esté dentro de ROOTJAIL
    if [[ "$ruta_real" != "$ROOTJAIL"* ]]; then
        error_msg "La ruta de la jaula no está dentro de $ROOTJAIL"
        echo "   Ruta solicitada: $ruta_completa"
        echo "   Ruta resuelta: $ruta_real"
        exit 1
    fi

    # Verificar que el directorio exista
    if [ ! -d "$ruta_completa" ]; then
        error_msg "La jaula no existe: $ruta_completa"
        echo ""
        info "Jaulas disponibles:"
        listar_jaulas
    fi

    return 0
}

# ==============================================================================
# Mostrar ayuda
# ==============================================================================
mostrar_ayuda() {
    echo " - - - - - - - - - - - - - - - - - -"
    echo -e "Elimina una jaula chroot de forma segura"
    echo " - - - - - - - - - - - - - - - - - -"
    echo ""
    echo "Uso:"
    echo "  $0 NombreJaula              # Desmonta y elimina la jaula"
    echo "  $0 NombreJaula umountonly   # Solo desmonta sin eliminar"
    echo "  $0 --list                   # Lista todas las jaulas disponibles"
    echo "  $0 --help                   # Muestra esta ayuda"
    echo ""
    echo "Advertencia:"
    echo "  Esta operación es IRREVERSIBLE. Todos los archivos de la jaula"
    echo "  serán eliminados permanentemente."
    echo ""
    echo "Ejemplos:"
    echo "  $0 mi-ubuntu"
    echo "  $0 mi-debian umountonly"
    echo "  $0 --list"
    echo ""
    exit 0
}

# ==============================================================================
# INICIO DEL SCRIPT PRINCIPAL
# ==============================================================================

# Verificar argumentos
if [ $# -eq 0 ] || [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    mostrar_ayuda
fi

# Comando: --list
if [ "$1" == "--list" ] || [ "$1" == "-l" ]; then
    listar_jaulas
fi

NOMBRE_JAULA="$1"
ACCION="${2:-delete}"

# Validar nombre
validar_nombre "$NOMBRE_JAULA"

CHROOT="$ROOTJAIL/$NOMBRE_JAULA"

# ==============================================================================
# Comando: umountonly
# ==============================================================================
if [ "$ACCION" == "umountonly" ] || [ "$ACCION" == "umount" ]; then
    echo ""
    echo " - - - - - - - - - - - - - - - - - -"
    info "Desmontando jaula: $NOMBRE_JAULA"
    echo " - - - - - - - - - - - - - - - - - -"
    echo ""

    # Verificar si hay algo montado
    if ! mount | grep -q "$CHROOT"; then
        info "No hay filesystems montados para la jaula '$NOMBRE_JAULA'"
        exito "Jaula $NOMBRE_JAULA está desmontada"
        exit 0
    fi

    # Desmontar
    if "$(dirname "$0")/mount_umount-chroot.sh" "$NOMBRE_JAULA" umount; then
        exito "Jaula $NOMBRE_JAULA desmontada exitosamente"
    else
        error_msg "Falló el desmontaje de la jaula $NOMBRE_JAULA"
        exit 1
    fi

    exit 0
fi

# ==============================================================================
# Comando: delete (desmontar y eliminar)
# ==============================================================================

echo ""
echo " - - - - - - - - - - - - - - - - - -"
advertencia "ELIMINACIÓN DE JAULA"
echo " - - - - - - - - - - - - - - - - - -"
echo ""
echo "   Jaula:     $NOMBRE_JAULA"
echo "   Ruta:      $CHROOT"
echo ""

# Calcular tamaño de la jaula
tamano=$(du -sh "$CHROOT" 2>/dev/null | awk '{print $1}')
if [ -n "$tamano" ]; then
    echo "   Tamaño:    $tamano"
    echo ""
fi

# Verificar que no hay filesystems montados
info "Verificando desmontaje..."
verificar_desmontado "$CHROOT" "$NOMBRE_JAULA"

# Confirmación explícita
echo ""
advertencia "ATENCIÓN: Esta operación eliminará PERMANENTEMENTE la jaula y todos sus archivos."
echo "   Esta acción NO se puede deshacer."
echo ""

# Verificar si se solicita confirmación forzada
if [ "${FORZAR_ELIMINACION:-}" != "true" ]; then
    read -p "¿Está seguro de que desea eliminar la jaula '$NOMBRE_JAULA'? (escriba 'ELIMINAR' para confirmar): " confirmacion

    if [ "$confirmacion" != "ELIMINAR" ]; then
        info "Operación cancelada por el usuario."
        exit 0
    fi
else
    info "Eliminación forzada (FORZAR_ELIMINACION=true)"
fi

# Eliminar la jaula
echo ""
info "Eliminando $CHROOT ..."

if rm -rf "$CHROOT"; then
    # Verificar que se eliminó
    if [ -d "$CHROOT" ]; then
        error_msg "La jaula no se eliminó completamente: $CHROOT"
        echo "   Verifique manualmente: ls -la $CHROOT"
        exit 1
    fi

    echo ""
    exito "Jaula '$NOMBRE_JAULA' eliminada exitosamente"
    info "Ruta eliminada: $CHROOT"
else
    error_msg "Falló la eliminación de la jaula: $CHROOT"
    echo "   Verifique permisos y que no haya procesos activos"
    exit 1
fi

echo ""
echo " - - - - - - - - - - RESUMEN - - - - - - - - - -"
echo ""
exito "Operación completada"
echo ""

# Mostrar jaulas restantes
info "Jaulas restantes:"
for jaula in "$ROOTJAIL"/*/; do
    [ -d "$jaula" ] || continue
    nombre=$(basename "$jaula")
    if mount | grep -q "on $ROOTJAIL/$nombre "; then
        echo -e "  ${AMARILLO}●${NC} $nombre (montada)"
    else
        echo -e "  ${VERDE}○${NC} $nombre"
    fi
done

echo " - - - - - - - - - - - - - - - - - -"
echo ""

exit 0
