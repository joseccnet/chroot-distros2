#!/bin/bash
# Ejecute para revisar si hay actualizaciones o mejoras en los archivos del proyecto
set -euo pipefail

cd "$(dirname "$0")"

# Verificar integridad del repositorio
if ! git fsck --no-dangling 2>/dev/null; then
    echo "⚠ Repositorio con errores, reconstruyendo índice..."
    rm -f .git/index
    git reset HEAD -- . 2>/dev/null || true
fi

# Obtener la rama actual
rama=$(git symbolic-ref --short HEAD 2>/dev/null || echo "master")

# Verificar que el remote exista
if ! git remote -v 2>/dev/null | grep -q fetch; then
    echo "⚠ No hay remote configurado. Agregando remote por defecto..."
    git remote add origin https://github.com/joseccnet/chroot-distros2.git
fi

echo "Actualizando desde origin/$rama ..."
git fetch --all

if git rev-parse --verify "origin/$rama" >/dev/null 2>&1; then
    git reset --hard "origin/$rama"
    chmod 750 *.sh
    echo "✅ Actualización completada."
else
    echo "⚠ La rama '$rama' no existe en el remote."
    echo "   Revise las ramas disponibles: git branch -r"
    exit 1
fi
