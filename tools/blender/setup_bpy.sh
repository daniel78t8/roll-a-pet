#!/usr/bin/env bash
# Installiert Blender als Python-Modul (bpy) fuer die headless Arbeit im Cloud-Container.
#   bash tools/blender/setup_bpy.sh [venv-ordner]
# BPY_VERSION an die Blender-Version auf dem eigenen Rechner anpassen, damit die .blend-Dateien
# dort ohne Versionsprobleme aufgehen (bpy 5.x braucht Python 3.13, bpy 4.x Python 3.11).
set -euo pipefail
BPY_VERSION="${BPY_VERSION:-5.2.2}"
VENV="${1:-$HOME/.venv-bpy}"
case "$BPY_VERSION" in
  4.*) PY=python3.11 ;;
  *)   PY=python3.13 ;;
esac
"$PY" -m venv "$VENV"
"$VENV/bin/pip" install -q "bpy==$BPY_VERSION"
# EEVEE und Workbench brauchen libEGL (Software-Rendering ueber Mesa); Cycles CPU laeuft ohne
if ! ldconfig -p | grep -q 'libEGL.so.1'; then
  apt-get install -y -q libegl1 libegl-mesa0 || echo "libEGL fehlt: nur Cycles verfuegbar"
fi
"$VENV/bin/python" -c "import bpy; print('Blender', bpy.app.version_string, 'bereit')"
