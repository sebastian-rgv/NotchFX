#!/usr/bin/env bash
# fx.sh — script de ejemplo que se ejecuta desde la isla de NotchFX.
#
# NotchFX lo corre tal cual (interpretado con /bin/zsh) cada vez que abres el
# Terminal desde el menú de la barra de menús o con el atajo Opt+Cmd+T. La salida
# (stdout y stderr) se transmite en vivo al notch.
#
# Edítalo con lo que necesites: comandos, deploys, tareas de build, etc.
set -euo pipefail

echo "fx.sh — $(date '+%Y-%m-%d %H:%M:%S')"
echo "Host:     $(hostname)"
echo "Usuario:  $(whoami)"
echo "Directorio: $(pwd)"
echo

for step in 1 2 3; do
    echo "Paso $step/3…"
    sleep 1
done

echo "Listo."
