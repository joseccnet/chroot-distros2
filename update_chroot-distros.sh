#!/bin/bash
# Descarga la última versión de chroot-distros2 desde GitHub
# Uso: ./update_chroot-distros.sh

set -euo pipefail

REPO_URL="https://github.com/joseccnet/chroot-distros2.git"
DESTINO="$(cd "$(dirname "$0")" && pwd)"

# Verificar que git esté instalado
if ! command -v git &>/dev/null; then
    echo "ERROR: git no está instalado."
    echo "  Instálelo: sudo apt-get install git   (Debian/Ubuntu)"
    echo "             sudo yum install git        (CentOS/RHEL)"
    echo "             sudo dnf install git        (Fedora)"
    exit 1
fi

if [ -d "$DESTINO/.git" ]; then
    # Ya es un repositorio: actualizar
    echo "Actualizando chroot-distros2 en $DESTINO ..."
    cd "$DESTINO"
    git fetch origin
    git reset --hard "origin/$(git symbolic-ref --short HEAD 2>/dev/null || echo master)"
    chmod 750 *.sh
    echo "✅ Actualización completada."
else
    # No existe: clonar en el directorio actual
    echo "Descargando chroot-distros2 en $DESTINO ..."
    CLONAR_EN="$(dirname "$DESTINO")"
    NOMBRE_DIR="$(basename "$DESTINO")"
    cd "$CLONAR_EN"
    git clone "$REPO_URL" "$NOMBRE_DIR"
    chmod 750 "$DESTINO"/*.sh
    echo "✅ Descarga completada."
    echo ""
    echo "Las jaulas se crean en /opt/jaulas2 (configurable en chroot.conf)"
fi
