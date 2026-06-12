#!/bin/bash
#
# Clona una jaula chroot existente sin reinstalar desde cero.
# Author: josecc@gmail.com
#
# Desmonta la jaula origen, la clona con rsync y preserva
# permisos, hardlinks, ACLs y atributos extendidos.
#
# Uso:
#   $0 origen destino
#
# Ejemplo:
#   $0 mi-debian copia-seguridad
#

set -euo pipefail

source "$(dirname "$0")/chroot.conf"
source "$(dirname "$0")/lib/chroot-lib.sh"

# ==============================================================================
# Auditoría de dependencias
# ==============================================================================
declare -A DEPENDENCIAS_CLONE=(
    ["rsync"]="rsync"
    ["mount"]="util-linux"
    ["grep"]="grep"
    ["awk"]="gawk"
    ["sed"]="sed"
    ["cp"]="coreutils"
    ["rm"]="coreutils"
    ["mkdir"]="coreutils"
    ["basename"]="coreutils"
    ["dirname"]="coreutils"
)
auditar_dependencias DEPENDENCIAS_CLONE

# ==============================================================================
# Función de limpieza ante errores
# ==============================================================================
limpieza() {
    local codigo_salida=$?
    if [ $codigo_salida -ne 0 ]; then
        error_msg "La clonación falló con código de salida $codigo_salida"
        if [ -n "${ORIGEN:-}" ] && [ -n "${DESTINO:-}" ]; then
            echo "   Origen: $ORIGEN"
            echo "   Destino: $DESTINO"
            if [ -d "${DESTINO:-}" ]; then
                echo "   Puede existir un clon parcial en: $DESTINO"
                echo "   Limpiar con: rm -rf $DESTINO"
            fi
        fi
    fi
    exit $codigo_salida
}
trap limpieza EXIT

# ==============================================================================
# Mostrar ayuda
# ==============================================================================
mostrar_ayuda() {
    echo " - - - - - - - - - - - - - - - - - -"
    echo -e "Clona una jaula chroot existente"
    echo " - - - - - - - - - - - - - - - - - -"
    echo ""
    echo "Uso:"
    echo "  $0 origen destino"
    echo ""
    echo "  origen   : Nombre de la jaula existente a clonar"
    echo "  destino  : Nombre de la nueva jaula (no debe existir)"
    echo ""
    echo "Ejemplos:"
    echo "  $0 mi-debian copia-seguridad"
    echo "  $0 prod-ubuntu test-ubuntu"
    echo ""
    echo "Notas:"
    echo "  - La jaula origen se desmontará antes de clonar"
    echo "  - Después de clonar, monta manualmente las jaulas:"
    echo "      sudo ./mount_umount-chroot.sh origen mount"
    echo "      sudo ./mount_umount-chroot.sh destino mount"
    echo "  - Los directorios /proc, /dev, /sys, /tmp, /run, /mnt, /media"
    echo "    se excluyen automáticamente de la clonación"
    echo ""
    exit 0
}

# ==============================================================================
# INICIO DEL SCRIPT PRINCIPAL
# ==============================================================================

# Verificar argumentos
if [ $# -lt 2 ] || [ "${1:-}" == "--help" ] || [ "${1:-}" == "-h" ]; then
    mostrar_ayuda
fi

verificar_root

# Validar nombres
validar_nombre_jaula "${1:-}"
validar_nombre_jaula "${2:-}"

ORIGEN="$ROOTJAIL/$1"
DESTINO="$ROOTJAIL/$2"

# Validar que origen exista
if [ ! -d "$ORIGEN" ]; then
    error_msg "La jaula origen no existe: $ORIGEN"
    echo "   Jaulas disponibles:"
    if [ -d "$ROOTJAIL" ]; then
        for j in "$ROOTJAIL"/*/; do
            [ -d "$j" ] && echo "   - $(basename "$j")"
        done
    fi
    exit 1
fi

# Validar que destino no exista
if [ -d "$DESTINO" ]; then
    error_msg "La jaula destino ya existe: $DESTINO"
    echo "   La clonación no sobrescribe jaulas existentes."
    echo "   Borre la existente o elija otro nombre."
    exit 1
fi

# Resumen
echo ""
echo " - - - - - - - - - - - - - - - - - -"
echo -e "Clonando jaula chroot"
echo " - - - - - - - - - - - - - - - - - -"
echo -e "Origen:  $ORIGEN"
echo -e "Destino: $DESTINO"
echo ""
echo -e "${AMARILLO}⚠ ATENCIÓN: La jaula origen SERÁ DESMONTADA durante la clonación.${NC}"
echo "   Después de clonar, deberá montarla manualmente."
echo ""

read -p "¿Desea continuar con la clonación? (s/N): " confirmacion
if [[ ! "$confirmacion" =~ ^[sSyY]$ ]]; then
    info "Clonación cancelada por el usuario."
    exit 0
fi

# Verificar si origen está montado y desmontar
montado=$(mount | grep "^$ORIGEN/" | awk '{print $3}' 2>/dev/null || true)
if [ -n "$montado" ]; then
    echo ""
    info "Desmontando jaula origen $1 ..."
    if "$(dirname "$0")/mount_umount-chroot.sh" "$1" umount; then
        exito "Jaula origen desmontada"
    else
        advertencia "No se pudo desmontar completamente. Continuando..."
    fi
    echo ""
fi

# Clonar con rsync
info "Clonando $1 → $2 ..."
echo ""
rsync -aHAX \
    --exclude=/proc \
    --exclude=/dev \
    --exclude=/sys \
    --exclude=/tmp \
    --exclude=/run \
    --exclude=/mnt \
    --exclude=/media \
    --exclude=/lost+found \
    --progress \
    "$ORIGEN/" "$DESTINO/" || {
    error_msg "Falló rsync. Revise los mensajes anteriores."
    exit 1
}

echo ""
exito "rsync completado exitosamente."

# Ajustar resumen-construcción del clon
if [ -f "$DESTINO/etc/resumen-construccion.txt" ]; then
    sed -i "s/$1/$2/g" "$DESTINO/etc/resumen-construccion.txt" 2>/dev/null || true
    info "Resumen de construcción actualizado en el clon."
fi

# Ajustar mychroot.conf si existe (comentar FS para evitar montajes duplicados)
if [ -f "$DESTINO/etc/mychroot.conf" ]; then
    info "Archivo mychroot.conf copiado. Revíselo antes de montar: $DESTINO/etc/mychroot.conf"
fi

echo ""
echo " - - - - - - - - - - RESUMEN - - - - - - - - - -"
echo ""
echo -e "${VERDE}✓ Clonación completada exitosamente.${NC}"
echo ""
echo -e "${CIAN}IMPORTANTE: Monte las jaulas manualmente:${NC}"
echo ""
echo "   sudo ./mount_umount-chroot.sh $1 mount"
echo "   sudo ./mount_umount-chroot.sh $2 mount"
echo ""
echo -e "${AMARILLO}⚠ La jaula origen fue desmontada. No olvide montarla de nuevo.${NC}"
echo " - - - - - - - - - - - - - - - - - -"
echo ""

exit 0
