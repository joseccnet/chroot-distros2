#!/bin/bash
# Ejecute para revisar si hay actualizaciones o mejoras en los archivos del proyecto
set -euo pipefail

cd "$(dirname "$0")"
git fetch --all
git reset --hard "origin/$(git symbolic-ref --short HEAD 2>/dev/null || echo master)"
chmod 750 *.sh
