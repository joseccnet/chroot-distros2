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
    echo "Actualizando chroot-distros2 en $DESTINO ..."
    cd "$DESTINO"
    git fetch origin

    RAMA=$(git remote show origin 2>/dev/null | grep 'HEAD branch' | awk '{print $NF}' || echo "")
    if [ -z "$RAMA" ]; then
        RAMA=$(git symbolic-ref --short HEAD 2>/dev/null || echo "main")
    fi

    if git rev-parse --verify "origin/$RAMA" >/dev/null 2>&1; then
        git reset --hard "origin/$RAMA"
    else
        echo "⚠ No se encontró la rama '$RAMA' en el remoto."
        echo "  Ramas disponibles:"
        git branch -r 2>/dev/null | sed 's/^/  /'
        exit 1
    fi
    chmod 750 *.sh
    echo "✅ Actualización completada."
else
    echo "Descargando chroot-distros2 en $DESTINO ..."
    git clone "$REPO_URL" "$DESTINO"
    chmod 750 "$DESTINO"/*.sh
    echo "✅ Descarga completada."
    echo ""
    echo "Las jaulas se crean en /opt/jaulas2 (configurable en chroot.conf)"
fi
